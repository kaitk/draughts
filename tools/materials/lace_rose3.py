#!/usr/bin/env python3
"""Prototype: way f3, way f2's twining wild rose with small frond-like leaves, its gaps
filled, and more and larger roses.

    python3 tools/materials/lace_rose3.py OUT_DIR [--seed N]

--seed grows the plant (SEED, 4). The library's copy:
    MANOR_DIR=.../design/manor lace_rose3.py build/notes/lace-library/f3 --seed 4

f2's botany, twining canes, arcing shoots and side-view cups; what changes:
- Leaves are fronds of small leaflets, as the download's: a terminal leaflet of 17 mm
  (f2: 30) and two or three pairs set closer, so a leaf finds room where f2's broad one
  did not; a leaf that does not fit turns further before it shrinks or loses a pair.
- All trails grow their flowering shoots first, then the leafy ones, then every leaf,
  so no trail's rose lands on another's leaves. A shoot takes the least crowded of
  SHOOT_TRIES arcs. A rose holds 0.9 of its radius, so leaves tuck under its petals' gaps.
- Gaps are filled: the free space is measured on the occupancy grid, and into each gap
  wider than GAP_MM a leaf, or a twig with leaves, grows from one of the nearest stems,
  sometimes a small rose or bud at the twig's tip where the gap is wide.
- Big roses are two a trail, 39 to 43 mm, mostly six broad petals as the download's,
  each petal rimmed by an open line inside its outline so it reads over the next.
"""

import os
import sys

import numpy as np

import common as cm
import lace
import lace_blossom as lb
import lace_crisp as lc
import lace_rose as lr
import lace_rose2 as f2
from lace_crisp import N, mm
from lace_rose import CELL, STEM_MM, at, curve_discs, unit

SEED = 4
TRAILS = 4
NODES = 16
BIG_SHOOT = (0, 8)           # f2: (0,)
SMALL_SHOOT = (12,)
LEAFY_SHOOT = (2, 10)        # f2: four; the fill grows the rest
SMALL_TWIG = (1, 3)
TERMINAL_MM = 17.0           # a full-size terminal leaflet (f2: 30)
PAIR_SIZE = (0.9, 0.84, 0.76, 0.68)
PAIR_ANGLE = (40.0, 50.0, 56.0, 60.0)
PAIR_GAP = (0.32, 0.6, 0.58, 0.56)     # of the terminal: tip to top pair, then between pairs
LEAFLET_W = 0.56
TRAIL_PAIRS = (3, 2, 2)      # a trail leaf's pairs, drawn from these
FIT = 0.12                   # share of a leaf's cells that may lie on others'
FIT_CROWDED = 0.22           # the last tries
FIT_FLOWER = 0.2             # share on a flower: the flower is drawn over it
RIM_MM = 0.85                # a petal's open rim, 0.5 mm wide, this far inside its outline
GAP_MM = 17.0                # a free cell this far from anything is a gap to fill
FILL_TRIES = 160             # gaps tried at most
ROSE_HOLD = 0.9              # of a rose's radius, held from leaves
FILL_FROM = 6                # stems a gap tries to grow from, nearest first
SHOOT_TRIES = 6              # arcs tried for a shoot, the least crowded kept
ROOM_MM = dict(big=22, small=16, leafy=14, twig=10)   # room wanted each side of its stem
BIG_R_MM = (39.0, 43.0)      # f2: 28 to 32
OPEN6 = (0.97, 0.12, 6, 0.94, 0.76)    # six broad petals, a little over one another
lb.KINDS.setdefault('open6', OPEN6)
OPEN_KINDS = ('open6', 'face', 'three_quarter')


