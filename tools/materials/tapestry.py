#!/usr/bin/env python3
"""Makes the library chairs' upholstery from ChatGPT's picture of a tapestry fabric.

    python3 -I tools/materials/tapestry.py OUT_DIR [--preview]

Reads design/manor/pieces/library-tapestry-01.png (local, not in git; MANOR_DIR points to
another checkout's design/manor): a flat floral tapestry, 549 x 625, with a printed caption
on a light band along its foot. Cuts the caption away, takes out the photo's slow light
gradient, and makes a 480 px square of it wrap both ways by image quilting: each seam is
the least-different cut through a band of fabric beyond the square's edge, joined with a
narrow feather across the cut only, so no flower is doubled.

Writes tapestry.png, 512 x 512 RGBA over 240 mm of fabric both ways (about 0.47 mm a
texel), tileable. RGB is the albedo and A is 1. The colours are stored with a 2.2 gamma,
not sRGB's curve, since the shader decodes with pow(c, 2.2).
--preview also writes tapestry_3x3.png, the tile 3 x 3 at 768 px in sRGB, and prints the
tile's mean colour as stored and in linear light.
"""

import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as cm  # noqa: E402

SOURCE = 'library-tapestry-01.png'
FABRIC_ROWS = 592     # the caption's light band starts at row 595
T = 480               # the tile's side in source px: 240 mm, so 0.5 mm a source px
W = 56                # the overlap band beyond the tile's right and bottom edges
FEATHER = 3.0         # px across the cut over which the two sides blend
MARGIN = 4            # the cut keeps this far inside the band, so the feather fits
FLAT_SIGMA = 60.0     # px: the light gradient is what a blur this wide leaves
SIZE = 512
PREVIEW = 768


def blur(a, sigma):
    """A wide Gaussian blur of a 2D array, as two dense kernel matrices; each row of a
    kernel is normalised over the picture, so the edges are not darkened."""
    def kernel(n):
        i = np.arange(n, dtype=np.float32)
        k = np.exp(-0.5 * ((i[:, None] - i[None, :]) / sigma) ** 2)
        return k / k.sum(1, keepdims=True)
    return kernel(a.shape[0]) @ a @ kernel(a.shape[1]).T


def fabric():
    """The picture's fabric, linear, with the caption cut and the light made even."""
    img = cm.to_linear(cm.load(cm.source(SOURCE))[:FABRIC_ROWS])
    lum = img @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    light = blur(lum, FLAT_SIGMA)
    return img * (light.mean() / light)[..., None]


def cut(a, c, wrap):
    """Joins a's band beyond column T onto its first columns along the least-different cut
    down the rows: a is rows x (T + W) x 3 (linear), c the same in the 2.2 encoding, which
    the cost is taken in. Returns the rows x T strip, linear and encoded, and the cut's
    cost. Left of the cut the strip takes the band (the fabric that follows column T-1),
    right of it its own columns; across the cut the two blend over FEATHER px."""
    diff = ((c[:, T:] - c[:, :W]) ** 2).sum(-1)
    diff[:, :MARGIN] += 10
    diff[:, W - MARGIN:] += 10
    path = cm._cut_path(diff, wrap)
    cost = float(diff[np.arange(len(path)), path].sum())
    # Weight of the band: 1 well left of the cut, 0 at and right of it, 3 px between.
    d = np.arange(T)[None, :] - path[:, None]
    far = np.clip(0.5 - (d + 0.5) / FEATHER, 0, 1)[..., None]
    pad = np.zeros_like(a[:, :T - W])
    band = np.concatenate([a[:, T:], pad], 1)
    out = a[:, :T] * (1 - far) + band * far
    return out, encode(out), cost


def encode(lin):
    return np.clip(lin, 0, 1) ** (1 / 2.2)


def quilt(img, x0, y0):
    """The T x T tile at (x0, y0), wrapped both ways. The first cut runs down all T + W
    rows; the second, across the columns, wraps, so it ends where it began, and it cuts
    the band's rows (already joined across) onto the tile's top: so at the corner where
    the seams meet, each side of both cuts is fabric that really follows on."""
    a = img[y0:y0 + T + W, x0:x0 + T + W]
    a, c, cost_x = cut(a, encode(a), False)
    a, c, cost_y = cut(np.swapaxes(a, 0, 1), np.swapaxes(c, 0, 1), True)
    return np.swapaxes(a, 0, 1), cost_x + cost_y


def resample(tile, n):
    """Lanczos to n x n over a copy padded by wrapping, so the filter sees the fabric that
    follows each edge and the result still wraps."""
    p = 8
    out = []
    for ch in range(tile.shape[2]):
        a = np.pad(tile[..., ch], p, mode='wrap').astype(np.float32)
        im = Image.fromarray(a, 'F').resize((n, n), Image.LANCZOS, box=(p, p, p + T, p + T))
        out.append(np.asarray(im))
    return np.stack(out, -1)


def bake(out, preview):
    img = fabric()
    # The square whose two seams cost least, over the offsets the picture leaves.
    h, w = img.shape[:2]
    best = min(((x0, y0) for x0 in range(0, w - T - W + 1, 2)
                for y0 in range(0, h - T - W + 1, 4)),
               key=lambda o: quilt(img, *o)[1])
    tile, cost = quilt(img, *best)
    print(f'tile at {best}, cut cost {cost:.2f}')
    tile = np.clip(resample(tile, SIZE), 0, 1)
    rgb = encode(tile)
    cm.save(os.path.join(out, 'tapestry.png'), rgb, np.ones((SIZE, SIZE), np.float32))
    if preview:
        big = cm.resize(np.tile(tile, (3, 3, 1)), PREVIEW, PREVIEW)
        cm.save(os.path.join(out, 'tapestry_3x3.png'), cm.to_srgb(np.clip(big, 0, 1)))
        stored = np.round(rgb * 255) / 255
        print('mean stored (2.2 gamma):', np.round(stored.reshape(-1, 3).mean(0) * 255, 1))
        print('mean linear (pow 2.2):  ', np.round((stored ** 2.2).reshape(-1, 3).mean(0), 4))


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if len(args) != 1:
        sys.exit(__doc__)
    os.makedirs(args[0], exist_ok=True)
    bake(args[0], '--preview' in sys.argv)
