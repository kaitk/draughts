# Task 117 step two: tools/tree_dump's leaves drawn as the game's leaf vertex shader draws
# them (the Goose templates in leaf-shapes.bin, mixed with the flat fan by each card's
# amount, twisted about the midrib), with the study's rasterizer (../../src/raster.py),
# beside the photo crops. A patch of crown round one outer twig, from below, from the side
# and against the light; and the whole tree from the front.
#   python dump_view.py OUT.jpg DIR:LABEL [DIR:LABEL ...] [--mesh card|rows|fan] [--twist DEG]
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
LEAVES = os.path.join(HERE, '..', '..')
sys.path.insert(0, os.path.join(LEAVES, 'src'))
sys.path.insert(0, os.path.join(LEAVES, '..', 'branches', 'src'))
import leaf as L          # noqa: E402
import raster as R        # noqa: E402
from draw import load_dump, render as render_whole  # noqa: E402

M = 30.48
KINDS, SHAPES = 8, 6
ROW_V, FAN_V = 24, 78
ROW_VEC4S = SHAPES * ROW_V * 2
try:
    FONT = ImageFont.truetype('arial.ttf', 20)
    SMALL = ImageFont.truetype('arial.ttf', 15)
except OSError:
    FONT = SMALL = None


def load_all(d):
    seg, limbs, cards = load_dump(os.path.join(d, 'tree-none-whole.bin'))
    f = np.fromfile(os.path.join(d, 'tree-none-whole.bin'), '<f4')
    n_seg = int(f[0]); i = 1 + n_seg * 9
    n_l = int(f[i]); i += 1 + n_l * 4
    n_c = int(f[i]); i += 1 + n_c * 16
    bends = f[i:i + n_c * 3].reshape(n_c, 3) if len(f) >= i + n_c * 3 else np.zeros((n_c, 3))
    shapes = np.fromfile(os.path.join(d, 'leaf-shapes.bin'), '<f4').reshape(-1, 4)
    return seg, limbs, cards, bends, shapes


def mesh_of(shapes, mesh, kind, shape):
    """(V, 3) bent points, (V, 3) normals, (V, 2) flat points of one template."""
    if mesh == 'rows':
        at, n = shape * ROW_V * 2, ROW_V
    else:
        at, n = ROW_VEC4S + (kind * SHAPES + shape) * FAN_V * 2, FAN_V
    v = shapes[at:at + n * 2].reshape(n, 2, 4)
    return v[:, 0, :3], v[:, 1, :3], np.stack([v[:, 0, 3], v[:, 1, 3]], 1)


CARD = np.array([(-1, 0), (1, 0), (1, 1), (-1, 0), (1, 1), (-1, 1)], float)


def leaf_world(card, bend, shapes, mesh, twist_deg):
    """One card's triangles as TREE_LEAF_VERT places them: P (T,3,3), UV (T,3,2), N (T,3,3)."""
    base, along, face = card[3:6] * 1.0, card[6:9], card[9:12]
    size, width, kind = card[12], card[13], int(card[14])
    shape, amount, twist = int(bend[0]), bend[1], bend[2]
    across = np.cross(face, along)
    if mesh == 'card':
        flat = np.stack([CARD[:, 0] * 0.853, -0.573 + CARD[:, 1] * (1.133 + 0.573)], 1)
        local = np.concatenate([flat, np.zeros((6, 1))], 1); nl = np.tile([0, 0, 1.0], (6, 1))
    else:
        p0, n0, flat = mesh_of(shapes, mesh, kind, 0)
        p1, n1, _ = mesh_of(shapes, mesh, kind, shape)
        local = p0 + (p1 - p0) * amount
        nl = n0 + (n1 - n0) * amount
        nl /= np.linalg.norm(nl, axis=1, keepdims=True) + 1e-9
        tw = twist * np.clip(local[:, 1], 0, None)
        c, s = np.cos(tw), np.sin(tw)
        local = np.stack([local[:, 0] * c - local[:, 2] * s, local[:, 1], local[:, 0] * s + local[:, 2] * c], 1)
        nl = np.stack([nl[:, 0] * c - nl[:, 2] * s, nl[:, 1], nl[:, 0] * s + nl[:, 2] * c], 1)
    wx = width / 1.15
    world = base + np.outer(local[:, 0] * wx, across) + np.outer(local[:, 1] * size, along) + np.outer(local[:, 2] * size, face)
    nw = np.outer(nl[:, 0], across) + np.outer(nl[:, 1], along) + np.outer(nl[:, 2], face)
    u, v = L.uv_of(flat[:, 0], flat[:, 1], kind)
    uv = np.stack([u, v], 1)
    k = len(world) // 3
    return world.reshape(k, 3, 3), uv.reshape(k, 3, 2), nw.reshape(k, 3, 3)


