#!/usr/bin/env python3
"""Makes the library's rug from ChatGPT's picture of it, with its end bands and fringes.

    python3 -I tools/materials/rug.py OUT_DIR [--preview]

Reads design/manor/pieces/library-rug-01.png (local, not in git; MANOR_DIR points to
another checkout's design/manor): a dense Kashan-type rug seen straight down in even light,
1536 x 1024 with a little dark floor round it. Cuts the floor away, scales the pile to
3.0 by 2.0 m and adds what the picture lacks: a narrow cream end band (a flat-woven strip)
and a fringe of cream tufts past each short end, and a little more wear where the players'
chairs stand and along the walk.

Writes rug.png, 1280 x 800 RGBA at 2.5 mm a texel (400 a metre): 3.2 m along by 2.0 m
across, the pile in the middle 3.0 m, the end band and fringe in the 0.1 m at each end.
On the pile RGB is the albedo and A is 1. Past the ends (shaders::ROOM_FRAG reads them so)
R is the cream's shade (the band and the strands, the colour itself is the shader's
RUG_CREAM), G the floor's shade under the tufts (their small shadows), B 0, and A the
strands' cover. The colours are stored with a 2.2 gamma, not sRGB's curve, since the shader
decodes with pow(c, 2.2): so the room shows the picture's own colours, its darks too.
--preview also writes rug_preview.png, the rug on a floor-brown ground.
"""

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as cm  # noqa: E402

SOURCE = 'library-rug-01.png'
CROP = (18, 13, 1518, 997)  # the pile in the picture (left, top, right, bottom): 1500 x 984
TEXEL_M = 0.0025
W, H = 1280, 800            # 3.2 m by 2.0 m
HALF = (1.5, 1.0)           # the pile's half length and width, metres
BAND = 0.015                # the cream end band past the pile
SEED = 11


def pile():
    """The picture's pile, linear, scaled to 3.0 by 2.0 m."""
    img = cm.to_linear(cm.load(cm.source(SOURCE)))
    l, t, r, b = CROP
    pw, ph = round(2 * HALF[0] / TEXEL_M), round(2 * HALF[1] / TEXEL_M)
    return np.clip(cm.resize(img[t:b, l:r], pw, ph), 0, None)


def wear(img, x, y):
    """Worn a little more where the chairs stand and along the walk: the pile thinned toward
    a greyer, paler foundation in patches, subtly (the picture is worn already)."""
    patch = cm.fbm(x / 0.25, y / 0.25, 4, SEED + 8) * 0.5 + 0.5
    chairs = np.exp(-(((np.abs(x) - 0.8) / 0.35) ** 2 + (y / 0.4) ** 2))
    walk = np.exp(-((y - 0.7) / 0.25) ** 2) * 0.6
    w = np.clip(np.maximum(chairs, walk) * (patch - 0.3) * 2.0, 0, 1) * 0.15
    grey = img.mean(-1, keepdims=True) * np.array([1.15, 1.05, 0.9], np.float32) + 0.02
    img += (grey - img) * w[..., None]


def blur(a, r):
    """A box blur of radius r texels, three times (near a Gaussian)."""
    for _ in range(3):
        for axis in (0, 1):
            c = np.cumsum(np.pad(a, [(r + 1, r) if i == axis else (0, 0) for i in range(2)], mode='edge'), axis)
            hi = np.take(c, np.arange(2 * r + 1, c.shape[axis]), axis)
            lo = np.take(c, np.arange(0, c.shape[axis] - 2 * r - 1), axis)
            a = (hi - lo) / (2 * r + 1)
    return a


