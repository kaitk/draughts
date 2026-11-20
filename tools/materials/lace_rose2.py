#!/usr/bin/env python3
"""Prototype: way f2, way f's wild rose grammar grown fuller and twining.

    python3 tools/materials/lace_rose2.py OUT_DIR [--seed N]

--seed grows the plant (SEED, 4). The library's copy:
    MANOR_DIR=.../design/manor lace_rose2.py build/notes/lace-library/f2 --seed 4

The botany is lace_rose's (trails, shoots out and up, pinnate leaves, roses only at the
tips); what changes is how much grows and how the stems move:
- Leaves are full: a terminal leaflet and two pairs, three on the lowest leaf of a shoot
  and on most trail leaves. Leaflets may lie over leaflets as real foliage does (each
  keeps its outline thread, so the overlap reads); a leaf that finds no room first turns,
  then shrinks, then is allowed more overlap, and only then loses a pair.
- Stems swing: a trail sways twice as far as f's, and a thinner cane winds round it,
  crossing it twice a tile and bearing leaves of its own. Shoots arc: out at 35 to 55
  degrees, then bend over past the vertical, faster toward the tip.
- Side veins are single open lines (no cord), so they read as veins, not hatching.
- Half-open roses are a cup of broad petals in two clasping sepals, larger than f's; buds
  are larger, with three sepals.
"""

import os
import sys

import numpy as np

import common as cm
import lace
import lace_blossom as lb
import lace_crisp as lc
import lace_rose as lr
from lace_crisp import BIG, N, mm
from lace_rose import LIGHT, STEM_MM, UP, at, curve_discs, unit

SEED = 4
TRAILS = 4
NODES = 16
SWAY_MM = (34.0, 9.0)        # the trail's sway once and twice a tile (f: 22, 4)
PHASE_STEP = 0.7            # radians between neighbouring trails' sway
CANE_MM = 15.0               # the winding cane's swing round its trail, twice a tile
CANE_NODES = (2, 5, 9, 13)   # where the cane bears a leaf, of NODES a tile
BIG_SHOOT = (0,)
SMALL_SHOOT = (8,)
LEAFY_SHOOT = (3, 6, 11, 14)
SMALL_TWIG = (1, 3)
FIT = 0.22                   # share of a leaf's cells that may lie on others' (f: 0.09)
FIT_CROWDED = 0.32           # the last try before a pair is lost
FIT_FLOWER = 0.04            # share that may lie on a flower: leaves keep off the roses
VEIN_FINE_MM = 0.17          # a side vein: an open line this far each side, no cord
PAIR_SIZE = (0.86, 0.74, 0.62)
PAIR_ANGLE = (42.0, 56.0, 62.0)
PAIR_GAP = (0.26, 0.5, 0.46)
LEAFLET_W = 0.52
HALF_OPEN = (0.42, 0.6, 5, 1.0, 0.84)   # a cup: tilt cos, cup slope, petals, length, fan
lb.KINDS.setdefault('cup', HALF_OPEN)


def arc_curve(p, h0, h1, length, ease=1.6, n=28):
    """Points from p whose heading turns from h0 to h1, slowly first (ease > 1)."""
    t = (np.arange(n - 1) + 0.5) / (n - 1)
    hs = h0 + (h1 - h0) * t ** ease
    d = np.stack([np.cos(hs), np.sin(hs)], 1) * (length / (n - 1))
    pts = np.concatenate([[p], p + np.cumsum(d, 0)])
    return pts, np.concatenate([[h0], hs])


