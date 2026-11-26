# The bark figures: the grown tile beside today's and the photos, at the window's distance
# and close, lit from the side and under an overcast sky; and the age strip, twig to trunk.
import sys, time, numpy as np
from PIL import Image, ImageDraw
import bark, today, render
from bark import snapshot, normals, grow

OUT = sys.argv[1]
PH = sys.argv[2]           # build/notes/bark-roots (the photos)
crack = np.load(OUT + '/crack.npy'); tough = np.load(OUT + '/tough.npy')

SIDE = np.array([0.93, 0.28, 0.24]); SIDE /= np.linalg.norm(SIDE)   # low raking sun from the right
FRONT = np.array([0.35, 0.45, 0.82]); FRONT /= np.linalg.norm(FRONT)

def t_of_radius(r):
    return float(np.clip(np.log(r / 0.004) / np.log(0.45 / 0.004), 0, 1))

cache = {}
def new_maps(t):
    if t not in cache:
        h, alb, ao = snapshot(crack, tough, t)
        cache[t] = render.maps_new(h, alb, ao, normals(h))
    return cache[t]
today_maps = render.maps_today(today.tile())

def to_img(a): return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))

def label(im, text):
    d = ImageDraw.Draw(im); d.rectangle([0, 0, 8 * len(text) + 8, 18], fill=(0, 0, 0)); d.text((4, 3), text, fill=(235, 225, 200))
    return im

