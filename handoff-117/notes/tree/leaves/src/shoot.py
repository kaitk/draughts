# A small Norway maple branch with its leaves, placed two ways, drawn from below, from the
# side and against the light:
#   now:      the game's rule (tree_whole.goose add_cards): four pairs along each twig's outer
#             four fifths, each a quarter turn from the last, stalks rising, blades turned
#             out and up with a random ball of 0.9 (about +-50 degrees), all flat;
#   proposed: leaves only on each tip's current shoot, the tip pair and one pair a quarter
#             turn below (decussate); on a level shoot the pair's lower leaf has the longer
#             stalk and the larger blade (Weisse 1895), the outer one of a side pair longer
#             than the inner; blades level, their tilt drawn from the measured Norway maple
#             distribution (Chianucci et al. 2018 data, Raabe et al. 2015), then nudged apart
#             in plan so they fill the gaps (the mosaic); each blade bent by the rule on the page.
# Writes ../img/shoot-*.png and ../img/shoot-stats.json.
import json, math, os, sys
import numpy as np
import leaf as L, raster as R

OUT = os.path.join(os.path.dirname(__file__), '..', 'img')
UP = np.array([0, 1.0, 0])

def norm(v): return v / (np.linalg.norm(v) + 1e-12)

def rot(v, axis, ang):
    axis = norm(axis)
    return v * math.cos(ang) + np.cross(axis, v) * math.sin(ang) + axis * np.dot(axis, v) * (1 - math.cos(ang))

def perp(d):
    p = np.cross(d, UP)
    if np.linalg.norm(p) < 1e-6: p = np.cross(d, np.array([1.0, 0, 0]))
    return norm(p)

# ---- the wood -------------------------------------------------------------------------

class Tip:
    def __init__(self, a, b, phase, mother):
        self.a, self.b, self.phase, self.mother = a, b, phase, mother   # last year's end to this year's tip

def grow_branch(rng):
    """A branch of a few years: straight-ish annual shoots that fork in opposite pairs, a
    level main axis bending down at its end. Returns segments (a, b, radius) and the tips'
    current shoots."""
    segs, tips = [], []
    def shoot(p, d, years, radius, phase, mother):
        for y in range(years):
            length = rng.uniform(0.10, 0.18) if years - y > 1 else rng.uniform(0.04, 0.08)
            d = norm(d + np.array([0, -0.12 + 0.10 * (radius < 0.004), 0]) + rng.normal(0, 0.10, 3))
            q = p + d * length
            if y == years - 1:
                tips.append(Tip(p, q, phase, mother))
            segs.append((p, q, radius))
            # the next year's pair from this node, a quarter turn on
            phase += math.pi / 2
            if years - y > 1 and radius > 0.002:
                side = rot(perp(d), d, phase)
                for sgn in (1, -1):
                    s = side * sgn
                    if s[1] < -0.6 and rng.random() < 0.8: continue    # buds below the shoot mostly stay asleep
                    if s[1] > 0.6 and rng.random() < 0.6: continue     # and many above it
                    if rng.random() < 0.15: continue
                    s = norm(s * np.array([1.0, 0.3, 1.0]))            # side shoots of a level branch lie flat
                    sd = norm(d * 0.6 + s * 0.8 + UP * 0.08)
                    shoot(q, sd, years - y - 1 if rng.random() < 0.6 else max(years - y - 2, 1), radius * 0.6, phase, d)
            p = q; radius *= 0.86
    shoot(np.zeros(3), norm(np.array([1.0, 0.05, 0.25])), 6, 0.014, 0.0, np.array([1.0, 0, 0]))
    return segs, tips

# ---- the leaves -----------------------------------------------------------------------

class Leaf:
    pass

