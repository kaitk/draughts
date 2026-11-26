# Step three's bark tile (trees::bark_layers) as tree_dump writes it, shaded the way
# shaders::TREE_WOOD_FRAG does: the normal from the height's slope, the cavity on the sky,
# the AO microshadow on the sun, the albedo from the height. Flat tiles and a trunk at the
# window's distance and close, beside the lawn photo's crops.
#   python tile.py DUMP_DIR PHOTO_DIR OUT_DIR TAG
import sys, numpy as np
from PIL import Image, ImageDraw

W, H = 256, 512
AGES = [0.45, 0.65, 0.82, 1.0]
TEX_MM = 250.0 / 256
SIDE = np.array([0.93, 0.28, 0.24]); SIDE /= np.linalg.norm(SIDE)
CROWN = np.array([0.155, 0.145, 0.13]); FURROW = np.array([0.05, 0.042, 0.036])
SKY = np.array([0.526, 0.601, 0.716]); GROUND = np.array([0.17, 0.12, 0.02])
LAWN_PHOTO = 'IVVnBQE6sVxjpRlsZrqUHe83OMLkxXoMiXOvWz3HAtdKbFRNpgTQRrLZ9mvxszqUyaJdn-5TaQAEbbL10vdpodwhntQ4t-fqqElQsxetSzCFaAgdG8X9P2qrrSbdP1fAAjzIm6PjaS1pXqWXvxFK86ydOflseDlbY_we9PuA19pJMINLdqe4ySzkjkoCRg2q.jpg'
PYR = None

def pyramid(a):
    out = [a]
    while out[-1].shape[0] > 1 and out[-1].shape[1] > 1:
        m = out[-1]; out.append(0.25 * (m[0::2, 0::2] + m[1::2, 0::2] + m[0::2, 1::2] + m[1::2, 1::2]))
    return out

def load(dump):
    global PYR
    hgt = np.fromfile(dump + '/bark-height.rgba', np.uint8).reshape(H, W, 4).astype(np.float32)
    cav = np.fromfile(dump + '/bark-cavity.rgba', np.uint8).reshape(H, W, 4).astype(np.float32) / 255
    PYR = pyramid(np.concatenate([(hgt - 128) * 0.1, cav], -1))

def bilinear(m, u, v):
    h, w = m.shape[:2]
    x = u * w - 0.5; y = v * h - 0.5
    i = np.floor(x).astype(int); j = np.floor(y).astype(int)
    fx = (x - i)[..., None]; fy = (y - j)[..., None]
    i0 = i % w; i1 = (i + 1) % w; j0 = j % h; j1 = (j + 1) % h
    return (m[j0, i0] * (1 - fx) + m[j0, i1] * fx) * (1 - fy) + (m[j1, i0] * (1 - fx) + m[j1, i1] * fx) * fy

def tri(u, v, lod):
    lod = np.clip(lod, 0, len(PYR) - 1.001)
    l0 = np.floor(lod).astype(int); f = (lod - l0)[..., None]
    out = np.zeros(u.shape + (8,))
    for L in np.unique(l0):
        k = l0 == L
        out[k] = bilinear(PYR[L], u[k], v[k]) * (1 - f[k]) + bilinear(PYR[L + 1], u[k], v[k]) * f[k]
    return out

def weights(age):
    a = np.asarray(age, np.float32)
    w = np.zeros(a.shape + (4,))
    w[..., 0] = np.clip((AGES[1] - a) / (AGES[1] - AGES[0]), 0, 1)
    for k in (1, 2):
        w[..., k] = np.clip(np.minimum((a - AGES[k - 1]) / (AGES[k] - AGES[k - 1]), (AGES[k + 1] - a) / (AGES[k + 1] - AGES[k])), 0, 1)
    w[..., 3] = np.clip((a - AGES[2]) / (AGES[3] - AGES[2]), 0, 1)
    return w

def shade(u, v, du, dv, n0, t, rw, age, l, relief=1.0, sun=2.5, sky=1.0, micro=True, wrap=0.0, rough=0.0, view=None):
    lod = np.log2(np.maximum(du * W, dv * H).clip(1e-6))
    ex = np.maximum(du, 1 / W); ey = np.maximum(dv, 1 / H)
    wt = weights(age)
    def hs(uu, vv):
        s = tri(uu, vv, lod); return (s[..., :4] * wt).sum(-1), (s[..., 4:] * wt).sum(-1)
    hc, ao = hs(u, v)
    hxp, _ = hs(u + ex, v); hxm, _ = hs(u - ex, v); hyp, _ = hs(u, v + ey); hym, _ = hs(u, v - ey)
    young = np.clip((np.asarray(age) - 0.15) / 0.3, 0, 1)
    sx = (hxp - hxm) / (2 * ex * W * TEX_MM) * relief * young
    sy = (hyp - hym) / (2 * ey * H * TEX_MM) * relief * young
    n = n0 - rw * sx[..., None] - t * sy[..., None]
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    ao = 1 - (1 - ao) * young
    crown = np.clip((hc + 3) / 5, 0, 1); crown = crown * crown * (3 - 2 * crown)
    alb = FURROW + (CROWN - FURROW) * crown[..., None]
    ndl = (n * l).sum(-1)
    ms = np.clip(np.abs(ndl) + 2 * ao * ao - 1, 0, 1) if micro else 1.0
    diffuse = np.maximum(ndl, 0)
    if rough > 0 and view is not None:
        s2 = rough * rough
        A = 1 - 0.5 * s2 / (s2 + 0.33); B = 0.45 * s2 / (s2 + 0.09)
        ndv = np.clip((n * view).sum(-1), 1e-3, 1)
        lp = l - n * ndl[..., None]; vp = view - n * ndv[..., None]
        cosphi = (lp * vp).sum(-1) / np.maximum(np.linalg.norm(lp, axis=-1) * np.linalg.norm(vp, axis=-1), 1e-4)
        ti = np.arccos(np.clip(ndl, -1, 1)); tr = np.arccos(ndv)
        alpha = np.maximum(ti, tr); beta = np.minimum(ti, tr)
        diffuse = diffuse * (A + B * np.maximum(cosphi, 0) * np.sin(alpha) * np.tan(beta))
    scatter = np.zeros_like(ndl)
    if wrap > 0:
        scatter = np.maximum(np.maximum(ndl + wrap, 0) / (1 + wrap) - np.maximum(ndl, 0), 0) * ao
    skyc = GROUND + (SKY - GROUND) * (0.5 + 0.5 * n[..., 1:2])
    warm = np.array([1.0, 0.78, 0.6])
    return alb * (skyc * (sky * ao)[..., None] + (diffuse * ms * sun)[..., None] + (scatter * sun)[..., None] * warm)

