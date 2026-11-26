# A Norway maple's bark tile grown by the fracture of a stretched outer layer, after
# Lefebvre and Neyret 2002 (cracks open where the cork is stretched past its strength,
# propagate along the stem, and old cracks widen), with the crack paths following a
# toughness field and bending into nearby cracks so ridges part and join (anastomosing).
#
# One growth run gives every age: each crack texel keeps the time it opened, and a
# snapshot at time t keeps only the cracks opened by then, each as wide and deep as its
# age. So a twig, a limb and the old trunk show the same network at different stages.
#
# The tile: W x H texels for TILE_W x TILE_H metres (today's 25 x 50 cm), wrapping both ways.
import numpy as np, time
from noise import wrapped, fbm, blur, chamfer, smoothstep

W, H = 256, 512
TILE_W, TILE_H = 0.25, 0.50
MM = TILE_W / W * 1000.0          # millimetres a texel (about 1)

# The growth's parameters (the maple preset). Time t runs 0 (a twig's bark) to 1 (an old
# trunk's); the cork starts to crack at T_CRACK.
P = dict(
    seed=7,
    steps=36,            # growth steps from T_CRACK to 1
    T_CRACK=0.42,        # the cork first cracks (about 7-8 cm wide wood)
    plate_end=20.0,      # widest plate at t=1, texels (mm): ridges 10-24 mm apart
    plate_exp=1.6,       # how fast plates subdivide: widest plate = plate_end * t^-exp
    strength_var=0.35,   # the cork's strength varies this much (noise)
    len_min=60, len_max=260,  # a crack's own run along the stem, texels (3-10 x spacing)
    attract=10,          # a crack within this many texels pulls the path toward it
    attract_p=0.8,       # how strongly it bends into it
    wander=0.35,
    slope=0.22,          # a crack's lean, texels across a row (diamonds come from leaning cracks meeting)
    slope_jitter=0.05,
    bridges=75,          # cuts across old ridges per step after t=0.75         # the path's side steps where the cork is equally weak
)

def toughness(seed):
    """The cork's strength: stretched noise (long along the stem), warped."""
    wu = (fbm(seed + 1, W, H, 4, 4, 3) - 0.5) * 30
    wv = (fbm(seed + 2, W, H, 4, 4, 3) - 0.5) * 30
    n = 0.6 * fbm(seed + 3, W, H, 24, 6, 3, (wu, wv)) + 0.4 * fbm(seed + 4, W, H, 64, 16, 2)
    return (n - n.min()) / (n.max() - n.min())

def grow(p=P):
    """Run the growth. Returns crack time (H x W, inf where uncracked) and the toughness."""
    rng = np.random.default_rng(p['seed'])
    tough = toughness(p['seed'])
    crack = np.full((H, W), np.inf)
    strength = 1.0 + p['strength_var'] * (fbm(p['seed'] + 9, W, H, 8, 4, 2) - 0.5) * 2
    xs = np.arange(W)
    for n in range(p['steps']):
        t = p['T_CRACK'] + (1 - p['T_CRACK']) * (n + 1) / p['steps']
        wc = p['plate_end'] * (t ** -p['plate_exp'])
        for attempt in range(400):
            # Plate width at each texel: distance to the crack left plus right, by row.
            c = np.isfinite(crack)
            left = run_dist(c, +1); right = run_dist(c, -1)
            width = left + right
            over = (width > wc * strength) & (np.minimum(left, right) > 0.3 * width) & ~c
            cand = np.flatnonzero(over)
            if len(cand) == 0:
                break
            # The weakest of a few random overstrained texels opens.
            pick = rng.choice(cand, size=min(12, len(cand)), replace=False)
            s = pick[np.argmin(tough.flat[pick])]
            y0, x0 = divmod(int(s), W)
            L = rng.integers(p['len_min'], p['len_max'])
            propagate(crack, tough, x0, y0, t, L, wc, strength, rng, p)
        if t > 0.75:
            bridges(crack, t, p['bridges'], rng, int(wc * 0.9))
    return crack, tough