class Blossom(lb.Blossom):
    """lace_blossom's rose with rounder petal tips, each petal rimmed: an open line just
    inside its outline, so a petal lying over the next reads as its own."""

    def __init__(self, kind, rng, tilt=None):
        super().__init__(kind, rng, tilt)
        for p in self.petals:
            p['wave'] *= 0.6
            p['notch'] *= 0.7

    def petal(self, cv, ix, X, Y, R, p):
        put = cv.paint                                   # the parent's petal, its paint rimmed

        def rimmed(ix_, d, veins, half):
            rim = np.where(d < 0, mm(0.2) + 0.8 * np.abs(-d - mm(RIM_MM)), lc.BIG)
            put(ix_, d, np.minimum(veins, rim), half * (-d > mm(RIM_MM + 0.6)))
        cv.paint = rimmed
        try:
            super().petal(cv, ix, X, Y, R, p)
        finally:
            cv.paint = put


class Plant(f2.Plant):

    def __init__(self, h, w, rng):
        super().__init__(h, w, rng)
        self.log['filled'] = 0
        self.log['fill_flowers'] = 0
        self.phase = 'shoot'

    def leaf_spec(self, P, h, scale, pairs, bend, folded=False):
        rng = self.rng
        Lt = mm(TERMINAL_MM) * scale
        below_tip = np.cumsum([PAIR_GAP[i] * Lt for i in range(pairs)])
        pl = mm(4.0) * scale
        total = pl + (below_tip[-1] if pairs else 0) + mm(0.4)
        pts, hs = lr.heading_curve(np.asarray(P, float), h, h + bend, total, 20)
        parts = []
        jit = rng.normal(0, 0.05)
        for j in reversed(range(pairs)):
            p, hh = at(pts, hs, (total - below_tip[j]) / total)
            L = PAIR_SIZE[j] * Lt * rng.uniform(0.94, 1.06)
            for side in (-1, 1):
                ang = np.radians(PAIR_ANGLE[j]) + jit + rng.normal(0, 0.07)
                b = p + unit(hh + side * np.pi / 2) * mm(0.4) * scale
                parts.append((b, hh + side * ang, L, LEAFLET_W * L, side * rng.uniform(0.04, 0.16), folded))
        parts.append((pts[-1], hs[-1] + rng.normal(0, 0.06), Lt, LEAFLET_W * Lt * 1.04,
                      rng.normal(0, 0.06), folded))
        discs = curve_discs(pts[::3], mm(1.0))
        for b, a, L, W, _, _ in parts:
            for f, rr in ((0.3, 0.45), (0.58, 0.42), (0.84, 0.26)):
                c = b + unit(a) * L * f
                discs.append((c[0], c[1], W * rr * (0.55 if folded else 1)))
        return dict(pts=pts, hs=hs, parts=parts, discs=discs, P=P, h=h, scale=scale,
                    pairs=pairs, folded=folded, Lt=Lt)

    def rose(self, tip, h, kind, R, parent):
        """f2's, holding a disc of ROSE_HOLD R: its petals leave the corners free for leaves."""
        self.flower_ids.append(self.occ.new())
        rot = np.arctan2(np.cos(h), -np.sin(h))
        c = tip + unit(h) * {'face': 0.12, 'open6': 0.12, 'three_quarter': 0.25}.get(kind, 0.2) * R
        self.occ.add([(c[0], c[1], ROSE_HOLD * R)], self.flower_ids[-1])
        self.flowers.append(('rose', kind, c, R, rot, int(self.rng.integers(1 << 30)), h))
        self.log['flowers'].append(kind)
        return c

    def fits(self, spec, parent, fit):
        yy, xx = self.occ.cells(spec['discs'])
        on_flower = np.isin(self.occ.g[yy, xx], self.flower_ids).mean() if len(yy) else 0
        return on_flower <= FIT_FLOWER and self.occ.clash(spec['discs'], allow=(parent,)) <= fit

    def leaf(self, P, h, scale, pairs, parent, side, folded=False, tries=True, count=True):
        """A leaf if it fits: turned either way, smaller, a pair less, more crowded. count:
        a leaf the plan wants, logged as left off when none fits (a gap's try is not)."""
        rng = self.rng
        bend = -side * rng.uniform(0.12, 0.3)
        less = max(pairs - 1, 1)
        options = [(pairs, scale, 0.0, FIT)]
        if tries:
            options += [(pairs, scale, -side * 0.25, FIT), (pairs, scale, side * 0.25, FIT),
                        (pairs, scale * 0.85, -side * 0.12, FIT), (less, scale, 0.0, FIT),
                        (less, scale, -side * 0.35, FIT), (less, scale, side * 0.35, FIT),
                        (pairs, scale * 0.85, 0.0, FIT_CROWDED), (less, scale * 0.85, -side * 0.2, FIT_CROWDED),
                        (less, scale * 0.85, -side * 0.6, FIT), (less, scale * 0.85, side * 0.6, FIT),
                        (less, scale * 0.75, -side * 0.9, FIT_CROWDED), (less, scale * 0.75, side * 0.9, FIT_CROWDED),
                        (max(pairs - 2, 1), scale * 0.75, side * 0.2, FIT_CROWDED),
                        (1, scale * 0.7, -side * 0.45, FIT_CROWDED)]
        for n, sc, turn, fit in options:
            spec = self.leaf_spec(P, h + turn, sc, n, bend, folded)
            if self.fits(spec, parent, fit):
                self.occ.add(spec['discs'], self.occ.new())
                self.leaves.append(spec)
                self.log['leaves'].append(n)
                self.log['pair_angles'] += [PAIR_ANGLE[j] for j in range(n)]
                return spec
        if count:
            self.log['skipped'] += 1
            self.log.setdefault('skipped_' + self.phase, 0)
            self.log['skipped_' + self.phase] += 1
        return None

    def shoot(self, P, up, side, kind, parent, rose=False, stage=None):
        """f2's arcing shoot with frond leaves; a big shoot ends in a large rose. Given a
        list as stage, the shoot's leaves go into it, to grow after every trail's shoots."""
        rng = self.rng
        best = None
        for _ in range(SHOOT_TRIES):                     # the arc with the most room along it
            a0 = np.radians(rng.uniform(38, 52) if kind == 'big' else rng.uniform(35, 55))
            a1 = -a0 * rng.uniform(0.15, 0.6)
            L = mm({'big': rng.uniform(115, 135), 'small': rng.uniform(62, 78),
                    'leafy': rng.uniform(85, 110), 'twig': rng.uniform(42, 58), 'bud': rng.uniform(34, 44)}[kind])
            pts, hs = f2.arc_curve(np.asarray(P, float), up + side * a0, up + side * a1, L, rng.uniform(1.3, 2.0))
            reach = mm(ROOM_MM.get(kind, 8))
            crowd = self.occ.clash(curve_discs(pts[6::3], reach), allow=(parent,))
            if best is None or crowd < best[0]:
                best = (crowd, a0, pts, hs)
        _, a0, pts, hs = best
        self.log['shoot_angles'].append(np.degrees(a0))
        own = self.occ.new()
        r0, r1 = (STEM_MM[1], STEM_MM[2]) if kind not in ('bud', 'twig') else (STEM_MM[2], STEM_MM[3] + 0.1)
        self.stem(pts, mm(r0), mm(r1))
        tip, th = pts[-1], hs[-1]
        if kind == 'big':
            fk = rng.choice(['open6', 'open6', 'open6', 'open6', 'face', 'face', 'three_quarter'])
            self.rose(tip, th, fk, mm(rng.uniform(*BIG_R_MM)), own)
        elif kind == 'small':
            if rng.random() < 0.6:
                self.rose(tip, th, 'open6' if rng.random() < 0.5 else 'face', mm(rng.uniform(19, 23)), own)
            else:
                self.rose(tip, th, 'cup', mm(rng.uniform(19, 23)), own)
        elif kind == 'bud':
            self.bud(tip, th, mm(rng.uniform(10, 12)), own)
        self.occ.add(curve_discs(pts[:-2], mm(r0) + mm(1.5)), own)
        if kind == 'big':
            plan = [(0.18, 'leaf', -side, 0.95, 3), (0.38, 'bud' if rng.random() < 0.6 else 'twig', side, 0, 0),
                    (0.56, 'leaf', -side, 0.9, 3), (0.72, 'leaf', side, 0.8, 2)]
        elif kind == 'small':
            plan = [(0.3, 'leaf', -side, 0.9, 3), (0.6, 'leaf', side, 0.8, 2)]
        elif kind == 'leafy':
            plan = [(0.18, 'leaf', -side, 0.95, 3), (0.4, 'small' if rose else 'twig', side, 0, 0),
                    (0.6, 'leaf', -side, 0.9, 3), (0.8, 'leaf', side, 0.8, 2)]
        elif kind == 'twig':
            plan = [(0.4, 'leaf', -side, 0.85, 2)]
        else:
            plan = [(0.5, 'young', -side, 0.6, 1)]
        leaves = []
        if kind in ('leafy', 'twig'):
            leaves.append((tip, th, 0.8 if kind == 'leafy' else 0.7, 2, own, side, False))
        for f, what, s, sc, pairs in plan:
            p, hh = at(pts, hs, f)
            if what in ('twig', 'small'):
                self.shoot(p, hh, s, what, own, stage=stage)
            elif what == 'bud':
                sub = self.shoot(p, hh, s, 'bud', own, stage=stage)
                self.labels.setdefault('side shoot', sub[len(sub) // 2])
            elif what == 'young':
                leaves.append((p, hh + s * np.radians(35), sc, 1, own, s, True))
            else:
                ang = np.radians(rng.uniform(45, 60))
                self.log['petiole_angles'].append(np.degrees(ang))
                leaves.append((p, hh + s * ang, sc, pairs, own, s, False))
        if stage is None:
            self.grow_leaves(leaves)
        else:
            stage.extend(leaves)
        return pts

    def draw(self, cv):
        """f2's, the roses rimmed."""
        flowers, self.flowers = self.flowers, [f for f in self.flowers if f[1] not in OPEN_KINDS]
        super().draw(cv)
        self.flowers = flowers
        for what, kind, c, R, rot, seed, h in flowers:
            if kind in OPEN_KINDS:
                Blossom(kind, np.random.default_rng(seed), lb.TILT_DEG).draw(cv, c, R, rot)

    def grow_leaves(self, leaves):
        for p, h, sc, pairs, own, s, folded in leaves:
            self.leaf(p, h, sc, pairs, own, s, folded=folded, tries=not folded)

    def trail_stems(self, ox, oy, phase):
        """A trail swaying wide and its winding cane (f2's); returns its nodes and the cane's."""
        rng = self.rng
        ph2 = rng.uniform(0, 2 * np.pi)
        ph3 = rng.uniform(0, 2 * np.pi)

        def x_at(y):
            return (ox + mm(f2.SWAY_MM[0]) * np.sin(2 * np.pi * y / N + phase)
                    + mm(f2.SWAY_MM[1]) * np.sin(4 * np.pi * y / N + ph2))

        def cane_x(y):
            return x_at(y) + mm(f2.CANE_MM) * np.sin(4 * np.pi * y / N + ph3)

        def node(fx, k):
            y = (k + 0.5 + rng.uniform(-0.12, 0.12)) * N / NODES
            up = np.arctan2(-1.0, -(fx(y + 4) - fx(y - 4)) / 8)
            return np.array([fx(y), y + oy]), up

        ys = np.linspace(0, N, 257)
        own = self.occ.new()
        self.stem(np.stack([x_at(ys), ys + oy], 1), mm(STEM_MM[0]), owner=own)
        cane = self.occ.new()
        self.stem(np.stack([cane_x(ys), ys + oy], 1), mm(STEM_MM[1]), owner=cane)
        nodes = [(k,) + node(x_at, k) + (1 if k % 2 == 0 else -1,) for k in range(NODES)]
        canes = []
        for k in f2.CANE_NODES:
            p, up = node(cane_x, k)
            side = 1 if cane_x(p[1] - oy) > x_at(p[1] - oy) else -1
            canes.append((p, up, side))
        return own, cane, nodes, canes

    def free_distance(self):
        """Each cell's distance in cells to the nearest held cell, wrapping."""
        held = self.occ.g != 0
        d = np.where(held, 0, 999).astype(np.int32)
        cur = held.copy()
        for k in range(1, 200):
            n = cur.copy()
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n |= np.roll(cur, (dy, dx), (0, 1))
            if k % 2:
                for dy, dx in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
                    n |= np.roll(cur, (dy, dx), (0, 1))
            d[n & ~cur] = k
            cur = n
            if cur.all():
                break
        return d

    def fill(self):
        """Into each gap wider than GAP_MM, from the nearest stem: a leaf, or a twig with
        leaves (and a small rose at its tip when the gap is wide)."""
        rng = self.rng
        tried = np.zeros(self.occ.g.shape, bool)
        gap = mm(GAP_MM) / CELL
        for _ in range(FILL_TRIES):
            d = self.free_distance().astype(float)
            d[tried] = 0
            i = int(np.argmax(d))
            gy, gx = divmod(i, d.shape[1])
            if d[gy, gx] < gap:
                break
            ry = int(d[gy, gx])
            g = np.array([(gx + 0.5) * CELL, (gy + 0.5) * CELL])
            stems = np.concatenate([pts for pts, _, _ in self.stems])     # with the twigs grown so far
            off = (stems - g + N / 2) % N - N / 2
            r = np.hypot(off[:, 0], off[:, 1])
            near = []                                    # the nearest stems, 15 mm apart
            for j in np.argsort(r):
                if len(near) == FILL_FROM or r[j] > mm(110):
                    break
                if all(np.hypot(*(stems[j] - stems[k])) > mm(15) for k in near):
                    near.append(j)
            if any(self.fill_from(stems[j], -off[j], r[j], ry * CELL) for j in near):
                self.log['filled'] += 1
                continue
            yy, xx = np.ogrid[-ry:ry + 1, -ry:ry + 1]    # no stem reaches it: leave it
            m = yy * yy + xx * xx <= ry * ry
            Y, X = np.broadcast_arrays(yy + gy, xx + gx)
            tried[Y[m] % d.shape[0], X[m] % d.shape[1]] = True

    def fill_from(self, P, to, dist, room):
        rng = self.rng
        h = np.arctan2(to[1], to[0])
        cy, cx = int(P[1] // CELL) % self.occ.g.shape[0], int(P[0] // CELL) % self.occ.g.shape[1]
        parent = int(self.occ.g[cy, cx])
        side = 1 if rng.random() < 0.5 else -1
        if dist > mm(30) and self.twig(P, h, dist, parent, rose=room > mm(24) and rng.random() < 0.35):
            return True
        sc = float(np.clip(dist / mm(45), 0.75, 1.0))
        return self.leaf(P, h, sc, 3, parent, side, count=False) is not None

    def twig(self, P, h, dist, parent, rose):
        """A twig from P toward a gap dist away, bending a little, leaves alternating."""
        rng = self.rng
        bend = rng.uniform(0.2, 0.45) * (1 if rng.random() < 0.5 else -1)
        L = min(dist - mm(10 if rose else 14), mm(90))
        pts, hs = f2.arc_curve(np.asarray(P, float), h - bend / 2, h + bend / 2, L, 1.3)
        discs = curve_discs(pts[4:-1], mm(STEM_MM[2]) + mm(1.5))
        if self.occ.clash(discs, allow=(parent,)) > 0.35:
            return False
        own = self.occ.new()
        self.stem(pts, mm(STEM_MM[2]), mm(STEM_MM[3] + 0.1))
        self.occ.add(discs, own)
        tip, th = pts[-1], hs[-1]
        if rose:
            if rng.random() < 0.6:
                self.rose(tip, th, 'open6' if rng.random() < 0.6 else 'face', mm(rng.uniform(17, 21)), own)
            else:
                self.bud(tip, th, mm(rng.uniform(10, 12)), own)
            self.log['fill_flowers'] += 1
        else:
            self.leaf(tip, th, 0.8, 2, own, 1, count=False)
        side = 1 if rng.random() < 0.5 else -1
        for f in (0.3, 0.62, 0.85) if L > mm(50) else (0.4, 0.8):
            p, hh = at(pts, hs, f)
            ang = np.radians(rng.uniform(45, 60))
            self.leaf(p, hh + side * ang, 0.85, 3, own, side, count=False)
            side = -side
        return True


def grow(seed=SEED):
    rng = np.random.default_rng(seed)
    plant = Plant(N, N, rng)
    base = rng.uniform(0, 2 * np.pi)
    trails = []
    for t in range(TRAILS):
        phase = base + t * f2.PHASE_STEP + rng.normal(0, 0.2)
        trails.append((t,) + plant.trail_stems(N / 8 + t * N / TRAILS,
                                               t * N / TRAILS + (N / 8 if t % 2 else 0), phase))
    later = []
    for t, own, cane, nodes, canes in trails:          # the flowering shoots, every trail
        for k, p, up, side in nodes:
            if k in BIG_SHOOT:
                plant.shoot(p, up, side, 'big', own, stage=later)
            elif k in SMALL_SHOOT:
                plant.shoot(p, up, side, 'small', own, stage=later)
    for t, own, cane, nodes, canes in trails:
        for k, p, up, side in nodes:
            if k in LEAFY_SHOOT:
                plant.shoot(p, up, side, 'leafy', own, rose=t in SMALL_TWIG and k == LEAFY_SHOOT[0],
                            stage=later)
    plant.grow_leaves(later)                           # the shoots' leaves
    plant.phase = 'trail'
    for t, own, cane, nodes, canes in trails:          # the trails' and canes' leaves
        for k, p, up, side in nodes:
            if k in BIG_SHOOT or k in SMALL_SHOOT or k in LEAFY_SHOOT:
                continue
            ang = np.radians(rng.uniform(48, 64))
            plant.log['petiole_angles'].append(np.degrees(ang))
            plant.leaf(p, up + side * ang, rng.uniform(0.95, 1.05), int(rng.choice(TRAIL_PAIRS)), own, side)
        for p, up, side in canes:
            ang = np.radians(rng.uniform(45, 60))
            plant.log['petiole_angles'].append(np.degrees(ang))
            plant.leaf(p, up + side * ang, rng.uniform(0.85, 0.95), 3, cane, side)
    plant.fill()
    cv = lc.Canvas(N, N)
    plant.draw(cv)
    return cv.finish(), plant


def report(plant):
    lines = lr.report(plant)
    lg = plant.log
    lines.append('left off: ' + ', '.join(f'{k[8:]} {v}' for k, v in lg.items() if k.startswith('skipped_')))
    big = sum(1 for f in plant.flowers if f[0] == 'rose' and f[3] > mm(30))
    lines.append(f'big roses {big}; gaps filled {lg["filled"]}, {lg["fill_flowers"]} with a flower')
    print(lines[-1])
    return lines


def bake(out, seed=SEED, tag='f3'):
    net = lace.net_tile()
    cloth = (lc.weave('whole'), lc.weave('half'))
    (sd, vein, half), plant = grow(seed)
    big = [f for f in plant.flowers if f[1] == 'open6' and f[3] > mm(30)]
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
    lines = report(plant)
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
