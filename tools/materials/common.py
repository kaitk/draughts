"""Helpers the material bakers share: image I/O, seam cutting, noise, and oak.

Images are float32 arrays in 0..1, sRGB unless a name says linear.
"""

import os

import numpy as np
from PIL import Image

# The downloads are local, not in git; MANOR_DIR points elsewhere (another checkout's).
MANOR = os.environ.get('MANOR_DIR') or os.path.join(
    os.path.dirname(os.path.abspath(__file__)), '..', '..', 'design', 'manor')


def source(name):
    """A design/manor image by its file name, wherever under design/manor it is."""
    for root, _, files in os.walk(MANOR):
        if name in files:
            return os.path.join(root, name)
    raise SystemExit(f'{name} not found under {os.path.normpath(MANOR)}')


def load(path, mode='RGB'):
    return np.asarray(Image.open(path).convert(mode), np.float32) / 255.0


def save(path, a, alpha=None):
    """Saves an sRGB image; alpha (linear, as roughness is) goes in A if given."""
    if alpha is not None:
        a = np.concatenate([a, alpha[..., None]], -1)
    a = np.clip(a * 255.0 + 0.5, 0, 255).astype(np.uint8)
    Image.fromarray(a).save(path, optimize=True)
    print(f'wrote {path} {a.shape[1]}x{a.shape[0]}')


def resize(a, w, h):
    """Area-correct resize of a float image (Lanczos per channel in float)."""
    if a.ndim == 2:
        return np.asarray(Image.fromarray(np.ascontiguousarray(a, np.float32), 'F').resize((w, h), Image.LANCZOS))
    return np.stack([resize(a[..., c], w, h) for c in range(a.shape[2])], -1)


def _spectrum_resize(a, h, w, sigma):
    F = np.fft.fft2(a)
    H, W = a.shape
    fy = np.rint(np.fft.fftfreq(H) * H)
    fx = np.rint(np.fft.fftfreq(W) * W)
    ky = np.abs(fy) < h / 2
    kx = np.abs(fx) < w / 2
    # A soft roll-off near the new Nyquist keeps sharp edges from ringing.
    ry = np.clip((np.abs(fy) / (h / 2) - 0.6) / 0.4, 0, 1)
    rx = np.clip((np.abs(fx) / (w / 2) - 0.6) / 0.4, 0, 1)
    win = np.outer(0.5 + 0.5 * np.cos(np.pi * ry), 0.5 + 0.5 * np.cos(np.pi * rx))
    if sigma:
        g = np.outer(np.exp(-0.5 * (2 * np.pi * sigma * np.fft.fftfreq(H)) ** 2),
                     np.exp(-0.5 * (2 * np.pi * sigma * np.fft.fftfreq(W)) ** 2))
        win = win * g
    F = (F * win)[ky][:, kx]
    G = np.zeros((h, w), complex)
    iy = fy[ky].astype(np.int64) % h
    ix = fx[kx].astype(np.int64) % w
    G[np.ix_(iy, ix)] = F
    return np.real(np.fft.ifft2(G)) * (h * w) / (H * W)


def resize_periodic(a, h, w, sigma=0.0):
    """Resizes a tile that wraps (down, mostly), keeping it wrapping; sigma blurs (source px)."""
    if a.ndim == 2:
        return _spectrum_resize(a, h, w, sigma).astype(np.float32)
    return np.stack([resize_periodic(a[..., c], h, w, sigma) for c in range(a.shape[2])], -1)


def to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    c = np.clip(c, 0, None)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def hex_rgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], np.float32) / 255.0


