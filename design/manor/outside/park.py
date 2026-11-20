# The park's layers put together: the three far panels, their skies cut, on a cylinder
# around the library's middle window; a sky of ours; the oak at 40 m; then the same seen
# through the three windows from the games table. python3 -I park.py OUTSIDE_DIR OUT_DIR (BAND_M, OAK=m,deg and TAG in the environment)
import sys, math
import numpy as np
from PIL import Image, ImageFilter

src, out = sys.argv[1], sys.argv[2]
F = 1024.0                      # px per radian; the panels' 24 mm focal length in px
EYE = 2.2                       # m over the lawn
PATH_M = 60.0                   # the path along the lawn's far edge, by the trees' size
PANELS = [                      # file, centre azimuth (deg, left negative), path row at its middle
    ('library-far-left-01.png', -50.0, 530),
    ('library-far-01.png',        0.0, 538),
    ('library-far-right-01.png', 50.0, 543),
]
SEAMS = [-25.0, 25.0]           # where one panel gives way to the next
SUN = (-20.0, 18.0)
import os
BAND_M = float(os.environ.get('BAND_M', 110))   # how far the tree line stands; the panels drawn for 60
OAK = tuple(map(float, os.environ.get('OAK', '70,22').split(',')))   # its distance (m), azimuth (deg)
TAG = os.environ.get('TAG', '')
W = int(F * math.radians(172)); H = 1900; V0 = 1400  # horizon row in the panorama

def load(p):
    return np.asarray(Image.open(p).convert('RGBA')).astype(np.float32) / 255

def box(a, r, axis):
    c = np.cumsum(np.pad(a, [(r + 1, r) if i == axis else (0, 0) for i in range(2)], mode='edge'), axis)
    n = a.shape[axis]
    hi = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis)
    lo = np.take(c, np.arange(0, n), axis)
    return (hi - lo) / (2 * r + 1)

def blur(a, r):                 # three box passes each way, near a Gaussian of radius r
    k = max(1, int(r / 1.7))
    for _ in range(3):
        a = box(box(a, k, 0), k, 1)
    return a

def fill(v, ok):                # carry the nearest known value into gaps, along axis 0
    idx = np.where(ok, np.arange(len(ok)), 0); np.maximum.accumulate(idx, out=idx)
    first = np.argmax(ok); idx[:first] = first
    return v[idx]

def sky_alpha(rgb, path_row):
    # The sky as a smooth field: a color per row plus an offset per column, fitted to the
    # pixels taken as sky, which can't follow the crowns down; a pixel's alpha is how far
    # its color is from it.
    c = rgb[..., :3]; h, w = c.shape[:2]
    m = np.zeros((h, w), np.float32); m[:100] = 1
    col = np.zeros((w, 3), np.float32)
    for _ in range(6):
        n = m.sum(1)
        row = (m[..., None] * (c - col[None])).sum(1) / np.maximum(n, 1)[:, None]
        row = fill(row, n > 15)
        n2 = m.sum(0)
        col = (m[..., None] * (c - row[:, None])).sum(0) / np.maximum(n2, 1)[:, None]
        col = fill(col, n2 > 5)
        col = np.stack([box(col[:, k:k + 1], 60, 0)[:, 0] for k in range(3)], -1)
        est = row[:, None] + col[None]
        d = np.sqrt(((c - est) ** 2).sum(-1))
        m = (d < 0.05).astype(np.float32); m[path_row - 30:] = 0
    a = np.clip((d - 0.03) / 0.07, 0, 1)
    a[path_row - 8:] = 1
    return a

def warp(img, az, path_row):
    hor = path_row - F * EYE / PATH_M
    k = BAND_M / PATH_M         # farther: the same angles hold k times less
    u = np.arange(W) - W / 2
    th = u / F * k - math.radians(az)   # the panels keep their overlap; the band spans less
    ok = np.abs(th) < math.radians(36.5)
    x = F * np.tan(th) + img.shape[1] / 2
    v = (np.arange(H) - V0)[:, None] * k
    y = v / np.cos(th)[None, :] + hor
    xi = np.clip(x, 0, img.shape[1] - 2); yi = np.clip(y, 0, img.shape[0] - 2)
    x0 = xi.astype(int)[None, :].repeat(H, 0); y0 = yi.astype(int)
    fx = (xi - np.floor(xi))[None, :, None]; fy = (yi - np.floor(yi))[..., None]
    g = lambda yy, xx: img[yy, xx]
    o = (g(y0, x0) * (1 - fx) * (1 - fy) + g(y0, x0 + 1) * fx * (1 - fy)
         + g(y0 + 1, x0) * (1 - fx) * fy + g(y0 + 1, x0 + 1) * fx * fy)
    inside = ok[None, :] & (y >= 0) & (y < img.shape[0] - 1)
    o[~inside] = 0
    return o

def sky():
    th = ((np.arange(W) - W / 2) / F)[None, :]
    ph = np.arctan((V0 - np.arange(H))[:, None] / F * np.ones((1, W)))
    s_th, s_ph = map(math.radians, SUN)
    c = (np.sin(ph) * math.sin(s_ph) + np.cos(ph) * math.cos(s_ph) * np.cos(th - s_th))
    ang = np.degrees(np.arccos(np.clip(c, -1, 1)))
    up = np.clip(ph / math.radians(40), 0, 1)[..., None]
    hex3 = lambda h: np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)], np.float32)
    zen, hor_cool, hor_warm, core = map(hex3, ('9fb3cf', 'd6dde6', 'f3d6aa', 'fff3d6'))
    warm = np.exp(-(ang / 45) ** 2)[..., None]
    hor = hor_cool * (1 - warm) + hor_warm * warm
    s = hor * (1 - up) + zen * up
    s = s + (core - s) * np.exp(-(ang / 7) ** 2)[..., None]
    return s

