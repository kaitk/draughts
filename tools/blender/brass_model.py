# The antique brass's model (task 129), without Blender: the values brass.py's Cycles
# material takes, and the same colour in numpy for brass_tile.py's --levels.
#
# Three states of one aged yellow brass (the specification's starting values, linear):
# exposed metal, a light tarnish, dark deposits. The tile's r is the mottling as a rank (0 to
# 1 evenly), so a state's coverage is a threshold on it: the darkest `deposit` of the surface
# is deposit, the lightest `exposed` bare metal, the rest tarnish, with wide soft edges.
#
# A level is the material's overall tone, for the user to pick: level 1 the specification's
# mix (35/50/15), level 5 bronze B's mean (room_shell::WINDOW_METAL). Between them the mean's
# luminance steps evenly in log; each level moves coverage toward the deposits, scales the
# tarnish and deposits by its gain and the bare metal by the gain's square root (rubbed brass
# stays brass, EXPOSED_POWER), and tints the tarnish and deposits toward bronze B's hue.
# The colour's mottling is then pulled halfway to the level's mean (MOTTLE): the states at full
# contrast read as camouflage beside the target's subtle patina; the metalness and roughness
# keep their full contrast, which breaks the highlights.
import numpy as np

EXPOSED = (0.91, 0.778, 0.423)    # C260 brass's f0, Real-Time Rendering 4th ed.
TARNISH = (0.55, 0.34, 0.13)
DEPOSIT = (0.10, 0.055, 0.025)
ROUGH = (0.28, 0.42, 0.58)         # exposed, tarnish, deposit
METAL = (1.0, 0.9, 0.1)
EXPOSED_POWER = 0.75
MOTTLE = 0.5
EDGE = 0.25                        # the states' soft edges, in rank
SPECKLE_DARK = 0.4                 # the pits: darker by this and rougher by SPECKLE_ROUGH
SPECKLE_ROUGH = 0.15
TILE_M = 0.064                     # the tile's side
BRONZE_B = (0.34, 0.25, 0.17)      # sRGB, task 127's metal

# level: (exposed, deposit) coverage
COVER = {1: (0.35, 0.15), 2: (0.28, 0.20), 3: (0.22, 0.26), 4: (0.16, 0.32), 5: (0.10, 0.38)}
# level: (exposed, deposit, gain, tint, the mean (linear)), from `brass_tile.py --levels` on the tile of seed 129.
LEVELS = {
    1: (0.35, 0.15, 1.000, (1.000, 1.000, 1.000), (0.6044, 0.4477, 0.2155)),   # sRGB 0.80, 0.70, 0.50
    2: (0.28, 0.20, 0.616, (1.085, 0.950, 0.973), (0.3803, 0.2607, 0.1255)),   # sRGB 0.65, 0.55, 0.39
    3: (0.22, 0.26, 0.388, (1.169, 0.911, 0.951), (0.2393, 0.1515, 0.0729)),   # sRGB 0.53, 0.43, 0.30
    4: (0.16, 0.32, 0.251, (1.238, 0.888, 0.953), (0.1505, 0.0879, 0.0423)),   # sRGB 0.42, 0.33, 0.23
    5: (0.10, 0.38, 0.167, (1.292, 0.880, 0.975), (0.0946, 0.0509, 0.0245)),   # sRGB 0.34, 0.25, 0.17
}


def smooth(a, b, x):
    x = np.clip((x - a) / (b - a), 0.0, 1.0)
    return x * x * (3 - 2 * x)


def weights(rank, cover):
    exposed_cover, deposit_cover = cover
    deposit = 1 - smooth(deposit_cover - EDGE, deposit_cover + EDGE, rank)
    exposed = smooth(1 - exposed_cover - EDGE, 1 - exposed_cover + EDGE, rank)
    return exposed, np.clip(1 - deposit - exposed, 0, 1), deposit


def colour(rank, speckle, cover, gain, tint):
    e, t, d = weights(rank, cover)
    tint = np.asarray(tint)
    c = (e[..., None] * np.asarray(EXPOSED) * gain ** EXPOSED_POWER + t[..., None] * np.asarray(TARNISH) * gain * tint
         + d[..., None] * np.asarray(DEPOSIT) * gain * tint)
    return c * (1 - SPECKLE_DARK * speckle)[..., None]
