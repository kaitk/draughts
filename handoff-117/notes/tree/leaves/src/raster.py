# A small software rasterizer for the leaf notes: perspective triangles with a z-buffer,
# the atlas's texel cut at alpha 0.5 as the game cuts it, and the game's leaf light
# (shaders::TREE_LEAF_FRAG, simplified): the front lit by sky and sun, the back by the sun
# through the leaf, stronger toward the sun's own way. Twigs as camera-facing ribbons.
import math
import numpy as np
from PIL import Image
import leaf as L

def tint_color(t):
    """shaders::TREE_LEAF_FRAG leaf_tint_color, linear RGB."""
    green = np.array([0.045, 0.11, 0.012]); lime = np.array([0.3, 0.33, 0.02])
    gold = np.array([0.62, 0.34, 0.01]); orange = np.array([0.6, 0.14, 0.008]); red = np.array([0.42, 0.045, 0.006])
    if t < 0.7: return green + (lime - green) * t / 0.7
    if t < 1.0: return lime + (gold - lime) * (t - 0.7) / 0.3
    if t < 1.5: return gold + (orange - gold) * (t - 1.0) / 0.5
    return orange + (red - orange) * min((t - 1.5) / 0.5, 1.0)

class Camera:
    def __init__(self, eye, at, w, h, fov=40.0, up=(0, 1, 0)):
        self.eye = np.array(eye, float); at = np.array(at, float)
        f = at - self.eye; f /= np.linalg.norm(f)
        upv = np.array(up, float)
        if abs(np.dot(f, upv)) > 0.99: upv = np.array([0, 0, 1.0])
        r = np.cross(f, upv); r /= np.linalg.norm(r)
        u = np.cross(r, f)
        self.f, self.r, self.u = f, r, u
        self.w, self.h = w, h
        self.k = 0.5 * h / math.tan(math.radians(fov) / 2)
    def project(self, p):
        d = p - self.eye
        z = d @ self.f
        x = d @ self.r; y = d @ self.u
        return np.stack([self.w / 2 + self.k * x / z, self.h / 2 - self.k * y / z, z], -1)

