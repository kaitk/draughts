# One Norway maple leaf as the game's atlas draws it, as a mesh that can bend.
#
# The atlas (build/notes/tree/branches/dump/atlas-shape.rgba, leaf_atlas.goose): 1024 x 512
# RGBA8, 4 x 2 cells of 256 texels; in a cell the leaf's foot (blade meets stalk) is at
# texel (128, 170), y up to the middle lobe's tip at 1, 150 texels a unit. A is the
# outline (cut at 0.5), R the blade's light and dark, G where it turns first, B the veins.
# The game's card spans x -0.853..0.853, y -0.573..1.133 in those units.
#
# Bending works on the palmate leaf's own lines: every point lies on a ray from the foot
# (r, phi), and each ray bends as an arc whose angle grows along it. The five main veins
# run along such rays (0, +-56, +-110 degrees), so "the lobes droop", "the leaf cups up",
# "the midrib droops" and "the lobe tips bend" are all one rule with a different angle per
# ray. The sinuses between the lobes take up the small stretch that a cup would need.
import math
import numpy as np

DUMP = 'C:/Users/kait/projects/draughts/build/notes/tree/branches/dump/'
CELL, SCALE, FOOT = 256, 150.0, (128.0, 170.0)
QUAD = (0.853, -0.573, 1.133)
LOBES = np.radians([0.0, 56.0, -56.0, 110.0, -110.0])   # leaf_atlas::leaf_of
LOBE_LEN = np.array([1.0, 0.9, 0.9, 0.56, 0.56])

_atlas = None
def atlas():
    """The shape layer, float 0..1, (512, 1024, 4)."""
    global _atlas
    if _atlas is None:
        _atlas = np.fromfile(DUMP + 'atlas-shape.rgba', np.uint8).reshape(512, 1024, 4).astype(np.float32) / 255.0
    return _atlas

