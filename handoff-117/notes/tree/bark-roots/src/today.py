# Today's bark tile (trees::bark_tile in src/model3d/tree_mesh.goose) in numpy, the same
# structure with numpy's own random lattice: ridged value noise drawn out along the stem.
# Returns RG normal bytes as the shader reads them, B light, A lichen, all 0..1.
import numpy as np
from noise import wrapped
W, H = 256, 512

def ridged(n):
    r = 1 - np.abs(2 * n - 1)
    return r * r

def tile():
    warp = 0.08 * (wrapped(17, W, H, 3, 4) - 0.5) * W
    ridges = ridged(wrapped(3, W, H, 14, 6, (warp, 0)))
    fine = ridged(wrapped(5, W, H, 28, 14, (warp * 1.5, 0)))
    h = 0.7 * ridges + 0.3 * fine
    dx = np.roll(h, -1, 1) - np.roll(h, 1, 1)
    dy = np.roll(h, -1, 0) - np.roll(h, 1, 0)
    blotch = wrapped(23, W, H, 5, 4) * 0.7 + wrapped(29, W, H, 16, 12) * 0.3
    lichen = np.clip((blotch - 0.62) / 0.12, 0, 1) * np.clip(h * 1.6, 0, 1)
    return np.stack([np.clip(0.5 - dx * 2.2, 0, 1), np.clip(0.5 - dy * 2.2, 0, 1),
                     np.clip(0.35 + 0.65 * h, 0, 1), lichen], -1)