class Canvas:
    def __init__(self, cam, sky_top=(0.30, 0.52, 0.85), sky_bottom=(0.62, 0.75, 0.92)):
        self.cam = cam
        h, w = cam.h, cam.w
        t = np.linspace(0, 1, h)[:, None, None]
        self.rgb = np.array(sky_top)[None, None, :] * (1 - t) + np.array(sky_bottom)[None, None, :] * t
        self.rgb = np.repeat(self.rgb, w, 1).astype(np.float64)
        self.z = np.full((h, w), np.inf)

    def triangles(self, P, UV, N, kind, tint, sun, sky=0.55, sunk=1.0, back=0.9):
        """P (T,3,3) world, UV (T,3,2) atlas texels, N (T,3,3) normals, kind/tint (T,)."""
        cam = self.cam
        S = cam.project(P.reshape(-1, 3)).reshape(-1, 3, 3)
        A = L.atlas()
        sun = np.asarray(sun, float); sun = sun / np.linalg.norm(sun)
        for i in range(len(P)):
            s = S[i]
            if np.any(s[:, 2] <= 0.01): continue
            x0 = max(int(np.floor(s[:, 0].min())), 0); x1 = min(int(np.ceil(s[:, 0].max())), cam.w - 1)
            y0 = max(int(np.floor(s[:, 1].min())), 0); y1 = min(int(np.ceil(s[:, 1].max())), cam.h - 1)
            if x1 < x0 or y1 < y0: continue
            xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            (ax, ay, _), (bx, by, _), (cx, cy, _) = s
            den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
            if abs(den) < 1e-9: continue
            l0 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / den
            l1 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / den
            l2 = 1 - l0 - l1
            m = (l0 >= 0) & (l1 >= 0) & (l2 >= 0)
            if not m.any(): continue
            iw = 1.0 / s[:, 2]
            q = l0 * iw[0] + l1 * iw[1] + l2 * iw[2]
            z = 1.0 / q
            b0, b1, b2 = l0 * iw[0] / q, l1 * iw[1] / q, l2 * iw[2] / q
            zb = self.z[y0:y1 + 1, x0:x1 + 1]
            m &= z < zb
            if not m.any(): continue
            u = b0 * UV[i, 0, 0] + b1 * UV[i, 1, 0] + b2 * UV[i, 2, 0]
            v = b0 * UV[i, 0, 1] + b1 * UV[i, 1, 1] + b2 * UV[i, 2, 1]
            tu = np.clip(u.astype(int), 0, 1023); tv = np.clip(v.astype(int), 0, 511)
            tex = A[tv, tu]
            m &= tex[..., 3] >= 0.5
            if not m.any(): continue
            n = b0[..., None] * N[i, 0] + b1[..., None] * N[i, 1] + b2[..., None] * N[i, 2]
            n /= np.linalg.norm(n, axis=-1, keepdims=True) + 1e-9
            wpos = b0[..., None] * P[i, 0] + b1[..., None] * P[i, 1] + b2[..., None] * P[i, 2]
            view = cam.eye - wpos; view /= np.linalg.norm(view, axis=-1, keepdims=True)
            nv = np.sum(n * view, -1)
            nf = np.where(nv[..., None] < 0, -n, n)
            nl = np.sum(nf * sun, -1)
            c0 = tint_color(tint[i])[None, None, :] * tex[..., 0:1]
            front = c0 * (1 + 0.3 * tex[..., 2:3])
            backc = np.power(c0, 1.35) * 2.4
            skyl = sky * (0.6 + 0.4 * np.clip(nf[..., 1:2], 0, 1))
            col = front * skyl
            g = 0.3
            hg = (1 - g * g) / np.power(1 + g * g - 2 * g * np.sum(-sun * view, -1), 1.5)
            col = np.where(nl[..., None] >= 0, col + front * sunk * nl[..., None],
                           col + backc * sunk * back * (-nl[..., None]) * (0.5 + 0.5 * hg[..., None]))
            sub = self.rgb[y0:y1 + 1, x0:x1 + 1]
            sub[m] = col[m]
            zb[m] = z[m]

    def ribbon(self, a, b, ra, rb, color=(0.05, 0.04, 0.035), steps=1):
        """A twig from a to b, radius ra to rb, as a camera-facing quad (two triangles)."""
        cam = self.cam
        a = np.asarray(a, float); b = np.asarray(b, float)
        d = b - a
        side = np.cross(d, cam.eye - (a + b) / 2); nn = np.linalg.norm(side)
        if nn < 1e-9: return
        side /= nn
        quad = np.array([a - side * ra, a + side * ra, b + side * rb, b - side * rb])
        s = cam.project(quad)
        # draw at least a pixel wide
        for tri in ((0, 1, 2), (0, 2, 3)):
            self._flat(s[list(tri)], color)

    def _flat(self, s, color):
        cam = self.cam
        if np.any(s[:, 2] <= 0.01): return
        x0 = max(int(np.floor(s[:, 0].min())), 0); x1 = min(int(np.ceil(s[:, 0].max())), cam.w - 1)
        y0 = max(int(np.floor(s[:, 1].min())), 0); y1 = min(int(np.ceil(s[:, 1].max())), cam.h - 1)
        if x1 < x0 or y1 < y0: return
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        (ax, ay, az), (bx, by, bz), (cx, cy, cz) = s
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-9: return
        l0 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / den
        l1 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / den
        l2 = 1 - l0 - l1
        m = (l0 >= -0.02) & (l1 >= -0.02) & (l2 >= -0.02)
        z = l0 * az + l1 * bz + l2 * cz
        zb = self.z[y0:y1 + 1, x0:x1 + 1]
        m &= z < zb
        sub = self.rgb[y0:y1 + 1, x0:x1 + 1]
        sub[m] = color
        zb[m] = z[m]

    def image(self, ss=1, exposure=1.6):
        c = 1 - np.exp(-self.rgb * exposure)            # a soft tonemap
        c = np.power(np.clip(c, 0, 1), 1 / 2.2)
        im = Image.fromarray((c * 255 + 0.5).astype(np.uint8))
        if ss > 1: im = im.resize((self.cam.w // ss, self.cam.h // ss), Image.LANCZOS)
        return im

# ---- leaves into world triangles ------------------------------------------------------

def vertex_normals(pos, tris):
    n = np.zeros_like(pos)
    for t in tris:
        a, b, c = pos[t]
        fn = np.cross(b - a, c - a)
        n[t] += fn
    n /= np.linalg.norm(n, axis=1, keepdims=True) + 1e-12
    return n

def leaf_triangles(xy, tris, shape, kind, base, along, face, size, width, card=False):
    """One leaf: card points xy bent by `shape` (leaf.Bend), placed like a game card:
    base the blade's foot, along its axis, face its normal, size the blade's length and
    width the card's half width a unit (trees::Card)."""
    aspect = width / size
    local = (L.bend_card if card else L.bend)(xy, shape, aspect=aspect)
    nloc = vertex_normals(local, tris)
    along = along / np.linalg.norm(along); face = face / np.linalg.norm(face)
    across = np.cross(face, along)
    M = np.stack([across, along, face], 1)          # local x, y, z to world
    world = base + (local * size) @ M.T
    nw = nloc @ M.T
    u, v = L.uv_of(xy[:, 0], xy[:, 1], kind)
    uv = np.stack([u, v], 1)
    return world[tris], uv[tris], nw[tris]
