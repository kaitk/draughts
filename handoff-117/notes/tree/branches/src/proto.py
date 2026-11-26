# The proposed growth, prototyped in Python for the notes (not the generator): every node
# an asymmetric fork after Gao and Newberry 2025 (PNAS Nexus pgaf003, github.com/mnewberry/
# treescale grove.js), taken to 3D, with the maple's terms added: thickness by Leonardo's
# rule (alpha), the fork's angles from its asymmetry, a tropism that turns thick wood up and
# lets long thin wood spread and sag, broken leaders with stubs and a side shoot taking over
# (reiteration), shaded twigs dying back to stubs inside the crown, and the leaves only at
# the shoot tips, in opposite pairs, their blades laid flat and turned to the light.
#
#   python3 proto.py OUT_DIR
import sys, math, time, random, numpy as np
from draw import render

UP = np.array([0.0, 1.0, 0.0])

def norm(v):
    n = np.linalg.norm(v)
    return v / n if n > 1e-9 else v

def turned(d, tilt, roll):
    """d turned by tilt away from itself, at roll about it (as trees::turned)."""
    other = UP if abs(d[1]) < 0.9 else np.array([1.0, 0, 0])
    u = norm(np.cross(d, other)); w = np.cross(d, u)
    side = u * math.cos(roll) + w * math.sin(roll)
    return norm(d * math.cos(tilt) + side * math.sin(tilt))

def ball(rng):
    while True:
        v = np.array([rng.uniform(-1, 1) for _ in range(3)])
        if v @ v <= 1: return v

def mixed(x):
    x = (x + 0x9E3779B97F4A7C15) & 0xFFFFFFFFFFFFFFFF
    x = ((x ^ (x >> 30)) * 0xBF58476D1CE4E5B9) & 0xFFFFFFFFFFFFFFFF
    x = ((x ^ (x >> 27)) * 0x94D049BB133111EB) & 0xFFFFFFFFFFFFFFFF
    return x ^ (x >> 31)

# The published baseline's terms (grove.js) and the maple's.
BASELINE = dict(alpha=2.0, beta=2.0, maxasym=4.0, spread=1.0, wind=0.3, wind_dir=UP, sag=0.0, rise=0.0,
                breaks=0.0, dieback=False, pieces=1, decussate=False, leaves='none', crook=0.0)
MAPLE = dict(alpha=2.3, beta=2.0, maxasym=6.0, spread=1.0, wind=0.0, sag=0.24, rise=0.25,
             breaks=0.06, dieback=True, pieces=3, decussate=True, leaves='tips', crook=0.05, elastic=True, codominant=True)

class Tree:
    def __init__(self):
        self.seg = []      # a.xyz b.xyz ra rb kind (0 wood, 1 stub)
        self.leaves = []   # foot base along face size width kind tint

class Crown:
    """The envelope, an ellipsoid about middle with half sizes size (metres)."""
    def __init__(self, middle, size): self.middle = np.array(middle); self.size = np.array(size)
    def radius(self, p): return float(np.linalg.norm((p - self.middle) / self.size))
    def out(self, p): return norm(p - self.middle)
    def depth(self, p): return max(1.0 - self.radius(p), 0.0) * float(self.size.min())

