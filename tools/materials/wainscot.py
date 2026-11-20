#!/usr/bin/env python3
"""Bakes the wainscot's oak: the floor's wood, darker, for stiles, rails and panels.

    python3 tools/materials/wainscot.py OUT_DIR

Writes wainscot_oak.png, tileable, the grain along y: RGB the albedo (sRGB), A the
perceptual roughness (linear, Filament's `roughness`). No height map: the mouldings
are geometry. The panelling
is geometry; stiles map it as it is, rails with u and v swapped, so the grain runs
along each piece. Boards are glued edge to edge, so they meet without a gap.
"""

import os
import sys

import numpy as np

import common as cm

SIZE = 1024             # px a side
SUPERSAMPLE = 2
TILE_CM = 50.0          # the tile's side; 20 px/cm, as the wainscot is seen nearer than the floor
BOARDS = 4              # boards across a tile (12.5 cm each, as wide as a stile)
SEED = 23

# Colour (all to check under our light): sRGB albedo, darker and redder than the floor (style-01's wainscot; the
# download's is far more orange than the concepts).
BASE = '#46240f'
BOARD_LIGHTNESS = 0.12
BOARD_HUE = 0.04
CONTRAST = (1.1, 1.25, 1.5)
BOARD_EDGE = 0.04       # the faint darkening where two boards are glued

# Roughness (perceptual), waxed oak. All guesses, to tune under our light.
ROUGH = (0.38, 0.48)    # guess: a board's range
ROUGH_ALONG = 0.04      # guess: +- along the grain
ROUGH_PORES = 0.12      # guess: open pores this much rougher

OAK = dict(
    seed=SEED,
    along_period_cm=TILE_CM,
    pith_depth=(3.0, 20.0),
    pith_offset=10.0,
    pith_tilt=0.0,              # no tilt, as the tile repeats along the grain; instead
    sweep=1.0,                  # cm the pith swings across and back over a tile's length
    rings_per_cm=3.0,
    early_band=0.13,
    early_dark=1.1,
    late_dark=0.10,
    warp=0.7, warp_scale=12.5,
    pore_len=0.6, pore_w=0.06, pore_density=0.40, pore_dark=0.8, pore_spread=0.8,
    figure=0.35, figure_cm=25.0,
    streak=0.10,
)


def bake(out):
    n = SIZE * SUPERSAMPLE
    t = (np.arange(n, dtype=np.float64) + 0.5) / n * TILE_CM
    across, along = np.meshgrid(t, t)
    board_w = TILE_CM / BOARDS
    board = np.floor(across / board_w).astype(np.int64)
    local = across - board * board_w

    shade, pores, streak = cm.oak(along, local, board, OAK)
    lin = cm.to_linear(cm.hex_rgb(BASE))
    light = 1 + BOARD_LIGHTNESS * (cm.rand(board, SEED + 20) * 2 - 1)
    hue = BOARD_HUE * (cm.rand(board, SEED + 21) * 2 - 1)
    tint = np.stack([1 + hue, np.ones_like(hue), 1 - hue], -1)
    edge = np.minimum(local, board_w - local) * 10  # mm
    glue = 1 - BOARD_EDGE * np.clip(1 - edge, 0, 1)
    col = lin * tint * (light * glue)[..., None] * np.exp(np.array(CONTRAST) * shade[..., None])

    lo, hi = ROUGH
    rough = lo + (hi - lo) * cm.rand(board, SEED + 22) + ROUGH_ALONG * streak + ROUGH_PORES * pores

    def down(a):
        return a.reshape(SIZE, SUPERSAMPLE, SIZE, SUPERSAMPLE, *a.shape[2:]).mean((1, 3))

    cm.save(os.path.join(out, 'wainscot_oak.png'), cm.to_srgb(down(col)), np.clip(down(rough), 0, 1))
    print(f'tile {TILE_CM / 100:.2f} m a side, {SIZE / TILE_CM:.1f} px/cm; '
          f'{BOARDS} boards of {board_w:g} cm')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    os.makedirs(sys.argv[1], exist_ok=True)
    bake(sys.argv[1])
