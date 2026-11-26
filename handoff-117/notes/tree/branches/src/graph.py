# The shared form of every method's tree, for the comparison (task 117): a list of nodes,
# each with its parent (a smaller index), its point, and the radius of the wood from its
# parent to it (at the parent's end and at its own). Node 0 is the trunk's foot and has no
# wood. Every method fills one, so the gravity layer, the pick of a limb and a twig fan,
# and the drawing are the same for all. Metres, y up.
import math, numpy as np

UP = np.array([0.0, 1.0, 0.0])


def norm(v):
    n = float(np.linalg.norm(v))
    return v / n if n > 1e-12 else v


def turned(d, tilt, roll):
    """d turned by tilt away from itself, at roll about it (as trees::turned)."""
    other = UP if abs(d[1]) < 0.9 else np.array([1.0, 0, 0])
    u = norm(np.cross(d, other)); w = np.cross(d, u)
    side = u * math.cos(roll) + w * math.sin(roll)
    return norm(d * math.cos(tilt) + side * math.sin(tilt))


def mixed(x):
    x = (x + 0x9E3779B97F4A7C15) & 0xFFFFFFFFFFFFFFFF
    x = ((x ^ (x >> 30)) * 0xBF58476D1CE4E5B9) & 0xFFFFFFFFFFFFFFFF
    x = ((x ^ (x >> 27)) * 0x94D049BB133111EB) & 0xFFFFFFFFFFFFFFFF
    return x ^ (x >> 31)


class Graph:
    def __init__(self, root=(0.0, 0.0, 0.0)):
        self.pos = [np.array(root, float)]
        self.parent = [-1]
        self.ra = [0.0]     # radius at the parent's end
        self.rb = [0.0]     # radius at this node
        self.kind = [0]     # 0 wood, 1 stub, 2 a joint (no wood)

    def add(self, parent, p, ra, rb=None, kind=0):
        self.pos.append(np.array(p, float)); self.parent.append(parent)
        self.ra.append(ra); self.rb.append(ra if rb is None else rb); self.kind.append(kind)
        return len(self.pos) - 1

    def __len__(self):
        return len(self.pos)

    def arrays(self):
        """pos N x 3, parent N, ra N, rb N, kind N as numpy."""
        return (np.array(self.pos), np.array(self.parent), np.array(self.ra),
                np.array(self.rb), np.array(self.kind))


class Arr:
    """The graph as arrays, after growth: what the gravity layer and the drawing take."""
    def __init__(self, pos, parent, ra, rb, kind):
        self.pos, self.parent, self.ra, self.rb, self.kind = pos, parent, ra, rb, kind

    @staticmethod
    def of(g):
        return Arr(*g.arrays())

    def copy(self):
        return Arr(self.pos.copy(), self.parent.copy(), self.ra.copy(), self.rb.copy(), self.kind.copy())

    def segments(self, keep=None):
        """N x 9: a.xyz b.xyz ra rb kind, as draw.render takes."""
        i = np.arange(1, len(self.pos))
        if keep is not None:
            i = i[keep[1:]]
        i = i[self.kind[i] != 2]      # joints along an axis are not wood
        a = self.pos[self.parent[i]]; b = self.pos[i]
        return np.hstack([a, b, self.ra[i, None], self.rb[i, None], self.kind[i, None]]).astype(np.float32)

    def children(self):
        ch = [[] for _ in range(len(self.pos))]
        for i in range(1, len(self.pos)):
            ch[self.parent[i]].append(i)
        return ch

    def subtree(self, root):
        keep = np.zeros(len(self.pos), bool); keep[root] = True
        for i in range(root + 1, len(self.pos)):
            if keep[self.parent[i]]:
                keep[i] = True
        return keep


def pipe_radii(parent, n_exp, tip_r):
    """The pipe model (Shinozaki 1964, as Runions 2007 and Palubicki 2009 use it): each tip
    tip_r, and r^n of a node the sum over its children."""
    N = len(parent)
    acc = np.zeros(N)
    has_child = np.zeros(N, bool)
    has_child[parent[1:]] = True
    acc[~has_child] = tip_r ** n_exp
    for i in range(N - 1, 0, -1):
        acc[parent[i]] += acc[i]
    return acc ** (1.0 / n_exp)


