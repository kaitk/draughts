#!/usr/bin/env python3
"""Draws the library's rug: a worn Persian-type carpet, 3 by 2.2 m, with its fringes.

    python3 -I tools/materials/rug.py OUT_DIR [--preview]

Writes rug.png, 1280 x 880 RGBA at 2.5 mm a texel (400 a metre): 3.2 m along by 2.2 m
across, the rug's pile in the middle 3.0 m and its fringes in the 0.1 m at each end. RGB is
the sRGB albedo, A the coverage (1 on the rug, the strands' cover in the fringes). Drawn
from nothing (no photograph), so it holds no light: no wrinkles, no shading, no corners
darker; the room's shader lights it as it lights the floor (shaders::ROOM_FRAG's rug).

The design is knotted, a texel a knot, as a rug's design is drawn on its knots: a medallion
with pendants and corner pieces on a madder field strewn with a diamond lattice of small
flowers and leaves, an indigo main border with a vine and rosettes between guard stripes,
a dark overcast selvedge along the sides and a flat-woven band at the ends. Then what time
does: dye lots that differ across the rug (abrash), the window side faded, the pile worn
thin where the players' chairs stand and along the walk, each knot a little its own.
--preview also writes rug_preview.png, the rug on a floor-brown ground.
"""

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as cm  # noqa: E402

TEXEL_M = 0.0025
W, H = 1280, 880            # 3.2 m by 2.2 m
HALF = (1.5, 1.1)           # the pile's half length and width, metres
FRINGE = 0.1                # the fringe's room at each end (strands about 6 cm)
SEED = 11

# Colours (sRGB), muted as old vegetable dyes are.
MADDER = '#7a2e29'
MADDER_DARK = '#5a2422'
INDIGO = '#2a3350'
INDIGO_LIGHT = '#4d6185'
IVORY = '#c9b994'
OCHRE = '#a8834a'
GREEN = '#5b6650'
ROSE = '#a9645a'
BROWN = '#2c2422'
SELVEDGE = '#2f2a30'
KILIM = '#6b3832'
FOUNDATION = '#9a8a70'      # the cotton under the pile, where it is worn through
STRAND = '#d6ccb4'


def col(name):
    return cm.to_linear(cm.hex_rgb(name))


def put(img, mask, name):
    img[mask] = col(name)


def frame_coords(x, y):
    """The border's coordinates: depth in from the nearest edge, the place along it, and
    whether that edge is an end (short side)."""
    dx = HALF[0] - np.abs(x)
    dy = HALF[1] - np.abs(y)
    end = dx < dy
    depth = np.where(end, dx, dy)
    along = np.where(end, y, x)
    return depth, along, end


