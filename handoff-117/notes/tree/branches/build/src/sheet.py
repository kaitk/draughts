# Task 117 step one: the Goose generator's bare tree (tools/tree_dump's tree-none-whole.bin)
# drawn beside the photo crops, for the elbows (0, 1-2, 3 a hero limb), the gravity layer
# and the shedding. Each dump drawn whole from the front and one hero limb from its side.
#   python sheet.py OUT.jpg TITLE PHOTO DIR:LABEL [DIR:LABEL ...]
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'src'))
from draw import load_dump, render   # noqa: E402

try:
    FONT = ImageFont.truetype('arial.ttf', 22)
    SMALL = ImageFont.truetype('arial.ttf', 16)
except OSError:
    FONT = SMALL = None

WHOLE = (560, 600)
LIMB = (560, 420)


def subtree(limbs, root):
    keep = np.zeros(len(limbs), bool); keep[root] = True
    for i in range(root + 1, len(limbs)):
        p = int(limbs[i, 3])
        if p >= 0 and keep[p]:
            keep[i] = True
    return keep


def segs_of(limbs, keep):
    idx = []
    for i in np.nonzero(keep)[0]:
        f, c = int(limbs[i, 0]), int(limbs[i, 1])
        idx.extend(range(f, f + c))
    return np.array(idx, int)


def hero(seg, limbs, pick):
    """The hero limb (level 1) leaving the trunk 4-9 m up with the most wood, the pick-th."""
    foot = seg[0, 0:3]
    cands = []
    for i in range(len(limbs)):
        if int(limbs[i, 2]) != 1 or int(limbs[i, 3]) != 0:
            continue
        s = seg[int(limbs[i, 0])]
        h = s[1] - foot[1]
        if not (3.5 < h < 9.5):
            continue
        k = segs_of(limbs, subtree(limbs, i))
        vol = np.sum(np.pi * ((seg[k, 6] + seg[k, 7]) / 2) ** 2 * np.linalg.norm(seg[k, 3:6] - seg[k, 0:3], axis=1))
        cands.append((vol, i))
    cands.sort(reverse=True)
    return cands[min(pick, len(cands) - 1)][1]


def limb_view(seg, limbs, root):
    k = segs_of(limbs, subtree(limbs, root))
    s = seg[k].copy()
    base = seg[int(limbs[root, 0]), 0:3]
    tip = s[:, 3:6].mean(axis=0)
    d = tip - base
    yaw = math.degrees(math.atan2(d[0], d[2]))
    # Seen from its side: the camera looks across the limb's level way.
    return s, yaw - 90.0


def label(im, text, small=None):
    d = ImageDraw.Draw(im)
    d.text((10, 8), text, fill=(40, 42, 48), font=FONT)
    if small:
        d.text((10, 36), small, fill=(70, 72, 80), font=SMALL)


def column(dirpath, text, pick):
    seg, limbs, _ = load_dump(os.path.join(dirpath, 'tree-none-whole.bin'))
    box = np.array([[-12.0 + seg[0, 0], seg[0, 1] - 0.3, 0.0], [12.0 + seg[0, 0], seg[0, 1] + 23.5, 0.0]])
    w = render(seg, None, *WHOLE, frame_pts=box)
    label(w, text, f'{len(seg)} segments')
    root = hero(seg, limbs, pick)
    s, yaw = limb_view(seg, limbs, root)
    l = render(s, None, *LIMB, yaw=yaw)
    label(l, 'a hero limb, from its side')
    out = Image.new('RGB', (WHOLE[0], WHOLE[1] + LIMB[1] + 6), (22, 24, 27))
    out.paste(w, (0, 0)); out.paste(l, (0, WHOLE[1] + 6))
    return out


def photo_column(paths):
    h = WHOLE[1] + LIMB[1] + 6
    out = Image.new('RGB', (WHOLE[0], h), (22, 24, 27))
    each = (h - 6 * (len(paths) - 1)) // len(paths)
    y = 0
    for p in paths:
        im = Image.open(p).convert('RGB')
        im.thumbnail((WHOLE[0], each))
        out.paste(im, ((WHOLE[0] - im.size[0]) // 2, y))
        y += each + 6
    return out


def main():
    out, title, photos = sys.argv[1], sys.argv[2], sys.argv[3].split(',')
    pick = 0
    cols = [photo_column(photos)]
    for a in sys.argv[4:]:
        if a.startswith('pick='):
            pick = int(a[5:]); continue
        d, text = a.split(':', 1)
        cols.append(column(d, text, pick))
    W = sum(c.size[0] for c in cols) + 8 * (len(cols) - 1)
    H = cols[0].size[1] + 44
    sheet = Image.new('RGB', (W, H), (22, 24, 27))
    ImageDraw.Draw(sheet).text((12, 10), title, fill=(220, 218, 210), font=FONT)
    x = 0
    for c in cols:
        sheet.paste(c, (x, 44)); x += c.size[0] + 8
    sheet.save(out, quality=90)
    print(out, sheet.size)


if __name__ == '__main__':
    main()