def leaflet(cv, base, ang, L, W, bend, folded=False, veins=True, seed=0):
    """lace_rose's leaflet with fine side veins: single open lines, fewer, curving."""
    r = L + W
    ix, X, Y = cv.box(base[0] - r, base[1] - r, base[0] + r, base[1] + r)
    if ix is None:
        return
    rng = np.random.default_rng(seed)
    ca, sa = np.cos(ang), np.sin(ang)
    s = (X - base[0]) * ca + (Y - base[1]) * sa
    t = -(X - base[0]) * sa + (Y - base[1]) * ca
    u = np.clip(s / L, 0, 1)
    t = t - bend * L * u * u
    w = 0.5 * W * np.sin(np.pi * u ** 0.85) ** 0.75
    saw = (s / (L / 12) + rng.random()) % 1
    w = w - 0.055 * W * (1 - saw) * ((u > 0.15) & (u < 0.95))
    if folded:
        side = 1 if rng.random() < 0.5 else -1
        tt = t * side
        d = lc.normalise(np.maximum(np.maximum(-tt, tt - 0.9 * w), np.maximum(-s, s - L)))
        across = tt
    else:
        d = lc.normalise(np.maximum(np.abs(t) - w, np.maximum(-s, s - L)))
        across = np.abs(t)
    vein = np.full(X.shape, BIG, np.float32)
    if veins:
        if not folded:
            vein = np.where((u > 0.04) & (u < 0.84), np.abs(t), BIG)
        # Side veins leave the midrib forward and bend toward the tip; open lines only.
        sp = L / 4.2
        a = across / np.maximum(w, 1e-3)
        sv = np.abs(((s - across * (0.8 + 0.5 * a)) / sp) % 1 - 0.5) * sp * 0.7
        ok = (u > 0.14) & (u < 0.8) & (a < 0.7) & (across > mm(0.6))
        vein = np.minimum(vein, np.where(ok, sv + mm(lc.VEIN_CORD_MM / 2 + lc.VEIN_OPEN_MM - VEIN_FINE_MM), BIG))
    n_plus = np.array([-sa, ca])
    shade = 1 if n_plus @ LIGHT < 0 else -1
    half = np.ones_like(X) if folded else (t * shade > 0).astype(np.float32)
    cv.paint(ix, d, vein, half)


def bud(cv, c, R, rot, rng):
    """lace_blossom's bud with its sepals longer and flaring, a third up its side."""
    H = 1.7 * R
    ux, uy = np.sin(rot), -np.cos(rot)
    foot = (c[0] - ux * 0.42 * H, c[1] - uy * 0.42 * H)
    up = np.arctan2(uy, ux)
    for s in (-1, 1):
        leaflet(cv, foot, up + s * rng.uniform(0.55, 0.75), 0.95 * H, 0.22 * H, -s * 0.35,
                veins=False, seed=int(rng.integers(1 << 30)))
    lb.bud(cv, c, R, rot, rng)


