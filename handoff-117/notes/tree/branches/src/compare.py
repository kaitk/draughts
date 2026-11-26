# Task 117's comparison: four methods, each grown with the same seed in the same envelope,
# drawn whole, one limb and one twig fan, gravity off and on (gravity.py), into ../img/c-*.
# Prints the counts and the Python times for compare.html.
#   python compare.py
import os, sys, time, json
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import gravity, m_sc, m_pal, m_wp, m_gn
from views import view_whole, view_pair, limb_root, fan_root
from graph import stats

OUT = os.path.join(os.path.dirname(__file__), '..', 'img')
SEED = 7
try:
    FONT = ImageFont.truetype('arial.ttf', 20)
except OSError:
    FONT = None


def timed(f, *a, **k):
    t0 = time.perf_counter(); r = f(*a, **k); return r, time.perf_counter() - t0


def save_pair(ims, name):
    w, h = ims[0].size
    im = Image.new('RGB', (w * 2 + 8, h), (22, 24, 27))
    im.paste(ims[0], (0, 0)); im.paste(ims[1], (w + 8, 0))
    d = ImageDraw.Draw(im)
    for k, text in enumerate(('gravity off', 'gravity on')):
        d.text((k * (w + 8) + 12, 10), text, fill=(60, 62, 68), font=FONT)
    im.save(os.path.join(OUT, name), quality=90)


def run(key, grow_off, grow_on, fan_off=None, fan_on=None, iterative=False):
    off, t_off = timed(grow_off)
    on, t_on = timed(grow_on, off)
    rec = dict(off=stats(off), on=stats(on), t_grow=t_off, t_on=t_on)
    save_pair([view_whole(off), view_whole(on)], f'c-{key}-whole.jpg')
    L = limb_root(off); L2 = limb_root(on) if iterative else L
    save_pair(view_pair([off, on], [L, L2], 'limb'), f'c-{key}-limb.jpg')
    if fan_off:
        fo, t_f = timed(fan_off); fn = fan_on(fo)
        save_pair(view_pair([fo, fn], [1, 1], 'fan'), f'c-{key}-fan.jpg')
        rec['fan'] = dict(segments=len(fo.pos) - 1, t=t_f)
    else:
        F = fan_root(off); F2 = fan_root(on) if iterative else F
        save_pair(view_pair([off, on], [F, F2], 'fan'), f'c-{key}-fan.jpg')
    print(key, json.dumps(rec, default=float))
    return rec


def bent(t):
    b = t.copy(); gravity.bend(b); return b


def main():
    recs = {}
    which = sys.argv[1:] or ['sc', 'pal', 'wp', 'gn']
    if 'sc' in which:
        recs['sc'] = run('sc', lambda: m_sc.tree(SEED), bent, lambda: m_sc.fan(SEED), bent)
    if 'pal' in which:
        recs['pal'] = run('pal', lambda: m_pal.tree(SEED), lambda _: m_pal.tree(SEED, bend=True),
                          lambda: m_pal.fan(SEED), lambda _: m_pal.fan(SEED, bend=True), iterative=True)
    if 'wp' in which:
        recs['wp'] = run('wp', lambda: m_wp.tree(SEED), bent)
        # Today's generator with its own sag heuristic, for reference.
        today = m_wp.tree(SEED, P=dict(sag=True, breaks=False))
        Image.fromarray(np.asarray(view_whole(today))).save(os.path.join(OUT, 'c-wp-today.jpg'), quality=90)
    if 'gn' in which:
        recs['gn'] = run('gn', lambda: m_gn.tree(SEED), bent)
    # The gravity pass's own time on the largest tree.
    t = m_wp.tree(SEED); _, tb = timed(gravity.bend, t)
    print('gravity pass on', len(t.pos), 'nodes:', f'{tb:.2f} s')
    path = os.path.join(os.path.dirname(__file__), 'times.json')
    old = json.load(open(path)) if os.path.exists(path) else {}
    old.update(recs); old['gravity_pass'] = dict(nodes=len(t.pos), t=tb)
    json.dump(old, open(path, 'w'), indent=1, default=float)


if __name__ == '__main__':
    main()