pano = sky()
pano[V0:] = np.array([0.36, 0.42, 0.16], np.float32)   # a plain lawn where no panel reaches
az = (np.arange(W) - W / 2) / F
edges = [-1e9] + [math.radians(s) / (BAND_M / PATH_M) for s in SEAMS] + [1e9]
acc = np.zeros_like(pano); acc_a = np.zeros(pano.shape[:2] + (1,), np.float32)
for i, (name, a, pr) in enumerate(PANELS):
    img = load(f'{src}/{name}')
    img[..., 3] = sky_alpha(img, pr)
    Image.fromarray((img[..., 3] * 255).astype(np.uint8)).save(f'{out}/alpha-{name}')
    w = warp(img, a, pr)
    feather = 10 / F
    sel = np.clip((az - edges[i]) / feather + 0.5, 0, 1) * np.clip((edges[i + 1] - az) / feather + 0.5, 0, 1)
    al = w[..., 3:] * sel[None, :, None]
    acc += w[..., :3] * al; acc_a += al
pano = pano * (1 - acc_a) + acc

oak = Image.open(f'{src}/library-oak-01.png').convert('RGBA')
oak = oak.crop(oak.getbbox())
oh = int(F * 20 / OAK[0]); ow = int(oak.width * oh / oak.height)
oak = np.asarray(oak.resize((ow, oh), Image.LANCZOS)).astype(np.float32) / 255
oak[..., 3] = np.clip((oak[..., 3] - 0.15) / 0.85, 0, 1)
foot = V0 + int(F * EYE / OAK[0]); cx = W // 2 + int(F * math.radians(OAK[1]))
y1, x1 = foot - oh, cx - ow // 2
al = oak[..., 3:]
pano[y1:foot, x1:x1 + ow] = pano[y1:foot, x1:x1 + ow] * (1 - al) + oak[..., :3] * al

Image.fromarray((np.clip(pano, 0, 1) * 255).astype(np.uint8)).save(f'{out}/park-panorama{TAG}.png')

# Through the windows, in perspective (straight lines stay straight), looking straight
# out: the inner face `back` m before the eye, the casement 0.8 m further (the wall's
# depth), the sill `over` m below the eye; openings 1.3 m (niche) and 1.1 m (glass),
# 2.5 m high with round tops; the windows' middles 3 m apart; 2 panes across, 4 up.
def opening(X, Y, d, over, cx, wid, bars):
    # The niche (no bars): 1.3 m, a shallow segmental arch over it, as style-01. The glass
    # (bars): a rectangular casement of two leaves, 2.35 m high; above the transom, at two
    # thirds of its height, small panes 3 across a leaf and 4 up; below, 2 large panes a leaf.
    s = d * X - cx
    h = d * Y + over
    r = wid / 2
    if not bars:
        return (np.abs(s) < r) & (h > 0) & (h < 2.4 + 0.25 * (1 - (s / r) ** 2))
    top = 2.35; tr = top * 2 / 3
    inside = (np.abs(s) < r) & (h > 0) & (h < top)
    b = 0.018
    bar = (np.abs(s) < b * 2.5) | (np.abs(np.abs(s) - r) < b * 2) | (np.abs(h - tr) < b * 1.8)
    bar = bar | ((h < tr) & (np.abs(h - tr / 2) < b))
    leaf = r - b * 2.5
    for k in (1, 2):
        bar = bar | ((h > tr) & (np.abs(np.abs(s) - b * 2.5 - k * leaf / 3) < b * 0.7))
    for k in (1, 2, 3):
        bar = bar | ((h > tr) & (np.abs(h - tr - k * (top - tr) / 4) < b * 0.7))
    return inside & ~bar

def sample(img, u, v):
    ui = np.clip(u, 0, img.shape[1] - 1).astype(int); vi = np.clip(v, 0, img.shape[0] - 1).astype(int)
    return img[vi, ui]

room = np.array([0.13, 0.11, 0.10], np.float32)
OW, OH = 1800, 1200
for name, back, over, hfov, pitch in (('table', 1.2, 0.4, 70.0, 0.25), ('room', 3.5, 0.8, 100.0, 0.12)):
    fp = OW / 2 / math.tan(math.radians(hfov) / 2)
    X = ((np.arange(OW) - OW / 2) / fp)[None, :] * np.ones((OH, 1))
    Y = ((OH / 2 - np.arange(OH)) / fp)[:, None] * np.ones((1, OW)) + pitch   # Y/Z, pitched up a little
    th = np.arctan(X)
    u = W / 2 + F * th
    v = V0 - F * Y / np.sqrt(X ** 2 + 1)
    vis = np.zeros((OH, OW), bool)
    for cx in (-3.0, 0.0, 3.0):
        vis |= opening(X, Y, back, over, cx, 1.3, False) & opening(X, Y, back + 0.8, over, cx, 1.1, True)
    view = np.where(vis[..., None], sample(pano, u, v), room)
    Image.fromarray((np.clip(view, 0, 1) * 255).astype(np.uint8)).save(f'{out}/park-windows-{name}{TAG}.png')