def pick_limb(t, rlo=0.06, rhi=0.16, ylo=2.5, yhi=9.0):
    """A low limb for the close view: a side branch (not its parent's thickest child) of
    radius rlo..rhi leaving at ylo..yhi m, spreading more than rising, the most wood."""
    ch = t.children()
    vol = seg_volumes(t)
    sub = vol.copy()
    for i in range(len(t.pos) - 1, 0, -1):
        sub[t.parent[i]] += sub[i]
    best, bi = -1.0, -1
    for i in range(1, len(t.pos)):
        p = t.parent[i]
        if not (rlo <= t.ra[i] <= rhi and ylo <= t.pos[p][1] <= yhi):
            continue
        if t.kind[i] != 0:
            continue
        sib = ch[p]
        if t.kind[p] != 2 and (len(sib) < 2 or t.ra[i] >= max(t.ra[j] for j in sib)):
            continue
        d = norm(t.pos[i] - t.pos[p])
        if d[1] > 0.75:
            continue
        if sub[i] > best:
            best, bi = sub[i], i
    return bi


def pick_fan(t, rlo=0.008, rhi=0.02, shell=None):
    """A twig fan: a side branch of radius rlo..rhi at its base with the most tips, in the
    crown's outer part if shell (a function of the point, 0 middle .. 1 outside) is given."""
    ch = t.children()
    tips = np.array([1 if not c else 0 for c in ch], float)
    for i in range(len(t.pos) - 1, 0, -1):
        tips[t.parent[i]] += tips[i]
    best, bi = -1.0, -1
    for i in range(1, len(t.pos)):
        p = t.parent[i]
        if not (rlo <= t.ra[i] <= rhi):
            continue
        if t.kind[i] != 0:
            continue
        sib = ch[p]
        if t.kind[p] != 2 and (len(sib) < 2 or t.ra[i] >= max(t.ra[j] for j in sib)):
            continue
        if shell is not None and shell(t.pos[p]) < 0.6:
            continue
        if tips[i] > best:
            best, bi = tips[i], i
    return bi


def seg_volumes(t):
    v = np.zeros(len(t.pos))
    i = np.arange(1, len(t.pos))
    L = np.linalg.norm(t.pos[i] - t.pos[t.parent[i]], axis=1)
    r = 0.5 * (t.ra[i] + t.rb[i])
    v[i] = math.pi * r * r * L
    return v


def laid_out(t, keep, base):
    """The kept part moved so `base` (its first node's parent point) is at the origin and
    turned about the vertical so its weight lies toward +x: for the side view."""
    idx = np.nonzero(keep)[0]
    o = t.pos[t.parent[idx[0]]]
    P = t.pos - o
    c = P[idx].mean(axis=0)
    ang = math.atan2(c[2], c[0])
    ca, sa = math.cos(ang), math.sin(ang)
    R = np.array([[ca, 0, sa], [0, 1, 0], [-sa, 0, ca]])
    out = t.copy(); out.pos = P @ R.T
    return out


def stats(t):
    ch = t.children()
    tips = sum(1 for c in ch[1:] if not c)
    return dict(segments=len(t.pos) - 1, tips=tips)


class Crown:
    """The envelope, an ellipsoid about middle with half sizes size (metres), as the
    generator's Whole has it (crown 10 x 9.5 x 9 m about 12.5 m up)."""
    def __init__(self, middle=(0.0, 12.5, 0.0), size=(10.0, 9.5, 9.0)):
        self.middle = np.array(middle, float); self.size = np.array(size, float)

    def radius(self, p):
        return float(np.linalg.norm((np.asarray(p) - self.middle) / self.size))

    def radii(self, P):
        return np.linalg.norm((P - self.middle) / self.size, axis=1)

    def out(self, p):
        return norm(np.asarray(p) - self.middle)

    def depth(self, p):
        return max(1.0 - self.radius(p), 0.0) * float(self.size.min())

    def ahead(self, p, d, most):
        """How far from p along d the outside is (p inside), as crown_ahead."""
        if self.radius(p + d * most) <= 1.0:
            return most
        lo, hi = 0.0, most
        for _ in range(14):
            mid = (lo + hi) * 0.5
            if self.radius(p + d * mid) <= 1.0: lo = mid
            else: hi = mid
        return lo

    def sample(self, rng, n, below=0.0):
        """n points uniform inside, none lower than `below` m."""
        out = []
        while len(out) < n:
            v = rng.uniform(-1, 1, size=(n * 2, 3))
            v = v[np.linalg.norm(v, axis=1) <= 1.0]
            P = self.middle + v * self.size
            out.extend(P[P[:, 1] >= below])
        return np.array(out[:n])
