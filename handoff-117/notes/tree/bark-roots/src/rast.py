# A small z-buffer rasterizer (a visibility buffer: triangle id and barycentrics a pixel),
# then deferred shading of the bark from the tile's age layers, as TREE_WOOD_FRAG would.
import math, numpy as np
from render import trilinear

class Cam:
    def __init__(self, eye, at, fov_deg, w, h):
        self.eye = np.asarray(eye, float); at = np.asarray(at, float)
        f = at - self.eye; f /= np.linalg.norm(f)
        r = np.cross(f, [0, 1.0, 0]); r /= np.linalg.norm(r)
        u = np.cross(r, f)
        self.f, self.r, self.u = f, r, u
        self.w, self.h = w, h
        self.foc = (h / 2) / math.tan(math.radians(fov_deg) / 2)

    def project(self, p):
        d = p - self.eye
        z = d @ self.f; x = d @ self.r; y = d @ self.u
        sx = self.w / 2 + self.foc * x / np.maximum(z, 1e-4)
        sy = self.h / 2 - self.foc * y / np.maximum(z, 1e-4)
        return np.stack([sx, sy, z], -1)

def raster(cam, pos, idx):
    """Returns tri id (h, w) (-1 empty), barycentrics (h, w, 3), depth."""
    P = cam.project(pos)
    W, H = cam.w, cam.h
    zb = np.full((H, W), np.inf); tid = np.full((H, W), -1, np.int64); bc = np.zeros((H, W, 3))
    tri = P[idx]                                  # (T, 3, 3)
    ok = (tri[:, :, 2] > 0.05).all(1)
    x0 = np.clip(np.floor(tri[:, :, 0].min(1)), 0, W - 1).astype(int)
    x1 = np.clip(np.ceil(tri[:, :, 0].max(1)), 0, W - 1).astype(int)
    y0 = np.clip(np.floor(tri[:, :, 1].min(1)), 0, H - 1).astype(int)
    y1 = np.clip(np.ceil(tri[:, :, 1].max(1)), 0, H - 1).astype(int)
    vis = ok & (x1 >= x0) & (y1 >= y0) & (tri[:, :, 0].max(1) >= 0) & (tri[:, :, 0].min(1) < W) \
          & (tri[:, :, 1].max(1) >= 0) & (tri[:, :, 1].min(1) < H)
    for t in np.nonzero(vis)[0]:
        (ax, ay, az), (bx, by, bz), (cx, cy, cz) = tri[t]
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-9: continue
        xs = np.arange(x0[t], x1[t] + 1) + 0.5; ys = np.arange(y0[t], y1[t] + 1) + 0.5
        X, Y = np.meshgrid(xs, ys)
        l0 = ((by - cy) * (X - cx) + (cx - bx) * (Y - cy)) / den
        l1 = ((cy - ay) * (X - cx) + (ax - cx) * (Y - cy)) / den
        l2 = 1 - l0 - l1
        inside = (l0 >= -1e-6) & (l1 >= -1e-6) & (l2 >= -1e-6)
        if not inside.any(): continue
        # perspective-correct: interpolate 1/z
        iz = l0 / az + l1 / bz + l2 / cz
        z = 1 / iz
        sub = zb[y0[t]:y1[t] + 1, x0[t]:x1[t] + 1]
        win = inside & (z < sub)
        if not win.any(): continue
        sub[win] = z[win]
        tid[y0[t]:y1[t] + 1, x0[t]:x1[t] + 1][win] = t
        b = np.stack([l0 / az * z, l1 / bz * z, l2 / cz * z], -1)
        bc[y0[t]:y1[t] + 1, x0[t]:x1[t] + 1][win] = b[win]
    return tid, bc, zb

def interp(attr, idx, tid, bc):
    m = tid >= 0
    a = attr[idx[tid[m]]]                         # (N, 3, C)
    return m, (a * bc[m][:, :, None]).sum(1)