def row(ims, gap=8, bg=(22, 24, 27)):
    h = max(i.height for i in ims); w = sum(i.width for i in ims) + gap * (len(ims) - 1)
    out = Image.new('RGB', (w, h), bg); x = 0
    for i in ims: out.paste(i, (x, (h - i.height) // 2)); x += i.width + gap
    return out

photo = {k: Image.open(PH + '/' + f).convert('RGB') for k, f in [
    ('diamond', 'IVVnBQE6sVxjpRlsZrqUHe83OMLkxXoMiXOvWz3HAtdKbFRNpgTQRrLZ9mvxszqUyaJdn-5TaQAEbbL10vdpodwhntQ4t-fqqElQsxetSzCFaAgdG8X9P2qrrSbdP1fAAjzIm6PjaS1pXqWXvxFK86ydOflseDlbY_we9PuA19pJMINLdqe4ySzkjkoCRg2q.jpg'),
    ('plates', 'tRrOYUKReGlSRZwwwQBy0LDKTW03fPik0BPOqam3h6BkoADwlJk01XOHO_i5iAD09m13pjLFpcY0HDVK2GPFa-AxRcsstAoSfOEiXMFay3VFF-sySzhJXgD0Xhu5yTkgodRl8bauqsoX_BL00nGR1Ah1EXeyGPoMH7KQNLL3BOhAtJilXaf9mEuRzGIHCZqn.jpg'),
    ('moss', 'AbTLl1p2ML7C_q0CSb3rBiQ8GH4S4Gh6RwDjZyGXETaFuI3WvOK9aZH8eRCcVX4CSYBe6HOFBuKVmN1B817wMmSuKTBTiGSveCPHp0OPk1evWm-ktTo0k62_RdJ-RDfFm3G1JmSxpVw6xSmhEnb8lsaJA38hgVJ00lrapPP2taGdlCYJ6Jof-cl_SbVr0cX3.jpg'),
    ('lichen', 'YCdjq0gQtOLeM0DbG5ANDkL9uyhY_aopfhVCszZdPtqVs0QeFSNiCluDpZlXy2b8mg_Zvtzc2EFoVA3YFeXvGiB-ShBsmtGenh4kdpL5yf0Ed2BmY4fUz4aaMkEwxFxh36rLEoySFXplT_aJGgESbwJC807ye0TWyBubKPjSUtSIa107ryMt29fwVu0NSDK9.jpg')]}

def crop_to(im, box, ppm_src, ppm_dst):
    c = im.crop(box); k = ppm_dst / ppm_src
    return c.resize((max(int(c.width * k), 1), max(int(c.height * k), 1)), Image.LANCZOS)

# The window's distance: a 0.7 m trunk, a few metres off, about 280 px a metre.
WIN = 280
p_win = crop_to(photo['diamond'], (160, 200, 560, 860), 577, WIN)
R = 0.35; HM = p_win.height / WIN
old = new_maps(1.0)
ims = [label(p_win, 'photo, side light'),
       label(to_img(render.cylinder(today_maps, R, WIN, HM, SIDE, 'today')), 'today'),
       label(to_img(render.cylinder(old, R, WIN, HM, SIDE, 'flat')), 'new, normal only'),
       label(to_img(render.cylinder(old, R, WIN, HM, SIDE, 'std')), 'new, standard'),
       label(to_img(render.cylinder(old, R, WIN, HM, SIDE, 'high')), 'new, high'),
       label(to_img(render.cylinder(old, R, WIN, HM, FRONT, 'std', sun=0.0, sky=1.4)), 'new, overcast')]
row(ims).save(OUT + '/far.png')

# Close: half a metre off, about 1500 px a metre; the photos' crops at their own scale.
CL = 800
HM = 0.40
p_close = crop_to(photo['diamond'], (210, 470, 210 + 317, 470 + 231), 577, CL)
ims = [label(p_close, 'photo, upscaled to the same scale'),
       label(to_img(render.cylinder(today_maps, 0.35, CL, HM, SIDE, 'today')[:, 180:620]), 'today'),
       label(to_img(render.cylinder(old, 0.35, CL, HM, SIDE, 'std')[:, 180:620]), 'new, standard'),
       label(to_img(render.cylinder(old, 0.35, CL, HM, SIDE, 'high')[:, 180:620]), 'new, high (parallax shadow)')]
row(ims).save(OUT + '/close.png')

# Old bark photos from the park's maples (Estonia), the scale guessed from the trunk.
pm = crop_to(photo['moss'], (900, 120, 1450, 700), 1000, 600)
pl = crop_to(photo['lichen'], (500, 150, 1100, 750), 1000, 600)
pp = crop_to(photo['plates'], (150, 60, 470, 380), 600, 600)
row([label(pm, 'park maple, moss'), label(pl, 'park maple, lichen'), label(pp, 'old trunk, plates'),
     label(to_img(render.cylinder(old, 0.45, 600, 1.0, SIDE, 'high')[:, 140:500]), 'new, t=1, high')]).save(OUT + '/old-photos.png')

# The age strip: one tube per radius, each with its own snapshot (on the GPU: four layers
# blended by the vertex's age).
radii = [0.008, 0.02, 0.04, 0.08, 0.16, 0.30, 0.45]
for name, ppm, hm in (('ages-far', WIN, 1.4), ('ages-close', 900, 0.45)):
    ims = []
    for r in radii:
        t = t_of_radius(r)
        im = to_img(render.cylinder(new_maps(round(t, 3)), r, ppm, hm, SIDE, 'std' if name == 'ages-far' else 'high'))
        if im.width > 420: im = im.crop(((im.width - 420) // 2, 0, (im.width + 420) // 2, im.height))
        ims.append(label(im, '%d cm t=%.2f' % (round(r * 200), t)))
    row(ims).save(OUT + '/%s.png' % name)

# The tile's own channels at t = 0.6 and 1.
for t in (0.6, 1.0):
    h, alb, ao = snapshot(crack, tough, t)
    n = normals(h)
    hv = (h - h.min()) / (h.max() - h.min())
    nn = n * 0.5 + 0.5
    row([to_img(np.repeat(hv[..., None], 3, -1)), to_img(nn), to_img(np.repeat(ao[..., None], 3, -1)), to_img(alb ** (1 / 2.2) * 1.6)]).save(OUT + '/channels-%d.png' % int(t * 10))
print('done')