# Norway maple blade tilt from horizontal in degrees, from the dataset (lia_stats.py): per
# crown sector, June and August pooled (summer) and 13 September (autumn).
TILT = {}
def load_tilts(csv_path):
    import csv
    rows = [r for r in csv.DictReader(open(csv_path, encoding='latin1')) if (r['Genus'], r['Species']) == ('Acer', 'platanoides')]
    for sec in ('top', 'middle', 'bottom'):
        TILT[('summer', sec)] = np.array([float(r['Angle_degree']) for r in rows if r['Canopy_sector'] == sec + ' canopy' and r['Date'] in ('14-06-13', '01-08-13')])
        TILT[('autumn', sec)] = np.array([float(r['Angle_degree']) for r in rows if r['Canopy_sector'] == sec + ' canopy' and r['Date'] == '13-09-13'])

def proposed_leaves(rng, tips, season='autumn', sector='top', blade=0.11, mosaic=True):
    leaves = []
    for t in tips:
        d = norm(t.b - t.a)
        n_len = np.linalg.norm(t.b - t.a)
        for node, at in ((0, 1.0), (1, max(0.35, 1 - 0.045 / n_len))):
            p = t.a + (t.b - t.a) * at
            side = rot(perp(d), d, t.phase + node * math.pi / 2)
            for sgn in (1, -1):
                s = side * sgn
                lf = Leaf()
                lf.node = p; lf.twig = d; lf.tip = t
                # which way the stalk points: up, down or level (its side's vertical part)
                lf.updown = s[1]
                # outer or inner of a level pair: away from the mother shoot
                outer = np.dot(s, perp(t.mother)) * np.sign(np.dot(np.cross(t.mother, d), UP) + 1e-9)
                k = 1.0 + 0.45 * (-s[1]) + 0.15 * outer * (abs(s[1]) < 0.5)   # Weisse 1895 ratios, softened
                size = blade * rng.uniform(0.85, 1.12) * (1.0 + 0.22 * (-s[1])) * (0.85 if node == 0 else 1.0)
                stalk = size * rng.uniform(0.75, 1.05) * k * (1.15 if node == 1 else 1.0)
                # the blade points out along the stalk's plan direction, level
                out = s * 0.75 + d * (0.9 if node == 0 else 0.35)
                out[1] = 0; out = norm(out) if np.linalg.norm(out) > 1e-3 else norm(np.array([d[0], 0, d[2]]))
                lf.size, lf.stalk, lf.az0 = size, stalk, math.atan2(out[2], out[0])
                lf.az = lf.az0
                # stalks fan out and rise (the shoot's up leaf higher, its down leaf lower)
                lf.drop = 0.25 * s[1]
                lf.tilt = math.radians(rng.choice(TILT[(season, sector)]))
                lf.tilt_dir = rng.uniform(-math.pi, math.pi) if rng.random() < 0.5 else 0.0   # half tip down, half any way
                leaves.append(lf)
    place(leaves)
    before = overlap(leaves)
    if mosaic: relax(leaves, rng)
    after = overlap(leaves)
    return leaves, before, after

def place(leaves):
    for lf in leaves:
        out = np.array([math.cos(lf.az), 0, math.sin(lf.az)])
        lf.base = lf.node + out * lf.stalk * 0.92 + UP * (lf.stalk * (0.22 + lf.drop))
        # the blade level, then tilted by its measured angle about an axis in the plane
        along = out.copy(); face = UP.copy()
        axis = rot(np.cross(out, UP), UP, lf.tilt_dir)
        lf.along = norm(rot(along, axis, lf.tilt)); lf.face = norm(rot(face, axis, lf.tilt))
        if lf.face[1] < 0: lf.face = -lf.face

def plan_disc(lf):
    c = lf.base + lf.along * lf.size * 0.42
    return np.array([c[0], c[2]]), lf.size * 0.5, c[1]