def shade(cam, mesh, tid, bc, zb, layers, layer_t, light, sky=0.55, sun=2.2, exposure=1.25,
          mode='std', ground=(0.10, 0.13, 0.07), bg=(0.62, 0.66, 0.70), grain=False):
    """mesh: dict pos, nrm, along, uv, uv2, w2, age, kind (0 wood, 1 ground), idx.
    layers: list of tile pyramids at ages layer_t (ascending)."""
    H, W = tid.shape
    img = np.zeros((H, W, 3)) + np.array(bg) ** 2.2
    m, pos = interp(mesh['pos'], mesh['idx'], tid, bc)
    if not m.any(): return np.clip(img, 0, 1) ** (1 / 2.2)
    _, n0 = interp(mesh['nrm'], mesh['idx'], tid, bc)
    _, alg = interp(mesh['along'], mesh['idx'], tid, bc)
    _, uv = interp(mesh['uv'], mesh['idx'], tid, bc)
    _, uv2 = interp(mesh['uv2'], mesh['idx'], tid, bc)
    _, w2 = interp(mesh['w2'][:, None], mesh['idx'], tid, bc)
    _, age = interp(mesh['age'][:, None], mesh['idx'], tid, bc)
    _, kind = interp(mesh['kind'][:, None], mesh['idx'], tid, bc)
    n0 /= np.linalg.norm(n0, axis=1, keepdims=True)
    alg = alg - n0 * (alg * n0).sum(1, keepdims=True); alg /= np.linalg.norm(alg, axis=1, keepdims=True) + 1e-9
    rnd = np.cross(alg, n0)
    v = cam.eye - pos; dist = np.linalg.norm(v, axis=1); v /= dist[:, None]
    pix_m = dist / cam.foc
    # the mip from the uv's change between pixels (as the GPU's derivatives), anisotropic 8x
    U = np.full((H, W, 2), np.nan); U[m] = uv
    def dd(a, ax):
        f = np.roll(a, -1, ax) - a; b = a - np.roll(a, 1, ax)
        f = np.where(np.isnan(f), b, f); b = np.where(np.isnan(b), f, b)
        return np.where((np.abs(f) < np.abs(b)), f, b)
    tex = np.array([256.0, 512.0])
    lx = np.linalg.norm(np.nan_to_num(dd(U, 1)) * tex, axis=-1)[m]
    ly = np.linalg.norm(np.nan_to_num(dd(U, 0)) * tex, axis=-1)[m]
    mx = np.maximum(lx, ly); mn = np.maximum(np.minimum(lx, ly), 1e-6)
    lod = np.log2(np.maximum(mx / np.minimum(mx / mn, 8), 1e-6))
    age = age[:, 0]; w2 = np.clip(w2[:, 0], 0, 1); kind = kind[:, 0]
    def sample(u):
        # the two age layers either side, blended
        out = None
        li = np.clip(np.searchsorted(layer_t, age) - 1, 0, len(layer_t) - 2)
        f = np.clip((age - np.array(layer_t)[li]) / (np.array(layer_t)[li + 1] - np.array(layer_t)[li]), 0, 1)
        out = np.zeros((len(age), layers[0][0].shape[2]))
        for L in np.unique(li):
            k = li == L
            a = trilinear(layers[L], u[k, 0], u[k, 1], lod[k]); b = trilinear(layers[L + 1], u[k, 0], u[k, 1], lod[k])
            out[k] = a * (1 - f[k, None]) + b * f[k, None]
        return out
    sA = sample(uv)
    sB = sample(uv2) if (w2 > 0.001).any() else sA
    # blend the two charts by height: the higher ridge wins over a narrow band
    hA = sA[:, 3]; hB = sB[:, 3]
    bw = np.clip(0.5 + (hB - hA) * 0.15 + (w2 - 0.5) * 2.2, 0, 1) * (w2 > 0.001)
    bw = np.where(w2 >= 0.999, 1.0, bw)
    s = sA * (1 - bw[:, None]) + sB * bw[:, None]
    nt = s[:, 0:3]; ao = s[:, 4]; alb = s[:, 5:8]
    n = nt[:, 0:1] * rnd + nt[:, 1:2] * alg + nt[:, 2:3] * n0
    n /= np.linalg.norm(n, axis=1, keepdims=True)
    if mode == 'plain':
        n = n0; ao = np.ones_like(ao); alb = np.tile([0.16, 0.14, 0.12], (len(n), 1)) * 1.6
    if grain:
        # grain lines: the bark's round coordinate as stripes, to show the flow
        g = 0.5 + 0.5 * np.cos(2 * math.pi * (uv[:, 0] * 8))
        g2 = 0.5 + 0.5 * np.cos(2 * math.pi * (uv2[:, 0] * 8))
        gg = g * (1 - w2) + g2 * w2
        alb = np.stack([0.12 + 0.25 * gg, 0.10 + 0.12 * gg, 0.08 + 0.05 * (1 - gg)], -1)
        n = n0; ao = np.ones_like(ao)
    gr = kind > 0.5
    alb[gr] = np.array(ground) * (0.8 + 0.4 * (np.sin(pos[gr, 0] * 7) * np.sin(pos[gr, 2] * 9) * 0.5 + 0.5))[:, None]
    n[gr] = n0[gr]; ao[gr] = 1
    ndl = n @ light
    ms = np.clip(np.abs(ndl) + 2 * ao * ao - 1, 0, 1)
    direct = np.maximum(ndl, 0) * ms * ((n0 @ light) > -0.1)
    # the ground in the trunk's shadow: none here (the renderer's own shadows do that)
    up = 0.5 + 0.5 * n[:, 1]
    c = alb * (sky * ao * (0.55 + 0.45 * up))[:, None] + alb * (sun * direct)[:, None]
    img[m] = 1 - np.exp(-c * exposure)
    return np.clip(img, 0, 1) ** (1 / 2.2)

def wire(im, cam, pos, idx, zb, color=(255, 200, 80), max_edges=200000):
    """Draw the triangles' edges whose middle is not hidden."""
    from PIL import ImageDraw
    d = ImageDraw.Draw(im)
    P = cam.project(pos)
    e = np.vstack([idx[:, [0, 1]], idx[:, [1, 2]], idx[:, [2, 0]]])
    e = np.unique(np.sort(e, 1), axis=0)[:max_edges]
    a, b = P[e[:, 0]], P[e[:, 1]]
    mid = (a + b) / 2
    H, W = zb.shape
    ok = (mid[:, 0] >= 0) & (mid[:, 0] < W) & (mid[:, 1] >= 0) & (mid[:, 1] < H) & (a[:, 2] > 0) & (b[:, 2] > 0)
    xi = np.clip(mid[:, 0].astype(int), 0, W - 1); yi = np.clip(mid[:, 1].astype(int), 0, H - 1)
    ok &= mid[:, 2] <= zb[yi, xi] * 1.01 + 0.002
    for (ax, ay, _), (bx, by, _) in zip(a[ok], b[ok]):
        d.line([(ax, ay), (bx, by)], fill=color, width=1)
    return im