def grow(t, crown, P, at, d, length, r, rmin, seed, sun, tint=1.0, depth=0):
    """One axis from `at`, then its fork, recursively; seeded per node so a culled part keeps the rest."""
    rng = random.Random(mixed(seed))
    # The segment, bent in pieces: thick wood rises, thin long wood sags, then turns up at its end.
    n = P['pieces'] if r > rmin * 4 else 1
    p = at.copy(); rr = r
    thin = clamp01(1.0 - math.log(r / rmin) / math.log(60.0))   # 0 thick .. 1 a twig
    for k in range(n):
        level_out = 1.0 - abs(d[1])
        bend = UP * (P['rise'] * (1.0 - thin) * 0.5 - P['sag'] * thin * (0.3 + level_out)) * (1.0 / n)
        bend += ball(rng) * P['crook']
        d = norm(d + bend)
        q = p + d * (length / n)
        rb = r * (1.0 - 0.06 * (k + 1) / n)
        t.seg.append((*p, *q, rr, rb, 0)); p = q; rr = rb
    # Out of the crown: stop here, a tip.
    if r < rmin or crown.radius(p) > 1.05:
        tip(t, crown, P, p, d, rng, sun, tint)
        return
    # Inside the crown's core, thin wood is shaded: it died back, leaving a short stub.
    if P["dieback"] and r < rmin * 2.5 and crown.depth(p) > 2.0 and rng.random() < 0.7:
        if rng.random() < 0.3:
            q = p + d * length * rng.uniform(0.2, 0.5)
            t.seg.append((*p, *q, rr, rr * 0.8, 1))
        return
    # The fork: asymmetry a in 1..maxasym, the thinner child leaves wide, the thicker narrow.
    A = P['maxasym']
    if P.get('codominant'):
        # Thick wood forks near evenly (the old tree's codominant stems), thin wood unevenly.
        A = 1.7 if r > 0.2 else 3.0 if r > 0.08 else A
    a = 1.0 / (rng.random() * (1.0 - 1.0 / A) + 1.0 / A)
    minr = (1.0 / (1.0 + a ** P['alpha'])) ** (1.0 / P['alpha']); majr = a * minr
    minl = (1.0 / (1.0 + a ** P['beta'])) ** (1.0 / P['beta']); majl = a * minl
    majt = math.atan(1.0 / a) * P['spread']; mint = math.atan(a) * P['spread']
    roll = rng.uniform(0, 2 * math.pi)
    if P['decussate']:
        # Opposite buds, each pair a quarter turn from the last, at random which of the pair grew.
        roll = depth * math.pi * 0.5 + (math.pi if rng.random() < 0.5 else 0.0) + rng.uniform(-0.3, 0.3)
    dmaj = turned(d, majt, roll + math.pi); dmin = turned(d, mint, roll)
    if P['wind'] > 0:
        dmaj = norm(dmaj * (1 - P['wind']) + P['wind_dir'] * P['wind'])
        dmin = norm(dmin * (1 - P['wind']) + P['wind_dir'] * P['wind'])
    else:
        # The maple's: side shoots lean out of the crown and level out (plagiotropy), more as they thin.
        out = crown.out(p); out[1] *= 0.3
        dmin = norm(dmin + out * 0.35 + UP * 0.1)
    if P.get('elastic'):
        # Elastic similarity (McMahon and Kronauer 1976): length goes as radius^(2/3), so twigs are slender.
        lmaj = max(length * majr ** (2 / 3) * rng.uniform(0.8, 1.2), 0.06)
        lmin = max(length * minr ** (2 / 3) * rng.uniform(0.8, 1.2), 0.06)
    else:
        lmaj, lmin = length * max(majl, 0.55), length * max(minl, 0.35)
    # A broken leader: the thicker child is a stub, the thinner takes over, thicker, turned up and out.
    if P['breaks'] > 0 and rmin * 8 < r < rmin * 60 and rng.random() < P['breaks']:
        q = p + dmaj * lmaj * rng.uniform(0.15, 0.4)
        t.seg.append((*p, *q, r * majr, r * majr * 0.85, 1))
        out = crown.out(p)
        dmin = norm(turned(d, rng.uniform(0.5, 0.9), roll) + UP * 0.25 + out * 0.2)
        grow(t, crown, P, p, dmin, length, r * 0.85, rmin, seed * 2 + 1, sun, tint, depth + 1)
        return
    grow(t, crown, P, p, dmaj, lmaj, r * majr, rmin, seed * 2, sun, tint, depth + 1)
    grow(t, crown, P, p, dmin, lmin, r * minr, rmin, seed * 2 + 1, sun, tint, depth + 1)

