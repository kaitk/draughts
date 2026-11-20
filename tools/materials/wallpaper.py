#!/usr/bin/env python3
"""Bakes the library's wallpaper: a one-channel mask of the gold flowers, tileable.

    python3 tools/materials/wallpaper.py OUT_DIR

The shader tints the mask from two colours: ground where it is 0, gold where it is 1.
Writes wallpaper_mask.png (L8), wallpaper_preview.png (the mask tinted here, RGB albedo),
and wallpaper_rough.png (L8, perceptual roughness): the mask keys roughness too, so the
shader may as well take it from the mask with the two values below and skip that file.
Sources: library-wallpaper-mask-01.png (the flowers, clean), library-wallpaper-01.png
(the printed paper, for the flowers' inner shading and the ground's mottle).
"""

import os
import sys

import numpy as np

import common as cm

SIZE = 1024             # px a side; one tile is the whole repeat
OVERLAP = 128           # source px the edges overlap for the seam cut
TILE_M = 1.4            # metres a tile covers: flower heads about 11 cm, near style-01's
                        # (a real paper's repeat would be 0.5 to 0.65 m, its flowers smaller)
GROUND = '#575d63'      # guess, to check under our light: sRGB albedo: dark blue-grey (style-01's ground under its warm light)
GOLD = '#a28e6a'        # guess, as GROUND: sRGB albedo: muted gold; the room's warm light makes it read golder
ROUGH_GROUND = 0.85     # guess: matte distemper-like paper
ROUGH_GOLD = 0.60       # guess: the gold print, a little sheen
DETAIL = 0.30           # how much of the printed paper's shading the flowers keep
MOTTLE = 0.06           # the ground's aged mottle, as a share of gold
SOFTEN = 0.6            # px of blur on the mask's edges before the resize (0 = none)


def bake(out):
    mask = cm.load(cm.source('library-wallpaper-mask-01.png'), 'L')
    paper = cm.load(cm.source('library-wallpaper-01.png'), 'L')
    if paper.shape != mask.shape:
        paper = cm.resize(paper, mask.shape[1], mask.shape[0])

    # The paper's shading, normalised inside the flowers and in the ground apart.
    flower = mask > 0.5
    lo, hi = np.percentile(paper[flower], [5, 95])
    shade = np.clip((paper - lo) / (hi - lo), 0, 1)
    g_lo, g_hi = np.percentile(paper[~flower], [5, 95])
    mottle = np.clip((paper - g_lo) / (g_hi - g_lo), 0, 1)
    mottle = cm.resize(cm.resize(mottle, 160, 160), *mask.shape[::-1])

    value = mask * (1 - DETAIL + DETAIL * shade) + (1 - mask) * MOTTLE * mottle
    tile = cm.seam_tile(value, OVERLAP, cost_img=mask)
    tile = np.clip(cm.resize_periodic(tile, SIZE, SIZE, SOFTEN), 0, 1)

    cm.save(os.path.join(out, 'wallpaper_mask.png'), tile)
    ground, gold = cm.to_linear(cm.hex_rgb(GROUND)), cm.to_linear(cm.hex_rgb(GOLD))
    preview = cm.to_srgb(ground + (gold - ground) * tile[..., None])
    cm.save(os.path.join(out, 'wallpaper_preview.png'), preview)
    rough = ROUGH_GROUND + (ROUGH_GOLD - ROUGH_GROUND) * tile
    cm.save(os.path.join(out, 'wallpaper_rough.png'), rough)
    print(f'tile {TILE_M} m a side, {SIZE / TILE_M / 100:.1f} px/cm; ground {GROUND}, gold {GOLD}')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    os.makedirs(sys.argv[1], exist_ok=True)
    bake(sys.argv[1])
