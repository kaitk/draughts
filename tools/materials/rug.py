#!/usr/bin/env python3
"""Bakes the library's rug from library-rug-01.png: cut out, 3 by 2.2 m, evened out.

    python3 tools/materials/rug.py OUT_DIR

Writes rug.png (RGB, sRGB albedo), the whole rug edge to edge, not a tile. The download
is a 3:2 rug seen straight down; it is stretched to 3:2.2 along its width, which also
brings its narrower top and bottom borders nearer the sides'. Its light is evened out:
the side-to-side and top-to-bottom differences its mirror symmetry shows, and the
darkening toward the corners its border shows.
"""

import os
import sys

import numpy as np

import common as cm

RUG_M = (3.0, 2.2)      # length, width
WIDTH = 1536            # px along the length (5.1 px/cm)
# The rug's edges in the download (px), found by its red selvedge against the floor;
# it lies square to the frame within a pixel.
BOX = (18.5, 12.5, 1517.5, 996.5)
SMOOTH = 0.12           # light is what varies slower than this share of the rug's width
BORDER = 0.10           # the border ring the corner darkening is measured in, as a share
WEAVE = 0.035           # the pile's knot-to-knot variation, +- share of lightness
KNOT_MM = 2.5
SEED = 5


def blur(a, sigma):
    """Gaussian blur through the spectrum, the image mirrored so its edges don't wrap."""
    h, w = a.shape
    m = np.concatenate([a, a[::-1]], 0)
    m = np.concatenate([m, m[:, ::-1]], 1)
    fy = np.fft.fftfreq(2 * h)[:, None]
    fx = np.fft.fftfreq(2 * w)[None, :]
    g = np.exp(-2 * (np.pi * sigma) ** 2 * (fy * fy + fx * fx))
    return np.real(np.fft.ifft2(np.fft.fft2(m) * g))[:h, :w]


def bake(out):
    src = cm.load(cm.source('library-rug-01.png'))
    x0, y0, x1, y1 = BOX
    height = int(round(WIDTH * RUG_M[1] / RUG_M[0]))
    # Resample the box (sub-pixel) to the output, bilinear: it is scaled by under 12%.
    ys = y0 + (np.arange(height) + 0.5) / height * (y1 - y0) - 0.5
    xs = x0 + (np.arange(WIDTH) + 0.5) / WIDTH * (x1 - x0) - 0.5
    yi = np.clip(np.floor(ys).astype(int), 0, src.shape[0] - 2)
    xi = np.clip(np.floor(xs).astype(int), 0, src.shape[1] - 2)
    fy = (ys - yi)[:, None, None]
    fx = (xs - xi)[None, :, None]
    rug = ((src[yi][:, xi] * (1 - fx) + src[yi][:, xi + 1] * fx) * (1 - fy)
           + (src[yi + 1][:, xi] * (1 - fx) + src[yi + 1][:, xi + 1] * fx) * fy)

    lin = cm.to_linear(rug)
    lum = np.log(lin @ np.array([0.2126, 0.7152, 0.0722], np.float32) + 1e-4)
    soft = blur(lum, SMOOTH * WIDTH)
    # The design is mirror-symmetric both ways, so what differs from its mirror images is light.
    sym = (soft + soft[::-1] + soft[:, ::-1] + soft[::-1, ::-1]) / 4
    light = soft - sym

    # Corners: within the border ring, the design is the same all round, so its slow
    # darkening toward the corners is light. Fit it as a * (u^2 + v^2) over the ring.
    v, u = np.meshgrid(np.linspace(-1, 1, height), np.linspace(-1, 1, WIDTH), indexing='ij')
    ring = (np.abs(u) > 1 - 2 * BORDER) | (np.abs(v) > 1 - 2 * BORDER * WIDTH / height)
    r2 = u * u + v * v
    a = np.polyfit(r2[ring], sym[ring], 1)[0]
    light = light + a * (r2 - r2.mean())

    lin = lin * np.exp(-light)[..., None]

    # The pile: each knot a little lighter or darker.
    px_mm = WIDTH / (RUG_M[0] * 1000)
    yy, xx = np.mgrid[0:height, 0:WIDTH].astype(np.float32)
    knots = cm.value_noise(xx / (KNOT_MM * px_mm), yy / (KNOT_MM * px_mm), SEED)
    lin = lin * (1 + WEAVE * (knots * 2 - 1))[..., None]

    cm.save(os.path.join(out, 'rug.png'), cm.to_srgb(lin))
    print(f'{RUG_M[0]} x {RUG_M[1]} m, {WIDTH}x{height} px, {WIDTH / RUG_M[0] / 100:.1f} px/cm; '
          f'stretched {((x1 - x0) / (y1 - y0)) / (WIDTH / height):.3f} times across; '
          f'corner darkening fitted {np.exp(-a * 1):.3f} at the corners against the edges\' middles')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    os.makedirs(sys.argv[1], exist_ok=True)
    bake(sys.argv[1])
