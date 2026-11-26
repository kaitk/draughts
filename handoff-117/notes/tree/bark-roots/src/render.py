# A CPU stand-in for TREE_WOOD_FRAG: a vertical tube seen from the front, its bark sampled
# from mip pyramids with trilinear filtering (as the GPU does), lit by a sky and a low sun.
# Variants: today's shading; the new tile with normal + cavity + the AO microshadow
# (standard tier); and the new tile with a parallax self-shadow march (high tier).
import numpy as np

TILE_W, TILE_H = 0.25, 0.50

def pyramid(a):
    """Mips of a (H, W, C) map, 2x2 box averages as tree_mesh's halve does."""
    out = [a]
    while out[-1].shape[0] > 1 and out[-1].shape[1] > 1:
        m = out[-1]
        out.append(0.25 * (m[0::2, 0::2] + m[1::2, 0::2] + m[0::2, 1::2] + m[1::2, 1::2]))
    return out

def bilinear(m, u, v):
    """m (h, w, C), u, v in tile units (wrapping), returns (..., C)."""
    h, w = m.shape[:2]
    x = u * w - 0.5; y = v * h - 0.5
    i = np.floor(x).astype(int); j = np.floor(y).astype(int)
    fx = (x - i)[..., None]; fy = (y - j)[..., None]
    i0 = i % w; i1 = (i + 1) % w; j0 = j % h; j1 = (j + 1) % h
    return ((m[j0, i0] * (1 - fx) + m[j0, i1] * fx) * (1 - fy) +
            (m[j1, i0] * (1 - fx) + m[j1, i1] * fx) * fy)

def trilinear(pyr, u, v, lod):
    lod = np.clip(np.nan_to_num(lod, nan=0.0, posinf=20.0, neginf=0.0), 0, len(pyr) - 1.001)
    out = np.zeros(u.shape + (pyr[0].shape[2],))
    l0 = np.floor(lod).astype(int); f = (lod - l0)[..., None]
    for L in np.unique(l0):
        k = l0 == L
        a = bilinear(pyr[L], u[k], v[k]); b = bilinear(pyr[L + 1], u[k], v[k])
        out[k] = a * (1 - f[k]) + b * f[k]
    return out

def maps_new(h_mm, alb, ao, normal):
    """Pack the new tile's maps: tangent normal xyz, height (mm), ao, albedo rgb."""
    return pyramid(np.concatenate([normal, h_mm[..., None], ao[..., None], alb], -1))

def maps_today(t):
    """Today's tile (today.tile()): the shader's n0 + round*(r*2-1) + along*(g*2-1)."""
    n = np.stack([t[..., 0] * 2 - 1, t[..., 1] * 2 - 1, np.ones(t.shape[:2])], -1)
    BARK = np.array([0.16, 0.14, 0.12]); LICHEN = np.array([0.2, 0.23, 0.15])
    b = t[..., 2:3]; a = t[..., 3:4]
    alb = BARK * b * (1 - a * 0.7) + LICHEN * (0.6 + 0.4 * b) * a * 0.7
    alb = alb / 0.16 * 0.28          # today's BARK scaled to the same mean brightness
    return pyramid(np.concatenate([n, np.zeros(t.shape[:2] + (1,)), np.ones(t.shape[:2] + (1,)), alb], -1))