def clamp01(x): return 0.0 if x < 0 else 1.0 if x > 1 else x

def tip(t, crown, P, p, d, rng, sun, tint):
    """A shoot's tip: the current year's shoot with its leaves in opposite pairs."""
    if P['leaves'] == 'none': return
    if P['dieback'] and crown.depth(p) > 2.6: return
    # The shoot: a short last segment, two nodes on it, the tip's pair and one a quarter turn below.
    shoot = 0.10
    q = p + d * shoot
    t.seg.append((*p, *q, 0.003, 0.002, 0))
    out = crown.out(q)
    goal = norm(UP * 1.0 + sun * 0.35 + out * 0.25)   # the blade's face: up, and a little to the sun
    for node, at in enumerate((q, p + d * shoot * 0.45)):
        roll0 = rng.uniform(0, math.pi) + node * math.pi * 0.5
        for k in range(2):
            side = turned(d, math.pi * 0.5, roll0 + k * math.pi)
            # The stalk spreads the pair apart and bends the blade level: one pointing down gets
            # a longer stalk so its blade reaches past the twig (the leaf mosaic).
            stalk_dir = norm(side + d * (0.6 if node == 0 else 0.25))
            down = max(-stalk_dir[1], 0.0)
            size = 0.11 * rng.uniform(0.85, 1.15) * (1.15 if node == 1 else 1.0)
            stalk = size * (0.7 + 0.6 * down + (0.3 if node == 1 else 0.0)) * rng.uniform(0.9, 1.1)
            level = norm(np.array([stalk_dir[0], 0.0, stalk_dir[2]]) + 1e-6)
            base = at + norm(stalk_dir + UP * 0.25) * stalk * 0.6 + level * stalk * 0.4
            face = norm(goal + ball(rng) * 0.25)
            along = level - face * (level @ face) - UP * 0.15
            along = norm(along - face * (along @ face))
            t.leaves.append((*at, *base, *along, *face, size, size * 1.15, 0, tint + rng.uniform(-0.1, 0.1)))

def arrays(t):
    s = np.array(t.seg, dtype=np.float32) if t.seg else np.zeros((0, 9), np.float32)
    l = np.array(t.leaves, dtype=np.float32) if t.leaves else np.zeros((0, 16), np.float32)
    return s, l

def hero_tree(P, seed=7, leaves=True):
    """The old-leader maple's frame as our Whole has it (22 m, fork at 3 m, limbs 62..28 degrees
    off the trunk), every limb grown by forks."""
    rng = random.Random(seed)
    t = Tree()
    crown = Crown((0.0, 12.5, 0.0), (10.0, 9.5, 9.0))
    sun = norm(np.array([-0.36, 0.35, 1.0]))
    P = dict(P)
    if not leaves: P['leaves'] = 'none'
    if P.get('codominant'):
        # A short trunk, then forks all the way: the stems, the limbs and the twigs alike.
        p = np.zeros(3); d = UP.copy()
        for i in range(4):
            d = norm(d + ball(rng) * 0.04)
            q = p + d * 1.0
            t.seg.append((*p, *q, 0.5 * (1.25 if i == 0 else 1.0) - 0.02 * i, 0.5 - 0.02 * (i + 1), 0)); p = q
        grow(t, crown, P, p, d, 1.5, 0.42, 0.006, seed * 1000, sun)
        # The low limb toward the house, as Whole's hang.
        grow(t, crown, P, np.array([0, 2.7, 0.0]), turned(UP, math.radians(70), 1.0), 0.8, 0.2, 0.006, seed * 1000 + 7, sun)
        return t
    # The trunk, a little crooked, up to the leader's 65 %.
    p = np.zeros(3); d = UP.copy(); top = 0.65 * 22.0
    pts = [p.copy()]; r0 = 0.5
    steps = 14
    for i in range(steps):
        d = norm(d + ball(rng) * 0.05 + UP * 0.02)
        q = p + d * (top / steps)
        r = r0 * (1.0 - 0.55 * (i + 1) / steps) * (1.25 if i == 0 else 1.0)
        t.seg.append((*p, *q, r0 * (1.0 - 0.55 * i / steps), r, 0)); p = q; pts.append(p.copy())
    # The limbs in a spiral from the fork up, wide low, steep high; and the leader's crown.
    limbs = 11
    for c in range(limbs):
        f = (c + rng.uniform(0.3, 1.0)) / limbs
        h = 3.0 + (top - 3.0) * f
        i = min(int(h / top * steps), steps - 1)
        at = pts[i] + (pts[i + 1] - pts[i]) * ((h / top * steps) - i)
        tilt = math.radians(62 + (28 - 62) * f + rng.uniform(-10, 10))
        d = turned(UP, tilt, c * 2.39996 + rng.uniform(-0.3, 0.3))
        r = 0.5 * (1 - 0.55 * f) * math.sqrt(0.22 * rng.uniform(0.75, 1.25))
        grow(t, crown, P, at, d, (0.6 + 0.3 * (1 - f)) if P.get('elastic') else 2.2 + 1.2 * (1 - f), r, 0.006, seed * 1000 + c, sun)
    grow(t, crown, P, p, UP, 0.7 if P.get('elastic') else 2.0, r0 * 0.45, 0.006, seed * 1000 + 99, sun)
    return t

