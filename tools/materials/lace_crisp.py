#!/usr/bin/env python3
"""Prototype: the library's lace with crisp motifs, two ways, beside lace.py's bake.

    python3 tools/materials/lace_crisp.py OUT_DIR [--ways abc] [--seed N]

--ways bakes only those ways; --seed replaces the way's seed (SEEDS: b grows from 7, its
hem from HEM_SEED 11; c regrows its flowers from 5; a has none). The library's copies:
    lace_crisp.py build/notes/lace-library/a --ways a
    lace_crisp.py build/notes/lace-library/b --ways b --seed 7
    lace_crisp.py build/notes/lace-library/c --ways c --seed 5
Each writes TAG_motif_full.png and TAG_hem_full.png (the motif and hem at full detail)
beside its previews, for lace_compare.py. With all three ways it also writes contact.html.

Both ways draw at the field's full detail, 4096 px a tile (0.137 mm a px, as the net's 16
tiles do), as distances: the motifs' silhouette as a signed distance (negative inside),
the veins as the distance to their centre lines, and where the clothwork is half stitch
(lighter). One structure turns them into coverage, as Leavers lace is built:
- clothwork: a fine woven fill denser than the net, so light still passes a little,
- the gimp: a raised outline thread round each motif, its holes, and its open veins,
- veins: a corded line with an open channel each side.
Way a traces the download's silhouettes (potrace) at 4x their source detail and carves
its veins and eyes in; way b grows its own: vines, compound leaves, rosettes; way c is
a's tracing with its flowers (its widest blobs) redrawn as b's rosettes. The hem is
parametric in both: big scallops of small lobes with picots, an eyelet band, double gimp
lines, a coarse openwork, and the garland arcs; ways a and c fill it with the download's traced
flowers (c's regrown), way b with its own.

The shader would take the distances, not coverage (way b's `encoded` previews): an RGBA8
motif texture, R silhouette distance, G vein distance, B half stitch, magnified with a
smoothstep, so edges stay crisp at any distance; the weaves would join the net texture.
"""

import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

import common as cm
import lace

N = 4096                    # px a motif tile at full detail
PX_MM = N / (lace.TILE_M * 1000)   # 7.31 px a mm
HEM_H = 1536                # px: the hem strip, 0.21 m
BIG = 1e4

GIMP_MM = 0.55              # the outline thread's width
VEIN_CORD_MM = 0.4         # a vein's cord, and the open channel each side of it
VEIN_OPEN_MM = 0.2
CLOTH = 0.84                # coverage of whole stitch (the weave's mean)
HALF = 0.55                 # coverage of half stitch


def mm(v):
    return v * PX_MM


# The weaves: whole stitch, threads close with pinholes in a brick bond 0.55 mm apart;
# half stitch, the same with larger, diagonal holes. Both tile the 4096 px tile.

