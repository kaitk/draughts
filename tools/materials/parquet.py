#!/usr/bin/env python3
"""Bakes the library's floor: oak herringbone, laid here plank by plank, tileable.

    python3 tools/materials/parquet.py OUT_DIR

Writes parquet.png: RGB the albedo (sRGB), A the perceptual roughness (linear, Filament's
`roughness`, squared in the shader), and parquet_height.png (L8: 1 the planks' face, 0 the
joint's bottom, JOINT_DEPTH_MM deep), optional. The planks run at 45 degrees to the tile's edges,
so the floor's rows of points run along the texture's x. One tile is
TILE_REPEATS * PLANK_RATIO * sqrt(2) plank widths a side (printed when baked).
"""

import os
import sys

import numpy as np

import common as cm

SIZE = 1024             # px a side
SUPERSAMPLE = 2         # baked this many times larger, then box-filtered down in linear light
PLANK_W_CM = 7.0        # plank width
PLANK_RATIO = 5         # plank length in widths (7 x 35 cm; the download's are about 1:4)
TILE_REPEATS = 2        # herringbone periods a tile holds (2: 40 distinct planks, 0.99 m)
SEED = 11

# Colour (all to check under our light): sRGB albedo of the mean plank, from library-parquet-01 made a little less red
# to meet style-01's floor; planks vary in lightness and a little in hue.
BASE = '#56331a'
PLANK_LIGHTNESS = 0.22  # +- share each plank's lightness varies
PLANK_HUE = 0.05        # +- share the red and blue vary against green
CONTRAST = (1.2, 1.3, 1.45)  # how strongly the grain darkens or lightens, per channel (log
                        # scale): darks go deeper brown, as oiled oak's do

JOINT_MM = 0.7          # the dark gap between planks
JOINT_DARK = 0.45       # guess: its colour as a share of the wood's (dirt in the gap)
BEVEL_MM = 2.5          # planks darken a little this close to their edges (wear, wax)
BEVEL_DARK = 0.12       # guess

# Roughness (perceptual), waxed oak. All guesses, to tune under our light.
ROUGH = (0.35, 0.50)    # guess: a plank's range; each plank draws its own
ROUGH_ALONG = 0.04      # guess: +- along the grain (the oak's slow streaks)
ROUGH_PORES = 0.12      # guess: open pores this much rougher
ROUGH_JOINT = 0.80      # guess: the joints
ROUGH_WORN = -0.06      # guess: the worn edge (the bevel) this much smoother
JOINT_DEPTH_MM = 1.0    # the height map's depth at a joint; the bevel falls 0.3 mm

OAK = dict(
    seed=SEED,
    pith_depth=(2.0, 14.0),     # cm under the face; shallow gives wide cathedral arcs
    pith_offset=8.0,            # cm the pith wanders across the plank
    pith_tilt=0.20,             # rings run out of the plank along its length
    rings_per_cm=3.0,           # growth rings (oak: 2 to 5 mm apart)
    early_band=0.13,            # the earlywood pore band, as a share of a ring
    early_dark=0.9,
    late_dark=0.10,
    warp=0.8, warp_scale=12.0,  # cm: the rings' wander
    pore_len=0.6, pore_w=0.07, pore_density=0.40, pore_dark=0.9, pore_spread=0.8,
    figure=0.35, figure_cm=18.0,
    streak=0.10,
)


def bake(out):
    n = SIZE * SUPERSAMPLE
    k = PLANK_RATIO
    m = TILE_REPEATS
    side = m * k * np.sqrt(2)  # tile side in plank widths
    t = (np.arange(n, dtype=np.float64) + 0.5) / n * side
    X, Y = np.meshgrid(t, t)
    u = (X + Y) / np.sqrt(2)
    v = (X - Y) / np.sqrt(2)

    # Herringbone in (u, v): staircases of a plank along u and one along v, stepping
    # (1, 1); the next staircase is (2k, 0) on.
    j = np.floor(v)
    b = np.floor((u - j + k) / (2 * k))
    ub = u - 2 * k * b
    ul = ub - j
    horiz = ul >= 0
    i = np.floor(ub)
    step = np.where(horiz, j, i)
    along = np.where(horiz, ul, v - (i + 1))
    across = np.where(horiz, v - j, ub - i)

    # Which plank of the tile this is, so copies of the tile show the same plank.
    q = np.floor(b / m)
    r = b - q * m
    s = np.mod(step + k * q * m, m * k)
    plank = ((r * m * k + s) * 2 + (~horiz)).astype(np.int64)

    w = PLANK_W_CM
    shade, pores, streak = cm.oak(along * w, across * w, plank, OAK)

    lin = cm.to_linear(cm.hex_rgb(BASE))
    light = 1 + PLANK_LIGHTNESS * (cm.rand(plank, SEED + 20) * 2 - 1)
    hue = PLANK_HUE * (cm.rand(plank, SEED + 21) * 2 - 1)
    tint = np.stack([1 + hue, np.ones_like(hue), 1 - hue], -1)
    col = lin * tint * light[..., None] * np.exp(np.array(CONTRAST) * shade[..., None])

    # Joints and the planks' worn edges, by distance to the plank's edge in mm.
    edge = np.minimum(np.minimum(along, k - along), np.minimum(across, 1 - across)) * w * 10
    px_mm = n / (side * w * 10)
    joint = np.clip((edge - JOINT_MM / 2) * px_mm + 0.5, 0, 1)
    bevel = 1 - BEVEL_DARK * np.clip(1 - edge / BEVEL_MM, 0, 1) ** 2
    col = col * (bevel * (JOINT_DARK + (1 - JOINT_DARK) * joint))[..., None]

    lo, hi = ROUGH
    rough = (lo + (hi - lo) * cm.rand(plank, SEED + 22) + ROUGH_ALONG * streak
             + ROUGH_PORES * pores)
    worn = np.clip(1 - edge / BEVEL_MM, 0, 1) ** 2
    rough = rough + ROUGH_WORN * worn
    rough = rough * joint + ROUGH_JOINT * (1 - joint)
    height = 1 - (0.3 / JOINT_DEPTH_MM) * worn
    height = height * joint

    def down(a):
        return a.reshape(SIZE, SUPERSAMPLE, SIZE, SUPERSAMPLE, *a.shape[2:]).mean((1, 3))

    cm.save(os.path.join(out, 'parquet.png'), cm.to_srgb(down(col)), np.clip(down(rough), 0, 1))
    cm.save(os.path.join(out, 'parquet_height.png'), down(height))
    tile_m = side * w / 100
    print(f'tile {tile_m:.3f} m a side, {SIZE / tile_m / 100:.1f} px/cm; '
          f'planks {w:g} x {w * k:g} cm, {2 * m * m * k} a tile')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    os.makedirs(sys.argv[1], exist_ok=True)
    bake(sys.argv[1])