def hero_limb(P, seed=3, leaves=False, length=None, r=0.16, rmin=0.006):
    """One low limb leaving the trunk at 70 degrees, for the side view against the photo's limb."""
    t = Tree()
    crown = Crown((0.0, 0.0, 0.0), (10.0, 10.0, 10.0))
    sun = norm(np.array([-0.36, 0.35, 1.0]))
    P = dict(P)
    if not leaves: P['leaves'] = 'none'
    if length is None: length = 0.6 if P.get('elastic') else 2.0
    grow(t, crown, P, np.zeros(3), turned(UP, math.radians(72), math.pi * 0.5), length, r, rmin, seed, sun)
    return t

def main():
    out = sys.argv[1]
    for name, P in (('baseline', BASELINE), ('maple', MAPLE)):
        t0 = time.perf_counter(); t = hero_tree(P, leaves=False); dt = time.perf_counter() - t0
        s, _ = arrays(t)
        print(name, 'tree bare:', len(s), 'segments', f'{dt * 1000:.0f} ms (Python)')
        render(s, None, 620, 1000).save(f'{out}/proto-{name}-bare.png')
        t = hero_limb(P, seed=5); s, _ = arrays(t)
        print(name, 'limb:', len(s), 'segments')
        render(s, None, 1000, 800).save(f'{out}/proto-{name}-limb.png')
    # The maple's whole tree in leaf, its counts and time.
    t0 = time.perf_counter(); t = hero_tree(MAPLE, leaves=True); dt = time.perf_counter() - t0
    s, l = arrays(t)
    print('maple tree in leaf:', len(s), 'segments', len(l), 'leaves', f'{dt * 1000:.0f} ms (Python)')
    np.save(f'{out}/../dump/proto-maple-seg.npy', s); np.save(f'{out}/../dump/proto-maple-leaves.npy', l)
    render(s, l[::3], 620, 1000, stalks=False).save(f'{out}/proto-maple-leafy.png')
    # A leafy branch, as the AI image's: a limb of 1.6 m, seen from the side and a little below.
    t = hero_limb(dict(MAPLE, dieback=False), seed=11, leaves=True, length=0.35, r=0.035, rmin=0.005)
    s, l = arrays(t)
    print('maple branch:', len(s), 'segments', len(l), 'leaves')
    pts = np.vstack([s[:, 0:3], s[:, 3:6], l[:, 3:6]])
    render(s, l, 1000, 760, yaw=90, pitch=-12, frame_pts=pts).save(f'{out}/proto-maple-branch.png')

if __name__ == '__main__':
    main()
