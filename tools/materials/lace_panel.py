#!/usr/bin/env python3
"""The lace a curtain panel samples: one way of the lace library's field and its hem in
one mask, the field's tile (1024 rows, 0.56 m) over the hem's strip (384 rows, 0.21 m), at
one scale, 1024 x 1408 L8.

    python3 tools/materials/lace_panel.py LIBRARY TAG OUT.png

LIBRARY is the lace library's folder (build/notes/lace-library), TAG a way in it (f2, f,
d): its TAG_mask.png (the field's tile, as the baker boxed it) and TAG_hem_full.png and
TAG_motif_full.png (the hem's R lace, G cloth, B field at full detail), put together as
lace_crisp.views does for its hem previews, then boxed to the field's scale. The hem's
top row continues the field's first, so shaders::ROOM_FRAG reads down the field's tile and
on into the hem with no seam; the scallops are the hem's own zero coverage.
"""

import os
import sys

import numpy as np

import common as cm
import lace

HEM_H = 1536          # lace_crisp.HEM_H: the hem strip's rows at full detail


def main(lib, tag, out):
    field = cm.load(os.path.join(lib, tag, f'{tag}_mask.png'), 'L')
    hem = cm.load(os.path.join(lib, tag, f'{tag}_hem_full.png'))
    motif = cm.load(os.path.join(lib, tag, f'{tag}_motif_full.png'), 'L')
    net = lace.net_tile()
    r, g, b = hem[..., 0], hem[..., 1], hem[..., 2]
    netb = lace.tiled(net, lace.NET_REPEAT, -(-HEM_H // lace.NET_SIZE))[:HEM_H]
    strip = g * np.maximum(np.maximum(netb, r), b * motif[:HEM_H])
    strip = lace.box(strip, hem.shape[1] // field.shape[1])
    assert field.shape == (1024, 1024) and strip.shape == (384, 1024), (field.shape, strip.shape)
    cm.save(out, np.concatenate([field, strip], 0))


if __name__ == '__main__':
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    main(*sys.argv[1:])