def cylinder(pyr, R, ppm, height_m, light, mode='std', sky=0.55, sun=2.2, exposure=1.6,
             tiles_round=None, aniso=8, shadow_mm=None, bg=(0.10, 0.11, 0.12)):
    """A tube of radius R metres, height_m tall, ppm pixels a metre, seen from the front
    (orthographic), x right, y up, z toward the eye. light: unit vector in that frame.
    mode: 'today' (n0 + offsets, no ao), 'flat' (normal only), 'std' (normal, cavity,
    microshadow), 'high' (std plus parallax self-shadow)."""
    w = int(2 * R * ppm * 1.15) + 8; hgt = int(height_m * ppm)
    xs = (np.arange(w) - w / 2 + 0.5) / ppm
    ys = (np.arange(hgt)[::-1] + 0.5) / ppm
    X, Y = np.meshgrid(xs, ys)
    inside = np.abs(X) < R
    s = np.clip(X / R, -0.999, 0.999)
    th = np.arcsin(s)
    n0 = np.stack([np.sin(th), np.zeros_like(th), np.cos(th)], -1)
    rnd = np.stack([np.cos(th), np.zeros_like(th), -np.sin(th)], -1)
    along = np.array([0.0, 1.0, 0.0])
    # The tile round the tube in whole repeats, as tree_mesh's `rounds`.
    rounds = tiles_round or max(np.floor(2 * np.pi * R / TILE_W + 0.5), 1)
    u = (th / (2 * np.pi)) * rounds + 0.37
    v = Y / TILE_H
    # Footprint in texels per pixel along both axes, then the GPU's anisotropic choice.
    W = pyr[0].shape[1]; H = pyr[0].shape[0]
    du = rounds * W / (2 * np.pi * R) / (ppm * np.maximum(np.cos(th), 0.05))
    dv = H / TILE_H / ppm
    mx = np.maximum(du, dv); mn = np.minimum(du, dv)
    lod = np.log2(np.maximum(mx / np.minimum(mx / mn, aniso), 1e-6))
    lod = np.maximum(lod, 0)
    smp = trilinear(pyr, u[inside], v[inside], lod[inside])
    nt = smp[:, 0:3]; hh = smp[:, 3]; ao = smp[:, 4]; alb = smp[:, 5:8]
    N0 = n0[inside]; RD = rnd[inside]
    n = nt[:, 0:1] * RD + nt[:, 1:2] * along[None] + nt[:, 2:3] * N0
    n /= np.linalg.norm(n, axis=1, keepdims=True)
    ndl = n @ light
    geo = N0 @ light
    if mode in ('today', 'flat'):
        ao = np.ones_like(ao) if mode == 'today' else ao * 0 + 1
        vis = (ndl > 0) * (geo > -0.1)
        direct = np.maximum(ndl, 0) * vis
    else:
        # The microshadow from the AO (Brinck and Maximov 2016): saturate(|n.l| + 2 ao^2 - 1).
        ms = np.clip(np.abs(ndl) + 2 * ao * ao - 1, 0, 1)
        direct = np.maximum(ndl, 0) * ms * (geo > -0.1)
        if mode == 'high':
            direct *= parallax_shadow(pyr, u[inside], v[inside], lod[inside], light, RD, N0, along, R, rounds)
    up = 0.5 + 0.5 * n[:, 1]
    c = alb * (sky * ao * (0.55 + 0.45 * up))[:, None] + alb * (sun * direct)[:, None]
    img = np.zeros((hgt, w, 3)) + np.array(bg)
    img[inside] = 1 - np.exp(-c * exposure)
    return np.clip(img, 0, 1) ** (1 / 2.2)

def parallax_shadow(pyr, u, v, lod, light, RD, N0, along, R, rounds, steps=24, reach_mm=24.0):
    """March the height field from each texel toward the light in the tangent plane; a
    texel is in shadow where the field rises over the ray (soft: by how far)."""
    W = pyr[0].shape[1]; H = pyr[0].shape[0]
    lt = np.stack([RD @ light, np.full(len(u), light @ along), N0 @ light], -1)
    lt[:, 2] = np.maximum(lt[:, 2], 0.02)
    horiz = np.linalg.norm(lt[:, :2], axis=1) + 1e-6
    dirx = lt[:, 0] / horiz; diry = lt[:, 1] / horiz
    slope = lt[:, 2] / horiz                      # mm risen per mm travelled
    h0 = trilinear(pyr, u, v, lod)[:, 3]
    shade = np.ones(len(u))
    tile_mm_u = 2 * np.pi * R * 1000 / rounds     # mm a tile round
    for k in range(1, steps + 1):
        d = reach_mm * k / steps
        uu = u + dirx * d / tile_mm_u
        vv = v + diry * d / (TILE_H * 1000)
        hk = trilinear(pyr, uu, vv, lod)[:, 3]
        over = hk - (h0 + slope * d)
        shade = np.minimum(shade, np.clip(1 - over / 1.5, 0, 1))
    return 0.25 + 0.75 * shade