def overlap(leaves):
    """Share of the blades' plan area covered twice or more, on a fine grid."""
    discs = [plan_disc(lf) for lf in leaves]
    xs = [d[0][0] for d in discs]; zs = [d[0][1] for d in discs]
    x0, x1, z0, z1 = min(xs) - 0.1, max(xs) + 0.1, min(zs) - 0.1, max(zs) + 0.1
    g = 0.004
    X, Z = np.meshgrid(np.arange(x0, x1, g), np.arange(z0, z1, g))
    cnt = np.zeros_like(X)
    for c, r, _ in discs:
        cnt += ((X - c[0]) ** 2 + (Z - c[1]) ** 2 < r * r)
    covered = (cnt >= 1).sum(); twice = (cnt >= 2).sum()
    return float(twice / max(covered, 1))

def relax(leaves, rng, steps=60):
    """The mosaic: each blade turns about its node (within 35 degrees of where it grew) and
    its stalk lengthens or shortens (within 0.7..1.5 of its own) away from the blades it
    covers or is covered by, the lower one moving more (it is in the other's shade)."""
    for it in range(steps):
        discs = [plan_disc(lf) for lf in leaves]
        push = [np.zeros(2) for _ in leaves]
        for i in range(len(leaves)):
            for j in range(i + 1, len(leaves)):
                ci, ri, yi = discs[i]; cj, rj, yj = discs[j]
                dv = ci - cj; dist = np.linalg.norm(dv) + 1e-9
                ov = ri + rj - dist
                if ov > 0:
                    wi = 0.7 if yi < yj else 0.3
                    push[i] += dv / dist * ov * wi
                    push[j] -= dv / dist * ov * (1 - wi)
        for lf, pv in zip(leaves, push):
            if not pv.any(): continue
            out = np.array([math.cos(lf.az), math.sin(lf.az)])
            tang = np.array([-out[1], out[0]])
            lever = lf.stalk + lf.size * 0.42
            lf.az += 0.5 * np.dot(pv, tang) / lever
            lf.az = lf.az0 + float(np.clip(np.angle(np.exp(1j * (lf.az - lf.az0))), -math.radians(35), math.radians(35)))
            if not hasattr(lf, 'stalk0'): lf.stalk0 = lf.stalk
            lf.stalk = float(np.clip(lf.stalk + 0.5 * np.dot(pv, out), lf.stalk0 * 0.7, lf.stalk0 * 1.5))
        place(leaves)

def current_leaves(rng, tips, segs, blade=0.11):
    """tree_whole.goose add_cards on the same twigs: TWIG_NODES = 4 pairs over the outer
    four fifths of each tip's last two segments, stalks rising, faces random about the goal."""
    leaves = []
    sun = norm(np.array([0.3, 0.8, 0.5]))
    middle = np.mean([s[0] for s in segs], 0) + np.array([0, -0.3, 0])
    for t in tips:
        a = t.a - (t.b - t.a) * 2.5          # a twig is longer than one year's shoot
        first = rng.uniform(0, 2 * math.pi)
        for node in range(1, 5):
            at = 0.2 + 0.8 * node / 4
            p = a + (t.b - a) * at
            twig = norm(t.b - a)
            for k in range(2):
                rnd = first + node * math.pi / 2 + k * math.pi + rng.uniform(-0.25, 0.25)
                side = rot(perp(twig), twig, rnd)
                lift = rng.uniform(0.15, 0.7)
                stalk_dir = norm(side + twig * (0.9 if node == 4 else 0.3) + UP * lift)
                size = blade * rng.uniform(0.75, 1.2)
                stalk = size * rng.uniform(0.7, 1.15)
                base = p + stalk_dir * stalk
                out = norm(p - middle)
                goal = norm(UP * 0.7 + out * 0.5 + sun * 0.25)
                face = norm(goal + rng.normal(0, 1, 3) / math.sqrt(3) * 0.9 * rng.uniform(0, 1) ** (1 / 3) * 1.7)
                if np.dot(face, goal) < 0: face = -face
                along = stalk_dir + UP * -0.45
                along = norm(along - face * np.dot(along, face))
                lf = Leaf(); lf.node = p; lf.base = base; lf.along = along; lf.face = face; lf.size = size
                lf.stalk = stalk; lf.bend = L.VARIANTS['flat']
                leaves.append(lf)
    return leaves

