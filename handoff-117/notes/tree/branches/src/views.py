# The three views every method is drawn in: the whole tree from the front (the same box
# for all, 24 x 24 m), one low limb from its side, and one twig fan from its side. A limb
# and a fan are laid out with their weight toward the right; gravity off and on share one
# camera, fitted to both, with a bar of 1 m (limb) or 20 cm (fan) for the scale.
import numpy as np
from PIL import ImageDraw
from draw import render
from graph import pick_limb, pick_fan, laid_out, Crown

WHOLE = (640, 660, np.array([[-12.0, -0.3, 0.0], [12.0, 23.5, 0.0]]))
SIZES = dict(limb=(900, 640), fan=(700, 560))


def view_whole(t):
    w, h, box = WHOLE
    return render(t.segments(), None, w, h, frame_pts=box)


def _laid(t, root):
    keep = t.subtree(root)
    lt = laid_out(t, keep, root)
    return lt, keep


def view_pair(ts, roots, which):
    """Each (tree, root) laid out and drawn with one camera fitted to all of them."""
    w, h = SIZES[which]
    laid = [_laid(t, r) for t, r in zip(ts, roots)]
    pts = np.vstack([lt.pos[keep] for lt, keep in laid] + [np.zeros((1, 3))])
    lo = pts.min(axis=0); hi = pts.max(axis=0)
    # Keep the picture's shape: widen the short side about the middle.
    mid = (lo + hi) / 2; dx = hi[0] - lo[0]; dy = hi[1] - lo[1]
    if dx / dy < w / h: dx = dy * w / h
    else: dy = dx * h / w
    box = np.array([[mid[0] - dx / 2, mid[1] - dy / 2, 0], [mid[0] + dx / 2, mid[1] + dy / 2, 0]])
    s = w * 0.92 / dx
    bar = 1.0 if which == 'limb' else 0.2
    out = []
    for lt, keep in laid:
        im = render(lt.segments(keep), None, w, h, frame_pts=box)
        d = ImageDraw.Draw(im)
        x0, y0 = 14, h - 16
        d.line([(x0, y0), (x0 + bar * s, y0)], fill=(90, 90, 96), width=3)
        d.text((x0, y0 - 16), '1 m' if bar == 1.0 else '20 cm', fill=(90, 90, 96))
        out.append(im)
    return out


def limb_root(t):
    return pick_limb(t)


def fan_root(t, crown=None):
    crown = crown or Crown()
    r = pick_fan(t, shell=crown.radius)
    if r < 0:
        r = pick_fan(t)
    return r