def border(img, x, y, depth, along, end):
    # The selvedge along the sides, the flat-woven band at the ends.
    sel = depth < 0.012
    put(img, sel & ~end, SELVEDGE)
    put(img, sel & end, KILIM)
    put(img, sel & end & (np.abs(depth - 0.006) < 0.0021), IVORY)

    # The outer guard: madder with small diamonds, indigo and ivory in turn.
    g = (depth >= 0.012) & (depth < 0.05)
    put(img, g, MADDER)
    period = 0.044
    k = np.floor(along / period + 0.5)
    s = along - k * period
    dia = np.abs(s) / 0.016 + np.abs(depth - 0.031) / 0.012 < 1.0
    put(img, g & dia & (k % 2 == 0), INDIGO)
    put(img, g & dia & (k % 2 != 0), IVORY)
    put(img, g & (np.abs(s) / 0.006 + np.abs(depth - 0.031) / 0.005 < 1.0), OCHRE)

    for d0 in (0.05, 0.27, 0.33):
        put(img, (depth >= d0) & (depth < d0 + 0.008), BROWN)

    # The main border: indigo, a vine winding along it with a rosette at each crossing and
    # a leaf in each bend. Its repeat fits each side a whole number of times, mirrored about
    # the middle (11 along, 8 across).
    m = (depth >= 0.058) & (depth < 0.27)
    put(img, m, INDIGO)
    rep = np.where(end, 2 * HALF[1] / 8, 2 * HALF[0] / 11)
    t0 = 0.164
    amp = 0.055
    phase = 2 * np.pi * along / rep
    vine_t = t0 + amp * np.sin(phase)
    slope = amp * 2 * np.pi / rep * np.cos(phase)
    vd = np.abs(depth - vine_t) / np.sqrt(1 + slope * slope)
    put(img, m & (vd < 0.008), OCHRE)
    put(img, m & (vd < 0.003), '#c9b58c')
    # Leaves in the bends, on the inside of each curve.
    kq = np.floor(along / rep * 2 - 0.5)
    lc = (kq + 1.0) * rep / 2
    sign = np.where(kq % 2 == 0, -1.0, 1.0)
    lu = (along - lc) / 0.05
    lv = (depth - (t0 + sign * amp * 0.2)) / 0.02
    leaf = lu * lu + lv * lv < 1.0
    hue = cm.rand(kq.astype(np.int64) + 300 * end, SEED) < 0.5
    put(img, m & leaf & hue, GREEN)
    put(img, m & leaf & ~hue, ROSE)
    put(img, m & leaf & (np.abs(lv) < 0.18) & (np.abs(lu) < 0.8), BROWN)
    # Rosettes where the vine crosses its middle line: eight petals of madder round an
    # ivory ring and an indigo heart.
    kr = np.floor(along / rep * 2 + 0.5)
    rc = kr * rep / 2
    ru = along - rc
    rv = depth - t0
    rr = np.sqrt(ru * ru + rv * rv)
    ra = np.arctan2(rv, ru)
    petal = rr < 0.036 * (0.78 + 0.22 * np.abs(np.cos(4 * ra)))
    put(img, m & petal, IVORY)
    put(img, m & (rr < 0.031 * (0.75 + 0.25 * np.abs(np.cos(4 * ra)))), MADDER)
    put(img, m & (rr < 0.014), IVORY)
    put(img, m & (rr < 0.008), INDIGO)

    # The inner guard: ochre-ivory with small madder flowers and indigo dots between.
    ig = (depth >= 0.278) & (depth < 0.33)
    put(img, ig, '#a88f64')
    per = 0.05
    k2 = np.floor(along / per + 0.5)
    s2 = along - k2 * per
    fr = np.sqrt(s2 * s2 + (depth - 0.304) ** 2)
    fa = np.arctan2(depth - 0.304, s2)
    put(img, ig & (fr < 0.015 * (0.7 + 0.3 * np.abs(np.cos(2 * fa)))), MADDER)
    put(img, ig & (fr < 0.005), IVORY)
    s3 = along - (k2 + 0.5) * per
    put(img, ig & (np.sqrt(s3 * s3 + (depth - 0.304) ** 2) < 0.005), INDIGO)