# ---- the bend each leaf gets ----------------------------------------------------------

def choose_bends(leaves, rng, season='autumn', exposure=1.0):
    """The proposed rule, per leaf: most leaves near flat; a share cup up a little (more in
    sun, where beech leaves are more curved); a share sag (more for big blades on long
    stalks and in autumn, when Norway maple blades steepen); amounts at random within each."""
    autumn = 1.0 if season == 'autumn' else 0.0
    mean = np.mean([lf.size for lf in leaves])
    counts = {}
    for lf in leaves:
        load = lf.size / mean
        p_cup = 0.10 + 0.10 * exposure
        p_sag = 0.15 + 0.15 * autumn + 0.25 * (load - 1)
        r = rng.random()
        a = rng.uniform(0.3, 1.0)
        if r < p_cup:
            kind, base = 'cup up', L.VARIANTS['cup up']
        elif r < p_cup + p_sag:
            kind = rng.choice(['midrib droop', 'edges down', 'lobe tips', 'sag + twist'])
            base = L.VARIANTS[kind]
        else:
            kind, base = 'flat', L.VARIANTS['flat']; a = 0.0
        # a near-flat leaf still has a trace of shape
        tip = base.tip * a + rng.normal(0, math.radians(4), 5)
        lf.bend = L.Bend(tip=tip, start=base.start, power=base.power, curl=base.curl * a, twist=base.twist * a * rng.choice([-1, 1]))
        lf.kind_name = kind
        counts[kind] = counts.get(kind, 0) + 1
    return counts

# ---- drawing ---------------------------------------------------------------------------

def stalk_curve(lf, n=6):
    """The stalk from the node to the blade's foot: leaving the twig rising, arriving along
    the blade (a quadratic Bezier)."""
    p0 = lf.node; p2 = lf.base + lf.along * L.QUAD[1] * lf.size
    mid = (p0 + p2) / 2 + UP * np.linalg.norm(p2 - p0) * 0.18
    pts = [(1 - t) ** 2 * p0 + 2 * (1 - t) * t * mid + t ** 2 * p2 for t in np.linspace(0, 1, n)]
    return pts

def render(segs, leaves, view, w=600, h=450, ss=2, tint=1.15, mesh=None, kinds=None, rng=None):
    eye, at, sun, sky, up, fov = view
    cam = R.Camera(eye, at, w * ss, h * ss, fov=fov, up=up)
    cv = R.Canvas(cam)
    rng = rng or np.random.default_rng(3)
    for a, b, r in sorted(segs, key=lambda s: -s[2]):
        cv.ribbon(a, b, max(r, 0.0016), max(r * 0.9, 0.0016))
    allP, allUV, allN, allK, allT = [], [], [], [], []
    for i, lf in enumerate(leaves):
        kind = int(rng.integers(0, 8))
        xy, tris = mesh[kind] if mesh else L.fan_mesh(kind, 16, 4)
        P, UV, N = R.leaf_triangles(xy, tris, lf.bend, kind, lf.base, lf.along, lf.face, lf.size, lf.size * 1.15)
        allP.append(P); allUV.append(UV); allN.append(N)
        allK.append(np.full(len(P), kind)); allT.append(np.full(len(P), tint + rng.uniform(-0.15, 0.2)))
        pts = stalk_curve(lf)
        for p, q in zip(pts[:-1], pts[1:]):
            cv.ribbon(p, q, 0.0012, 0.0012, color=(0.30, 0.07, 0.03))
    cv.triangles(np.concatenate(allP), np.concatenate(allUV), np.concatenate(allN), np.concatenate(allK), np.concatenate(allT), sun, sky=sky)
    return cv.image(ss)