def downscale(a, f):
    """Box-filter by an integer factor, in linear light (as a mip chain would)."""
    h, w = a.shape[0] // f * f, a.shape[1] // f * f
    a = to_linear(a[:h, :w])
    a = a.reshape(h // f, f, w // f, f, *a.shape[2:]).mean((1, 3))
    return to_srgb(a)


# Seam cutting: makes an image that is not periodic into a tile, by overlapping
# its far edge with its near one and cutting the overlap along the path where
# the two differ least (as image quilting does).

def _cut_path(cost, wrap):
    """Min-cost path down the rows of cost (rows x ov), moving at most one column
    a row. With wrap, the path's last column is within one of its first."""
    rows, ov = cost.shape
    big = np.float32(1e9)
    starts = np.arange(ov) if wrap else np.array([0])
    acc = np.full((len(starts), ov), big, np.float32)
    if wrap:
        acc[np.arange(ov), np.arange(ov)] = cost[0]
    else:
        acc[0] = cost[0]
    back = np.zeros((rows, len(starts), ov), np.int8)
    for r in range(1, rows):
        left = np.concatenate([np.full((len(starts), 1), big), acc[:, :-1]], 1)
        right = np.concatenate([acc[:, 1:], np.full((len(starts), 1), big)], 1)
        stack = np.stack([left, acc, right])
        k = stack.argmin(0)
        acc = stack.min(0) + cost[r]
        back[r] = k.astype(np.int8) - 1
    if wrap:
        s = np.arange(ov)
        ends = np.full((ov, ov), big, np.float32)
        for d in (-1, 0, 1):
            e = np.clip(s + d, 0, ov - 1)
            ends[s, e] = np.minimum(ends[s, e], acc[s, e])
        si, ei = np.unravel_index(ends.argmin(), ends.shape)
    else:
        si, ei = 0, int(acc[0].argmin())
    path = np.zeros(rows, np.int64)
    path[-1] = ei
    for r in range(rows - 1, 0, -1):
        path[r - 1] = path[r] + back[r, si, path[r]]
    return path


def seam_tile(img, ov, cost_img=None, margin=4, both=True):
    """Cuts img (H x W [x C]) into a (H-ov) x (W-ov) tile that wraps both ways, or
    without both into an H x (W-ov) strip that wraps along x only. cost_img (H x W) is
    what the cut avoids crossing; img itself by default."""
    if cost_img is None:
        cost_img = img if img.ndim == 2 else img.mean(2)

    def horizontal(a, c, wrap):
        t = a.shape[1] - ov
        diff = np.abs(c[:, t:] - c[:, :ov])
        diff[:, :margin] += 10
        diff[:, ov - margin:] += 10
        path = _cut_path(diff, wrap)
        cols = np.arange(t)[None, :]
        take_far = cols < path[:, None]
        src = np.where(take_far, cols + t, cols)
        rows = np.arange(a.shape[0])[:, None]
        return a[rows, src], c[rows, src]

    a, c = horizontal(img, cost_img, False)
    if not both:
        return a
    a = np.swapaxes(a, 0, 1)
    c = c.T
    a, c = horizontal(a, c, True)
    return np.swapaxes(a, 0, 1)


# Noise: value noise from a hash of the lattice, optionally periodic per axis.

def _hash(ix, iy, seed):
    h = (ix.astype(np.int64) * 374761393 + iy.astype(np.int64) * 668265263
         + seed * 2147483647) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h = h ^ (h >> 16)
    return (h & 0xFFFFFF).astype(np.float32) / 0xFFFFFF


def value_noise(x, y, seed=0, period=(0, 0)):
    """Smooth noise in 0..1 at float coords; period (px, py) in lattice cells, 0 = none."""
    x0 = np.floor(x)
    y0 = np.floor(y)
    fx = x - x0
    fy = y - y0
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    x0 = x0.astype(np.int64)
    y0 = y0.astype(np.int64)
    x1 = x0 + 1
    y1 = y0 + 1
    if period[0]:
        x0, x1 = x0 % period[0], x1 % period[0]
    if period[1]:
        y0, y1 = y0 % period[1], y1 % period[1]
    a = _hash(x0, y0, seed)
    b = _hash(x1, y0, seed)
    c = _hash(x0, y1, seed)
    d = _hash(x1, y1, seed)
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(x, y, octaves, seed=0, period=(0, 0), gain=0.5):
    """Sum of octaves of value noise, roughly in -1..1."""
    total = np.zeros_like(x, dtype=np.float32)
    amp = 1.0
    norm = 0.0
    f = 1
    for o in range(octaves):
        p = (period[0] * f, period[1] * f)
        total += amp * (value_noise(x * f, y * f, seed + 17 * o, p) * 2 - 1)
        norm += amp
        amp *= gain
        f *= 2
    return total / norm


def rand(key, seed):
    """A float in 0..1 per integer key (array or scalar)."""
    k = np.asarray(key, np.int64)
    return _hash(k, k * 7 + 3, seed)


# Oak, flat-sawn: growth rings of a log whose pith lies below the board,
# cut through by the face, with pores along the grain and a few ray flecks.

def oak(along, across, board, p):
    """Oak at plank-local coords in cm (along the grain, across it), for integer board
    ids: its shade, about -1..1 (pores and latewood dark); how open its pores are, 0..1
    (for roughness); and a slow streak along the grain, about -1..1. Flat-sawn: the
    growth rings of a log whose pith lies under the face, ring-porous, so each ring
    starts with a band of open pores. p: the wood's parameters (see the bakers' heads).
    With p['along_period_cm'], everything repeats along the grain at that length."""
    seed = p['seed']
    period = p.get('along_period_cm', 0)

    def noise_along(scale_cm):
        # Lattice cells along the grain for a feature scale_cm long, and their period.
        if not period:
            return along / scale_cm, 0
        cells = max(1, int(round(period / scale_cm)))
        return along / period * cells, cells

    depth = p['pith_depth'][0] + rand(board, seed + 1) * (p['pith_depth'][1] - p['pith_depth'][0])
    offset = (rand(board, seed + 2) - 0.5) * p['pith_offset']
    tilt = 0.0 if period else (rand(board, seed + 3) - 0.5) * p['pith_tilt']
    phase = rand(board, seed + 4) * 100.0
    jitter = board * 13.1 + rand(board, seed + 5) * 97.0

    # The rings wander: warp the across coordinate with slow noise along the grain.
    x, n = noise_along(p['warp_scale'])
    warp = fbm(x, across / p['warp_scale'] + jitter, 3, seed + 6, (n, 0)) * p['warp']
    c = across - offset + warp + tilt * along
    if period:
        # In place of the tilt, the pith sweeps across and back once a period, so the
        # rings still cut through the face in arcs.
        c = c + p.get('sweep', 0.0) * np.sin(2 * np.pi * (along / period + rand(board, seed + 11)))
    r = np.sqrt(c * c + depth * depth) * p['rings_per_cm'] + phase
    ring = r - np.floor(r)

    # Pores: short dark streaks along the grain, broken up.
    x, n = noise_along(p['pore_len'])
    pn = value_noise(x, across / p['pore_w'] + jitter * 7.3, seed + 7, (n, 0))
    x2, n2 = noise_along(p['pore_len'] * 0.43)
    pn = 0.6 * pn + 0.4 * value_noise(x2, across / (p['pore_w'] * 0.7) + jitter * 3.1, seed + 9, (n2, 0))
    pores = np.clip((pn - (1 - p['pore_density'])) / p['pore_density'], 0, 1)

    # Earlywood: a band of open pores at each ring's start, soft on both sides.
    w = p['early_band']
    early = np.exp(-((np.minimum(ring, 1 - ring)) / w) ** 2)
    # Latewood: a gentle darkening in the ring's second half, no hard edge.
    late = 0.5 - 0.5 * np.cos(2 * np.pi * (ring - 0.25))

    # Figure: slow tone patches, and faint colour streaks along the grain.
    x, n = noise_along(p['figure_cm'])
    tone = fbm(x, across / (p['figure_cm'] * 0.3) + jitter, 3, seed + 8, (n, 0))
    x, n = noise_along(8.0)
    streak = fbm(x, across / 0.5 + jitter, 2, seed + 10, (n, 0))

    open_pores = early * (0.3 + 0.7 * pores) + pores * (1 - early) * p['pore_spread']
    shade = (-p['early_dark'] * early * (0.3 + 0.7 * pores)
             - p['pore_dark'] * pores * (1 - early) * p['pore_spread']
             - p['late_dark'] * late
             + p['figure'] * tone + p['streak'] * streak)
    return shade, np.clip(open_pores, 0, 1), streak
