#!/usr/bin/env python3
"""Prototype: the library's lace grown as wild roses by a botanical grammar (way f).

    python3 tools/materials/lace_rose.py OUT_DIR [--seed N] [--sprig-only]
    python3 tools/materials/lace_rose.py --page PAGE_DIR WAY_DIR PHOTO_DIR [WAY_DIR ...]

--seed grows the plant (SEED, 4); --sprig-only draws just the anatomy sprig. --page
writes PAGE_DIR/index.html from a baked WAY_DIR: the sprig, the tile, and the 14 cm and
50 cm crops beside the download and the wild rose photos in PHOTO_DIR (17.png, a leaf;
20.png, a flower; the user's, local), with more ways' tiles and crops beside f's (f2,
lace_rose2.py's; f3, lace_rose3.py's). The library's copy and its page:
    MANOR_DIR=.../design/manor lace_rose.py build/notes/lace-library/f --seed 4
    lace_rose.py --page build/notes/lace-rose build/notes/lace-library/f PHOTO_DIR \
        build/notes/lace-library/f2 build/notes/lace-library/f3

After Wong, Zongker and Salesin's floral ornament and the L-systems behind it: a few
rules grow every part from a stem, and the layout comes out of the growth, not a
tracing. All on lace_crisp's Canvas, as distances at 4096 px a tile.
- Trails: four a tile, 14 cm apart as the download's stems, each dropped a little from
  the last, a stem swaying gently once a tile (so it tiles), with nodes at even steps,
  the side alternating at each.
- A node bears a pinnate leaf, or a shoot leaving at 35 to 55 degrees up and out that
  curves back toward the vertical: a long one ends in a big open rose and carries
  leaves and a side shoot with a bud; a short one ends in a small rose or a half-open
  one; a leafy one carries leaves and a twig and ends in a young leaf. A trail a tile:
  one long, one short, two leafy shoots, so a tile holds 4 big roses and about 8 small
  heads (small and half-open roses, buds).
- A leaf: a petiole with two stipules at its foot, a rachis bending gently up, a
  terminal leaflet and 1 to 3 opposite pairs, the top pair close under the terminal (the
  three read together), each pair smaller and wider set going down. Leaflets are ovate,
  finely serrated, a midrib and side veins as open lines, half stitch on their shaded
  side. Leaves get smaller toward a shoot's tip; the last below a bud is young, folded.
- Roses: lace_blossom's wild rose, tilted so its near side faces the stem it grows on;
  half-open ones with two sepals clasping; buds with their sepals.
A part is grown only where it fits (a coarse occupancy grid, wrapping): a leaf that
does not fit tries fewer pairs, smaller, turned, and is left off otherwise, so nothing
floats and little overlaps. The hem is lace_crisp's (way c's, as way d's).
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw

import common as cm
import lace
import lace_blossom as lb
import lace_crisp as lc
from lace_crisp import BIG, N, mm

SEED = 4
TRAILS = 4                  # a tile across, 14 cm apart as the download's; each dropped
                            # a quarter tile more than the last
NODES = 16                  # on a trail a tile: 35 mm apart, alternating sides
SWAY_MM = (22.0, 4.0)       # the trail's sway once and twice a tile
BIG_SHOOT = (0,)            # nodes bearing a long shoot to a big rose
SMALL_SHOOT = (8,)          # nodes bearing a short shoot to a small or half-open rose
LEAFY_SHOOT = (3, 6, 11, 14)  # nodes bearing a leafy shoot, ending in a leaf (a rose on SMALL_TWIG trails)
SMALL_TWIG = (1, 3)         # trails whose first leafy shoot's twig ends in a small rose
TERMINAL_MM = 30.0          # a full-size terminal leaflet's length
LEAFLET_W = 0.56            # its width, of its length (ovate)
PAIR_SIZE = (0.88, 0.76, 0.66)   # each pair down from the top, of the terminal
PAIR_ANGLE = (40.0, 55.0, 62.0)  # degrees from the rachis, top pair first
PAIR_GAP = (0.24, 0.6, 0.55)     # rachis between tip and top pair, and between pairs, of the terminal
LIGHT = np.array([0.5, -0.85])   # where the light comes from (screen, y down): the far side is half stitch
STEM_MM = (1.0, 0.7, 0.5, 0.32)  # radius: trail, shoot, shoot's tip, rachis
CELL = 8                    # px an occupancy cell: 1.1 mm
FIT = 0.09                  # the share of a part's cells that may lie on others'


def heading_curve(p, h0, h1, length, n=24):
    """Points from p whose heading turns linearly from h0 to h1 over length."""
    hs = h0 + (h1 - h0) * (np.arange(n - 1) + 0.5) / (n - 1)
    step = length / (n - 1)
    d = np.stack([np.cos(hs), np.sin(hs)], 1) * step
    return np.concatenate([[p], p + np.cumsum(d, 0)]), np.linspace(h0, h1, n)


def at(pts, hs, f):
    """The point and heading a share f along a heading_curve."""
    k = f * (len(pts) - 1)
    i = min(int(k), len(pts) - 2)
    t = k - i
    return pts[i] * (1 - t) + pts[i + 1] * t, hs[i] * (1 - t) + hs[i + 1] * t


def unit(h):
    return np.array([np.cos(h), np.sin(h)])


UP = -np.pi / 2


class Occ:
    """Which part holds each 1.1 mm cell, wrapping as the tile does."""

    def __init__(self, h, w):
        self.g = np.zeros((h // CELL, w // CELL), np.int32)
        self.n = 0

    def new(self):
        self.n += 1
        return self.n

    def cells(self, discs):
        gh, gw = self.g.shape
        ys_all, xs_all = [], []
        for x, y, r in discs:
            cx, cy, rc = x / CELL, y / CELL, r / CELL
            ys = np.arange(int(np.floor(cy - rc)), int(np.ceil(cy + rc)) + 1)
            xs = np.arange(int(np.floor(cx - rc)), int(np.ceil(cx + rc)) + 1)
            Y, X = np.meshgrid(ys, xs, indexing='ij')
            m = (X + 0.5 - cx) ** 2 + (Y + 0.5 - cy) ** 2 <= rc * rc
            ys_all.append(Y[m] % gh)
            xs_all.append(X[m] % gw)
        if not ys_all:
            return np.zeros(0, int), np.zeros(0, int)
        return np.concatenate(ys_all), np.concatenate(xs_all)

    def clash(self, discs, allow=()):
        yy, xx = self.cells(discs)
        if len(yy) == 0:
            return 0.0
        v = self.g[yy, xx]
        return float(((v != 0) & ~np.isin(v, list(allow))).mean())

    def add(self, discs, owner):
        yy, xx = self.cells(discs)
        free = self.g[yy, xx] == 0
        self.g[yy[free], xx[free]] = owner


def curve_discs(pts, r):
    return [(p[0], p[1], r) for p in pts]


# The parts, as drawing steps on a Canvas.

def leaflet(cv, base, ang, L, W, bend, folded=False, veins=True, seed=0):
    """An ovate leaflet from base along ang: rounded base, widest at two fifths, a drawn
    point; fine teeth pointing to the tip; a midrib and side veins; half stitch on the
    side away from LIGHT. folded: a young leaflet folded on its midrib, one half shown."""
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
    pitch = L / 12
    saw = (s / pitch + rng.random()) % 1
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
            vein = np.where((u > 0.04) & (u < 0.86), np.abs(t), BIG)
        k = 1.0                                         # side veins at 45 degrees, forward
        sp = L / 5
        sv = np.abs(((s - across * k) / sp) % 1 - 0.5) * sp / np.sqrt(1 + k * k)
        sv = np.where((u > 0.1) & (u < 0.84) & (across < 0.72 * w) & (across > mm(0.55)), sv, BIG)
        vein = np.minimum(vein, sv)
    n_plus = np.array([-sa, ca])                        # the t > 0 side's outward normal
    shade = 1 if n_plus @ LIGHT < 0 else -1
    half = np.ones_like(X) if folded else (t * shade > 0).astype(np.float32)
    cv.paint(ix, d, vein, half)


class Plant:
    """The plan: stems, leaves and flowers as steps in three layers, and what was grown."""

    def __init__(self, h, w, rng):
        self.occ = Occ(h, w)
        self.rng = rng
        self.stems, self.leaves, self.flowers = [], [], []
        self.log = dict(leaves=[], shoot_angles=[], petiole_angles=[], pair_angles=[],
                        flowers=[], skipped=0)
        self.labels = {}                                 # for the anatomy sprig

    def stem(self, pts, r0, r1=None, owner=None):
        r1 = r0 if r1 is None else r1
        self.stems.append((np.asarray(pts), r0, r1))
        if owner is not None:
            self.occ.add(curve_discs(pts, max(r0, r1) + mm(1.5)), owner)

    # A pinnate leaf.

    def leaf_spec(self, P, h, scale, pairs, bend, folded=False):
        rng = self.rng
        Lt = mm(TERMINAL_MM) * scale
        gaps = [PAIR_GAP[i] * Lt for i in range(pairs)]
        below_tip = np.cumsum(gaps)
        pl = mm(6.5) * scale                             # the petiole, to the lowest pair
        total = pl + (below_tip[-1] if pairs else 0) + mm(0.5)
        pts, hs = heading_curve(np.asarray(P, float), h, h + bend, total, 20)
        parts = []
        jit = rng.normal(0, 0.04)
        for j in reversed(range(pairs)):                 # the lowest first: the top lies over
            a = (total - below_tip[j]) / total
            p, hh = at(pts, hs, a)
            L = PAIR_SIZE[j] * Lt * rng.uniform(0.97, 1.03)
            ang = np.radians(PAIR_ANGLE[j]) + jit
            for side in (-1, 1):
                b = p + unit(hh + side * np.pi / 2) * mm(0.5) * scale
                parts.append((b, hh + side * ang, L, LEAFLET_W * L, side * 0.08, folded))
        tip, th = pts[-1], hs[-1]
        parts.append((tip, th + rng.normal(0, 0.05), Lt, LEAFLET_W * Lt, rng.normal(0, 0.05), folded))
        discs = curve_discs(pts[::3], mm(1.2))
        for b, a, L, W, _, _ in parts:
            for f, rr in ((0.3, 0.5), (0.58, 0.45), (0.84, 0.28)):
                c = b + unit(a) * L * f
                discs.append((c[0], c[1], W * rr * (0.55 if folded else 1)))
        return dict(pts=pts, hs=hs, parts=parts, discs=discs, P=P, h=h, scale=scale,
                    pairs=pairs, folded=folded, Lt=Lt)

    def leaf(self, P, h, scale, pairs, parent, side, folded=False, tries=True):
        """Grows a leaf at P heading h if it fits; fewer pairs, smaller, turned toward the
        stem otherwise. Returns its spec or None."""
        rng = self.rng
        bend = -side * rng.uniform(0.15, 0.3)            # the rachis bends back up
        options = [(pairs, scale, 0.0)]
        if tries:
            options += [(pairs, scale, -side * 0.25), (pairs, scale, side * 0.2), (pairs, scale * 0.85, 0.0),
                        (max(pairs - 1, 1), scale * 0.85, -side * 0.2),
                        (max(pairs - 1, 1), scale * 0.7, side * 0.2)]
        for n, sc, turn in options:
            spec = self.leaf_spec(P, h + turn, sc, n, bend, folded)
            if self.occ.clash(spec['discs'], allow=(parent,)) <= FIT:
                own = self.occ.new()
                self.occ.add(spec['discs'], own)
                self.leaves.append(spec)
                self.log['leaves'].append(n)
                self.log['pair_angles'] += [PAIR_ANGLE[j] for j in range(n)]
                return spec
        self.log['skipped'] += 1
        return None

    # Flowers.

    def rose(self, tip, h, kind, R, parent):
        """A rose facing along h at a stem's tip: its near side toward the stem."""
        rot = np.arctan2(np.cos(h), -np.sin(h))
        shift = {'face': 0.12, 'face6': 0.12, 'three_quarter': 0.25, 'half_open': 0.4}.get(kind, 0.2)
        c = tip + unit(h) * shift * R
        squash = lb.KINDS[kind][0]
        self.occ.add([(c[0], c[1], R * 1.02)], parent)
        self.flowers.append(('rose', kind, c, R, rot, int(self.rng.integers(1 << 30)), h))
        self.log['flowers'].append(kind)
        return c

    def bud(self, tip, h, R, parent):
        rot = np.arctan2(np.cos(h), -np.sin(h))
        H = 1.7 * R
        c = tip + unit(h) * 0.42 * H
        self.occ.add([(c[0], c[1], 0.75 * H)], parent)
        self.flowers.append(('bud', 'bud', c, R, rot, int(self.rng.integers(1 << 30)), h))
        self.log['flowers'].append('bud')
        return c

    # Shoots.

    def shoot(self, P, up, side, kind, parent, rose=False):
        """A shoot from P on a stem heading up: out at 35 to 55 degrees, curving back
        toward the vertical; leaves alternating on it, smaller toward its tip; a flower or
        bud at its tip."""
        rng = self.rng
        a0 = np.radians(rng.uniform(38, 52) if kind == 'big' else rng.uniform(35, 55))
        self.log['shoot_angles'].append(np.degrees(a0))
        a1 = a0 * rng.uniform(0.1, 0.35)
        L = mm({'big': rng.uniform(105, 125), 'small': rng.uniform(55, 70),
                'leafy': rng.uniform(85, 110), 'twig': rng.uniform(40, 55), 'bud': rng.uniform(32, 42)}[kind])
        h0, h1 = up + side * a0, up + side * a1
        pts, hs = heading_curve(np.asarray(P, float), h0, h1, L)
        own = self.occ.new()
        r0, r1 = (STEM_MM[1], STEM_MM[2]) if kind not in ('bud', 'twig') else (STEM_MM[2], STEM_MM[3] + 0.1)
        self.stem(pts, mm(r0), mm(r1))
        tip, th = pts[-1], hs[-1]
        if kind == 'big':
            R = mm(rng.uniform(28, 32))
            fk = 'three_quarter' if rng.random() < 0.3 else 'face'
            self.rose(tip, th, fk, R, own)
        elif kind == 'small':
            if rng.random() < 0.75:
                R = mm(rng.uniform(17, 21))
                self.rose(tip, th, 'face', R, own)
            else:
                R = mm(rng.uniform(16, 19))
                self.rose(tip, th, 'half_open', R, own)
        elif kind == 'bud':
            self.bud(tip, th, mm(rng.uniform(8, 9.5)), own)
        self.occ.add(curve_discs(pts[:-2], mm(r0) + mm(1.5)), own)
        # Leaves and side shoots along it.
        if kind == 'big':
            plan = [(0.25, 'leaf', -side, 0.9), (0.45, 'bud', side, 0), (0.68, 'leaf', -side, 0.75)]
        elif kind == 'small':
            plan = [(0.4, 'leaf', -side, 0.75)]
        elif kind == 'leafy':
            plan = [(0.22, 'leaf', -side, 0.9), (0.45, 'small' if rose else 'twig', side, 0),
                    (0.7, 'leaf', -side, 0.75)]
        elif kind == 'twig':
            plan = [(0.4, 'leaf', -side, 0.7)]
        else:
            plan = [(0.55, 'young', -side, 0.42)]
        if kind in ('leafy', 'twig'):                    # its tip: a young leaf, still opening
            self.leaf(tip, th, 0.62 if kind == 'leafy' else 0.5, 1, own, side, tries=True)
        for f, what, s, sc in plan:
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
                self.leaf(p, hh + s * ang, sc, 2 if sc > 0.8 else int(rng.choice([1, 2])), own, s)
        return pts

    # A trail.

    def trail(self, ox, oy, phase, index):
        rng = self.rng
        ph2 = rng.uniform(0, 2 * np.pi)

        def x_at(y):
            return (ox + mm(SWAY_MM[0]) * np.sin(2 * np.pi * y / N + phase)
                    + mm(SWAY_MM[1]) * np.sin(4 * np.pi * y / N + ph2))

        ys = np.linspace(0, N, 257)
        pts = np.stack([x_at(ys), ys + oy], 1)
        own = self.occ.new()
        self.stem(pts, mm(STEM_MM[0]), owner=own)
        nodes = []
        for k in range(NODES):
            y = (k + 0.5 + rng.uniform(-0.12, 0.12)) * N / NODES
            p = np.array([x_at(y), y + oy])
            up = np.arctan2(-1.0, -(x_at(y + 4) - x_at(y - 4)) / 8)
            nodes.append((k, p, up, 1 if k % 2 == 0 else -1))
        # Shoots first, they need the room; then the leaves between.
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
            pairs = int(rng.choice([2, 2, 2, 3, 1]))
            self.leaf(p, up + side * ang, rng.uniform(0.92, 1.05), pairs, own, side)

    # Drawing.

    def draw(self, cv):
        for pts, r0, r1 in self.stems:
            cv.curve('sd', pts, r0, r1)
        for spec in self.leaves:
            pts = spec['pts']
            cv.curve('sd', pts, mm(STEM_MM[3] + 0.12) * min(spec['scale'], 1), mm(STEM_MM[3]) * min(spec['scale'], 1))
        for spec in self.leaves:
            P, h, sc = np.asarray(spec['P']), spec['h'], spec['scale']
            if not spec['folded']:
                for s in (-1, 1):                        # stipules hugging the petiole's foot
                    leaflet(cv, P - unit(h) * mm(0.8) * sc, h + s * 0.3, mm(5) * sc, mm(1.6) * sc,
                            -s * 0.15, veins=False, seed=abs(int(P[0] * 7 + s)))
            for i, (b, a, L, W, bend, folded) in enumerate(spec['parts']):
                leaflet(cv, b, a, L, W, bend, folded, seed=abs(int(b[0] * 13 + b[1] * 7 + i)))
        for f in self.flowers:
            what, kind, c, R, rot, seed, h = f
            rng = np.random.default_rng(seed)
            if what == 'bud':
                lb.bud(cv, c, R, rot, rng)
                continue
            if kind == 'half_open':                      # two sepals clasping from behind
                base = c - unit(h) * 0.35 * R
                for s in (-1, 1):
                    leaflet(cv, base, h + s * 0.85, 0.62 * R, 0.2 * R, -s * 0.25, veins=False,
                            seed=abs(seed + s))
            lb.Blossom(kind, rng, lb.TILT_DEG).draw(cv, c, R, rot)