def tonemap(c):
    c = c * 1.4; c = c / (1 + c)
    return np.where(c < 0.0031308, c * 12.92, 1.055 * np.power(np.clip(c, 0, 1), 1 / 2.4) - 0.055)

def img(a): return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))

def label(im, text):
    d = ImageDraw.Draw(im); d.rectangle([0, 0, 7 * len(text) + 8, 16], fill=(0, 0, 0)); d.text((4, 2), text, fill=(235, 225, 200)); return im

def row(ims, gap=8):
    h = max(i.height for i in ims); w = sum(i.width for i in ims) + gap * (len(ims) - 1)
    out = Image.new('RGB', (w, h), (22, 24, 27)); x = 0
    for i in ims: out.paste(i, (x, (h - i.height) // 2)); x += i.width + gap
    return out

def cylinder(R, ppm, hm, age, l=SIDE, **kw):
    wpx = int(2 * R * ppm) + 2; hpx = int(hm * ppm)
    xs = (np.arange(wpx) + 0.5 - wpx / 2) / ppm; ys = (np.arange(hpx) + 0.5) / ppm
    X, Y = np.meshgrid(xs, ys)
    inside = np.abs(X) < R
    s = np.clip(X / R, -1, 1); a = np.arcsin(s)
    n0 = np.stack([s, np.zeros_like(s), np.cos(a)], -1)
    t = np.broadcast_to(np.array([0, -1.0, 0]), n0.shape)
    rw = np.stack([np.cos(a), np.zeros_like(s), -s], -1)
    rounds = max(np.floor(2 * np.pi * R / 0.25 + 0.5), 1)
    u = a / (2 * np.pi) * rounds; v = -Y / 0.5
    du = (1 / ppm) / np.maximum(np.cos(a), 0.05) / (2 * np.pi * R) * rounds
    dv = np.full_like(u, (1 / ppm) / 0.5)
    view = np.broadcast_to(np.array([0, 0, 1.0]), n0.shape)
    c = shade(u, v, du, dv, n0, t, rw, np.full_like(u, age), l, view=view, **kw)
    out = tonemap(c); out[~inside] = [0.09, 0.1, 0.11]
    return out

def flat_tile(layer, l=SIDE):
    u, v = np.meshgrid((np.arange(W) + 0.5) / W, (np.arange(H) + 0.5) / H)
    n0 = np.broadcast_to(np.array([0, 0, 1.0]), u.shape + (3,))
    t = np.broadcast_to(np.array([0, -1.0, 0]), u.shape + (3,)); rw = np.broadcast_to(np.array([1.0, 0, 0]), u.shape + (3,))
    return tonemap(shade(u, -v, np.full_like(u, 1 / W), np.full_like(u, 1 / H), n0, t, rw, np.full_like(u, AGES[layer]), l))

def photo_crop(ph, box, src, dst):
    photo = Image.open(ph + '/' + LAWN_PHOTO).convert('RGB')
    c = photo.crop(box); k = dst / src
    return c.resize((int(c.width * k), int(c.height * k)), Image.LANCZOS)

if __name__ == '__main__':
    dump, ph, out = sys.argv[1], sys.argv[2], sys.argv[3]
    tag = sys.argv[4] if len(sys.argv) > 4 else 'tile'
    load(dump)
    row([label(img(flat_tile(k)), 't=%.2f' % AGES[k]) for k in range(4)]).save(out + '/%s-layers.png' % tag)
    WIN = 280
    pw = photo_crop(ph, (160, 200, 560, 860), 577, WIN)
    row([label(pw, 'photo'), label(img(cylinder(0.35, WIN, pw.height / WIN, 1.0)), 'old trunk t=1'),
         label(img(cylinder(0.35, WIN, pw.height / WIN, 0.85)), 't=0.85'),
         label(img(cylinder(0.35, WIN, pw.height / WIN, 1.0, wrap=0.5, rough=0.8)), 't=1, scatter+rough')]).save(out + '/%s-far.png' % tag)
    CL = 800
    pc = photo_crop(ph, (210, 470, 210 + 317, 470 + 231), 577, CL)
    row([label(pc, 'photo, upscaled'), label(img(cylinder(0.35, CL, 0.40, 1.0)[:, 180:620]), 't=1, close')]).save(out + '/%s-close.png' % tag)
    ims = []
    for r in [0.02, 0.04, 0.08, 0.16, 0.30, 0.45]:
        age = float(np.clip(np.log(r / 0.004) / np.log(0.45 / 0.004), 0, 1))
        ims.append(label(img(cylinder(r, WIN, 1.2, age)), '%d cm' % round(r * 200)))
    row(ims).save(out + '/%s-ages.png' % tag)