def run_dist(c, dirn):
    """Per row, the distance (texels) to the nearest crack going one way, wrapping."""
    d = np.full(c.shape, W * 2.0)
    # three passes round the ring are enough to wrap
    cur = np.full(c.shape[0], W * 2.0)
    order = list(range(W)) if dirn > 0 else list(range(W - 1, -1, -1))
    for _ in range(2):
        for x in order:
            cur = np.where(c[:, x], 0.0, cur + 1)
            d[:, x] = np.minimum(d[:, x], cur)
    return d

def propagate(crack, tough, x0, y0, t, L, wc, strength, rng, p):
    """Open a crack at (x0, y0) and run it up and down the stem: each row it steps to the
    weakest of the three texels ahead, bends into a crack nearby, and stops on meeting one
    or when its run is spent and the cork there isn't overstrained."""
    crack[y0, x0] = t
    for dy in (1, -1):
        x, y = x0, y0
        fx = float(x0)                    # the path's exact place across
        slope = rng.normal(0, p['slope'])  # its lean: texels across a row (dir = a*slope + b*rnd)
        for k in range(H):
            y2 = (y + dy) % H
            row = crack[y2]
            # nearest crack in this row within reach pulls the path (Lefebvre and Neyret:
            # a crack near another follows it, so they interlace and join)
            pull = 0
            for r in range(1, p['attract'] + 1):
                if np.isfinite(row[(x + r) % W]): pull = r; break
                if np.isfinite(row[(x - r) % W]): pull = -r; break
            slope = slope * 0.97 + rng.normal(0, p['slope_jitter'])
            slope = float(np.clip(slope, -0.8, 0.8))
            step = slope
            if pull and rng.random() < p['attract_p']:
                step += 0.6 * np.sign(pull)
            # the weakest cork near where the lean takes it
            want = fx + step
            cands = [int(np.floor(want)) - 1, int(np.floor(want)), int(np.floor(want)) + 1]
            costs = [tough[y2, c % W] + abs(c - want) * 0.25 + rng.random() * p['wander'] * 0.3 for c in cands]
            nx = cands[int(np.argmin(costs))]
            fx = 0.6 * want + 0.4 * nx
            y = y2
            # fill across so the path stays connected row to row
            lo, hi = (x, nx) if nx >= x else (nx, x)
            met = False
            for xx in range(lo, hi + 1):
                if np.isfinite(crack[y, xx % W]) and xx != x:
                    met = True
            for xx in range(lo, hi + 1):
                crack[y, xx % W] = min(crack[y, xx % W], t)
            x = nx
            if met:
                break                       # joined another crack
            if k > L:
                rl = row_plate(crack[y], x % W)
                if rl < wc * strength[y, x % W] * 0.9:
                    break

def bridges(crack, t, n, rng, most):
    """Short cuts across old ridges, crack to crack (the strips between close cracks break
    again, so ridges become scales)."""
    ys, xs = np.nonzero(np.isfinite(crack) & (crack < t))
    for _ in range(n):
        k = rng.integers(len(ys)); y, x = int(ys[k]), int(xs[k])
        d = 1 if rng.random() < 0.5 else -1
        lean = rng.normal(0, 0.25)
        path = []; fy = float(y)
        for s in range(1, most):
            xx = (x + d * s) % W; fy += lean; yy = int(round(fy)) % H
            if np.isfinite(crack[yy, xx]):
                if s > 2:
                    for (a, b) in path: crack[a, b] = t
                break
            path.append((yy, xx))

def row_plate(row, x):
    c = np.isfinite(row)
    l = r = 0
    while l < W and not c[(x - l - 1) % W]: l += 1
    while r < W and not c[(x + r + 1) % W]: r += 1
    return l + r

# --- A snapshot at time t: height (mm), albedo, cavity ---------------------------------

S = dict(
    relief_mm=9.0,       # furrow depth at t=1 for the oldest cracks
    width_young=1.2,     # a new crack's half width, texels
    width_old=3.6,       # widening of the oldest cracks by t=1, texels
    crown=0.5,          # how rounded a ridge's crown is, share of the relief
    breaks=0.5,          # transverse breaks across old ridges (scaling)
    micro_mm=0.5,        # cork granules
)

