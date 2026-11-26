# Step three's wood on the CPU: tools/tree_dump's wood.bin (shaped) and wood-plain.bin
# (today's tubes) rasterized and shaded as TREE_WOOD_FRAG shades them, the bark from the age
# layers (tile.py). Views: the flare and roots, a limb's collar on the trunk, a branch's fork
# on a limb, each new and today, wireframe, and the grain's lines.
#   python scene.py DUMP_DIR PHOTO_DIR OUT_DIR
import sys, math, struct, numpy as np
from PIL import Image, ImageDraw
import tile

M = 30.48

def load_wood(path):
    a = np.fromfile(path, np.float32)
    n = int(a[0]); v = a[1:1 + n * 15].reshape(n, 15)
    k = int(a[1 + n * 15]); idx = a[2 + n * 15:2 + n * 15 + k].astype(np.int64).reshape(-1, 3)
    return dict(pos=v[:, 0:3].astype(float), nrm=v[:, 3:6].astype(float), along=v[:, 6:9].astype(float),
                uv=v[:, 9:11].astype(float), light=v[:, 11:15].astype(float), idx=idx)

def load_tree(path):
    a = np.fromfile(path, np.float32); o = 0
    n = int(a[o]); o += 1; seg = a[o:o + n * 9].reshape(n, 9); o += n * 9
    m = int(a[o]); o += 1; limbs = a[o:o + m * 4].reshape(m, 4).astype(int)
    return seg, limbs

class Cam:
    def __init__(self, eye, at, fov_deg, w, h):
        self.eye = np.asarray(eye, float); at = np.asarray(at, float)
        f = at - self.eye; f /= np.linalg.norm(f)
        r = np.cross(f, [0, 1.0, 0]); r /= np.linalg.norm(r)
        self.f, self.r, self.u = f, r, np.cross(r, f)
        self.w, self.h = w, h
        self.foc = (h / 2) / math.tan(math.radians(fov_deg) / 2)
    def project(self, p):
        d = p - self.eye
        z = d @ self.f; x = d @ self.r; y = d @ self.u
        return np.stack([self.w / 2 + self.foc * x / np.maximum(z, 1e-4), self.h / 2 - self.foc * y / np.maximum(z, 1e-4), z], -1)

def raster(cam, pos, idx):
    P = cam.project(pos)
    W, H = cam.w, cam.h
    zb = np.full((H, W), np.inf); tid = np.full((H, W), -1, np.int64); bc = np.zeros((H, W, 3))
    tri = P[idx]
    ok = (tri[:, :, 2] > 0.05).all(1)
    x0 = np.clip(np.floor(tri[:, :, 0].min(1)), 0, W - 1).astype(int); x1 = np.clip(np.ceil(tri[:, :, 0].max(1)), 0, W - 1).astype(int)
    y0 = np.clip(np.floor(tri[:, :, 1].min(1)), 0, H - 1).astype(int); y1 = np.clip(np.ceil(tri[:, :, 1].max(1)), 0, H - 1).astype(int)
    vis = ok & (tri[:, :, 0].max(1) >= 0) & (tri[:, :, 0].min(1) < W) & (tri[:, :, 1].max(1) >= 0) & (tri[:, :, 1].min(1) < H)
    for t in np.nonzero(vis)[0]:
        (ax, ay, az), (bx, by, bz), (cx, cy, cz) = tri[t]
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-9: continue
        X, Y = np.meshgrid(np.arange(x0[t], x1[t] + 1) + 0.5, np.arange(y0[t], y1[t] + 1) + 0.5)
        l0 = ((by - cy) * (X - cx) + (cx - bx) * (Y - cy)) / den
        l1 = ((cy - ay) * (X - cx) + (ax - cx) * (Y - cy)) / den
        l2 = 1 - l0 - l1
        inside = (l0 >= -1e-6) & (l1 >= -1e-6) & (l2 >= -1e-6)
        if not inside.any(): continue
        z = 1 / (l0 / az + l1 / bz + l2 / cz)
        sub = zb[y0[t]:y1[t] + 1, x0[t]:x1[t] + 1]
        win = inside & (z < sub)
        if not win.any(): continue
        sub[win] = z[win]
        tid[y0[t]:y1[t] + 1, x0[t]:x1[t] + 1][win] = t
        bc[y0[t]:y1[t] + 1, x0[t]:x1[t] + 1][win] = np.stack([l0 / az * z, l1 / bz * z, l2 / cz * z], -1)[win]
    return tid, bc, zb

def near(mesh, centre, radius):
    """Only the triangles near a point, for speed."""
    p = mesh['pos'][mesh['idx']].mean(1)
    keep = np.linalg.norm(p - centre, axis=1) < radius
    return dict(mesh, idx=mesh['idx'][keep])