def field(img, x, y):
    f = frame_coords(x, y)[0] >= 0.338
    put(img, f, MADDER)
    # The lattice: diamonds 0.14 by 0.10 m, thin indigo lines, an ivory flower at each node,
    # a small indigo or blue flower in each diamond, leaves along the edges.
    cu, cv = 0.14, 0.10
    p = x / cu + y / cv
    q = x / cu - y / cv
    lp = np.abs(p - np.round(p))
    lq = np.abs(q - np.round(q))
    unit = 1.0 / np.hypot(1.0 / cu, 1.0 / cv)                    # metres per unit of p, across the line
    put(img, f & (np.minimum(lp, lq) * unit < 0.0028), MADDER_DARK)
    # Leaves on the edges' middles, along them.
    for a, b in ((p, q), (q, p)):
        on = np.abs(a - np.round(a)) * unit
        mid = np.abs(b - np.floor(b) - 0.5)
        leaf = (on / 0.009) ** 2 + (mid / 0.28) ** 2 < 1.0
        idx = (np.round(a) * 31 + np.floor(b)).astype(np.int64)
        green = cm.rand(idx, SEED + 1) < 0.45
        put(img, f & leaf & green, GREEN)
        put(img, f & leaf & ~green, '#8a6a3c')
    # Nodes: ivory rosettes with a madder heart.
    np_, nq = np.round(p), np.round(q)
    node = ((np_ + nq) % 2 == 0)
    nx = (np_ + nq) / 2 * cu
    ny = (np_ - nq) / 2 * cv
    dn = np.hypot(x - nx, y - ny)
    an = np.arctan2(y - ny, x - nx)
    put(img, f & node & (dn < 0.019 * (0.7 + 0.3 * np.abs(np.cos(3 * an)))), '#bba57e')
    put(img, f & node & (dn < 0.008), MADDER_DARK)
    # Diamonds' middles: small four-petal flowers.
    fp, fq = np.floor(p) + 0.5, np.floor(q) + 0.5
    mx = (fp + fq) / 2 * cu
    my = (fp - fq) / 2 * cv
    dm = np.hypot(x - mx, y - my)
    am = np.arctan2(y - my, x - mx)
    blue = cm.rand((fp * 57 + fq).astype(np.int64), SEED + 2) < 0.6
    flower = dm < 0.02 * (0.55 + 0.45 * np.abs(np.cos(2 * am)))
    put(img, f & flower & blue, INDIGO)
    put(img, f & flower & ~blue, INDIGO_LIGHT)
    put(img, f & (dm < 0.006), ROSE)

    # Corner pieces: a quarter lozenge of indigo in each corner of the field.
    ex, ey = HALF[0] - 0.338 - np.abs(x), HALF[1] - 0.338 - np.abs(y)
    ca = np.arctan2(ey / 0.34, ex / 0.5)
    dc = np.hypot(ex / 0.5, ey / 0.34) * (1 + 0.05 * np.cos(14 * ca))
    put(img, f & (dc < 1.0), IVORY)
    put(img, f & (dc < 0.95), INDIGO)
    cf = f & (dc < 0.95)
    put(img, cf & (np.abs(dc - 0.6) < 0.02), OCHRE)
    put(img, cf & flower, ROSE)
    put(img, cf & node & (dn < 0.012), OCHRE)

    # The medallion: a scalloped lozenge, indigo inside an ivory rim, its heart ivory with a
    # madder rosette and an indigo star; a pendant at each end.
    ang = np.arctan2(y / 0.42, x / 0.62)
    d = (np.abs(x) / 0.62 + np.abs(y) / 0.42) * (1 + 0.05 * np.cos(20 * ang))
    put(img, d < 1.0, BROWN)
    put(img, d < 0.97, IVORY)
    put(img, d < 0.92, INDIGO)
    md = d < 0.92
    put(img, md & node & (dn < 0.012), OCHRE)
    put(img, md & flower, ROSE)
    put(img, (d < 0.58) & (d > 0.53), OCHRE)
    put(img, d < 0.53, IVORY)
    hr = np.hypot(x / 0.62, y / 0.42) * 0.42
    ha = np.arctan2(y, x)
    put(img, (d < 0.53) & (hr < 0.14 * (0.7 + 0.3 * np.abs(np.cos(4 * ha)))), MADDER)
    put(img, (d < 0.53) & (hr < 0.07 * (0.6 + 0.4 * np.abs(np.cos(4 * ha + np.pi / 4)))), INDIGO)
    put(img, (d < 0.53) & (hr < 0.02), IVORY)
    # Leaves round the heart, green and ochre in turn.
    for i in range(8):
        a = i * np.pi / 4 + np.pi / 8
        cx, cy = 0.2 * np.cos(a) * 0.62 / 0.42 * 0.8, 0.2 * np.sin(a) * 0.9
        u = ((x - cx) * np.cos(a) + (y - cy) * np.sin(a)) / 0.045
        v = (-(x - cx) * np.sin(a) + (y - cy) * np.cos(a)) / 0.016
        put(img, (d < 0.53) & (u * u + v * v < 1.0), GREEN if i % 2 else OCHRE)
    # Pendants on the long axis.
    for sx in (-1.0, 1.0):
        px = x - sx * 0.70
        pd = np.abs(px) / 0.09 + np.abs(y) / 0.07
        put(img, (pd < 1.0) & (d >= 0.97), IVORY)
        put(img, (pd < 0.82) & (d >= 0.97), INDIGO)
        put(img, (pd < 0.35) & (d >= 0.97), ROSE)
        stem = (np.abs(y) < 0.004) & (np.abs(px) < 0.14) & (d >= 1.0) & (pd >= 1.0)
        put(img, stem, IVORY)


