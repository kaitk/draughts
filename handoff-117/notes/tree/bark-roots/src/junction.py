# Junctions and the root flare on today's skeleton (tools/tree_dump's tree-none-whole.bin),
# as a method demo: the tubes as today (rings along each limb, a frame carried without
# twist), then near a junction extra rings, and every vertex moved along its normal onto
# one blended surface:
#
#   F(x) = smin(d_parent(x), d_child(x), k) - ridge(x)
#
# d_* the distance to a tapered capsule chain (the child's radius swollen into a collar at
# its foot), smin the polynomial smooth minimum (blend width k), ridge a raised fold along
# the crease on the crotch side (the branch bark ridge). A vertex whose projected point lies
# on the other limb's side of the crease stays where it was, inside the other limb, so the
# two meshes never lie on each other. The bark's grain: the parent's round coordinate is
# bent round the child's footprint by the stream function of a flow past a cylinder; in
# the blend each vertex also carries the other limb's chart and a weight, and the fragment
# blends the two samples by height.
#
# The flare: the trunk's lowest rings take 32 sides and lobes over each root; 4-7 root
# tubes with flattened sections run out and down below the ground, joined by the same
# projection.
import sys, math, time, numpy as np
sys.path.insert(0, __file__.rsplit('\\', 1)[0].rsplit('/', 1)[0])
TILE_W, TILE_H = 0.25, 0.50

# --- distance fields ---------------------------------------------------------------------

class Chain:
    """A tapered capsule chain: points (n, 3), radii (n,), and an optional collar at its
    foot: the radius times 1 + c * exp(-s / (lam * r0)) past s0 along it, more below."""
    def __init__(self, pts, rad, collar=0.0, lam=1.5, s0=0.0, under=0.6):
        self.p = np.asarray(pts, float); self.r = np.asarray(rad, float)
        self.collar, self.lam, self.s0, self.under = collar, lam, s0, under
        seglen = np.linalg.norm(np.diff(self.p, axis=0), axis=1)
        self.s = np.concatenate([[0], np.cumsum(seglen)])

    def closest(self, x):
        """For points x (m, 3): distance to the axis, the radius there, arc s, axis point,
        axis way."""
        best = np.full(len(x), 1e9); rad = np.zeros(len(x)); s = np.zeros(len(x))
        ap = np.zeros_like(x); way = np.zeros_like(x)
        for i in range(len(self.p) - 1):
            a, b = self.p[i], self.p[i + 1]; ab = b - a; L2 = ab @ ab
            t = np.clip(((x - a) @ ab) / L2, 0, 1)
            q = a + t[:, None] * ab
            d = np.linalg.norm(x - q, axis=1)
            r = self.r[i] + (self.r[i + 1] - self.r[i]) * t
            better = d - r < best - rad
            best = np.where(better, d, best); rad = np.where(better, r, rad)
            s = np.where(better, self.s[i] + t * math.sqrt(L2), s)
            ap[better] = q[better]; way[better] = ab / math.sqrt(L2)
        return best, rad, s, ap, way

    def dist(self, x, up=np.array([0, 1.0, 0])):
        d, r, s, ap, way = self.closest(x)
        if self.collar > 0:
            n = (x - ap) / np.maximum(d, 1e-9)[:, None]
            below = np.clip(-(n @ up), 0, 1)
            swell = self.collar * np.exp(-np.maximum(s - self.s0, 0) / (self.lam * self.r[0]))
            r = r * (1 + swell * (1 + self.under * below))
        return d - r

def smin(a, b, k):
    h = np.maximum(k - np.abs(a - b), 0) / k
    return np.minimum(a, b) - h * h * k * 0.25

class Junction:
    """The blended field of a parent and its children (each child with its own k)."""
    def __init__(self, parent, children, ks, ridge_h, ridge_w, lobes=None):
        self.P = parent; self.C = children; self.k = ks
        self.rh = ridge_h; self.rw = ridge_w; self.lobes = lobes

    def parts(self, x):
        dP = self.P.dist(x)
        if self.lobes is not None: dP = dP - self.lobes(x)
        dC = [c.dist(x) for c in self.C]
        return dP, dC

    def F(self, x):
        dP, dC = self.parts(x)
        f = dP
        for c, d, k, rh, rw in zip(self.C, dC, self.k, self.rh, self.rw):
            g = smin(f, d, k)
            if rh > 0:
                # the crotch: where the two surfaces' outward ways oppose (an acute angle)
                _, _, _, apP, _ = self.P.closest(x); _, _, _, apC, _ = c.closest(x)
                nP = x - apP; nP /= np.linalg.norm(nP, axis=1, keepdims=True) + 1e-9
                nC = x - apC; nC /= np.linalg.norm(nC, axis=1, keepdims=True) + 1e-9
                crotch = np.clip((-(nP * nC).sum(1) - 0.1) / 0.5, 0, 1)
                g = g - rh * np.exp(-((f - d) / rw) ** 2) * crotch * (np.abs(f - d) < k)
            f = g
        return f

    def side(self, x):
        """Which part a point belongs to: -1 the parent, i a child (nearest surface)."""
        dP, dC = self.parts(x)
        best = dP.copy(); who = np.full(len(x), -1)
        for i, d in enumerate(dC):
            who = np.where(d < best, i, who); best = np.minimum(best, d)
        return who, dP, dC