def patch_centre(cards):
    """An outer twig low on the crown's window side: the card farthest out at 0.35-0.5 of the height."""
    foot = cards[:, 0:3]
    y0, y1 = foot[:, 1].min(), foot[:, 1].max()
    h = (foot[:, 1] - y0) / (y1 - y0)
    mid = np.median(foot, 0)
    r = np.hypot(foot[:, 0] - mid[0], foot[:, 2] - mid[2])
    m = (h > 0.35) & (h < 0.5) & (foot[:, 0] < mid[0])
    i = np.nonzero(m)[0][np.argmax(r[m])]
    return foot[i]


def render_patch(seg, cards, bends, shapes, centre, view, mesh, twist, w=420, h=420, ss=2, radius=0.7):
    near = np.linalg.norm(cards[:, 0:3] - centre, axis=1) < radius
    eye, at, sun, sky, up, fov = view
    cam = R.Camera(eye, at, w * ss, h * ss, fov=fov, up=up)
    cv = R.Canvas(cam)
    ms = np.linalg.norm((seg[:, 0:3] + seg[:, 3:6]) / 2 - centre, axis=1) < radius * 1.6
    for s in seg[ms][np.argsort(-seg[ms][:, 6])]:
        cv.ribbon(s[0:3], s[3:6], max(s[6], 0.0015), max(s[7], 0.0015))
    P, UV, N, K, T = [], [], [], [], []
    for c, b in zip(cards[near], bends[near]):
        p, uv, n = leaf_world(c, b, shapes, mesh, twist)
        P.append(p); UV.append(uv); N.append(n)
        K.append(np.full(len(p), int(c[14]))); T.append(np.full(len(p), c[15]))
        cv.ribbon(c[0:3], c[3:6], 0.0012, 0.0012, color=(0.30, 0.07, 0.03))
    if P:
        cv.triangles(np.concatenate(P), np.concatenate(UV), np.concatenate(N), np.concatenate(K), np.concatenate(T), sun, sky=sky)
    return cv.image(ss), int(near.sum())


def views(centre):
    e = 1.1
    return {
        'below': (centre + np.array([0.15, -1.6 * e, -0.2]), centre, np.array([0.3, 1.0, 0.4]), 0.5, (1, 0, 0), 46),
        'side': (centre + np.array([-0.2, -0.15, -1.7 * e]), centre, np.array([0.3, 0.9, 0.5]), 0.6, (0, 1, 0), 46),
        'light': (centre + np.array([-0.3, -0.35, -1.6 * e]), centre, np.array([0.2, 0.5, 1.0]), 0.35, (0, 1, 0), 46),
    }


def label(im, text, small=None):
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, im.width, 30 if not small else 52], fill=(245, 245, 245))
    d.text((8, 5), text, fill=(30, 30, 36), font=FONT)
    if small:
        d.text((8, 30), small, fill=(70, 70, 80), font=SMALL)


def main():
    args = sys.argv[1:]
    out = args.pop(0)
    mesh, twist, centre_from = 'fan', 25.0, None
    cols = []
    while args:
        a = args.pop(0)
        if a == '--mesh': mesh = args.pop(0)
        elif a == '--twist': twist = float(args.pop(0))
        else: cols.append(a.split(':', 1))
    photos = ['photo-tartu-plates.jpg', 'photo-ai-side.jpg', 'photo-flat-sun.jpg']
    tile = 420
    rows = []
    prow = []
    for p in photos:
        im = Image.open(os.path.join(LEAVES, 'img', p)).convert('RGB')
        s = min(im.size); im = im.crop(((im.width - s) // 2, (im.height - s) // 2, (im.width + s) // 2, (im.height + s) // 2))
        im = im.resize((tile, tile), Image.LANCZOS); label(im, 'photo: ' + p[6:-4]); prow.append(im)
    whole_photo = Image.open(os.path.join(LEAVES, 'img', 'photo-tartu-edge.jpg')).convert('RGB').resize((tile, tile))
    label(whole_photo, 'photo: tartu-edge'); prow.append(whole_photo)
    rows.append(prow)
    for d, text in cols:
        seg, limbs, cards, bends, shapes = load_all(d)
        if centre_from is None: centre_from = patch_centre(cards)
        row = []
        for k, (vn, vv) in enumerate(views(centre_from).items()):
            im, n = render_patch(seg, cards, bends, shapes, centre_from, vv, mesh, twist)
            label(im, f'{text}: {vn}', f'{n} leaves in the patch' if k == 0 else None)
            row.append(im)
        whole = render_whole(seg, cards, tile, tile, yaw=0.0, frame_pts=np.vstack([seg[:, 0:3], cards[:, 3:6]]))
        label(whole, f'{text}: whole', f'{len(cards)} leaves')
        row.append(whole)
        rows.append(row)
    W = Image.new('RGB', (tile * 4, tile * len(rows)), (255, 255, 255))
    for j, row in enumerate(rows):
        for i, im in enumerate(row):
            W.paste(im, (i * tile, j * tile))
    W.save(out, quality=88)
    print('wrote', out)


if __name__ == '__main__':
    main()