def fringe(x, y):
    """The strands' cover past the ends, and their shade: a warp every texel, gathered in
    bundles of eight, knotted 1 cm out, then splayed till they meet their neighbours, frayed
    at the tips."""
    out = np.abs(x) - HALF[0]
    side = np.sign(x)
    bundle = 0.02
    knot = 0.01
    k = np.floor(y / bundle)
    key = (k * 2 + (side > 0)).astype(np.int64)
    lean = (cm.rand(key, SEED + 3) - 0.5) * 0.12
    length = 0.055 + 0.012 * cm.rand(key, SEED + 4)
    yc = (k + 0.5) * bundle + lean * np.clip(out - knot, 0, None)
    half = np.where(out < knot, 0.5 * bundle - 0.15 * bundle * out / knot,
                    np.minimum(0.35 * bundle + 0.4 * (out - knot), 0.55 * bundle))
    strand = np.floor(y / TEXEL_M).astype(np.int64) * 2 + (side > 0)
    own = length * (0.8 + 0.3 * cm.rand(strand, SEED + 5))
    cover = (np.abs(y - yc) < half) & (out < own)
    a = cover.astype(np.float32) * np.clip((own - out) / 0.01, 0.4, 1.0)
    a *= 0.7 + 0.3 * cm.rand(strand, SEED + 6)
    a[out <= 0] = 1.0
    # The knot fatter and darker, the strands paler toward their tips, each its own.
    shade = (0.7 + 0.3 * np.clip((out - knot) / 0.04, 0, 1)) * (0.85 + 0.15 * cm.rand(strand, SEED + 12))
    shade = np.where(np.abs(out - knot) < 0.003, 0.6, shade)
    return np.clip(a, 0, 1), shade


def age(img, x, y, inside):
    rng_y, rng_x = np.mgrid[0:H, 0:W]
    # Abrash: dye lots across the rug, bands along its length, sharper than noise.
    band = cm.fbm(x * 2.2, np.zeros_like(x) + 3.0, 3, SEED + 7)
    band = np.tanh(band * 3.0) * 0.07
    sat = img.mean(-1, keepdims=True)
    dyed = np.clip((img.max(-1) - img.min(-1)) / (img.max(-1) + 1e-4), 0, 1)[..., None]
    img *= 1 + band[..., None] * dyed
    # The window side faded by the sun (y < 0 lies toward the window wall).
    fade = 0.22 * np.clip(-y / HALF[1], 0, 1) ** 1.5 + 0.04
    img[:] = img + (sat - img) * fade[..., None] * 0.6 + fade[..., None] * 0.012
    # Worn: where the players' chairs stand either side of the table, along the walk on the
    # room's side, and here and there; the pile thinned toward its cotton foundation.
    patch = cm.fbm(x / 0.25, y / 0.25, 4, SEED + 8) * 0.5 + 0.5
    chairs = np.exp(-(((np.abs(x) - 0.8) / 0.35) ** 2 + (y / 0.4) ** 2))
    walk = np.exp(-((y - 0.75) / 0.3) ** 2) * 0.6
    edge = np.exp(-np.minimum(HALF[0] - np.abs(x), HALF[1] - np.abs(y)) / 0.05) * 0.5
    wear = np.clip((0.25 + np.maximum(np.maximum(chairs, walk), edge)) * (patch - 0.25) * 1.6, 0, 1) * 0.55
    knot = cm.rand(rng_y * W + rng_x, SEED + 9) - 0.5
    # A worn knot shows its foundation through, more of them the more worn.
    through = np.clip((wear - (knot + 0.5) * 0.8) * 4.0, 0, 1) * 0.6 + wear * 0.25
    img[:] = img + (col(FOUNDATION) * 0.7 + img * 0.3 - img) * through[..., None]
    # Each knot a little its own, each weft row too.
    row = cm.rand(rng_x, SEED + 10) - 0.5
    img *= (1 + 0.10 * knot + 0.04 * row)[..., None]
    return wear


def bake(out, preview):
    xs = (np.arange(W) + 0.5) * TEXEL_M - W * TEXEL_M / 2
    ys = (np.arange(H) + 0.5) * TEXEL_M - H * TEXEL_M / 2
    x, y = np.meshgrid(xs, ys)
    inside = np.abs(x) < HALF[0]
    img = np.zeros((H, W, 3), np.float32)
    field(img, x, y)
    depth, along, end = frame_coords(x, y)
    b = depth < 0.338
    tmp = img.copy()
    border(tmp, x, y, depth, along, end)
    img[b] = tmp[b]
    a, shade = fringe(x, y)
    img[~inside] = col(STRAND) * shade[~inside][..., None]
    age(img, x, y, inside)
    img[~inside] *= 0.9
    srgb = cm.to_srgb(img)
    cm.save(os.path.join(out, 'rug.png'), srgb, a)
    if preview:
        ground = cm.hex_rgb('#3a2618')
        cm.save(os.path.join(out, 'rug_preview.png'), srgb * a[..., None] + ground * (1 - a[..., None]))


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if len(args) != 1:
        sys.exit(__doc__)
    os.makedirs(args[0], exist_ok=True)
    bake(args[0], '--preview' in sys.argv)
