# Quick look: snapshots of the grown tile at several ages, height and lit from the side.
import sys, numpy as np
from PIL import Image
import bark
from bark import snapshot, normals

D = sys.argv[1]
crack = np.load(D + '/crack.npy'); tough = np.load(D + '/tough.npy')
ages = [0.3, 0.5, 0.65, 0.8, 1.0]
L = np.array([0.85, 0.15, 0.5]); L /= np.linalg.norm(L)    # sun from the side, low
cols = []
for t in ages:
    h, alb, ao = snapshot(crack, tough, t)
    n = normals(h)
    ndl = np.clip(n @ L, 0, 1)
    c = alb * (0.35 * ao[..., None] + 1.4 * ndl[..., None])
    img = np.clip(c ** (1 / 2.2), 0, 1)
    hv = (h - h.min()) / max(h.max() - h.min(), 1e-6)
    cols.append(np.concatenate([img, np.repeat(hv[..., None], 3, -1)], 1))
    print('t %.2f height %.1f..%.1f mm, ao min %.2f mean %.2f' % (t, h.min(), h.max(), ao.min(), ao.mean()))
out = np.concatenate(cols, 1)
Image.fromarray((out * 255).astype(np.uint8)).save(D + '/look-tile.png')