def grow(seed=SEED):
    """The field tile: (sd, vein, half) and the plant (for its log and its big roses)."""
    rng = np.random.default_rng(seed)
    plant = Plant(N, N, rng)
    for t in range(TRAILS):
        plant.trail(N / 8 + t * N / TRAILS, t * N / TRAILS + (N / 8 if t % 2 else 0), rng.uniform(0, 2 * np.pi), t)
    cv = lc.Canvas(N, N)
    plant.draw(cv)
    return cv.finish(), plant


def report(plant):
    lg = plant.log
    leaves = lg['leaves']
    kinds = {k: lg['flowers'].count(k) for k in sorted(set(lg['flowers']))}
    hist = {n: leaves.count(n) for n in sorted(set(leaves))}
    lines = [
        f'flowers {len(lg["flowers"])}: ' + ', '.join(f'{k} {v}' for k, v in kinds.items()),
        f'leaves {len(leaves)} (pairs: ' + ', '.join(f'{n}: {v}' for n, v in hist.items())
        + f'), {lg["skipped"]} left off for room',
        f'leaflets a leaf: {np.mean([2 * n + 1 for n in leaves]):.1f}',
        f'shoots leave at {min(lg["shoot_angles"]):.0f} to {max(lg["shoot_angles"]):.0f} deg '
        f'(mean {np.mean(lg["shoot_angles"]):.0f}); petioles at {min(lg["petiole_angles"]):.0f} to '
        f'{max(lg["petiole_angles"]):.0f} deg',
    ]
    for ln in lines:
        print(ln)
    return lines