class Plant(lr.Plant):

    def leaf_spec(self, P, h, scale, pairs, bend, folded=False):
        rng = self.rng
        Lt = mm(lr.TERMINAL_MM) * scale
        below_tip = np.cumsum([PAIR_GAP[i] * Lt for i in range(pairs)])
        pl = mm(6.0) * scale
        total = pl + (below_tip[-1] if pairs else 0) + mm(0.5)
        pts, hs = lr.heading_curve(np.asarray(P, float), h, h + bend, total, 20)
        parts = []
        jit = rng.normal(0, 0.05)
        for j in reversed(range(pairs)):                 # the lowest first: the top lies over
            p, hh = at(pts, hs, (total - below_tip[j]) / total)
            L = PAIR_SIZE[j] * Lt * rng.uniform(0.95, 1.05)
            for side in (-1, 1):
                ang = np.radians(PAIR_ANGLE[j]) + jit + rng.normal(0, 0.06)
                b = p + unit(hh + side * np.pi / 2) * mm(0.5) * scale
                parts.append((b, hh + side * ang, L, LEAFLET_W * L, side * rng.uniform(0.04, 0.14), folded))
        parts.append((pts[-1], hs[-1] + rng.normal(0, 0.06), Lt, LEAFLET_W * Lt * 1.04,
                      rng.normal(0, 0.06), folded))
        discs = curve_discs(pts[::3], mm(1.2))
        for b, a, L, W, _, _ in parts:
            for f, rr in ((0.3, 0.45), (0.58, 0.42), (0.84, 0.26)):
                c = b + unit(a) * L * f
                discs.append((c[0], c[1], W * rr * (0.55 if folded else 1)))
        return dict(pts=pts, hs=hs, parts=parts, discs=discs, P=P, h=h, scale=scale,
                    pairs=pairs, folded=folded, Lt=Lt)

    def leaf(self, P, h, scale, pairs, parent, side, folded=False, tries=True):
        """A leaf if it fits: turned, smaller, then more crowded, and only then a pair less."""
        rng = self.rng
        bend = -side * rng.uniform(0.15, 0.32)
        options = [(pairs, scale, 0.0, FIT)]
        if tries:
            options += [(pairs, scale, -side * 0.25, FIT), (pairs, scale, side * 0.2, FIT),
                        (pairs, scale * 0.88, -side * 0.12, FIT), (pairs, scale * 0.85, 0.0, FIT_CROWDED),
                        (max(pairs - 1, 1), scale * 0.85, -side * 0.2, FIT_CROWDED),
                        (max(pairs - 1, 1), scale * 0.72, side * 0.2, FIT_CROWDED)]
        for n, sc, turn, fit in options:
            spec = self.leaf_spec(P, h + turn, sc, n, bend, folded)
            yy, xx = self.occ.cells(spec['discs'])
            on_flower = np.isin(self.occ.g[yy, xx], self.flower_ids).mean() if len(yy) else 0
            if on_flower <= FIT_FLOWER and self.occ.clash(spec['discs'], allow=(parent,)) <= fit:
                self.occ.add(spec['discs'], self.occ.new())
                self.leaves.append(spec)
                self.log['leaves'].append(n)
                self.log['pair_angles'] += [PAIR_ANGLE[j] for j in range(n)]
                return spec
        self.log['skipped'] += 1
        return None

    def __init__(self, h, w, rng):
        super().__init__(h, w, rng)
        self.flower_ids = []

    def rose(self, tip, h, kind, R, parent):
        self.flower_ids.append(self.occ.new())
        return super().rose(tip, h, kind, R, self.flower_ids[-1])

    def bud(self, tip, h, R, parent):
        self.flower_ids.append(self.occ.new())
        c = super().bud(tip, h, R, self.flower_ids[-1])
        self.flowers[-1] = ('bud2',) + self.flowers[-1][1:]
        return c

    def shoot(self, P, up, side, kind, parent, rose=False):
        """A shoot out at 35 to 55 degrees arcing over past the vertical; leaves alternating,
        the lowest of three pairs; a flower, bud or young leaf at its tip."""
        rng = self.rng
        a0 = np.radians(rng.uniform(38, 52) if kind == 'big' else rng.uniform(35, 55))
        self.log['shoot_angles'].append(np.degrees(a0))
        a1 = -a0 * rng.uniform(0.15, 0.6)                # past the vertical: the shoot arcs over
        L = mm({'big': rng.uniform(110, 130), 'small': rng.uniform(60, 75),
                'leafy': rng.uniform(90, 115), 'twig': rng.uniform(42, 58), 'bud': rng.uniform(34, 44)}[kind])
        pts, hs = arc_curve(np.asarray(P, float), up + side * a0, up + side * a1, L, rng.uniform(1.3, 2.0))
        own = self.occ.new()
        r0, r1 = (STEM_MM[1], STEM_MM[2]) if kind not in ('bud', 'twig') else (STEM_MM[2], STEM_MM[3] + 0.1)
        self.stem(pts, mm(r0), mm(r1))
        tip, th = pts[-1], hs[-1]
        if kind == 'big':
            fk = 'three_quarter' if rng.random() < 0.3 else 'face'
            self.rose(tip, th, fk, mm(rng.uniform(28, 32)), own)
        elif kind == 'small':
            if rng.random() < 0.55:
                self.rose(tip, th, 'face', mm(rng.uniform(17, 21)), own)
            else:
                self.rose(tip, th, 'cup', mm(rng.uniform(19, 23)), own)
        elif kind == 'bud':
            self.bud(tip, th, mm(rng.uniform(10, 12)), own)
        self.occ.add(curve_discs(pts[:-2], mm(r0) + mm(1.5)), own)
        if kind == 'big':
            plan = [(0.2, 'leaf', -side, 0.95, 3), (0.42, 'bud', side, 0, 0), (0.62, 'leaf', -side, 0.85, 2),
                    (0.78, 'leaf', side, 0.7, 2)]
        elif kind == 'small':
            plan = [(0.3, 'leaf', -side, 0.85, 2), (0.62, 'leaf', side, 0.7, 2)]
        elif kind == 'leafy':
            plan = [(0.18, 'leaf', -side, 0.95, 3), (0.4, 'small' if rose else 'twig', side, 0, 0),
                    (0.6, 'leaf', -side, 0.85, 2), (0.8, 'leaf', side, 0.72, 2)]
        elif kind == 'twig':
            plan = [(0.35, 'leaf', -side, 0.75, 2)]
        else:
            plan = [(0.5, 'young', -side, 0.48, 1)]
        if kind in ('leafy', 'twig'):                    # its tip: a young leaf, still opening
            self.leaf(tip, th, 0.66 if kind == 'leafy' else 0.55, 1, own, side)
        for f, what, s, sc, pairs in plan:
            p, hh = at(pts, hs, f)
            if what in ('twig', 'small'):
                self.shoot(p, hh, s, what, own)
            elif what == 'bud':
                sub = self.shoot(p, hh, s, 'bud', own)
                self.labels.setdefault('side shoot', sub[len(sub) // 2])
            elif what == 'young':
                self.leaf(p, hh + s * np.radians(35), sc, 1, own, s, folded=True, tries=False)
            else:
                ang = np.radians(rng.uniform(45, 60))
                self.log['petiole_angles'].append(np.degrees(ang))
                self.leaf(p, hh + s * ang, sc, pairs, own, s)
        return pts

    def trail(self, ox, oy, phase, index):
        """A trail swaying wide, and a thinner cane winding round it."""
        rng = self.rng
        ph2 = rng.uniform(0, 2 * np.pi)
        ph3 = rng.uniform(0, 2 * np.pi)

        def x_at(y):
            return (ox + mm(SWAY_MM[0]) * np.sin(2 * np.pi * y / N + phase)
                    + mm(SWAY_MM[1]) * np.sin(4 * np.pi * y / N + ph2))

        def cane_x(y):
            return x_at(y) + mm(CANE_MM) * np.sin(4 * np.pi * y / N + ph3)

        def node(fx, k):
            y = (k + 0.5 + rng.uniform(-0.12, 0.12)) * N / NODES
            p = np.array([fx(y), y + oy])
            up = np.arctan2(-1.0, -(fx(y + 4) - fx(y - 4)) / 8)
            return p, up

        ys = np.linspace(0, N, 257)
        own = self.occ.new()
        self.stem(np.stack([x_at(ys), ys + oy], 1), mm(STEM_MM[0]), owner=own)
        cane = self.occ.new()
        self.stem(np.stack([cane_x(ys), ys + oy], 1), mm(STEM_MM[1]), owner=cane)
        nodes = [(k,) + node(x_at, k) + (1 if k % 2 == 0 else -1,) for k in range(NODES)]
        for k, p, up, side in nodes:
            if k in BIG_SHOOT:
                self.shoot(p, up, side, 'big', own)
            elif k in SMALL_SHOOT:
                self.shoot(p, up, side, 'small', own)
        for k, p, up, side in nodes:
            if k in LEAFY_SHOOT:
                self.shoot(p, up, side, 'leafy', own, rose=index in SMALL_TWIG and k == LEAFY_SHOOT[0])
        for k, p, up, side in nodes:
            if k in BIG_SHOOT or k in SMALL_SHOOT or k in LEAFY_SHOOT:
                continue
            ang = np.radians(rng.uniform(48, 64))
            self.log['petiole_angles'].append(np.degrees(ang))
            self.leaf(p, up + side * ang, rng.uniform(0.92, 1.05), int(rng.choice([3, 3, 2])), own, side)
        for k in CANE_NODES:                             # the cane's leaves, on its outer swing
            p, up = node(cane_x, k)
            side = 1 if cane_x(p[1] - oy) > x_at(p[1] - oy) else -1
            ang = np.radians(rng.uniform(45, 60))
            self.log['petiole_angles'].append(np.degrees(ang))
            self.leaf(p, up + side * ang, rng.uniform(0.8, 0.92), 2, cane, side)

    def draw(self, cv):
        for pts, r0, r1 in self.stems:
            cv.curve('sd', pts, r0, r1)
        for spec in self.leaves:
            sc = min(spec['scale'], 1)
            cv.curve('sd', spec['pts'], mm(STEM_MM[3] + 0.12) * sc, mm(STEM_MM[3]) * sc)
        for spec in self.leaves:
            P, h, sc = np.asarray(spec['P']), spec['h'], spec['scale']
            if not spec['folded']:
                for s in (-1, 1):
                    leaflet(cv, P - unit(h) * mm(0.8) * sc, h + s * 0.3, mm(5) * sc, mm(1.6) * sc,
                            -s * 0.15, veins=False, seed=abs(int(P[0] * 7 + s)))
            for i, (b, a, L, W, bend, folded) in enumerate(spec['parts']):
                leaflet(cv, b, a, L, W, bend, folded, seed=abs(int(b[0] * 13 + b[1] * 7 + i)))
        for what, kind, c, R, rot, seed, h in self.flowers:
            rng = np.random.default_rng(seed)
            if what in ('bud', 'bud2'):
                bud(cv, c, R, rot, rng)
                continue
            lb.Blossom(kind, rng, lb.TILT_DEG).draw(cv, c, R, rot)
            if kind == 'cup':                            # sepals clasping the cup's foot, tips flaring
                base = c - unit(h) * 0.52 * R
                for s in (-1, 1):
                    leaflet(cv, base, h + s * 0.7, 0.8 * R, 0.22 * R, -s * 0.4, veins=False,
                            seed=abs(seed + s))


def grow(seed=SEED):
    rng = np.random.default_rng(seed)
    plant = Plant(N, N, rng)
    base = rng.uniform(0, 2 * np.pi)
    for t in range(TRAILS):                              # neighbours sway nearly together: even spacing
        plant.trail(N / 8 + t * N / TRAILS, t * N / TRAILS + (N / 8 if t % 2 else 0),
                    base + t * PHASE_STEP + rng.normal(0, 0.2), t)
    cv = lc.Canvas(N, N)
    plant.draw(cv)
    return cv.finish(), plant


def bake(out, seed=SEED, tag='f2'):
    net = lace.net_tile()
    cloth = (lc.weave('whole'), lc.weave('half'))
    (sd, vein, half), plant = grow(seed)
    big = [f for f in plant.flowers if f[1] in ('face', 'three_quarter') and f[3] > mm(24)]
    c = big[0][2]
    want = np.array([0.149, 0.222]) / lace.TILE_M * N
    dy, dx = int(round(want[1] - c[1])), int(round(want[0] - c[0]))
    sd, vein, half = (np.roll(a, (dy, dx), (0, 1)) for a in (sd, vein, half))
    motif = lc.render(sd, vein, half, cloth)
    src = cm.load(cm.source('library-lace-01.png'))

    def hem_motifs(cv, g, traced=lc.hem_motifs_traced(src)):      # way c's, as f's
        sd_h, _, half_h = traced(cv, g)
        return lc.regrow_flowers(sd_h, half_h, wrap_y=False)
    hem = lc.hem_strip(hem_motifs, cloth, motif)
    close = (int(want[1]) - 512, int(want[0]) - 512)
    mean = lc.views(out, tag, motif, hem, net, close)
    cm.save(os.path.join(out, f'{tag}_motif.png'), lace.box(motif, 4))
    lines = lr.report(plant)
    with open(os.path.join(out, f'{tag}_report.txt'), 'w') as fh:
        fh.write(f'seed {seed}, mean field coverage {mean:.2f}\n' + '\n'.join(lines) + '\n')
    print(f'mean field coverage {mean:.2f}')


if __name__ == '__main__':
    args = sys.argv[1:]
    opts = dict(zip(args[1::2], args[2::2]))
    if not args or len(args) % 2 != 1 or set(opts) - {'--seed'}:
        sys.exit(__doc__)
    os.makedirs(args[0], exist_ok=True)
    bake(args[0], int(opts.get('--seed', SEED)))
