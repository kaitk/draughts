# Task 117 round two: tools/tree_dump's trees drawn beside the photo crops, one column a
# dump, one row a view (step one's sheet with more views and Windows paths).
#   python sheet.py OUT.jpg TITLE PHOTO[,PHOTO] VIEWS LABEL=DIR [LABEL=DIR ...]
# VIEWS: comma-separated of front (the bare tree from the room's side), side (from 90°),
# limb (the largest hero limb 3.5-9.5 m up, from its side), fan (the second), leafy (the
# tree with its leaves, front), crown (the culled tree with its leaves from below).
import sys, os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

NOTES = 'C:/Users/kait/projects/draughts/build/notes/tree'
sys.path.insert(0, NOTES + '/branches/src')
sys.path.insert(0, NOTES + '/branches/build/src')
from draw import load_dump, render   # noqa: E402
from sheet import hero, limb_view   # noqa: E402

FONT = ImageFont.truetype('arial.ttf', 22)
SMALL = ImageFont.truetype('arial.ttf', 16)
W = 520
SIZES = {'front': 560, 'side': 560, 'limb': 400, 'fan': 400, 'leafy': 560, 'crown': 520}


def label(im, text, small=None):
    d = ImageDraw.Draw(im)
    d.text((10, 8), text, fill=(40, 42, 48), font=FONT)
    if small:
        d.text((10, 36), small, fill=(70, 72, 80), font=SMALL)


def box_of(seg):
    return np.array([[-12.0 + seg[0, 0], seg[0, 1] - 0.3, seg[0, 2]], [12.0 + seg[0, 0], seg[0, 1] + 23.5, seg[0, 2]]])


def view(d, v, text):
    h = SIZES[v]
    seg, limbs, cards = load_dump(os.path.join(d, 'tree-none-whole.bin'))
    if v == 'front':
        im = render(seg, None, W, h, frame_pts=box_of(seg))
        label(im, text, f'{len(seg)} segments')
    elif v == 'side':
        b = box_of(seg)
        b[:, 2] = b[:, 0] - seg[0, 0] + seg[0, 2]
        b[:, 0] = seg[0, 0]
        im = render(seg, None, W, h, yaw=90.0, frame_pts=b)
        label(im, 'from the side')
    elif v in ('limb', 'fan'):
        root = hero(seg, limbs, 0 if v == 'limb' else 1)
        s, yaw = limb_view(seg, limbs, root)
        im = render(s, None, W, h, yaw=yaw)
        label(im, 'a hero limb, from its side' if v == 'limb' else 'another limb, from its side')
    elif v == 'leafy':
        im = render(seg, cards, W, h, frame_pts=box_of(seg), stalks=False)
        label(im, text, f'{len(cards)} leaves')
    elif v == 'crown':
        seg, limbs, cards = load_dump(os.path.join(d, 'tree-none-culled.bin'))
        im = render(seg, cards, W, h, pitch=-35.0, stalks=False)
        label(im, 'culled, from below', f'{len(cards)} leaves')
    return im


def photo_column(paths, height):
    out = Image.new('RGB', (W, height), (22, 24, 27))
    each = (height - 6 * (len(paths) - 1)) // len(paths)
    y = 0
    for p in paths:
        im = Image.open(p).convert('RGB')
        im.thumbnail((W, each))
        out.paste(im, ((W - im.size[0]) // 2, y))
        y += each + 6
    return out


def main():
    out, title, photos, views = sys.argv[1], sys.argv[2], sys.argv[3].split(','), sys.argv[4].split(',')
    height = sum(SIZES[v] for v in views) + 6 * (len(views) - 1)
    cols = [photo_column(photos, height)]
    for a in sys.argv[5:]:
        text, d = a.split('=', 1)
        col = Image.new('RGB', (W, height), (22, 24, 27))
        y = 0
        for v in views:
            col.paste(view(d, v, text), (0, y))
            y += SIZES[v] + 6
        cols.append(col)
    sheet = Image.new('RGB', (sum(c.size[0] for c in cols) + 8 * (len(cols) - 1), height + 44), (22, 24, 27))
    ImageDraw.Draw(sheet).text((12, 10), title, fill=(220, 218, 210), font=FONT)
    x = 0
    for c in cols:
        sheet.paste(c, (x, 44))
        x += c.size[0] + 8
    sheet.save(out, quality=88)
    print(out, sheet.size)


if __name__ == '__main__':
    main()