def snapshot(crack, tough, t, s=S, seed=11):
    vis = crack <= t
    age = np.where(vis, t - crack, 0.0)            # how long each crack has been open
    cork = smoothstep(P['T_CRACK'] - 0.05, 1.0, t) # the cork's thickness: relief grows with it
    if vis.any():
        d, a = chamfer(vis, age, iters=60)
    else:
        d = np.full(crack.shape, 99.0); a = np.zeros(crack.shape)
    old = np.clip(a / (1 - P['T_CRACK']), 0, 1)
    hw = s['width_young'] + s['width_old'] * old ** 0.8      # half width of nearest furrow
    depth = s['relief_mm'] * cork * (0.35 + 0.65 * old ** 0.6)
    # The ridge's profile: steep shoulders into a narrow furrow, a rounded crown.
    sdist = d / hw
    shoulder = smoothstep(0.0, 1.0, sdist) ** 0.6
    crown = np.clip((d - hw) / (P['plate_end'] * 0.5), 0, 1)
    hgt = -depth * (1 - shoulder) + depth * s['crown'] * (1 - (1 - crown) ** 2)
    # Macro and micro relief.
    macro = (fbm(seed + 1, W, H, 3, 2, 2) - 0.5) * 3.0 * cork
    micro = (fbm(seed + 2, W, H, 64, 64, 3) - 0.5) * 2 * s['micro_mm'] * (0.3 + cork)
    hgt = hgt + macro + micro
    # Young bark: smooth, fine streaks along, lenticels (short dashes across, raised).
    young = 1 - smoothstep(P['T_CRACK'] - 0.1, P['T_CRACK'] + 0.15, t)
    if young > 0:
        streak = (fbm(seed + 3, W, H, 48, 6, 2) - 0.5) * 0.5
        hgt = hgt + young * (streak + lenticels(seed) * 0.5)
    hgt = blur(hgt, 1)
    # Cavity: how far below its surroundings a texel sits, at three radii.
    cav = np.zeros_like(hgt)
    for r, wgt in ((2, 0.5), (5, 0.35), (10, 0.15)):
        cav += wgt * np.maximum(blur(hgt, r) - hgt, 0)
    ao = np.clip(1 - cav / 2.6, 0.1, 1)
    # Albedo: weathered grey crowns, browner furrows, blotches; young bark olive-grey.
    blot = fbm(seed + 4, W, H, 6, 6, 3)
    crownmask = smoothstep(-0.3 * S['relief_mm'], 0.3 * S['relief_mm'], hgt)
    grey = np.array([0.20, 0.195, 0.18]); brown = np.array([0.05, 0.042, 0.036])
    youngc = np.array([0.20, 0.19, 0.16])
    alb = brown[None, None] + (grey - brown)[None, None] * crownmask[..., None]
    alb = alb * (0.85 + 0.3 * blot[..., None])
    alb = alb * (1 - young) + youngc * young * (0.9 + 0.2 * blot[..., None])
    return hgt, alb, ao

def lenticels(seed):
    rng = np.random.default_rng(seed + 77)
    m = np.zeros((H, W))
    for _ in range(260):
        x, y = rng.integers(W), rng.integers(H)
        l = rng.integers(2, 5)
        for dx in range(-l, l + 1):
            m[y, (x + dx) % W] = 1; m[(y + 1) % H, (x + dx) % W] = 0.5
    return blur(m, 1)

def normals(hgt, strength=1.0):
    """Tangent-space normal (x round, y along, z out) from height in mm, physical slopes."""
    dx = (np.roll(hgt, -1, 1) - np.roll(hgt, 1, 1)) / (2 * MM)
    dy = (np.roll(hgt, -1, 0) - np.roll(hgt, 1, 0)) / (2 * MM)
    n = np.stack([-dx * strength, -dy * strength, np.ones_like(hgt)], -1)
    return n / np.linalg.norm(n, axis=-1, keepdims=True)

if __name__ == '__main__':
    import sys
    from PIL import Image
    out = sys.argv[1] if len(sys.argv) > 1 else '../img'
    t0 = time.time(); crack, tough = grow(); t1 = time.time()
    print('grow %.1f s, cracks %d texels' % (t1 - t0, np.isfinite(crack).sum()))
    np.save(out + '/crack.npy', crack); np.save(out + '/tough.npy', tough)
