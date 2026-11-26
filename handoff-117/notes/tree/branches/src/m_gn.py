# Method d: Gao and Newberry's asymmetric forks (PNAS Nexus 2025, pgaf003; grove.js in
# github.com/mnewberry/treescale), taken to 3D, with Palubicki et al. 2009's tropism per
# piece of wood, weighted by thickness, in place of grove.js's single "wind" pull.
#
# grove.js, as published (2D, SVG): every node forks in two. Asymmetry a = 1/(u(1-1/A)+1/A),
# u uniform, A = maxasym = 4. Radii: minor (1/(1+a^alpha))^(1/alpha), major a times that
# (r^alpha kept at the fork, alpha 1..3 in its demo). Lengths the same with beta = 2. The
# thin side leaves at atan(a), the thick at atan(1/a), on opposite sides (rot = cos(pi u)
# is a uniform roll seen in 2D). Then each child's angle is blended 30 % toward 81 degrees
# (wind). Stops when the radius is under 0.5 (its units).
# The notes' terms for the maple (the task's): alpha 2.3 (Leonardo's rule, 2..2.5 in the
# paper), A 6, the fork's plane a quarter turn from the last (opposite buds), the
# lengths scaled by the room ahead to the envelope, broken leaders, dieback in the core.
import math, random, numpy as np
from graph import Graph, Arr, Crown, UP, norm, turned, mixed

P0 = dict(alpha=2.3, beta=2.0, maxasym=6.0, pieces=3, eta_up=0.6, eta_level=0.25, crook=0.04,
          out=0.30, breaks=0.10, stub=(0.15, 0.4), turn=(30, 50), rmin=0.006,
          trunk_to=4.5, r0=0.42, l0=1.8, dieback=True, room=True)


def thinness(r, rmin):
    """0 thick (40 cm) .. 1 a twig."""
    return min(max(1.0 - math.log(max(r, rmin) / rmin) / math.log(0.4 / rmin), 0.0), 1.0)


def ball(rng):
    while True:
        v = np.array([rng.uniform(-1, 1) for _ in range(3)])
        if v @ v <= 1: return v


def grow(g, crown, P, node, d, length, r, seed, depth, roll_prev):
    rng = random.Random(mixed(seed))
    rmin = P['rmin']
    # The piece, bent per part by the tropism (Palubicki's weighted sum): thick wood up,
    # thin wood level and down; a little crook.
    n = P['pieces'] if r > rmin * 4 else 1
    th = thinness(r, rmin)
    p = g.pos[node]; rr = r
    for k in range(n):
        # thick wood is pulled up (orthotropic), thin wood toward level (plagiotropic):
        # growth's own tropism only; the weight's sag is the gravity layer's.
        trop = UP * (P['eta_up'] * (1.0 - th) ** 2 - P['eta_level'] * th * d[1])
        d = norm(d + trop / n + ball(rng) * P['crook'])
        q = p + d * (length / n)
        rb = r * (1.0 - 0.05 * (k + 1) / n)
        node = g.add(node, q, rr, rb); p = q; rr = rb
    if r < rmin or crown.radius(p) > 1.04:
        return
    # Shaded thin wood in the core died back; some of it left as a stub.
    if P['dieback'] and r < rmin * 3 and crown.depth(p) > 2.2 and rng.random() < 0.7:
        if rng.random() < 0.3:
            g.add(node, p + d * length * rng.uniform(0.2, 0.5), rr, rr * 0.8, kind=1)
        return
    A = P['maxasym']
    a = 1.0 / (rng.random() * (1.0 - 1.0 / A) + 1.0 / A)
    minr = (1.0 / (1.0 + a ** P['alpha'])) ** (1.0 / P['alpha']); majr = a * minr
    minl = (1.0 / (1.0 + a ** P['beta'])) ** (1.0 / P['beta']); majl = a * minl
    roll = roll_prev + math.pi * 0.5 + rng.uniform(-0.3, 0.3) + (math.pi if rng.random() < 0.5 else 0.0)
    dmaj = turned(d, math.atan(1.0 / a), roll + math.pi)
    dmin = turned(d, math.atan(a), roll)
    out = crown.out(p); out[1] *= 0.3
    dmin = norm(dmin + out * P['out'])
    lmaj = length * majl; lmin = length * max(minl, 0.3)
    if P['room']:
        # The length from the room ahead: the forks still to come on the thick side, times
        # this length, should about reach the envelope.
        left = max(math.log(r / rmin) / 0.16, 1.0)
        for which in (0, 1):
            dd = dmaj if which == 0 else dmin
            ll = lmaj if which == 0 else lmin
            room = crown.ahead(p, dd, ll * left * 2.0)
            s = min(max(room / (ll * left), 0.55), 1.5)
            if which == 0: lmaj *= s
            else: lmin *= s
    lmaj = max(lmaj, 0.05); lmin = max(lmin, 0.05)
    # A broken leader: the thick side ends as a stub, the thin side takes over, turned.
    if P['breaks'] > 0 and 0.025 < r < 0.175 and rng.random() < P['breaks']:
        g.add(node, p + dmaj * lmaj * rng.uniform(*P['stub']), r * majr, r * majr * 0.8, kind=1)
        t = math.radians(rng.uniform(*P['turn']))
        dn = norm(turned(d, t, roll) + out * 0.15)
        grow(g, crown, P, node, dn, lmaj, r * max(majr * 0.92, minr), seed * 2 + 1, depth + 1, roll)
        return
    grow(g, crown, P, node, dmaj, lmaj, r * majr, seed * 2, depth + 1, roll)
    grow(g, crown, P, node, dmin, lmin, r * minr, seed * 2 + 1, depth + 1, roll)


def tree(seed=7, P=None, crown=None):
    P = dict(P0, **(P or {}))
    crown = crown or Crown()
    rng = random.Random(seed)
    g = Graph()
    # A short trunk, then forks all the way (the photo's tree forks at about 4.5 m).
    node = 0; d = UP.copy(); steps = 5; r0 = 0.5
    for i in range(steps):
        d = norm(d + np.array([rng.uniform(-1, 1), 0, rng.uniform(-1, 1)]) * 0.03)
        node = g.add(node, g.pos[node] + d * P['trunk_to'] / steps, r0 * (1.2 if i == 0 else 1.0 - 0.03 * i),
                     r0 * (1.0 - 0.03 * (i + 1)))
    grow(g, crown, P, node, d, P['l0'], P['r0'], seed * 1000 + 1, 0, rng.uniform(0, 6.28))
    return Arr.of(g)


def fan(seed=7, P=None):
    """A twig fan on its own: a side shoot of 1.5 cm leaving level, open space all round."""
    P = dict(P0, **(P or {})); P['dieback'] = False; P['breaks'] = 0.0
    crown = Crown((0.8, -0.3, 0.0), (1.4, 1.0, 1.2))
    g = Graph()
    grow(g, crown, P, 0, turned(UP, math.radians(80), 0.0), 0.22, 0.015, seed * 77, 0, 0.0)
    return Arr.of(g)
