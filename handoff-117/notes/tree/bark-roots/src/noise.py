# Wrapped value noise and helpers over a periodic tile, numpy only.
import numpy as np

def lattice(seed, nx, ny):
    rng = np.random.default_rng(seed)
    return rng.random((ny, nx))

def wrapped(seed, W, H, cx, cy, warp=None):
    """Value noise over a W x H tile, cx cells across and cy along, wrapping both ways,
    0..1, eased. warp: optional (du, dv) arrays in texels added before lookup."""
    L = lattice(seed, cx, cy)
    x = (np.arange(W) + 0.5)[None, :] * cx / W + np.zeros((H, 1))
    y = (np.arange(H) + 0.5)[:, None] * cy / H + np.zeros((1, W))
    if warp is not None:
        x = x + warp[0] * cx / W
        y = y + warp[1] * cy / H
    i = np.floor(x).astype(int); j = np.floor(y).astype(int)
    fx = x - i; fy = y - j
    sx = fx * fx * (3 - 2 * fx); sy = fy * fy * (3 - 2 * fy)
    i0 = i % cx; i1 = (i + 1) % cx; j0 = j % cy; j1 = (j + 1) % cy
    a = L[j0, i0]; b = L[j0, i1]; c = L[j1, i0]; d = L[j1, i1]
    return (a + (b - a) * sx) * (1 - sy) + (c + (d - c) * sx) * sy

def fbm(seed, W, H, cx, cy, octaves=4, warp=None):
    s = np.zeros((H, W)); amp = 1.0; tot = 0.0
    for o in range(octaves):
        s += amp * wrapped(seed + 101 * o, W, H, cx << o, cy << o, warp)
        tot += amp; amp *= 0.5
    return s / tot

def blur(a, r, axis_y=True, axis_x=True):
    """Box blur of radius r texels, wrapping, applied twice (about a tent)."""
    out = a.astype(np.float64)
    for _ in range(2):
        if axis_x:
            c = np.cumsum(np.concatenate([out[:, -r:], out, out[:, :r + 1]], axis=1), axis=1)
            out = (c[:, 2 * r + 1:] - c[:, :-2 * r - 1])[:, :a.shape[1]] / (2 * r + 1)
        if axis_y:
            c = np.cumsum(np.concatenate([out[-r:], out, out[:r + 1]], axis=0), axis=0)
            out = (c[2 * r + 1:] - c[:-2 * r - 1])[:a.shape[0]] / (2 * r + 1)
    return out

def chamfer(seed_mask, attr, iters=40):
    """Distance (texels) to the nearest True of seed_mask, wrapping, by repeated
    8-neighbour relaxation (a chamfer transform), carrying attr of the nearest seed."""
    INF = 1e9
    d = np.where(seed_mask, 0.0, INF)
    a = np.where(seed_mask, attr, 0.0)
    steps = [(0, 1, 1.0), (0, -1, 1.0), (1, 0, 1.0), (-1, 0, 1.0),
             (1, 1, 1.4142), (1, -1, 1.4142), (-1, 1, 1.4142), (-1, -1, 1.4142)]
    for _ in range(iters):
        changed = False
        for dy, dx, c in steps:
            dn = np.roll(np.roll(d, dy, 0), dx, 1) + c
            better = dn < d - 1e-6
            if better.any():
                changed = True
                d = np.where(better, dn, d)
                a = np.where(better, np.roll(np.roll(a, dy, 0), dx, 1), a)
        if not changed:
            break
    return d, a

def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)
