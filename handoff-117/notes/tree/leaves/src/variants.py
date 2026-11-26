# The curved leaf variants, each from below, from the side and against the light, and the
# meshes per tier. Writes ../img/variants.png, ../img/meshes.png, ../img/tiers.png.
import math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import leaf as L, raster as R

OUT = os.path.join(os.path.dirname(__file__), '..', 'img')
os.makedirs(OUT, exist_ok=True)
SS = 2
CELL = 250
TINT = 1.15          # gold-orange, as in the autumn photos
KIND = 1

def font(n):
    try: return ImageFont.truetype('arial.ttf', n)
    except OSError: return ImageFont.load_default()

# one leaf, foot at the origin, pointing along +x, face up
BASE = np.zeros(3); ALONG = np.array([1.0, 0, 0]); FACE = np.array([0, 1.0, 0])
SIZE, WIDTH = 1.0, 1.15

VIEWS = {
    # name: eye, at, toward the sun, sky, camera's up
    'from below': (np.array([0.42, -3.4, 0.0]), np.array([0.42, 0, 0]), np.array([0.5, 1.0, 0.6]), 0.45, (1, 0, 0)),
    'three-quarter': (np.array([2.2, 1.9, 2.2]), np.array([0.42, 0.0, 0]), np.array([0.4, 0.9, 0.6]), 0.55, (0, 1, 0)),
    'from the side': (np.array([0.42, 0.45, 3.4]), np.array([0.42, -0.05, 0]), np.array([0.4, 0.9, 0.6]), 0.55, (0, 1, 0)),
    'against the light': (np.array([1.9, -0.35, 2.6]), np.array([0.42, -0.05, 0]), np.array([-0.4, 0.55, -1.0]), 0.35, (0, 1, 0)),
}

def draw(shape, view, mesh, w=CELL, h=CELL, fov=29, card=False):
    eye, at, sun, sky, up = VIEWS[view]
    cam = R.Camera(eye, at, w * SS, h * SS, fov=fov, up=up)
    cv = R.Canvas(cam)
    xy, tris = mesh
    P, UV, N = R.leaf_triangles(xy, tris, shape, KIND, BASE, ALONG, FACE, SIZE, WIDTH, card=card)
    cv.triangles(P, UV, N, np.full(len(P), KIND), np.full(len(P), TINT), sun, sky=sky)
    # the stalk below the card, to the twig
    cv.ribbon(BASE + ALONG * L.QUAD[1] * SIZE, BASE + ALONG * (-1.1), 0.012, 0.016, color=(0.25, 0.05, 0.02))
    return cv.image(SS)

def grid(names, cols, cellfn, label_rows=True, title_h=26, label_w=120):
    W = label_w + CELL * len(cols); H = title_h + CELL * len(names)
    im = Image.new('RGB', (W, H), (22, 24, 27))
    d = ImageDraw.Draw(im)
    for j, c in enumerate(cols):
        d.text((label_w + j * CELL + 8, 5), c, fill=(216, 214, 208), font=font(15))
    for i, n in enumerate(names):
        d.text((8, title_h + i * CELL + CELL // 2 - 8), n, fill=(216, 214, 208), font=font(15))
        for j, c in enumerate(cols):
            im.paste(cellfn(n, c), (label_w + j * CELL, title_h + i * CELL))
    return im

if __name__ == '__main__':
    fine = L.fan_mesh(KIND, 16, 4)
    names = list(L.VARIANTS)
    im = grid(names, list(VIEWS), lambda n, c: draw(L.VARIANTS[n], c, fine))
    im.save(os.path.join(OUT, 'variants.png'))

    # the meshes, flat, seen from above, over the atlas texel
    meshes = {'card (now): 4 verts': L.quad_mesh(),
              'fan 8 x 2: 21 verts': L.fan_mesh(KIND, 8, 2),
              'fan 12 x 2: 29 verts': L.fan_mesh(KIND, 12, 2),
              'fan 16 x 3: 53 verts': L.fan_mesh(KIND, 16, 3)}
    A = L.atlas()
    cx, cy = (KIND % 4) * 256, (KIND // 4) * 256
    tiles = []
    for name, (xy, tris) in meshes.items():
        cell = (A[cy:cy + 256, cx:cx + 256, 3:4] * np.array([0.85, 0.55, 0.15]) * 255).astype(np.uint8)
        t = Image.fromarray(cell).resize((512, 512), Image.NEAREST)
        d = ImageDraw.Draw(t)
        u, v = L.uv_of(xy[:, 0], xy[:, 1], KIND)
        pts = np.stack([(u - cx) * 2, (v - cy) * 2], 1)
        for tr in tris:
            p = [tuple(pts[k]) for k in tr]
            d.line(p + [p[0]], fill=(120, 200, 255), width=2)
        c, area = L.coverage(KIND, xy, tris)
        d.text((10, 8), name, fill=(255, 255, 255), font=font(22))
        d.text((10, 478), '%d triangles, blade covers %d %% of it' % (len(tris), round(100 * c)), fill=(255, 255, 255), font=font(20))
        tiles.append(t.resize((300, 300), Image.LANCZOS))
    m = Image.new('RGB', (300 * len(tiles) + 8 * (len(tiles) - 1), 300), (22, 24, 27))
    for k, t in enumerate(tiles): m.paste(t, (k * 308, 0))
    m.save(os.path.join(OUT, 'meshes.png'))

    # one sagging leaf on each tier's mesh, from the side and against the light
    shape = L.VARIANTS['sag + twist']
    tiers = {'card (flat)': (L.quad_mesh(), L.VARIANTS['flat']),
             'card 4 rows, bent': (L.quad_mesh(1, ys=[L.QUAD[1], 0.0, 0.38, 0.76, L.QUAD[2]]), shape),
             'fan 8 x 2': (L.fan_mesh(KIND, 8, 2), shape),
             'fan 12 x 2': (L.fan_mesh(KIND, 12, 2), shape),
             'fan 16 x 3': (L.fan_mesh(KIND, 16, 3), shape)}
    im = grid(['from the side', 'against the light', 'from below'], list(tiers),
              lambda n, c: draw(tiers[c][1], n, tiers[c][0], card=c.startswith('card')), label_w=140)
    im.save(os.path.join(OUT, 'tiers.png'))
    print('ok')