def uv_of(x, y, kind):
    """Atlas texel (column, row) of leaf-frame point (x, y), as the shader computes it."""
    cx, cy = (kind % 4) * CELL, (kind // 4) * CELL
    return cx + FOOT[0] + x * SCALE, cy + FOOT[1] - y * SCALE

def outline_radius(kind, spokes, margin=0.04):
    """Per spoke (angle from +y, clockwise toward +x), the farthest blade texel in its wedge."""
    a = atlas()[:, :, 3]
    cx, cy = (kind % 4) * CELL, (kind // 4) * CELL
    cell = a[cy:cy + CELL, cx:cx + CELL]
    jj, ii = np.nonzero(cell >= 0.5)
    x = (ii + 0.5 - FOOT[0]) / SCALE
    y = (FOOT[1] - (jj + 0.5)) / SCALE
    keep = ~((np.abs(x) < 0.05) & (y < -0.02))   # the blade, not the stalk below the foot
    x, y = x[keep], y[keep]
    r = np.hypot(x, y); phi = np.arctan2(x, y)
    out = np.zeros(len(spokes))
    n = len(spokes)
    half = math.pi / n
    for k, s in enumerate(spokes):
        d = np.angle(np.exp(1j * (phi - s)))
        m = np.abs(d) <= half
        out[k] = (r[m].max() if m.any() else 0.05)
    # a straight edge between two spokes cuts inside a lobe that lies between them: the
    # chord's middle is at r cos(half), so push out by 1/cos(half) and a margin
    return out / math.cos(half) + margin

def spoke_angles(n):
    """One ray along each lobe and one straight down, then the widest gaps halved until n."""
    a = sorted(list(LOBES) + [math.pi])
    while len(a) < n:
        gaps = [(a[(k + 1) % len(a)] - a[k]) % (2 * math.pi) for k in range(len(a))]
        k = int(np.argmax(gaps))
        a.insert(k + 1, a[k] + gaps[k] / 2)
        a = sorted(np.angle(np.exp(1j * np.array(a))))
    return np.array(a)

def fan_mesh(kind, spokes=12, rings=2):
    """A fan from the foot hugging the outline: spokes rays (one along each lobe), rings
    steps out along them, and a two-triangle strip for the stalk. Returns (xy (V,2) in
    leaf units, triangles (T,3))."""
    base = spoke_angles(spokes)
    rad = outline_radius(kind, base)
    xy = [(0.0, 0.0)]
    for ring in range(1, rings + 1):
        f = ring / rings
        for k, s in enumerate(base):
            xy.append((math.sin(s) * rad[k] * f, math.cos(s) * rad[k] * f))
    n = len(base)
    tris = []
    for k in range(n):
        tris.append((0, 1 + k, 1 + (k + 1) % n))
    for ring in range(1, rings):
        a0, b0 = 1 + (ring - 1) * n, 1 + ring * n
        for k in range(n):
            k1 = (k + 1) % n
            tris.append((a0 + k, b0 + k, b0 + k1))
            tris.append((a0 + k, b0 + k1, a0 + k1))
    # the stalk: a thin strip below the foot, to the card's bottom
    v = len(xy)
    w = 0.035
    xy += [(-w, 0.0), (w, 0.0), (w, QUAD[1]), (-w, QUAD[1])]
    tris += [(v, v + 1, v + 2), (v, v + 2, v + 3)]
    return np.array(xy, np.float64), np.array(tris, np.int64)

def quad_mesh(nx=1, ny=1, ys=None):
    """The game's card, or a grid over it (ys: the rows, say one at the foot)."""
    xs = np.linspace(-QUAD[0], QUAD[0], nx + 1)
    ys = np.linspace(QUAD[1], QUAD[2], ny + 1) if ys is None else np.array(ys)
    ny = len(ys) - 1
    X, Y = np.meshgrid(xs, ys)
    xy = np.stack([X.ravel(), Y.ravel()], 1)
    tris = []
    for j in range(ny):
        for i in range(nx):
            a = j * (nx + 1) + i
            tris += [(a, a + 1, a + nx + 2), (a, a + nx + 2, a + nx + 1)]
    return xy, np.array(tris, np.int64)

def coverage(kind, xy, tris):
    """Share of the mesh's area the blade covers (the rest is cut by alpha, overdraw)."""
    area = 0.0
    for t in tris:
        p = xy[t]
        e1, e2 = p[1] - p[0], p[2] - p[0]
        area += abs(e1[0] * e2[1] - e1[1] * e2[0]) / 2
    a = atlas()[:, :, 3]
    cx, cy = (kind % 4) * CELL, (kind // 4) * CELL
    blade = (a[cy:cy + CELL, cx:cx + CELL] >= 0.5).sum() / SCALE ** 2
    return blade / area, area

# ---- the bends ------------------------------------------------------------------------

def lobe_weights(phi, sigma=math.radians(24)):
    """How much each of the five lobes owns a ray at phi (sums to at most 1)."""
    d = np.angle(np.exp(1j * (phi[:, None] - LOBES[None, :])))
    w = np.exp(-(d / sigma) ** 2)
    return w

class Bend:
    """A leaf's shape: per lobe, the angle (radians, + up toward the face) its ray turns
    by at the lobe's tip, and where along it the turn starts (0 at the foot, 0.6 only the
    tip); a curl across each lobe's vein (+ edges up, - edges down); a twist about the
    midrib (radians at the tip)."""
    def __init__(self, tip=(0, 0, 0, 0, 0), start=0.0, power=2.0, curl=0.0, twist=0.0):
        self.tip = np.array(tip, np.float64); self.start = start; self.power = power
        self.curl = curl; self.twist = twist

def bend_card(xy, b, aspect=1.0, steps=24):
    """The cheap bend for a card cut in rows across: the whole blade bends along its
    midrib only, by the mean of the lobes' angles, and twists; below the foot it stays."""
    x = xy[:, 0] * aspect; y = xy[:, 1]
    amp = float(np.mean(b.tip))
    yy = np.clip(y, 0, None)
    s = np.linspace(0, 1, steps + 1)[None, :] * yy[:, None]
    u = np.clip((s / 1.0 - b.start) / max(1 - b.start, 1e-3), 0, None)
    ang = amp * u ** b.power
    ds = yy[:, None] / steps
    Y = np.where(y > 0, np.sum(np.cos(ang[:, 1:]) * ds, 1), y)
    Z = np.where(y > 0, np.sum(np.sin(ang[:, 1:]) * ds, 1), 0.0)
    X = x.copy()
    tw = b.twist * np.clip(Y, 0, None)
    c, sn = np.cos(tw), np.sin(tw)
    X, Z = X * c - Z * sn, X * sn + Z * c
    return np.stack([X, Y, Z], 1)

def bend(xy, b, aspect=1.0, steps=24):
    """Leaf-frame points (x, y) on the card to 3D (x, y, z): z along the face, metres in
    leaf units; x is first scaled by aspect (the card's width over its length)."""
    x = xy[:, 0] * aspect; y = xy[:, 1]
    blade = ~((np.abs(xy[:, 0]) < 0.05) & (y < -0.02))   # the stalk strip stays straight
    r = np.hypot(x, y); phi = np.arctan2(x, y)
    w = lobe_weights(phi)
    # the angle each ray turns by at its own lobe's tip, and that lobe's length
    wsum = w.sum(1) + 1e-6
    amp = (w * b.tip[None, :]).sum(1) / np.maximum(wsum, 0.35)
    length = (w * LOBE_LEN[None, :]).sum(1) / wsum
    # integrate the ray's arc: angle(s) = amp * ramp(s / length) ** power
    s = np.linspace(0, 1, steps + 1)[None, :] * r[:, None]
    u = np.clip((s / length[:, None] - b.start) / max(1 - b.start, 1e-3), 0, None)
    ang = amp[:, None] * u ** b.power
    ds = r[:, None] / steps
    h = np.sum(np.cos(ang[:, 1:]) * ds, 1)
    v = np.sum(np.sin(ang[:, 1:]) * ds, 1)
    ux, uy = np.sin(phi), np.cos(phi)
    X = ux * h; Y = uy * h; Z = v
    # curl across the nearest lobe's vein: a parabola in the distance from the vein
    near = np.argmax(w, 1)
    dirn = LOBES[near]
    t = np.sin(phi - dirn) * r                       # signed distance from the vein
    along = np.cos(phi - dirn) * r / LOBE_LEN[near]
    Z = Z + b.curl * t ** 2 * np.clip(along, 0, 1) * 4.0
    # twist about the midrib: turn (x, z) by twist * y
    tw = b.twist * np.clip(Y, 0, None)
    c, sn = np.cos(tw), np.sin(tw)
    X, Z = X * c - Z * sn, X * sn + Z * c
    # the stalk stays straight, in the card's plane
    X = np.where(blade, X, x); Y = np.where(blade, Y, y); Z = np.where(blade, Z, 0.0)
    return np.stack([X, Y, Z], 1)

# The variants shown on the page, in degrees at the lobe tips (middle, two big, two small).
D = math.radians
VARIANTS = {
    'flat':          Bend(),
    'cup up':        Bend(tip=(D(14), D(20), D(20), D(22), D(22)), power=1.6, curl=0.10),
    'midrib droop':  Bend(tip=(D(-38), D(-12), D(-12), D(-4), D(-4)), power=1.8),
    'edges down':    Bend(tip=(D(-10), D(-28), D(-28), D(-34), D(-34)), power=2.0, curl=-0.22),
    'lobe tips':     Bend(tip=(D(-30), D(-35), D(-14), D(-40), D(-8)), start=0.55, power=1.5),
    'sag + twist':   Bend(tip=(D(-30), D(-24), D(-30), D(-30), D(-26)), power=1.8, curl=-0.15, twist=D(-22)),
}
