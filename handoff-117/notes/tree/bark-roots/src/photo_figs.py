# Photo crops for the page: the flares and roots, and the collars, from the brief's photos.
import sys, glob
from PIL import Image, ImageDraw
PH, OUT = sys.argv[1], sys.argv[2]
f = {k: Image.open(glob.glob(PH + '/' + p + '*.jpg')[0]).convert('RGB') for k, p in
     [('moss', 'AbTL'), ('diamond', 'IVVn'), ('park', 'QkYk'), ('lichen', 'YCdj'), ('plates', 'tRrO')]}
def crop(k, box, h=340):
    c = f[k].crop(box); return c.resize((int(c.width * h / c.height), h), Image.LANCZOS)
def row(ims, gap=8):
    W = sum(i.width for i in ims) + gap * (len(ims) - 1); out = Image.new('RGB', (W, ims[0].height), (22, 24, 27)); x = 0
    for i in ims: out.paste(i, (x, 0)); x += i.width + gap
    return out
row([crop('diamond', (0, 560, 685, 1024)), crop('moss', (380, 450, 1700, 1400)), crop('lichen', (250, 500, 2000, 1500)),
     crop('park', (360, 330, 720, 620))]).save(OUT + '/photo-flares.jpg', quality=88)
row([crop('park', (200, 40, 700, 330)), crop('plates', (0, 0, 520, 390)), crop('diamond', (230, 0, 685, 300))]).save(OUT + '/photo-junctions.jpg', quality=88)
