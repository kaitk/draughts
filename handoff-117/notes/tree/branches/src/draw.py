# Shared drawing for the branch notes: a tree's segments and leaves drawn orthographically
# by Pillow, the bare wood as a dark silhouette on a pale sky like the Tartu photos, the
# leaves as five-lobed blades. Segments: N x 9 (a.xyz b.xyz ra rb level); leaves: N x 16
# (foot.xyz base.xyz along.xyz face.xyz size width kind tint), the dump's layout, metres.
import math, numpy as np
from PIL import Image, ImageDraw

M = 30.48  # world units per metre in tools/tree_dump's dump

def load_dump(path):
    f = np.fromfile(path, '<f4'); i = 0
    n = int(f[i]); i += 1
    seg = f[i:i + n * 9].reshape(n, 9).copy(); i += n * 9
    n = int(f[i]); i += 1
    limbs = f[i:i + n * 4].reshape(n, 4).copy(); i += n * 4
    n = int(f[i]); i += 1
    cards = f[i:i + n * 16].reshape(n, 16).copy()
    seg[:, :8] /= M
    cards[:, :6] /= M
    cards[:, 12:14] /= M
    return seg, limbs, cards

def basis(yaw_deg, pitch_deg=0.0):
    """Right and up vectors of a camera turned yaw about the vertical, pitched up."""
    y, p = math.radians(yaw_deg), math.radians(pitch_deg)
    fwd = np.array([math.sin(y) * math.cos(p), math.sin(p), math.cos(y) * math.cos(p)])
    right = np.cross(np.array([0, 1.0, 0]), fwd); right /= np.linalg.norm(right)
    up = np.cross(fwd, right)
    return right, up, fwd

def leaf_outline(n=40):
    """A Norway maple blade in (u along from the base, v across), u 0..1."""
    pts = []
    for k in range(n):
        t = -math.pi + 2 * math.pi * k / n
        lobes = 0.62 + 0.38 * abs(math.cos(2.5 * t)) ** 3
        r = 0.5 * lobes * (0.75 if abs(t) > 2.6 else 1.0)
        pts.append((0.5 + r * math.cos(t), r * math.sin(t) * 1.1))
    return np.array(pts)

OUTLINE = leaf_outline()

def fit(points, w, h, margin=0.04, right=None, up=None):
    x = points @ right; y = points @ up
    lo = np.array([x.min(), y.min()]); hi = np.array([x.max(), y.max()])
    s = min(w * (1 - 2 * margin) / (hi[0] - lo[0]), h * (1 - 2 * margin) / (hi[1] - lo[1]))
    mid = (lo + hi) / 2
    return s, mid

def render(seg, leaves, w, h, yaw=0.0, pitch=0.0, frame_pts=None, ss=2, sky=(222, 226, 230),
           wood=(38, 40, 44), leaf_rgb=(226, 168, 40), stalks=True):
    right, up, fwd = basis(yaw, pitch)
    W, H = w * ss, h * ss
    pts = frame_pts if frame_pts is not None else np.vstack([seg[:, 0:3], seg[:, 3:6]])
    s, mid = fit(pts, W, H, right=right, up=up)
    def px(p):
        return ((p @ right - mid[0]) * s + W / 2, H / 2 - (p @ up - mid[1]) * s)
    img = Image.new('RGB', (W, H), sky)
    d = ImageDraw.Draw(img)
    # wood: thick first so thin twigs draw over; sub-pixel twigs lighter (their coverage).
    order = np.argsort(-(seg[:, 6] + seg[:, 7]))
    ax, ay = px(seg[:, 0:3]); bx, by = px(seg[:, 3:6])
    for i in order:
        r = (seg[i, 6] + seg[i, 7]) * s  # diameter in pixels
        if r >= 1.0:
            col = wood; wd = int(round(r))
        else:
            c = max(r, 0.25)
            col = tuple(int(sky[k] + (wood[k] - sky[k]) * c) for k in range(3)); wd = 1
        d.line([(ax[i], ay[i]), (bx[i], by[i])], fill=col, width=wd)
        if wd > 3:
            rr = wd / 2
            d.ellipse([bx[i] - rr, by[i] - rr, bx[i] + rr, by[i] + rr], fill=col)
    if leaves is not None and len(leaves):
        depth = leaves[:, 3:6] @ fwd
        for i in np.argsort(-depth):
            L = leaves[i]
            foot, base, along, face = L[0:3], L[3:6], L[6:9], L[9:12]
            size, width = L[12], L[13]
            across = np.cross(face, along)
            poly = base + np.outer(OUTLINE[:, 0] * size, along) + np.outer(OUTLINE[:, 1] * width, across)
            qx, qy = px(poly)
            lit = 0.55 + 0.45 * abs(face @ fwd)
            tint = L[15]
            base_rgb = np.array(leaf_rgb) * (1.0 - 0.15 * (tint - 1.0))
            col = tuple(int(min(255, c * lit)) for c in base_rgb)
            if stalks:
                fx, fy = px(foot); bx2, by2 = px(base)
                d.line([(fx, fy), (bx2, by2)], fill=(120, 80, 40), width=max(1, ss // 2))
            d.polygon(list(zip(qx, qy)), fill=col, outline=tuple(int(c * 0.8) for c in col))
    return img.resize((w, h), Image.LANCZOS)