def views(segs, leaves):
    pts = np.array([s[1] for s in segs] + [lf.base for lf in leaves])
    c = (pts.min(0) + pts.max(0)) / 2; ext = np.linalg.norm(pts.max(0) - pts.min(0))
    return {
        'below': (c + np.array([0.0, -1.5 * ext, -0.1 * ext]), c, np.array([0.3, 1.0, 0.4]), 0.5, (1, 0, 0), 34),
        'side': (c + np.array([0.0, -0.12 * ext, 1.45 * ext]), c, np.array([0.3, 0.9, 0.5]), 0.6, (0, 1, 0), 34),
        'light': (c + np.array([-0.2 * ext, -0.3 * ext, 1.4 * ext]), c, np.array([0.2, 0.5, -1.0]), 0.35, (0, 1, 0), 34),
    }

def close_views(tip_leaves):
    pts = np.array([lf.base + lf.along * lf.size * 0.4 for lf in tip_leaves])
    c = pts.mean(0); ext = max(np.linalg.norm(pts.max(0) - pts.min(0)), 0.2)
    return {
        'below': (c + np.array([0.0, -1.3 * ext, -0.15 * ext]), c, np.array([0.3, 1.0, 0.4]), 0.5, (1, 0, 0), 40),
        'side': (c + np.array([0.25 * ext, -0.3 * ext, 1.2 * ext]), c, np.array([0.3, 0.9, 0.5]), 0.6, (0, 1, 0), 40),
        'light': (c + np.array([-0.3 * ext, -0.3 * ext, 1.2 * ext]), c, np.array([0.2, 0.5, -1.0]), 0.35, (0, 1, 0), 40),
    }

def close_ups(segs, prop, flat, tip_index):
    """One plate: a tip's four leaves and its neighbours, flat and bent."""
    t = prop[tip_index * 4].tip
    centre = t.b
    near = [i for i, lf in enumerate(prop) if np.linalg.norm(lf.node - centre) < 0.09]
    v = close_views([prop[i] for i in near])
    near_segs = [s for s in segs if np.linalg.norm(s[1] - centre) < 0.16 and np.linalg.norm(s[0] - centre) < 0.3]
    for name, lv in (('flat', flat), ('proposed', prop)):
        for vn, vv in v.items():
            render(near_segs, [lv[i] for i in near], vv).save(os.path.join(OUT, 'plate-%s-%s.png' % (name, vn)))

if __name__ == '__main__':
    load_tilts(sys.argv[1])
    rng = np.random.default_rng(int(sys.argv[2]) if len(sys.argv) > 2 else 7)
    segs, tips = grow_branch(rng)
    stats = {'tips': len(tips), 'segments': len(segs)}
    cur = current_leaves(np.random.default_rng(11), tips, segs)
    stats['now_leaves'] = len(cur); stats['now_overlap'] = overlap(cur)
    flat, b0, _ = proposed_leaves(np.random.default_rng(5), tips, mosaic=False)
    for lf in flat: lf.bend = L.VARIANTS['flat']
    prop, before, after = proposed_leaves(np.random.default_rng(5), tips, mosaic=True)
    stats['proposed_leaves'] = len(prop); stats['overlap_before_mosaic'] = before; stats['overlap_after_mosaic'] = after
    flat_m, _, _ = proposed_leaves(np.random.default_rng(5), tips, mosaic=True)
    for lf in flat_m: lf.bend = L.VARIANTS['flat']
    stats['bends'] = choose_bends(prop, np.random.default_rng(9))
    v = views(segs, prop)
    for name, lv in (('now', cur), ('flat', flat_m), ('proposed', prop)):
        for vn, vv in v.items():
            render(segs, lv, vv).save(os.path.join(OUT, 'shoot-%s-%s.png' % (name, vn)))
    json.dump(stats, open(os.path.join(OUT, 'shoot-stats.json'), 'w'), indent=1)
    # the plate: the tip whose leaves stick out farthest along the branch
    far = int(np.argmax([lf.node[0] for lf in prop[::4]]))
    close_ups(segs, prop, flat_m, far)
    print(stats)