# The anatomy sprig: one long shoot alone, its parts labelled.

def sprig(cloth, net):
    h, w = 1800, 1400
    rng = np.random.default_rng(12)
    plant = Plant(h, w, rng)
    base = np.array([w * 0.36, h - 30.0])
    pts, hs = heading_curve(base, UP - 0.04, UP + 0.1, h * 0.72)
    own = plant.occ.new()
    plant.stem(pts, mm(STEM_MM[0]), owner=own)
    p1, h1 = at(pts, hs, 0.16)
    leaf1 = plant.leaf(p1, h1 - np.radians(55), 1.0, 3, own, -1, tries=False)
    p2, h2 = at(pts, hs, 0.36)
    shoot = plant.shoot(p2, h2, 1, 'big', own)
    p3, h3 = at(pts, hs, 0.6)
    leaf2 = plant.leaf(p3, h3 - np.radians(50), 0.9, 2, own, -1, tries=False)
    plant.rose(pts[-1], hs[-1], 'half_open', mm(19), own)
    cv = lc.Canvas(h, w, wrap_y=False)
    plant.draw(cv)
    sd, vein, half = cv.finish()
    cov = lc.render(sd, vein, half, (lb._tile(cloth[0], h, w), lb._tile(cloth[1], h, w)))
    front, _ = lace.shade(np.maximum(lb._tile(lace.tiled(net, lace.NET_REPEAT), h, w) * 0.35, cov))
    im = Image.fromarray((np.clip(front, 0, 1) * 255 + 0.5).astype(np.uint8)).convert('RGB')
    d = ImageDraw.Draw(im)
    from lace_compare import font
    f = font(28)
    big = next(fl for fl in plant.flowers if fl[1] in ('face', 'three_quarter'))
    bud = next(fl for fl in plant.flowers if fl[0] == 'bud')
    half_open = plant.flowers[-1]
    lt = leaf1['parts']

    def mid(part, f=0.5):
        return part[0] + unit(part[1]) * part[2] * f

    labels = [
        ('trail stem', at(pts, hs, 0.05)[0], (120, 0)),
        ('petiole', at(leaf1['pts'], leaf1['hs'], 0.08)[0], (60, 90)),
        ('stipules', np.asarray(leaf1['P']), (80, 30)),
        ('rachis', at(leaf1['pts'], leaf1['hs'], 0.55)[0], (-150, -40)),
        ('terminal leaflet', mid(lt[-1]), (-60, -190)),
        ('top pair, close under it', mid(lt[-2]), (50, -170)),
        ('lower pairs, smaller', mid(lt[0]), (-120, 150)),
        ('midrib, side veins, half stitch', mid(leaf2['parts'][-1], 0.6), (-30, -120)),
        ('shoot, out at %d deg' % plant.log['shoot_angles'][0], shoot[len(shoot) // 4], (90, 60)),
        ('open rose: 5 petals, boss', big[2], (-120, -big[3] - 80)),
        ('side shoot, bud with sepals', bud[2], (90, 60)),
        ('half-open rose, sepals', half_open[2], (-60, -half_open[3] - 60)),
    ]
    for text, p, off in labels:
        q = (p[0] + off[0], p[1] + off[1])
        d.line([tuple(p), q], fill=(76, 201, 240), width=3)
        d.ellipse([p[0] - 5, p[1] - 5, p[0] + 5, p[1] + 5], fill=(76, 201, 240))
        tw = d.textlength(text, font=f)
        tx = q[0] - tw - 6 if off[0] < 0 else q[0] + 6
        tx = min(max(tx, 4), w - tw - 4)
        d.text((tx, q[1] - 15), text, fill=(236, 232, 224), font=f, stroke_width=3, stroke_fill=(20, 19, 18))
    return im, plant


def bake(out, seed=SEED, sprig_only=False):
    net = lace.net_tile()
    cloth = (lc.weave('whole'), lc.weave('half'))
    im, sp = sprig(cloth, net)
    im.save(os.path.join(out, 'f_sprig.jpg'), quality=90)
    print('wrote', os.path.join(out, 'f_sprig.jpg'))
    if sprig_only:
        return
    (sd, vein, half), plant = grow(seed)
    # A big rose where lace_compare's 14 cm window looks (0.149, 0.222 m from the corner).
    big = [f for f in plant.flowers if f[1] in ('face', 'three_quarter') and f[3] > mm(24)]
    c = big[0][2]
    want = np.array([0.149, 0.222]) / lace.TILE_M * N
    dy, dx = int(round(want[1] - c[1])), int(round(want[0] - c[0]))
    sd, vein, half = (np.roll(a, (dy, dx), (0, 1)) for a in (sd, vein, half))
    motif = lc.render(sd, vein, half, cloth)
    src = cm.load(cm.source('library-lace-01.png'))

    def hem_motifs(cv, g, traced=lc.hem_motifs_traced(src)):      # way c's, as way d's
        sd_h, _, half_h = traced(cv, g)
        return lc.regrow_flowers(sd_h, half_h, wrap_y=False)
    hem = lc.hem_strip(hem_motifs, cloth, motif)
    close = (int(want[1]) - 512, int(want[0]) - 512)
    mean = lc.views(out, 'f', motif, hem, net, close)
    cm.save(os.path.join(out, 'f_motif.png'), lace.box(motif, 4))
    lines = report(plant)
    with open(os.path.join(out, 'f_report.txt'), 'w') as fh:
        fh.write(f'seed {seed}, mean field coverage {mean:.2f}\n' + '\n'.join(lines) + '\n')


def page(out, way_dir, photos, *more):
    """The page: the sprig, the tile, the crops beside the download and the photos; more
    baked ways (as f2 and f3) beside f's."""
    import shutil
    import lace_compare as lcmp
    os.makedirs(out, exist_ok=True)
    shutil.copy(os.path.join(way_dir, 'f_sprig.jpg'), os.path.join(out, 'sprig.jpg'))
    for name, dst in (('17.png', 'photo_leaf.jpg'), ('20.png', 'photo_rose.jpg')):
        Image.open(os.path.join(photos, name)).convert('RGB').save(os.path.join(out, dst), quality=88)
    net = lace.net_tile()
    src_lin = cm.to_linear(cm.load(cm.source('library-lace-01.png')))
    valid = (lcmp.FIELD_ROWS[0], lcmp.FIELD_ROWS[1], lace.FIELD[0], lace.FIELD[2])
    what = {'f': 'wild rose grammar', 'f2': 'fuller leaves, twining stems',
            'f3': 'frond leaves, gaps filled, larger roses'}

    def pre(tag):
        return '' if tag == 'f' else tag + '_'

    tags, reports, crops = [], {}, []
    for wd in (way_dir,) + more:
        tag = os.path.basename(os.path.normpath(wd))
        tags.append(tag)
        way = lcmp.Way(os.path.dirname(os.path.abspath(wd)), tag, tag, net)
        front, back = lace.shade(way.quarter)
        lace.save_jpg(os.path.join(out, f'{pre(tag)}tile_front.jpg'), front)
        lace.save_jpg(os.path.join(out, f'{pre(tag)}tile_backlit.jpg'), back)
        crops = []
        for i, (vname, win, size) in enumerate(lcmp.FIELD_VIEWS[:2]):
            if len(tags) == 1:
                img, _ = lcmp.download_view(src_lin, win, size, lace.FIELD[0], lace.FIELD[1], valid)
                lcmp.labelled(img, lcmp.GPT, 'ChatGPT (library-lace-01)', 'the download, ' + vname,
                              'its own light: front-lit on black').save(os.path.join(out, f'crop{i}_download.jpg'), quality=88)
            f, b = lace.shade(way.field(win, size))
            for kind, img, light in (('front', f, 'front-lit on a dark ground'),
                                     ('backlit', b, 'backlit by a bright window')):
                lcmp.labelled(img, lcmp.OURS, f'Ours: {tag}', f'{what.get(tag, tag)}, {vname}',
                              light).save(os.path.join(out, f'{pre(tag)}crop{i}_{kind}.jpg'), quality=88)
            crops.append(vname)
        with open(os.path.join(wd, f'{tag}_report.txt')) as fh:
            reports[tag] = fh.read().strip().splitlines()

    def fig(src, cap):
        return f'<figure><a href="{src}" target="_blank"><img src="{src}" loading="lazy"></a><figcaption>{cap}</figcaption></figure>'

    report_html = ''.join(f'<h3>{t}</h3><ul>' + ''.join(f'<li>{ln}</li>' for ln in reports[t]) + '</ul>'
                          for t in tags)
    tiles = ''.join(fig(f'{pre(t)}tile_{k}.jpg', f'{t}, one tile, ' + ('front-lit on dark' if k == 'front' else 'backlit'))
                    for k in ('front', 'backlit') for t in tags)
    rows = ''
    n = len(tags) + 1                                    # the download, then each way
    for i, vname in enumerate(crops):
        rows += f'<h2>{vname}</h2><div class="grid" style="--n: {n}">' + fig(f'crop{i}_download.jpg', 'the download')
        rows += ''.join(fig(f'{pre(t)}crop{i}_front.jpg', f'{t}, front-lit') for t in tags) + '</div>'
        rows += f'<div class="grid" style="--n: {n}"><div></div>'
        rows += ''.join(fig(f'{pre(t)}crop{i}_backlit.jpg', f'{t}, backlit') for t in tags) + '</div>'
    f2_note = ''
    if 'f2' in tags:
        f2_note = '''<h2>f2: fuller and twining</h2>
<p>Way f's botany grown fuller by tools/materials/lace_rose2.py: most leaves a terminal
leaflet and two pairs, three low on a shoot and on most trail leaves, allowed to lie a
little over one another (each leaflet keeps its outline thread, so the overlap reads)
instead of being left off, but kept off the flowers; the trails sway half again as far,
neighbours nearly together, and a thinner cane winds round each, crossing it twice a
tile; shoots arc over past the vertical; side veins are single open lines, not corded,
so they no longer read as hatching; half-open roses are a cup seen from the side in two
flaring sepals; buds are larger, with longer sepals.</p>'''
    if 'f3' in tags:
        f2_note += '''<h2>f3: fronds, no gaps, larger roses</h2>
<p>f2 grown by tools/materials/lace_rose3.py: leaves are fronds of small leaflets (a 17 mm
terminal, f2's 30) with two or three pairs, so they fit where f2's were left off; every
trail grows its flowering shoots first, then the leafy ones, then the leaves, and each
shoot takes the least crowded of six arcs; the free space left is then measured and each
gap wider than 17 mm gets a leaf, or a twig with leaves and now and then a small rose or
bud, from one of its nearest stems. Big roses are two a trail, 39 to 43 mm, mostly of
six broad petals with rounder tips, each petal rimmed by an open line inside its outline
so it reads over the next.</p>'''
    html = f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Wild rose lace</title>
<style>
:root {{ --bg: #141312; --fg: #ece8e0; --muted: #a9a399; }}
* {{ box-sizing: border-box; }}
body {{ background: var(--bg); color: var(--fg); font: 16px/1.5 system-ui, sans-serif; margin: 0; padding: 16px 24px 64px; }}
h1 {{ font-size: 24px; margin: 8px 0 4px; }}
h2 {{ font-size: 20px; margin: 36px 0 6px; border-bottom: 2px solid #333; padding-bottom: 4px; }}
h3 {{ font-size: 17px; margin: 14px 0 2px; }}
p, li {{ color: var(--muted); max-width: 95ch; }}
.grid {{ display: grid; gap: 14px; grid-template-columns: repeat(var(--n, 3), minmax(0, 1fr)); align-items: start; margin-bottom: 14px; }}
@media (max-width: 900px) {{ .grid {{ grid-template-columns: 1fr; }} }}
figure {{ margin: 0; }}
img {{ width: 100%; display: block; background: #000; }}
figcaption {{ color: var(--muted); font-size: 14px; margin-top: 4px; }}
</style></head><body>
<h1>Wild rose lace: way f, a botanical grammar{''.join(', and ' + t for t in tags[1:])}</h1>
<p>Grown by tools/materials/lace_rose.py (seed in the report below): trails with nodes
alternating sides; at each node a pinnate leaf or a shoot leaving 35 to 55 degrees up and
out; leaves of a terminal leaflet and 1 to 3 opposite pairs, the top pair close under the
terminal; roses only at the tips of shoots. Nothing floats: every part hangs on a stem.
Click an image for full size.</p>
{f2_note}
<h2>One sprig's anatomy (f)</h2>
<p>A trail stem with a leaf of three pairs, a long shoot to an open rose carrying two
leaves and a side shoot with a bud, a second leaf, and the stem's tip a half-open rose.
Beside it the photos it follows: a wild rose leaf (terminal leaflet, opposite pairs,
ovate, serrated) and a wild rose (five broad petals, a boss, pinnate leaves alternating).</p>
<div class="grid">{fig('sprig.jpg', 'the sprig, at full detail (19 x 25 cm), front-lit')}
{fig('photo_leaf.jpg', "a wild rose leaf (the user's reference)")}
{fig('photo_rose.jpg', "a wild rose (the user's reference)")}</div>
<h2>Counts and angles</h2>
{report_html}
<p>The photo's leaf: a terminal and 3 pairs, the pairs at about 55 to 65 degrees to the
rachis; ours take the top pair at about 40 (so the three read together), the next at 55,
the lowest at 62. Its leaves leave the stem at about 45 to 60 degrees; ours 45 to 64.
Mean field coverage counts the net.</p>
<h2>The tile, 0.56 m</h2>
<div class="grid" style="--n: {len(tags)}">{tiles}</div>
{rows}
<p>All the ways side by side: <a style="color:inherit" href="../lace-compare/index.html">lace-compare</a>.</p>
</body></html>
'''
    with open(os.path.join(out, 'index.html'), 'w') as fh:
        fh.write(html)
    print('wrote', os.path.join(out, 'index.html'))


if __name__ == '__main__':
    args = sys.argv[1:]
    if args[:1] == ['--page']:
        if len(args) < 4:
            sys.exit(__doc__)
        page(*args[1:])
        sys.exit()
    only = '--sprig-only' in args
    args = [a for a in args if a != '--sprig-only']
    opts = dict(zip(args[1::2], args[2::2]))
    if not args or len(args) % 2 != 1 or set(opts) - {'--seed'}:
        sys.exit(__doc__)
    os.makedirs(args[0], exist_ok=True)
    bake(args[0], int(opts.get('--seed', SEED)), only)