def weave(kind):
    """Clothwork as threads running down the cloth, 0.55 mm apart, crossed by the bobbin
    threads: long narrow gaps between them in a brick bond. Half stitch has wider gaps
    that lean, as its diagonals do."""
    ss = 8
    ph, pw = 8, 4                       # px: a cell of the bond is 4 x 8 (two rows)
    y, x = (np.mgrid[0:ph * ss, 0:pw * ss] + 0.5) / ss
    lean = 0.0 if kind == 'whole' else 0.35
    hw, hh = (0.55, 1.6) if kind == 'whole' else (0.9, 1.8)
    d = []
    for cy, cx in ((2, 2), (6, 0), (6, 4)):
        xx = x - cx - lean * (y - cy)
        d.append((xx / hw) ** 2 + ((y - cy) / hh) ** 2)
    hole = np.min(d, 0) < 1
    cell = 1 - hole.astype(np.float32).reshape(ph, ss, pw, ss).mean((1, 3))
    return np.tile(cell, (N // ph, N // pw))


def render(sd, vein, half, cloth=None):
    """Coverage from the distances (px). sd < 0 inside a motif; vein >= 0."""
    if cloth is None:
        cloth = (weave('whole'), weave('half'))
    whole, halfw = cloth
    hh, ww = sd.shape
    whole, halfw = whole[:hh, :ww], halfw[:hh, :ww]
    aa = lambda d: np.clip(0.5 - d, 0, 1)
    inside = aa(sd)
    gimp = inside * (1 - aa(sd + mm(GIMP_MM)))
    cord = aa(vein - mm(VEIN_CORD_MM) / 2)
    open_ = aa(vein - mm(VEIN_CORD_MM) / 2 - mm(VEIN_OPEN_MM)) * (1 - cord)
    fill = whole + (halfw - whole) * half
    return inside * np.maximum(np.maximum(gimp, cord), fill * (1 - open_))


def normalise(d):
    """An approximate distance divided by its gradient's length, so bands keep their width."""
    gy, gx = np.gradient(d)
    return d / np.clip(np.hypot(gx, gy), 0.35, 3.0)


def edt_band(target, r, wrap_y=True):
    """Distance to the nearest target px, exact within r px (r + 1 beyond); wraps along x,
    and along y when wrap_y (separable, as Saito's)."""
    far = np.float32(r + 1)
    g = np.where(target, 0, far).astype(np.float32)
    for d in range(1, r + 1):
        hit = np.roll(target, d, 1) | np.roll(target, -d, 1)
        g = np.minimum(g, np.where(hit, np.float32(d), far))
    if not wrap_y:
        pad = r + 1
        g = np.pad(g, ((pad, pad), (0, 0)), constant_values=far)
    d2 = g * g
    for d in range(1, r + 1):
        d2 = np.minimum(d2, np.minimum(np.roll(g, d, 0), np.roll(g, -d, 0)) ** 2 + d * d)
    if not wrap_y:
        d2 = d2[r + 1:-(r + 1)]
    return np.sqrt(d2)


def signed(inside, r=24, wrap_y=True):
    d = np.where(inside, -(edt_band(~inside, r, wrap_y) - 0.5), edt_band(inside, r, wrap_y) - 0.5)
    return lace.blur(d, 0.8, wrap=wrap_y) if wrap_y else lace.blur(d, 0.8)


def trace(mask, scale, pad=192, wrap_y=True):
    """potrace's smooth curves through a binary mask, rendered scale times larger,
    antialiased, 0..1. Wraps along x (and y), by tracing a padded copy."""
    if wrap_y:
        m = np.pad(mask, pad, mode='wrap')
    else:
        m = np.pad(np.pad(mask, ((0, 0), (pad, pad)), mode='wrap'), ((pad, pad), (0, 0)), mode='edge')
    with tempfile.TemporaryDirectory() as tmp:
        src, dst = os.path.join(tmp, 'm.pbm'), os.path.join(tmp, 'm.pgm')
        Image.fromarray(~m).convert('1').save(src)
        subprocess.run(['potrace', '-g', '-x', str(scale), '-a', '1.1', '-O', '0.4',
                        '-t', '6', '-o', dst, src], check=True)
        out = 1 - np.asarray(Image.open(dst), np.float32) / 255
    p = pad * scale
    return out[p:-p, p:-p]


# Way a: the download sharpened.

def source_tile(src):
    x0, y0, x1 = lace.FIELD
    c = lace.coverage(lace.luminance(src[:, x0:x1]))
    t = 2 * lace.REPEAT
    c = c[y0:y0 + t + lace.OVERLAP, :t + lace.OVERLAP]
    return cm.seam_tile(c, lace.OVERLAP, cost_img=lace.blur(c, 2.0))


def sharpen(c, h, w, wrap_y=True, vein_ramp=(0.16, 0.28), half_level=0.78, shape=lace.SHAPE):
    """Silhouette (sd), carved veins and the half stitch from a coverage tile c: veins
    where the coverage dips by vein_ramp under its surroundings, half stitch where its
    level is under half_level; the outline where the smoothed coverage passes shape."""
    rs = (lambda a, hh, ww: cm.resize_periodic(a, hh, ww)) if wrap_y else \
        (lambda a, hh, ww: cm.resize_periodic(cm.resize(a, a.shape[1], hh), hh, ww))
    bl = (lambda a, s: lace.blur(a, s, True)) if wrap_y else lace.blur
    sil = lace.ramp(rs(bl(c, lace.SHAPE_BLUR), h // 4, w // 4), shape)
    sil = sil * lace.ramp(bl(sil, lace.SUPPORT), lace.SUPPORT_MIN)
    inside = trace(sil > 0.5, 4, wrap_y=wrap_y)[:h, :w] > 0.5
    vein = lace.ramp(rs(bl(c, lace.VEIN_AROUND) - bl(c, lace.DETAIL_BLUR), h, w), vein_ramp)
    inside &= ~(vein > 0.5)
    sd = signed(inside, wrap_y=wrap_y)
    level = rs(bl(c, 2.5), h, w)
    half = (level < half_level).astype(np.float32)
    return sd, half


# Way b: grown.

class Canvas:
    def __init__(self, h, w, wrap_y=True):
        self.h, self.w, self.wrap_y = h, w, wrap_y
        self.sd = np.full((h, w), BIG, np.float32)
        self.vein = np.full((h, w), BIG, np.float32)
        self.half = np.zeros((h, w), np.float32)
        self.holes = np.full((h, w), BIG, np.float32)

    def box(self, x0, y0, x1, y1):
        ys = np.arange(int(np.floor(y0)), int(np.ceil(y1)) + 1)
        xs = np.arange(int(np.floor(x0)), int(np.ceil(x1)) + 1)
        if not self.wrap_y:
            ys = ys[(ys >= 0) & (ys < self.h)]
        if len(ys) == 0 or len(xs) == 0:
            return None, None, None
        Y, X = np.meshgrid(ys.astype(np.float32), xs.astype(np.float32), indexing='ij')
        return np.ix_(ys % self.h, xs % self.w), X, Y

    def put(self, layer, ix, d):
        a = getattr(self, layer)
        a[ix] = np.minimum(a[ix], d)

    def paint(self, ix, d, vein, half):
        """A shape laid over what is there, as the lace's outlines overlap: inside it, its
        own outline, veins and stitch; outside, the union."""
        over = d < 0.5
        self.sd[ix] = np.where(over, d, np.minimum(self.sd[ix], d))
        self.vein[ix] = np.where(over, vein, self.vein[ix])
        self.half[ix] = np.where(over, half, self.half[ix])
        self.holes[ix] = np.where(over, BIG, self.holes[ix])

    def segment(self, layer, p, q, r0, r1=None, pad=4):
        r1 = r0 if r1 is None else r1
        rm = max(r0, r1) + pad
        ix, X, Y = self.box(min(p[0], q[0]) - rm, min(p[1], q[1]) - rm,
                            max(p[0], q[0]) + rm, max(p[1], q[1]) + rm)
        if ix is None:
            return
        dx, dy = q[0] - p[0], q[1] - p[1]
        t = np.clip(((X - p[0]) * dx + (Y - p[1]) * dy) / max(dx * dx + dy * dy, 1e-6), 0, 1)
        d = np.hypot(X - p[0] - t * dx, Y - p[1] - t * dy) - (r0 + (r1 - r0) * t)
        self.put(layer, ix, d)

    def curve(self, layer, pts, r0, r1=None):
        r1 = r0 if r1 is None else r1
        n = len(pts) - 1
        for i in range(n):
            self.segment(layer, pts[i], pts[i + 1], r0 + (r1 - r0) * i / n,
                         r0 + (r1 - r0) * (i + 1) / n)

    def leaf(self, base, ang, length, width, teeth, bend, half_side, rng):
        """A leaflet from base along ang: pointed, serrated, a midrib, half its blade half
        stitch."""
        r = length + width
        ix, X, Y = self.box(base[0] - r, base[1] - r, base[0] + r, base[1] + r)
        if ix is None:
            return
        ca, sa = np.cos(ang), np.sin(ang)
        s = (X - base[0]) * ca + (Y - base[1]) * sa
        t = -(X - base[0]) * sa + (Y - base[1]) * ca
        u = np.clip(s / length, 0, 1)
        t = t - bend * length * u * u
        w = width * 0.62 * np.sin(np.pi * u ** 0.85) ** 0.7 * (1 - 0.2 * u)
        saw = (teeth * u + rng.random()) % 1
        w = w * (1 - 0.16 * saw * (u > 0.25))
        d = normalise(np.maximum(np.abs(t) - w, np.maximum(-s, s - length)))
        rib = np.where((u > 0.05) & (u < 0.82), np.abs(t), BIG)
        # Side veins: short strokes from the midrib toward the tip.
        sv = np.abs(((s - np.abs(t) * 1.1) / length * 4.0) % 1 - 0.5) * length / 4.0
        sv = np.where((u > 0.2) & (u < 0.75) & (np.abs(t) < 0.65 * w) & (np.abs(t) > mm(0.6)), sv, BIG)
        rib = np.minimum(rib, sv)
        side = (t * half_side > 0).astype(np.float32)
        self.paint(ix, d, rib, side)

    def flower(self, c, R, n, rot, rng):
        """A rosette: n round petals, each notched, veined and outlined; an eye with a ring
        of holes."""
        ix, X, Y = self.box(c[0] - R - 4, c[1] - R - 4, c[0] + R + 4, c[1] + R + 4)
        if ix is None:
            return
        x, y = X - c[0], Y - c[1]
        r = np.hypot(x, y)
        th = np.arctan2(y, x) - rot
        k = np.round(th * n / (2 * np.pi))
        ph = th - k * 2 * np.pi / n                 # angle off the nearest petal's axis
        size = 1 + 0.08 * np.sin(k * 2.3 + rng.random() * 6)
        edge = R * size * (0.38 + 0.62 * np.sqrt(np.clip(np.cos(ph * n / 2), 0, 1)))
        edge = edge - 0.07 * R * np.exp(-(ph * n / 0.55) ** 2)
        across = r * np.abs(np.sin(ph))
        main = np.where((r > 0.36 * R) & (r < 0.8 * R), across, BIG)
        gap = np.pi / n - np.abs(ph)
        side = np.where((r > 0.27 * R) & (r < 0.62 * R * size), r * np.abs(np.sin(gap)), BIG)
        eye = np.abs(r - 0.27 * R)
        band = ((r > 0.3 * R) & (r < 0.48 * R)).astype(np.float32)
        self.paint(ix, normalise(r - edge), np.minimum(np.minimum(main, side), eye), band)
        m = 9 if R > 150 else 7
        for j in range(m):
            a = rot + 2 * np.pi * (j + 0.5) / m
            hc = (0.17 * R * np.cos(a), 0.17 * R * np.sin(a))
            self.put('holes', ix, np.hypot(x - hc[0], y - hc[1]) - max(0.035 * R, 3.0))

    def finish(self):
        return np.maximum(self.sd, -self.holes), self.vein, self.half


def bezier(p0, p1, p2, n=16):
    t = np.linspace(0, 1, n)[:, None]
    p0, p1, p2 = map(np.asarray, (p0, p1, p2))
    return (1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2


def sprig(cv, base, ang, length, pairs, rng, depth=0):
    """A compound leaf on a curved twig: leaflets in pairs, smaller toward the tip, and a
    terminal one; one level of side sprigs (as an L-system's)."""
    bend = rng.uniform(-0.35, 0.35)
    tip = (base[0] + length * np.cos(ang), base[1] + length * np.sin(ang))
    mid = (base[0] + 0.5 * length * np.cos(ang + bend), base[1] + 0.5 * length * np.sin(ang + bend))
    pts = bezier(base, mid, tip)
    cv.curve('sd', pts, mm(0.7), mm(0.4))
    for i in range(pairs):
        f = 0.25 + 0.7 * i / max(pairs, 1)
        k = int(f * (len(pts) - 1))
        p = pts[k]
        dirn = np.arctan2(*(pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)])[::-1])
        size = mm(rng.uniform(21, 26)) * (1 - 0.3 * f)
        for side in (-1, 1):
            if depth == 0 and i == 1 and side == (1 if rng.random() < 0.5 else -1) and length > mm(40):
                sprig(cv, p, dirn + side * 0.9, length * 0.45, 2, rng, depth + 1)
                continue
            cv.leaf(p, dirn + side * rng.uniform(0.75, 1.05), size, size * 0.42,
                    rng.integers(3, 6), side * rng.uniform(-0.15, 0.1), side, rng)
    dirn = np.arctan2(*(pts[-1] - pts[-3])[::-1])
    cv.leaf(pts[-1], dirn, mm(rng.uniform(16, 20)), mm(7), 4, rng.uniform(-0.1, 0.1),
            1 if rng.random() < 0.5 else -1, rng)


def grow_field(seed=7):
    """Two trails a tile, the second dropped half a tile: each a main stem swinging twice
    a tile, flowers on its swings and sprigs between, and a thinner one halfway to the
    next trail."""
    rng = np.random.default_rng(seed)
    cv = Canvas(N, N)
    later = []                              # flowers lie over the leaves
    for rep in range(2):
        ox, oy = rep * N / 2, rep * N / 2
        ph = rng.uniform(0, 2 * np.pi)
        for stem in range(2):
            amp = mm(44 if stem == 0 else 36)
            sph = ph + (0 if stem == 0 else np.pi * 0.85)

            cx = ox + N / 4 + stem * N / 4          # the thinner stem halfway to the next trail

            def stem_x(y, amp=amp, sph=sph, cx=cx):
                return (cx + amp * np.sin(2 * np.pi * 2 * y / N + sph)
                        + mm(5) * np.sin(2 * np.pi * 5 * y / N + sph))

            ys = np.linspace(0, N, 257)
            cv.curve('sd', np.stack([stem_x(ys), ys + oy], 1), mm(1.1 if stem == 0 else 0.8))
            count = 16 if stem == 0 else 12
            for j in range(count):
                y = (j + 0.5 + 0.25 * stem) * N / count
                x = stem_x(y)
                slope = (stem_x(y + 4) - stem_x(y - 4)) / 8
                up = np.arctan2(-1, -slope)             # along the stem, upward
                s = np.sin(2 * np.pi * 2 * y / N + sph)
                side = 1 if (j % 2 == 0) else -1
                p = (x, y + oy)
                if j % 4 == 1:
                    out = 1 if s > 0 else -1
                    a = up + out * 0.95
                    L = mm(rng.uniform(30, 40))
                    fc = (p[0] + L * np.cos(a), p[1] + L * np.sin(a))
                    bend = (p[0] + 0.5 * L * np.cos(a - out * 0.4), p[1] + 0.5 * L * np.sin(a - out * 0.4))
                    cv.curve('sd', bezier(p, bend, fc), mm(0.6))
                    cv.leaf(p, a + out * 0.9, mm(20), mm(8), 5, 0.1, out, rng)
                    cv.leaf(fc, a + out * 2.2, mm(18), mm(7.5), 5, -0.1, -out, rng)
                    later.append((fc, mm(rng.uniform(31, 36)) * (1 if stem == 0 else 0.85), int(rng.choice([5, 6])), rng.uniform(0, 6.3)))
                elif j % 4 == 3:
                    a = up - side * 0.9
                    L = mm(rng.uniform(18, 24))
                    fc = (p[0] + L * np.cos(a), p[1] + L * np.sin(a))
                    cv.curve('sd', [p, fc], mm(0.5))
                    later.append((fc, mm(rng.uniform(17, 21)), 5, rng.uniform(0, 6.3)))
                    sprig(cv, p, up + side * 1.0, mm(rng.uniform(50, 62)), 3, rng)
                else:
                    sprig(cv, p, up + side * rng.uniform(0.7, 1.0), mm(rng.uniform(55, 72)), 3, rng)
                    if stem == 0 and j % 2 == 0:
                        sprig(cv, (x, y + oy + mm(20)), up - side * rng.uniform(0.8, 1.1),
                              mm(rng.uniform(38, 48)), 2, rng)
    for f in later:
        cv.flower(*f, rng)
    return cv.finish()


# The hem, parametric: x along the hem (2 scallops, wraps), y down from the field.

HEM = dict(period=N // 2, edge_mid=mm(203), edge_cusp=mm(172), lobes=7, lobe_mm=9.0,
           band_mm=15, gap_mm=4.0, garland_mid=mm(66), mesh_mm=4.2, mesh_thread_mm=0.55,
           picot_mm=3.6, picot_r_mm=1.35, scallops=1)
# scallops: the edge's scallops under each garland arc, each with lobes lobes (the
# download has two small ones; ways c and d one large one)


def hem_geometry(cv):
    """The scallops' lines, holes and openwork as distances, and which parts are cloth,
    border lace, and field. Returns (sd, vein, half, cloth, field)."""
    h, w = cv.h, cv.w
    P = HEM['period']
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    lx = (x % P) - P / 2                         # from the scallop's middle

    Ps = P / HEM.get('scallops', 1)             # an edge scallop's width
    ls = (x % Ps) - Ps / 2                       # from its middle

    def circle_y(mid, cusp, up):                 # an arc through mid at 0 and cusp at +-Ps/2
        s = abs(mid - cusp)
        R = ((Ps / 2) ** 2 + s * s) / (2 * s)
        sag = R - np.sqrt(np.maximum(R * R - ls * ls, 0))
        return mid - sag if not up else mid - sag

    edge = circle_y(HEM['edge_mid'], HEM['edge_cusp'], False)   # the scallops' line
    # Distance up from the edge, roughly: the arcs are shallow, so y does.
    up = edge - y
    # Lobes along the edge: rounded bumps, notched between, with picots round each.
    arc = (ls + Ps / 2) / Ps * HEM['lobes']
    k = np.floor(arc)
    f = arc - k - 0.5
    lobe = mm(HEM['lobe_mm']) * np.sqrt(np.clip(1 - (2 * f) ** 2, 0, 1))
    outer = up + lobe                            # > 0 inside the cloth
    sd = -outer
    # Picots: small loops standing out of the lobe's rim.
    lob_len = Ps / HEM['lobes']
    n_pic = max(3, int(lob_len / mm(HEM['picot_mm'])) - 2)
    vein = np.full((h, w), BIG, np.float32)
    picots = np.full((h, w), BIG, np.float32)
    phase = (f + 0.5) * n_pic
    pk = np.floor(phase)
    pf = phase - pk - 0.5
    rim_y = edge + lobe                          # the lobe's outline, at y
    keep = (pk > 0) & (pk < n_pic - 1)
    pr = mm(HEM['picot_r_mm'])
    cx = (pk + 0.5) / n_pic - 0.5                # of the lobe
    px_ = ls + Ps / 2 - (k + 0.5 + cx) * lob_len
    py_ = y - (rim_y + pr * 0.45)
    ring = np.abs(np.hypot(px_, py_) - pr * 0.6) - pr * 0.27
    ring = np.maximum(ring, -(py_ + pr * 0.45 + 1.5))   # only below the rim: no ring inside the cloth
    picots = np.where(keep, ring, BIG)
    sd = np.minimum(sd, picots)
    # The eyelet band: one wheel a lobe, then a double gimp line along the band's top.
    band = mm(HEM['band_mm'])
    ex = ls + Ps / 2 - (k + 0.5) * lob_len
    ey = up - band * 0.45
    er = np.hypot(ex, ey)
    holes = np.where(er < mm(2.6), np.abs(er - mm(1.6)) - mm(0.7), BIG)   # the wheel's ring open
    sd = np.maximum(sd, -holes)
    vein = np.minimum(vein, np.abs(er - mm(2.6)))
    line1 = np.abs(up - band)
    line2 = np.abs(up - band - mm(HEM['gap_mm']))
    vein = np.minimum(vein, np.minimum(line1, line2))
    # The garland: a concave-up arc from cusp to cusp, its sides rising to the field.
    gmid = HEM['garland_mid']
    R = ((P / 2) ** 2 + gmid ** 2) / (2 * gmid)
    garland = gmid - (R - np.sqrt(np.maximum(R * R - lx * lx, 0)))   # y of the arc
    below_g = y - garland
    vein = np.minimum(vein, np.minimum(np.abs(below_g), np.abs(below_g - mm(HEM['gap_mm']))))
    field = np.clip(0.5 - below_g, 0, 1)            # above the arc the field goes on
    solid_band = (up > 0) & (up < band + mm(HEM['gap_mm']))
    garland_band = (below_g > -mm(1)) & (below_g < mm(HEM['gap_mm']) + mm(1))
    # The openwork between the band and the garland: a coarse hexagonal mesh.
    pitch = mm(HEM['mesh_mm'])
    q = x / pitch
    r_ = y / (pitch * 0.866)
    j = np.floor(r_)
    off = 0.5 * (j % 2)
    i = np.floor(q - off)
    best = np.full((h, w), BIG, np.float32)
    second = best.copy()
    for dj in (-1, 0, 1):
        jj = j + dj
        oo = 0.5 * (jj % 2)
        ii0 = np.floor(q - oo)
        for di in (-1, 0, 1):
            ii = ii0 + di
            key = (ii.astype(np.int64) % 4096) * 7919 + (jj.astype(np.int64) % 4096)
            cxm = (ii + oo + 0.5 + (cm.rand(key, 21) - 0.5) * 0.45) * pitch
            cym = (jj + 0.5 + (cm.rand(key, 22) - 0.5) * 0.45) * pitch * 0.866
            d = np.hypot(x - cxm, y - cym)
            second = np.where(d < best, best, np.minimum(second, d))
            best = np.minimum(best, d)
    mesh_d = (second - best) * 0.5 - mm(HEM['mesh_thread_mm']) / 2   # < 0 on a thread
    open_zone = (up >= band + mm(HEM['gap_mm'])) & (below_g >= mm(HEM['gap_mm']))
    return dict(sd=sd, vein=vein, outer=outer, solid=solid_band | garland_band, band=solid_band,
                open_zone=open_zone, mesh=mesh_d, field=field, lx=lx, up=up, garland=garland)


def field_reach(field, motif, steps=48):
    """Where the field's motifs that cross the garland carry on below it: grown from the
    field through the motif's cloth, at a quarter of the detail, steps quarter px deep."""
    f = 4
    inside = lace.box((motif > 0.3).astype(np.float32), f) > 0.5
    grown = lace.box(field, f) > 0.5
    for _ in range(steps):
        n = grown | np.roll(grown, 1, 1) | np.roll(grown, -1, 1)
        n[1:] |= grown[:-1]
        n[:-1] |= grown[1:]
        grown = grown | (n & inside)
    out = np.kron(grown.astype(np.float32), np.ones((f, f), np.float32))
    return np.maximum(field, out * (motif > 0.05))


def hem_strip(motif_fn, cloth, field_motif):
    """The hem's R lace, G cloth, B field, at full detail (N x HEM_H)."""
    cv = Canvas(HEM_H, N, wrap_y=False)
    g = hem_geometry(cv)
    m_sd, m_vein, m_half = motif_fn(cv, g)
    B = field_reach(g['field'], field_motif[:HEM_H])
    keep_off = lace.blur(B, mm(1.2)) > 0.02          # the border's motifs keep clear of it
    # The border's own lace: the band and lines everywhere along it, motifs in the openwork.
    band_sd = np.where(g['solid'], g['sd'], BIG)
    band_sd = np.minimum(band_sd, np.where(g['outer'] > 0, np.maximum(g['sd'], g['up'] - mm(HEM['band_mm'] + HEM['gap_mm'])), BIG))
    band_sd = np.minimum(band_sd, np.where(g['outer'] <= 0, g['sd'], BIG))   # the picots
    in_open = g['open_zone']
    m_sd = np.where(in_open & ~keep_off, m_sd, BIG)
    sd = np.minimum(band_sd, m_sd)
    sd = np.minimum(sd, np.where((g['up'] > 0) & ~g['open_zone'] & (g['field'] < 0.5), g['sd'], BIG))
    vein = np.minimum(np.where(in_open, m_vein, BIG), g['vein'])
    half = np.maximum(m_half * in_open, g['band'] & (g['up'] > mm(HEM['band_mm']) * 0.12))
    lace_ = render(sd, vein, half.astype(np.float32), cloth)
    mesh = np.clip(0.5 - g['mesh'], 0, 1) * in_open
    cloth_any = np.clip(g['outer'] + 0.5, 0, 1)                  # 0 below the lobes
    picot = np.clip(0.5 - g['sd'], 0, 1) * (g['outer'] <= 0)
    cloth_any = np.maximum(cloth_any, picot)
    # In the openwork no net: cloth only on the mesh, the motifs and the field's reach.
    motif_in = np.clip(0.5 - m_sd, 0, 1)
    G = np.where(in_open, np.maximum(np.maximum(mesh, motif_in), B), cloth_any)
    R = np.maximum(lace_, mesh) * (1 - B)
    return np.clip(np.stack([R, G, B], -1), 0, 1)


def hem_motifs_grown(cv, g):
    rng = np.random.default_rng(HEM_SEED)
    P = HEM['period']
    sub = Canvas(cv.h, cv.w, wrap_y=False)
    for s in range(2):
        cx = s * P + P / 2
        fy = (HEM['edge_mid'] - mm(HEM['band_mm'] + 4) + g['garland'][0, int(cx)]) / 2 + mm(4)
        sub.flower((cx, fy), mm(30), 6, rng.uniform(0, 6), rng)
        for side in (-1, 1):
            sprig(sub, (cx + side * mm(24), fy + mm(12)), np.pi / 2 - side * 2.0, mm(62), 3, rng)
            sprig(sub, (cx + side * mm(26), fy - mm(10)), -np.pi / 2 - side * 2.0, mm(50), 2, rng)
            sub.leaf((cx + side * mm(10), fy - mm(26)), -np.pi / 2 + side * 0.5, mm(20), mm(8), 5, 0.1, side, rng)
        # Between the garlands, at the cusp: a smaller flower and leaves rising.
        kx = s * P
        sub.flower((kx, mm(78)), mm(16), 5, rng.uniform(0, 6), rng)
        sub.curve('sd', bezier((kx, mm(95)), (kx + mm(4), mm(118)), (kx, mm(150))), mm(0.7))
        for side in (-1, 1):
            sprig(sub, (kx, mm(120)), -np.pi / 2 + side * 0.8, mm(30), 2, rng)
    return sub.finish()


def hem_motifs_traced(src):
    """The download's hem flowers, traced, as the motif inside the openwork."""
    y0, y1 = lace.BORDER_ROWS
    x0, _, x1 = lace.FIELD
    lum = lace.luminance(src[:y1, x0:x1])
    c = lace.coverage(lum)[y0:]
    t = 2 * lace.BORDER_PERIOD
    c = cm.seam_tile(c[:, :t + lace.OVERLAP], lace.OVERLAP,
                     cost_img=lace.blur(c, 2.0)[:, :t + lace.OVERLAP], both=False)
    sd, half = sharpen(c, HEM_H, N, wrap_y=False)
    # Lift the openwork's own mesh out: keep only shapes wider than the mesh's threads.
    # Align its scallops' cusps (where the cloth's bottom edge is highest) with the
    # parametric hem's, at x = 0 and P.
    inside = sd < 0
    rows = np.arange(sd.shape[0])[:, None]
    bottom = np.max(np.where(inside, rows, 0), 0).astype(np.float32)
    bottom = lace.blur(np.tile(bottom[None, :], (8, 1)), 20)[0]
    P = HEM['period']
    cusp = int(np.argmin((bottom[:P] + bottom[P:]) / 2))
    sd, half = np.roll(sd, -cusp, 1), np.roll(half, -cusp, 1)
    body = edt_band(~(sd < 0), 12, wrap_y=False) > mm(0.9)
    grown = edt_band(body, 12, wrap_y=False) < mm(1.1)
    sd = np.where(grown, sd, np.maximum(sd, 2.0))
    return lambda cv, g: (sd, np.full_like(sd, BIG), half)


# Way c: the download's layout and leaves traced, its flowers redrawn as way b's rosettes.

def regrow_flowers(sd, half, wrap_y=True, seed=5):
    """Finds the traced silhouette's flowers, its widest blobs (leaves are narrower), and
    lays a grown rosette of the same size over each, cleared round."""
    f = 4
    inside = lace.box((sd < 0).astype(np.float32), f) > 0.5
    depth = edt_band(~inside, 28, wrap_y) * f          # px of full detail to the edge
    cv = Canvas(sd.shape[0], sd.shape[1], wrap_y)
    cv.sd, cv.half = sd.copy(), half.copy()
    rng = np.random.default_rng(seed)
    d = depth.copy()
    yy, xx = np.mgrid[0:d.shape[0], 0:d.shape[1]]
    found = []
    while True:
        k = int(np.argmax(d))
        y, x = divmod(k, d.shape[1])
        if d[y, x] < mm(6.0):
            break
        found.append((x * f + f / 2, y * f + f / 2, d[y, x]))
        dx = np.abs(xx - x)
        dx = np.minimum(dx, d.shape[1] - dx)
        dy = np.abs(yy - y)
        if wrap_y:
            dy = np.minimum(dy, d.shape[0] - dy)
        d[dx * dx + dy * dy < (mm(30) / f) ** 2] = 0
    for x, y, dep in found:
        R = float(np.clip(dep * 2.8, mm(15), mm(33)))
        ix, X, Y = cv.box(x - R * 1.1, y - R * 1.1, x + R * 1.1, y + R * 1.1)
        r = np.hypot(X - x, Y - y)
        cv.sd[ix] = np.maximum(cv.sd[ix], R * 1.06 - r)
        cv.flower((x, y), R, int(rng.choice([5, 6])), rng.uniform(0, 6.3), rng)
    print(f'regrew {len(found)} flowers')
    return cv.finish()


# Previews.

def save(path, a):
    lace.save_jpg(path, a) if path.endswith('.jpg') else cm.save(path, a)


def views(out, tag, motif, hem, net, close_at):
    """The kinds of materials-lace-2: close up, tiled, from afar, the hem."""
    big = np.maximum(lace.tiled(net, lace.NET_REPEAT), motif)
    tile = lace.box(big, 4)
    front, back = lace.shade(tile)
    cm.save(os.path.join(out, f'{tag}_mask.png'), tile)
    cm.save(os.path.join(out, f'{tag}_backlit.png'), back)
    for kind, img in (('preview', front), ('backlit', back)):
        lace.save_jpg(os.path.join(out, f'{tag}_{kind}_3x3.jpg'),
                      cm.resize(lace.tiled(img, 3), 1536, 1536))
        lace.save_jpg(os.path.join(out, f'{tag}_{kind}_far.jpg'),
                      lace.tiled(cm.downscale(img, 8), 6))
    cy, cx = close_at
    close = np.roll(big, (-cy, -cx), (0, 1))[:1024, :1024]
    f, b = lace.shade(close)
    lace.save_jpg(os.path.join(out, f'{tag}_close.jpg'), np.concatenate([f, b], 1))
    # The hem: the field one tile, then the strip, two tiles across, at half the full detail.
    r, g, bb = hem[..., 0], hem[..., 1], hem[..., 2]
    netb = lace.tiled(net, lace.NET_REPEAT, -(-HEM_H // lace.NET_SIZE))[:HEM_H]
    strip = g * np.maximum(np.maximum(netb, r), bb * motif[:HEM_H])
    curtain = np.concatenate([big[N // 2:], strip, np.zeros((512, N), np.float32)], 0)
    curtain = lace.tiled(curtain, 2, 1)
    f, b = lace.shade(lace.box(curtain, 4))
    lace.save_jpg(os.path.join(out, f'{tag}_hem_backlit.jpg'), b)
    lace.save_jpg(os.path.join(out, f'{tag}_hem_front.jpg'), f)
    # The hem close up: 14 cm round a scallop's cusp and lobes, at full detail.
    hc = np.concatenate([big[N - 400:], strip, np.zeros((200, N), np.float32)], 0)
    end = 400 + int(HEM['edge_mid']) + 80
    hc = np.roll(hc, 400, 1)[end - 1024:end, :1024]
    f, b = lace.shade(hc)
    lace.save_jpg(os.path.join(out, f'{tag}_hem_close.jpg'), np.concatenate([f, b], 1))
    lace.save_jpg(os.path.join(out, f'{tag}_border_rgb.jpg'), cm.resize(hem, 1024, 384))
    # The motif and the hem at full detail, for lace_compare.py and later tuning.
    cm.save(os.path.join(out, f'{tag}_motif_full.png'), motif)
    cm.save(os.path.join(out, f'{tag}_hem_full.png'), hem)
    return tile.mean()


def encode_roundtrip(sd, vein, half, size, k_px):
    """The distances stored at size px (8 bits, +-k_px of the full detail), then magnified
    back bilinearly as a GPU would sample them."""
    f = N // size
    h = sd.shape[0] // f

    def store(a):
        a = lace.box(np.clip(a, -k_px, k_px), f)
        q = np.round((a / k_px * 0.5 + 0.5) * 255) / 255
        return (q - 0.5) * 2 * k_px

    def mag(a):
        # Texel centres sit at (i + 0.5) f - 0.5 in the full grid; wraps.
        hh, ww = a.shape
        y = (np.arange(hh * f) + 0.5) / f - 0.5
        x = (np.arange(ww * f) + 0.5) / f - 0.5
        y0, x0 = np.floor(y).astype(int), np.floor(x).astype(int)
        fy, fx = (y - y0)[:, None], (x - x0)[None, :]
        a00 = a[np.ix_(y0 % hh, x0 % ww)]
        a01 = a[np.ix_(y0 % hh, (x0 + 1) % ww)]
        a10 = a[np.ix_((y0 + 1) % hh, x0 % ww)]
        a11 = a[np.ix_((y0 + 1) % hh, (x0 + 1) % ww)]
        return ((a00 * (1 - fx) + a01 * fx) * (1 - fy) + (a10 * (1 - fx) + a11 * fx) * fy).astype(np.float32)

    return mag(store(sd)), mag(store(np.minimum(vein, k_px))), (mag(lace.box(half, f)) > 0.5).astype(np.float32)


def compare_strip(out, crops):
    """The same kind of patch from each: download, lace-2, a, b."""
    tiles = []
    for img in crops:
        im = Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)).convert('RGB')
        tiles.append(im.resize((512, 512), Image.LANCZOS))
    strip = Image.new('RGB', (512 * len(tiles) + 8 * (len(tiles) - 1), 512), (27, 26, 25))
    for i, t in enumerate(tiles):
        strip.paste(t, (i * 520, 0))
    strip.save(os.path.join(out, 'compare_flower.jpg'), quality=90)


SEEDS = dict(b=7, c=5)      # way b's growth (its hem's is HEM_SEED), way c's regrown flowers
HEM_SEED = 11


def bake(out, ways='abc', seed=None):
    src_path = cm.source('library-lace-01.png')
    src = cm.load(src_path)
    net = lace.net_tile()
    cloth = (weave('whole'), weave('half'))
    stats = {}

    # Way a.
    if 'a' in ways or 'c' in ways:
        c = source_tile(src)
        sd_a, half_a = sharpen(c, N, N)
    if 'a' in ways:
        motif_a = render(sd_a, np.full_like(sd_a, BIG), half_a, cloth)
        hem_a = hem_strip(hem_motifs_traced(src), cloth, motif_a)
        stats['a'] = views(out, 'a', motif_a, hem_a, net, (1500, 1000))
        cm.save(os.path.join(out, 'a_motif.png'), lace.box(motif_a, 4))

    # Way c.
    if 'c' in ways:
        seed_c = SEEDS['c'] if seed is None else seed
        sd_c, vein_c, half_c = regrow_flowers(sd_a, half_a, seed=seed_c)
        motif_c = render(sd_c, vein_c, half_c, cloth)

        def hem_c_motifs(cv, g, traced=hem_motifs_traced(src)):
            sd, _, half = traced(cv, g)
            return regrow_flowers(sd, half, wrap_y=False, seed=seed_c)
        hem_c = hem_strip(hem_c_motifs, cloth, motif_c)
        stats['c'] = views(out, 'c', motif_c, hem_c, net, (1500, 1000))
        cm.save(os.path.join(out, 'c_motif.png'), lace.box(motif_c, 4))
    if 'b' not in ways:
        return

    # Way b.
    sd_b, vein_b, half_b = grow_field(SEEDS['b'] if seed is None else seed)
    motif_b = render(sd_b, vein_b, half_b, cloth)
    hem_b = hem_strip(hem_motifs_grown, cloth, motif_b)
    close_b = (1200, 400)
    stats['b'] = views(out, 'b', motif_b, hem_b, net, close_b)
    cm.save(os.path.join(out, 'b_motif.png'), lace.box(motif_b, 4))
    for size in (1024, 2048):
        e = encode_roundtrip(sd_b, vein_b, half_b, size, mm(1.6) * N / size / 1.4)
        m = render(*e, cloth)
        big = np.maximum(lace.tiled(net, lace.NET_REPEAT), m)
        f, b = lace.shade(np.roll(big, (-close_b[0], -close_b[1]), (0, 1))[:1024, :1024])
        lace.save_jpg(os.path.join(out, f'b_encoded{size}_close.jpg'), np.concatenate([f, b], 1))

    if ways != 'abc':
        return
    # The same flower patch side by side: download (source px), lace-2, a, b.
    old = os.path.join(os.path.dirname(os.path.abspath(out)), 'materials-lace-2', 'lace_close.png')
    srcflower = np.asarray(Image.open(src_path).convert('RGB'), np.float32)[240:500, 120:380] / 255
    crops = [srcflower]
    if os.path.exists(old):
        crops.append(np.asarray(Image.open(old).convert('RGB'), np.float32)[:, :1024] / 255)
    for tag in ('a', 'b', 'c'):
        crops.append(np.asarray(Image.open(os.path.join(out, f'{tag}_close.jpg')), np.float32)[:, :1024] / 255)
    compare_strip(out, crops)
    Image.open(src_path).convert('RGB').save(os.path.join(out, 'library-lace-01.jpg'), quality=90)
    write_contact(out, stats)


def write_contact(out, stats):
    def fig(src, caption, cls=''):
        return f'<figure class="{cls}"><img src="{src}"><figcaption>{caption}</figcaption></figure>'

    old = '../materials-lace-2/'
    rows = [
        ('Side by side', 'The same kind of patch: the download (a flower, source px), the old bake, ways a, b and c.', [
            fig('compare_flower.jpg', 'download / lace-2 / a traced / b grown / c hybrid (14 cm, on dark)', 'full'),
        ]),
        ('Close up, 14 cm: on dark and backlit', '', [
            fig(old + 'lace_close.png', 'lace-2 (the current bake)', 'wide'),
            fig('a_close.jpg', 'a: the download traced, clothwork and gimp', 'wide'),
            fig('b_close.jpg', 'b: grown', 'wide'),
            fig('c_close.jpg', 'c: a with its flowers regrown as b\'s rosettes', 'wide'),
            fig('b_encoded1024_close.jpg', 'b as the shader would draw it from a 1024 px distance texture', 'wide'),
            fig('b_encoded2048_close.jpg', 'b from a 2048 px distance texture', 'wide'),
        ]),
        ('The hem close up, 14 cm', 'Lobes, picots, the eyelet band, the double gimp lines and the openwork.', [
            fig('a_hem_close.jpg', 'a', 'wide'),
            fig('b_hem_close.jpg', 'b', 'wide'),
            fig('c_hem_close.jpg', 'c', 'wide'),
        ]),
        ('The hem under the field, 1.1 m, backlit', '', [
            fig(old + 'lace_hem_backlit.jpg', 'lace-2', 'wide'),
            fig('a_hem_backlit.jpg', 'a', 'wide'),
            fig('b_hem_backlit.jpg', 'b', 'wide'),
            fig('c_hem_backlit.jpg', 'c', 'wide'),
            fig('a_hem_front.jpg', 'a on dark', 'wide'),
            fig('b_hem_front.jpg', 'b on dark', 'wide'),
            fig('c_hem_front.jpg', 'c on dark', 'wide'),
        ]),
        ('Tiled 3x3 (1.7 m), backlit', '', [
            fig(old + 'lace_backlit_3x3.jpg', 'lace-2'),
            fig('a_backlit_3x3.jpg', 'a'),
            fig('b_backlit_3x3.jpg', 'b'),
            fig('c_backlit_3x3.jpg', 'c'),
            fig(old + 'lace_preview_3x3.jpg', 'lace-2 on dark'),
            fig('a_preview_3x3.jpg', 'a on dark'),
            fig('b_preview_3x3.jpg', 'b on dark'),
            fig('c_preview_3x3.jpg', 'c on dark'),
        ]),
        ('From afar: an eighth, 6x6 (3.4 m)', '', [
            fig(old + 'lace_backlit_far.png', 'lace-2 backlit'),
            fig('a_backlit_far.jpg', 'a backlit'),
            fig('b_backlit_far.jpg', 'b backlit'),
            fig('c_backlit_far.jpg', 'c backlit'),
            fig(old + 'lace_preview_far.png', 'lace-2 on dark'),
            fig('a_preview_far.jpg', 'a on dark'),
            fig('b_preview_far.jpg', 'b on dark'),
            fig('c_preview_far.jpg', 'c on dark'),
        ]),
        ('The textures and the download', '', [
            fig('a_motif.png', 'a: motif coverage, averaged to 1024 px'),
            fig('b_motif.png', 'b: motif coverage, averaged to 1024 px'),
            fig('a_border_rgb.jpg', 'a: hem R lace, G cloth, B field', 'wide'),
            fig('b_border_rgb.jpg', 'b: hem', 'wide'),
            fig('c_motif.png', 'c: motif coverage, averaged to 1024 px'),
            fig('c_border_rgb.jpg', 'c: hem', 'wide'),
            fig('library-lace-01.jpg', 'library-lace-01 (the download)'),
        ]),
    ]
    body = '\n'.join(f'<h2>{t}</h2><p>{n}</p><div class="row">{"".join(f)}</div>' for t, n, f in rows)
    note = (f'Prototype by tools/materials/lace_crisp.py: both ways drawn at 4096 px a tile '
            f'(0.137 mm a px). Mean field coverage: a {stats["a"]:.2f}, b {stats["b"]:.2f}, c {stats["c"]:.2f} '
            f'(lace-2: 0.52).')
    html = f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Library lace, crisp</title>
<style>
:root {{ --bg: #1b1a19; --fg: #e8e4dc; --muted: #a39d92; }}
body {{ background: var(--bg); color: var(--fg); font: 15px/1.45 system-ui, sans-serif;
       margin: 0; padding: 16px 24px 48px; }}
h1 {{ font-size: 22px; margin: 8px 0 4px; }}
h2 {{ font-size: 17px; margin: 28px 0 8px; }}
p {{ color: var(--muted); margin: 0 0 12px; max-width: 80ch; }}
.row {{ display: flex; flex-wrap: wrap; gap: 14px; align-items: flex-start; }}
figure {{ margin: 0; width: 420px; max-width: 100%; }}
figure.wide {{ width: 860px; }}
figure.full {{ width: 100%; }}
img {{ width: 100%; display: block; background: #000; }}
figcaption {{ color: var(--muted); font-size: 13px; margin-top: 4px; }}
</style></head><body>
<h1>Library lace, crisp</h1>
<p>{note} Click an image to open it full size.</p>
{body}
<script>document.querySelectorAll('img').forEach(i => i.onclick = () => window.open(i.src));</script>
</body></html>
'''
    with open(os.path.join(out, 'contact.html'), 'w') as f:
        f.write(html)
    print('wrote', os.path.join(out, 'contact.html'))


if __name__ == '__main__':
    args = sys.argv[1:]
    opts = dict(zip(args[1::2], args[2::2]))
    if not args or len(args) % 2 != 1 or set(opts) - {'--ways', '--seed'}:
        sys.exit(__doc__)
    os.makedirs(args[0], exist_ok=True)
    seed = opts.get('--seed')
    bake(args[0], opts.get('--ways', 'abc'), None if seed is None else int(seed))
