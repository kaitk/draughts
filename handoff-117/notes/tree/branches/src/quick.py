# A quick look at one method: whole, limb and fan, gravity off and on, side by side.
#   python quick.py MODULE OUT_PREFIX
import sys, time, importlib, gravity
from views import *
from graph import stats
from PIL import Image
m = importlib.import_module(sys.argv[1]); out = sys.argv[2]
t0 = time.perf_counter(); t = m.tree(); dt = time.perf_counter() - t0
print(stats(t), f'grow {dt*1000:.0f} ms')
b = m.tree(bend=True) if getattr(m, "ITERATIVE", False) else t.copy()
if not getattr(m, "ITERATIVE", False): gravity.bend(b)
L = limb_root(t); F = fan_root(t); print('limb', L, t.ra[L] if L > 0 else None, 'fan', F, t.ra[F] if F > 0 else None)
im = Image.new('RGB', (1280, 660)); im.paste(view_whole(t), (0, 0)); im.paste(view_whole(b), (640, 0)); im.save(out + '-whole.png')
for which, R, W, H in (('limb', L, 900, 640), ('fan', F, 700, 560)):
    if R > 0:
        R2 = R if not getattr(m, "ITERATIVE", False) else (limb_root(b) if which == 'limb' else fan_root(b))
        a, c = view_pair([t, b], [R, R2], which)
        im = Image.new('RGB', (W * 2, H)); im.paste(a, (0, 0)); im.paste(c, (W, 0)); im.save(out + f'-{which}.png')