def project(J, x, n, iters=6, reach=None):
    """Move points x along their normals n onto F = 0 (secant steps on F along n)."""
    y = x.copy()
    for _ in range(iters):
        f = J.F(y); e = 1e-3
        df = (J.F(y + n * e) - f) / e
        df = np.where(np.abs(df) < 0.2, np.sign(df) * 0.2 + (df == 0) * 0.2, df)
        step = -f / df
        if reach is not None: step = np.clip(step, -reach, reach)
        y = y + n * step[:, None]
    return y

# --- tubes -------------------------------------------------------------------------------

def frame0(way):
    other = np.array([0, 1.0, 0]) if abs(way[1]) < 0.9 else np.array([1.0, 0, 0])
    s = np.cross(way, other); return s / np.linalg.norm(s)

def tube(chain, stations, sides, shift=(0.0, 0.0), tile_rounds=None, start_side=None, radius_fn=None, flat=1.0):
    """Rings at arc lengths `stations` along the chain. Returns dict of arrays: pos, nrm,
    along, uv (u in tiles round, v in tiles along), ring (int), k (side), and indices."""
    P, R, S = chain.p, chain.r, chain.s
    rounds = tile_rounds or max(math.floor(2 * math.pi * R[0] / TILE_W + 0.5), 1)
    side = start_side if start_side is not None else frame0((P[1] - P[0]) / np.linalg.norm(P[1] - P[0]))
    pos, nrm, alg, uv, ring, kk = [], [], [], [], [], []
    for j, st in enumerate(stations):
        i = min(np.searchsorted(S, st, side='right') - 1, len(P) - 2); i = max(i, 0)
        t = (st - S[i]) / max(S[i + 1] - S[i], 1e-9)
        p = P[i] + (P[i + 1] - P[i]) * t
        r = R[i] + (R[i + 1] - R[i]) * t
        way = (P[i + 1] - P[i]) / np.linalg.norm(P[i + 1] - P[i])
        side = side - way * (side @ way); side /= np.linalg.norm(side)
        up = np.cross(way, side)
        for k in range(sides + 1):
            a = 2 * math.pi * k / sides
            n = side * math.cos(a) + up * math.sin(a)
            rr = radius_fn(st, n, r) if radius_fn else r
            off = n * rr
            if flat != 1.0: off = off * np.array([1.0 / math.sqrt(flat), flat, 1.0 / math.sqrt(flat)])
            pos.append(p + off); nrm.append(n); alg.append(way)
            uv.append((k * rounds / sides + shift[0], st / TILE_H + shift[1])); ring.append(j); kk.append(k)
    idx = []
    rs = sides + 1
    for j in range(len(stations) - 1):
        for k in range(sides):
            a = j * rs + k; b = a + 1; c = a + rs; d = c + 1
            idx += [(a, c, b), (b, c, d)]
    return dict(pos=np.array(pos), nrm=np.array(nrm), along=np.array(alg), uv=np.array(uv, float),
                ring=np.array(ring), k=np.array(kk), idx=np.array(idx), rounds=rounds, sides=sides)

def recompute_normals(m):
    p = m['pos']; n = np.zeros_like(p)
    for a, b, c in ((0, 1, 2),):
        pa, pb, pc = p[m['idx'][:, 0]], p[m['idx'][:, 1]], p[m['idx'][:, 2]]
        fn = np.cross(pb - pa, pc - pa)
        for j in range(3): np.add.at(n, m['idx'][:, j], fn)
    # the seam's twin vertices (k = 0 and k = sides) share their normal
    n /= np.linalg.norm(n, axis=1, keepdims=True) + 1e-12
    # face normals wound c-b: flip to point outward like the ring's
    flip = (n * m['nrm']).sum(1) < 0
    n[flip] *= -1
    return n

# --- the skeleton -----------------------------------------------------------------------

def load(path):
    from draw import load_dump
    return load_dump(path)

def chain_of(seg, limbs, i):
    f, c = int(limbs[i, 0]), int(limbs[i, 1])
    s = seg[f:f + c]
    pts = np.vstack([s[:, 0:3], s[-1:, 3:6]]); rad = np.concatenate([s[:, 6], s[-1:, 7]])
    return pts, rad
