# The current tree (tools/tree_dump's tree-none-whole.bin) drawn bare, whole and one limb,
# and one leafy branch, for the comparison with the photos.
import sys, numpy as np
from draw import load_dump, render
D, OUT = sys.argv[1], sys.argv[2]
seg, limbs, cards = load_dump(D + '/tree-none-whole.bin')
print('segments', len(seg), 'limbs', len(limbs), 'cards', len(cards))
render(seg, None, 620, 1000).save(OUT + '/current-bare.png')
# The descendants of one limb.
parent = limbs[:, 3].astype(int); level = limbs[:, 2].astype(int)
def descendants(root):
    keep = np.zeros(len(limbs), bool); keep[root] = True
    for i in range(len(limbs)):  # parents come before children
        if parent[i] >= 0 and keep[parent[i]]: keep[i] = True
    return keep
def segs_of(keep):
    idx = [np.arange(int(limbs[i, 0]), int(limbs[i, 0] + limbs[i, 1])) for i in np.nonzero(keep)[0]]
    return np.concatenate(idx)
lv1 = np.nonzero(level == 1)[0]
# the longest limb that leaves the trunk low
lengths = [np.linalg.norm(seg[int(limbs[i,0]):int(limbs[i,0]+limbs[i,1]), 3:6] - seg[int(limbs[i,0]):int(limbs[i,0]+limbs[i,1]), 0:3], axis=1).sum() for i in lv1]
root = lv1[int(np.argmax(lengths))]
s1 = seg[segs_of(descendants(root))]
render(s1, None, 1000, 800, yaw=0).save(OUT + '/current-limb.png')
# a level-3 branchlet with its leaves (cards whose foot lies on its twigs)
lv3 = [i for i in np.nonzero(level == 3)[0] if descendants(i).sum() > 6]
root3 = lv3[len(lv3) // 3]
k = descendants(root3); s3 = seg[segs_of(k)]
tw = s3[s3[:, 8] == 4]
foot = cards[:, 0:3]
near = np.zeros(len(cards), bool)
for a, b in zip(tw[:, 0:3], tw[:, 3:6]):
    ab = b - a; t = np.clip(((foot - a) @ ab) / max(ab @ ab, 1e-9), 0, 1)
    near |= np.linalg.norm(foot - (a + np.outer(t, ab)), axis=1) < 0.01
print('branchlet', len(s3), 'segments', near.sum(), 'leaves')
pts = np.vstack([s3[:, 0:3], s3[:, 3:6], cards[near, 3:6]])
render(s3, cards[near], 1000, 760, yaw=20, pitch=-15, frame_pts=pts).save(OUT + '/current-leafy.png')