def with_ground(mesh, y, centre, size):
    """A lawn quad at height y under the scene (its own vertices, kind 1)."""
    c = np.asarray(centre, float)
    g = 24
    xs = np.linspace(c[0] - size, c[0] + size, g + 1); zs = np.linspace(c[2] - size, c[2] + size, g + 1)
    X, Z = np.meshgrid(xs, zs)
    q = np.stack([X.ravel(), np.full(X.size, y), Z.ravel()], -1)
    n = len(mesh['pos']); k = len(q)
    tris = []
    for j in range(g):
        for i in range(g):
            a = n + j * (g + 1) + i
            tris += [[a, a + g + 1, a + 1], [a + 1, a + g + 1, a + g + 2]]
    out = {key: np.concatenate([mesh[key], v]) for key, v in [('pos', q), ('nrm', np.tile([0, 1.0, 0], (k, 1))), ('along', np.tile([1.0, 0, 0], (k, 1))),
                                                            ('uv', np.zeros((k, 2))), ('light', np.tile([1, 1, -1, 0], (k, 1)))]}
    out['idx'] = np.concatenate([mesh['idx'], np.array(tris)])
    return out

def render(cam, mesh, light, mode='bark', wrap=0.0, rough=0.0, bg=(0.62, 0.66, 0.70)):
    tid, bc, zb = raster(cam, mesh['pos'], mesh['idx'])
    H, W = tid.shape
    img = np.zeros((H, W, 3)) + np.array(bg)
    m = tid >= 0
    if not m.any(): return img, zb
    def it(a):
        return (a[mesh['idx'][tid[m]]] * bc[m][:, :, None]).sum(1)
    pos = it(mesh['pos']); n0 = it(mesh['nrm']); alg = it(mesh['along']); uv = it(mesh['uv']); lt = it(mesh['light'])
    n0 /= np.linalg.norm(n0, axis=1, keepdims=True) + 1e-12
    alg = alg - n0 * (alg * n0).sum(1, keepdims=True); alg /= np.linalg.norm(alg, axis=1, keepdims=True) + 1e-9
    rw = np.cross(alg, n0)
    U = np.full((H, W, 2), np.nan); U[m] = uv
    def dd(a, ax):
        f = np.roll(a, -1, ax) - a; b = a - np.roll(a, 1, ax)
        f = np.where(np.isnan(f), b, f); b = np.where(np.isnan(b), f, b)
        return np.where(np.abs(f) < np.abs(b), f, b)
    gx = np.nan_to_num(dd(U, 1))[m]; gy = np.nan_to_num(dd(U, 0))[m]
    du = np.abs(gx[:, 0]) + np.abs(gy[:, 0]); dv = np.abs(gx[:, 1]) + np.abs(gy[:, 1])
    radius = lt[:, 2] / M
    age = np.clip(np.log(np.maximum(radius, 1e-5) / 0.004) / np.log(0.45 / 0.004), 0, 1)
    view = cam.eye - pos; view /= np.linalg.norm(view, axis=1, keepdims=True)
    ground = lt[:, 2] < 0
    if mode == 'grain':
        g = 0.5 + 0.5 * np.cos(2 * math.pi * uv[:, 0] * 6)
        alb = np.stack([0.10 + 0.3 * g, 0.08 + 0.14 * g, 0.06 + 0.04 * (1 - g)], -1)
        c = alb * (0.5 + 1.5 * np.maximum(n0 @ light, 0))[:, None]
    elif mode == 'plain':
        nn = n0
        c = np.array([0.16, 0.14, 0.12]) * (tile.GROUND + (tile.SKY - tile.GROUND) * (0.5 + 0.5 * nn[:, 1:2])) * lt[:, 1:2] \
            + np.array([0.16, 0.14, 0.12]) * (2.5 * np.maximum(nn @ light, 0) * lt[:, 0])[:, None]
    else:
        c = tile.shade(uv[:, 0], uv[:, 1], du, dv, n0, alg, rw, age, light, sun=2.5 * lt[:, 0], sky=lt[:, 1], wrap=wrap, rough=rough, view=view)
    gr = np.array([0.07, 0.1, 0.045]) * (0.85 + 0.3 * np.sin(pos[:, 0] * 0.7) * np.sin(pos[:, 2] * 0.9))[:, None]
    c[ground] = (gr[ground] * (0.6 + 2.0 * max(light[1], 0)))
    out = img.copy(); out[m] = tile.tonemap(c)
    return np.clip(out, 0, 1), zb

def wire(im, cam, mesh, zb, color=(255, 200, 80)):
    d = ImageDraw.Draw(im)
    P = cam.project(mesh['pos']); idx = mesh['idx']
    e = np.unique(np.sort(np.vstack([idx[:, [0, 1]], idx[:, [1, 2]], idx[:, [2, 0]]]), 1), axis=0)
    a, b = P[e[:, 0]], P[e[:, 1]]; mid = (a + b) / 2
    H, W = zb.shape
    ok = (mid[:, 0] >= 0) & (mid[:, 0] < W) & (mid[:, 1] >= 0) & (mid[:, 1] < H) & (a[:, 2] > 0) & (b[:, 2] > 0)
    xi = np.clip(mid[:, 0].astype(int), 0, W - 1); yi = np.clip(mid[:, 1].astype(int), 0, H - 1)
    ok &= mid[:, 2] <= zb[yi, xi] * 1.002 + 0.05
    for (ax, ay, _), (bx, by, _) in zip(a[ok], b[ok]): d.line([(ax, ay), (bx, by)], fill=color, width=1)
    return im

