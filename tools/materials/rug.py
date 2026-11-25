#!/usr/bin/env python3
"""Makes the library's rug from ChatGPT's picture of it.

    python3 -I tools/materials/rug.py OUT_DIR [--preview]

Reads design/manor/pieces/library-rug-01.png (local, not in git; MANOR_DIR points to
another checkout's design/manor): a dense Kashan-type rug seen straight down in even light,
1536 x 1024 with a little dark floor round it. Cuts the floor away, scales the pile to
3.0 by 2.0 m and adds a little more wear where the players' chairs stand and along the walk.

Writes rug.png, 1200 x 800 RGBA at 2.5 mm a texel (400 a metre): 3.0 m along by 2.0 m
across, the pile alone, with no end bands or fringes. RGB is the albedo and A is 1. The
colours are stored with a 2.2 gamma, not sRGB's curve, since the shader decodes with
pow(c, 2.2): so the room shows the picture's own colours, its darks too.
--preview also writes rug_preview.png, the pile in sRGB.
"""

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as cm  # noqa: E402

SOURCE = 'library-rug-01.png'
CROP = (18, 13, 1518, 997)  # the pile in the picture (left, top, right, bottom): 1500 x 984
TEXEL_M = 0.0025
W, H = 1200, 800            # 3.0 m by 2.0 m
HALF = (1.5, 1.0)           # the pile's half length and width, metres
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


def bake(out, preview):
    xs = (np.arange(W) + 0.5) * TEXEL_M - W * TEXEL_M / 2
    ys = (np.arange(H) + 0.5) * TEXEL_M - H * TEXEL_M / 2
    x, y = np.meshgrid(xs, ys)
    img = pile()
    wear(img, x, y)
    # The 2.2 gamma the shader decodes.
    rgb = np.clip(img, 0, 1) ** (1 / 2.2)
    cm.save(os.path.join(out, 'rug.png'), rgb, np.ones((H, W), np.float32))
    if preview:
        cm.save(os.path.join(out, 'rug_preview.png'), cm.to_srgb(np.clip(img, 0, 1)))


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if len(args) != 1:
        sys.exit(__doc__)
    os.makedirs(args[0], exist_ok=True)
    bake(args[0], '--preview' in sys.argv)