def ends(x, y):
    """Past the pile: the end band and the fringe's tufts. Returns the cream's shade, the
    floor's shade under them, and the cover."""
    out = np.abs(x) - HALF[0]
    side = (x > 0).astype(np.int64)
    row = np.floor(y / TEXEL_M).astype(np.int64)
    # The band: weft rows across, a darker pair of lines in it, each warp its own.
    band = out < BAND
    shade = np.where(band, 0.92 + 0.08 * cm.rand(row * 2 + side, SEED + 20), 0.0)
    shade = np.where(band & (np.abs(out - 0.6 * BAND) < 0.0016), 0.62, shade)
    # The tufts: the warps gathered in bundles of about 1.5 cm, knotted 8 mm out, then
    # splayed and frayed; each bundle its own width, lean and length.
    f = out - BAND
    k = np.floor(y / 0.015)
    key = (k * 2 + side).astype(np.int64)
    width = 0.015 * (0.65 + 0.55 * cm.rand(key, SEED + 2))
    lean = (cm.rand(key, SEED + 3) - 0.5) * 0.5
    length = 0.035 + 0.035 * cm.rand(key, SEED + 4)
    knot = 0.008
    yc = (k + 0.5) * 0.015 + lean * np.clip(f - knot, 0, None)
    half = np.where(f < knot, 0.45 * width - 0.2 * width * f / knot,
                    np.minimum(0.25 * width + 0.12 * (f - knot), 0.42 * width))
    own = length * (0.88 + 0.15 * cm.rand(row * 2 + side, SEED + 5))
    strands = (np.abs(y - yc) < half) & (f > 0) & (f < own)
    a = strands * np.clip((own - f) / 0.008, 0.35, 1.0) * (0.65 + 0.35 * cm.rand(row * 2 + side, SEED + 6))
    s = (0.72 + 0.28 * np.clip((f - knot) / 0.03, 0, 1)) * (0.8 + 0.2 * cm.rand(row * 2 + side, SEED + 12))
    s = np.where(np.abs(f - knot) < 0.0025, 0.55, s)
    s *= 0.85 + 0.3 * cm.rand(key, SEED + 7)
    shade = np.where(band, shade, s)
    cover = np.where(band, 1.0, a)
    # The tufts' small shadows on the floor round them, a little toward the room's side.
    under = blur(np.roll(np.clip(cover * (f > 0), 0, 1), 2, axis=0), 3)
    floor = np.clip(under * 1.4, 0, 1) * 0.6
    return np.clip(shade, 0, 1), floor, np.clip(cover, 0, 1)


def bake(out, preview):
    xs = (np.arange(W) + 0.5) * TEXEL_M - W * TEXEL_M / 2
    ys = (np.arange(H) + 0.5) * TEXEL_M - H * TEXEL_M / 2
    x, y = np.meshgrid(xs, ys)
    inside = np.abs(x) < HALF[0]
    img = np.zeros((H, W, 3), np.float32)
    x0 = (W - round(2 * HALF[0] / TEXEL_M)) // 2
    img[:, x0:W - x0] = pile()
    wear(img, x, y)
    shade, floor, cover = ends(x, y)
    a = np.where(inside, 1.0, cover).astype(np.float32)
    # The 2.2 gamma the shader decodes; past the ends the shade (as linear) and the floor's.
    rgb = np.clip(img, 0, 1) ** (1 / 2.2)
    rgb[~inside] = np.stack([shade, floor, np.zeros_like(shade)], -1)[~inside]
    cm.save(os.path.join(out, 'rug.png'), rgb, a)
    if preview:
        cream = np.array([0.5, 0.44, 0.33], np.float32)
        lin = np.where(inside[..., None], np.clip(img, 0, 1), cream * shade[..., None])
        ground = cm.to_linear(cm.hex_rgb('#3a2618')) * (1 - np.where(inside, 0, floor))[..., None]
        p = lin * a[..., None] + ground * (1 - a[..., None])
        cm.save(os.path.join(out, 'rug_preview.png'), cm.to_srgb(p))


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if len(args) != 1:
        sys.exit(__doc__)
    os.makedirs(args[0], exist_ok=True)
    bake(args[0], '--preview' in sys.argv)