def unit(v): v = np.asarray(v, float); return v / np.linalg.norm(v)

def views(dump, out, tag, wrap=0.0, rough=0.0):
    new = load_wood(dump + '/wood.bin'); old = load_wood(dump + '/wood-plain.bin')
    seg, limbs = load_tree(dump + '/tree-none-culled.bin')
    foot = seg[limbs[0, 0], 0:3].astype(float)
    sun = unit([0.9, 0.35, -0.3])
    shots = []
    # The flare: the trunk's base from about 3 m, the sun from the side.
    eye = foot + np.array([-60.0, 45.0, -80.0]); at = foot + np.array([0, 12.0, 0])
    cam = Cam(eye, at, 40, 700, 520)
    for name, mesh in [('new', new), ('today', old)]:
        mm = with_ground(near(mesh, foot, 120), foot[1] + 0.01, foot, 400)
        im, zb = render(cam, mm, sun, wrap=wrap, rough=rough)
        shots.append(('flare-' + name, tile.img(im)))
        if name == 'new':
            im2, zb2 = render(cam, mm, sun, mode='grain')
            shots.append(('flare-grain', tile.img(im2)))
            shots.append(('flare-wire', wire(tile.img(im), cam, near(mesh, foot, 120), zb)))
    # Far: about 7 m.
    cam = Cam(foot + np.array([-150.0, 90.0, -180.0]), foot + np.array([0, 25.0, 0]), 32, 700, 520)
    mm = with_ground(near(new, foot, 250), foot[1] + 0.01, foot, 600)
    shots.append(('flare-far', tile.img(render(cam, mm, sun, wrap=wrap, rough=rough)[0])))
    # A limb's collar on the trunk: the lowest limb.
    kids = [k for k in range(len(limbs)) if limbs[k, 2] == 1 and limbs[k, 3] == 0]
    kids.sort(key=lambda k: seg[limbs[k, 0], 1])
    for kname, k in [('collar', kids[0])]:
        a = seg[limbs[k, 0], 0:3].astype(float); b = seg[limbs[k, 0], 3:6].astype(float)
        d = unit(b - a); rc = seg[limbs[k, 0], 6]
        tr = [i for i in range(limbs[0, 0], limbs[0, 0] + limbs[0, 1]) if seg[i, 4] >= a[1]]
        rp = seg[tr[0], 6] if tr else rc * 2
        centre = a + d * (rp * 1.1)
        side = unit(np.cross(d, [0, 1.0, 0]))
        eye = centre + side * rp * 4.5 + np.array([0, rp * 1.2, 0]) - d * rp * 0.8
        cam = Cam(eye, centre, 50, 700, 520)
        for name, mesh in [('new', new), ('today', old)]:
            mm = near(mesh, centre, rp * 6)
            im, zb = render(cam, mm, sun, wrap=wrap, rough=rough)
            shots.append((kname + '-' + name, tile.img(im)))
            if name == 'new':
                shots.append((kname + '-grain', tile.img(render(cam, mm, sun, mode='grain')[0])))
                shots.append((kname + '-wire', wire(tile.img(im), cam, mm, zb)))
        # from below
        cam = Cam(centre - np.array([0, rp * 3.5, 0]) + side * rp * 2.5, centre, 55, 700, 520)
        mm = near(new, centre, rp * 6)
        shots.append((kname + '-below', tile.img(render(cam, mm, sun, wrap=wrap, rough=rough)[0])))
    # A branch on a limb: the thickest branch of the lowest limb.
    bk = [k for k in range(len(limbs)) if limbs[k, 2] == 2 and limbs[k, 3] == kids[0]]
    if bk:
        k = max(bk, key=lambda k: seg[limbs[k, 0], 6])
        a = seg[limbs[k, 0], 0:3].astype(float); b = seg[limbs[k, 0], 3:6].astype(float)
        d = unit(b - a); rc = seg[limbs[k, 0], 6]
        centre = a + d * rc * 2
        side = unit(np.cross(d, [0, 1.0, 0]))
        cam = Cam(centre + side * rc * 10 + np.array([0, rc * 3, 0]), centre, 45, 700, 520)
        for name, mesh in [('new', new), ('today', old)]:
            mm = near(mesh, centre, rc * 16)
            im, zb = render(cam, mm, sun, wrap=wrap, rough=rough)
            shots.append(('fork-' + name, tile.img(im)))
            if name == 'new': shots.append(('fork-wire', wire(tile.img(im), cam, mm, zb)))
    for name, im in shots:
        im.save(out + '/%s-%s.png' % (tag, name))
    return shots

if __name__ == '__main__':
    dump, ph, out = sys.argv[1], sys.argv[2], sys.argv[3]
    tag = sys.argv[4] if len(sys.argv) > 4 else 'mesh'
    tile.load(dump)
    views(dump, out, tag)
