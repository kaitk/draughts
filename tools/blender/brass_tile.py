# The antique brass's concept tile (task 129) and the levels' solver. The game makes its own
# tile (room_shell::brass_tile, the export's brass_tile.ppm), which the Cycles material and
# --levels now take; this one is kept for the concept's micro-finish (brass_height.png, which
# brass_check.py's --micro reads). 64 mm square, periodic gradient noise. Writes OUT/brass_tile.png
# (8-bit RGB, linear data: r the mottling as a rank, 0 to 1 evenly; g the speckles; b unused)
# and OUT/brass_height.png (16-bit grey, the micro-finish's height).
#
#   python3 tools/blender/brass_tile.py [--out build/scratch/brass] [--size 2048]
#   python3 tools/blender/brass_tile.py --levels build/blender/brass_tile.ppm   # brass_model.LEVELS from the game's tile
#
# The bands (the specification's, at 64 mm a tile): clouds 4-13 mm (periods 5, 9, 16),
# blots 1.3-2.7 mm (24, 48) and flecks 0.33-0.67 mm (96, 192) under a slight warp, ranked
# together; the speckles' pits about 0.2-0.4 mm (150, 300), the micro-finish 0.06-0.1 mm
# (640, 1024).
import os
import sys

import numpy as np
from PIL import Image

TILE_MM = 64.0


def flags():
    f = {"out": "build/scratch/brass", "size": "2048", "seed": "129"}
    a = sys.argv[1:]
    for i in range(0, len(a), 2):
        f[a[i][2:]] = a[i + 1]
    return f


def noise(x, y, period, rng):
    # Gradient noise on the torus: x, y in tiles, `period` cells a tile; about -0.7 to 0.7.
    ang = rng.uniform(0, 2 * np.pi, (period, period))
    gx, gy = np.cos(ang), np.sin(ang)
    px, py = x * period, y * period
    ix, iy = np.floor(px).astype(np.int64), np.floor(py).astype(np.int64)
    fx, fy = px - ix, py - iy
    ux = fx * fx * fx * (fx * (fx * 6 - 15) + 10)
    uy = fy * fy * fy * (fy * (fy * 6 - 15) + 10)

    def corner(dx, dy):
        cx, cy = (ix + dx) % period, (iy + dy) % period
        return gx[cy, cx] * (fx - dx) + gy[cy, cx] * (fy - dy)

    a = corner(0, 0) + ux * (corner(1, 0) - corner(0, 0))
    b = corner(0, 1) + ux * (corner(1, 1) - corner(0, 1))
    return a + uy * (b - a)


def fbm(x, y, periods, amps, rng):
    s = sum(a * noise(x, y, p, rng) for p, a in zip(periods, amps))
    return s / np.sqrt(sum(a * a for a in amps))


def unit(v):
    return (v - v.mean()) / v.std()


def rank(v):
    # Each value's place in the sorted field, 0 to 1: the coverage of the states is then a
    # threshold on it.
    order = np.argsort(v, axis=None)
    r = np.empty(v.size)
    r[order] = (np.arange(v.size) + 0.5) / v.size
    return r.reshape(v.shape)


def levels(tile_path):
    # Solves brass.LEVELS from the tile, without the sink: level 1 the specification's mix, level 5
    # bronze B's mean; between them the mean's luminance steps evenly in log and its hue moves
    # from the one to the other by the tarnish's tint.
    import importlib.util
    spec = importlib.util.spec_from_file_location("brass_model", os.path.join(os.path.dirname(__file__), "brass_model.py"))
    bm = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(bm)
    t = np.asarray(Image.open(tile_path)).astype(float)[::2, ::2] / 255
    lum = np.array([0.2126, 0.7152, 0.0722])
    lin = np.array([((c + 0.055) / 1.055) ** 2.4 for c in bm.BRONZE_B])

    def mean(cover, gain, tint):
        return bm.colour(t[..., 0], t[..., 1], cover, gain, tint).reshape(-1, 3).mean(0)

    first = mean(bm.COVER[1], 1.0, np.ones(3))
    for lv in range(1, 6):
        f = (lv - 1) / 4
        target = (first @ lum) * ((lin @ lum) / (first @ lum)) ** f
        hue = np.exp(np.log(first / (first @ lum)) * (1 - f) + np.log(lin / (lin @ lum)) * f)
        tint = np.ones(3)
        for _ in range(6):
            lo, hi = 0.01, 2.0
            for _ in range(40):
                gain = 0.5 * (lo + hi)
                lo, hi = (lo, gain) if mean(bm.COVER[lv], gain, tint) @ lum > target else (gain, hi)
            m = mean(bm.COVER[lv], gain, tint)
            if lv == 1:
                break
            tint = tint * hue / (m / (m @ lum))
        s = np.where(m <= 0.0031308, 12.92 * m, 1.055 * m ** (1 / 2.4) - 0.055)
        e, ta, d = bm.weights(t[..., 0], bm.COVER[lv])
        # On the hardware the rank is sunk (bm.sunk): its far mean colour, roughness, metalness.
        r = bm.sunk(t[..., 0])
        far = bm.colour(r, t[..., 1], bm.COVER[lv], gain, tint).reshape(-1, 3).mean(0)
        e, ta, d = bm.weights(r, bm.COVER[lv])
        rough = (e * bm.ROUGH[0] + ta * bm.ROUGH[1] + d * bm.ROUGH[2] + bm.SPECKLE_ROUGH * t[..., 1]).mean()
        metal = (e * bm.METAL[0] + ta * bm.METAL[1] + d * bm.METAL[2]).mean()
        print(f"    {lv}: ({bm.COVER[lv][0]:.2f}, {bm.COVER[lv][1]:.2f}, {gain:.3f}, ({tint[0]:.3f}, {tint[1]:.3f}, {tint[2]:.3f}),"
              f" ({m[0]:.4f}, {m[1]:.4f}, {m[2]:.4f}), ({far[0]:.4f}, {far[1]:.4f}, {far[2]:.4f}), ({rough:.3f}, {metal:.3f})),"
              f"   # sRGB {s[0]:.2f}, {s[1]:.2f}, {s[2]:.2f}")


def main():
    F = flags()
    if "levels" in F:
        levels(F["levels"])
        return
    n = int(F["size"])
    rng = np.random.default_rng(int(F["seed"]))
    t = (np.arange(n) + 0.5) / n
    x, y = np.meshgrid(t, t)
    clouds = fbm(x, y, (5, 9, 16), (1.0, 0.6, 0.4), rng)
    # A slight warp makes the blots irregular (period 20: 3 mm, by about 0.13 mm).
    wx = x + 0.002 * unit(fbm(x, y, (20, 40), (1.0, 0.5), rng))
    wy = y + 0.002 * unit(fbm(x, y, (20, 40), (1.0, 0.5), rng))
    blots = fbm(wx, wy, (24, 48), (1.0, 0.7), rng)
    flecks = fbm(wx, wy, (96, 192), (1.0, 0.6), rng)
    mottle = rank(0.6 * unit(clouds) + 0.7 * unit(blots) + unit(flecks))
    fine = unit(fbm(x, y, (150, 300), (1.0, 0.5), rng))
    speckle = np.clip((fine - 2.0) / 0.5, 0.0, 1.0)  # about 1 per cent, soft-edged
    micro = unit(fbm(x, y, (640, 1024), (1.0, 0.7), rng))
    height = np.clip(0.5 + 0.16 * micro, 0.0, 1.0)
    out = F["out"]
    os.makedirs(out, exist_ok=True)
    rgb = np.stack([mottle, speckle, np.zeros_like(mottle)], -1)
    Image.fromarray(np.round(rgb * 255).astype(np.uint8), "RGB").save(os.path.join(out, "brass_tile.png"))
    Image.fromarray(np.round(height * 65535).astype(np.uint16)).save(os.path.join(out, "brass_height.png"))
    print(f"brass tile {n}² ({TILE_MM / n * 1000:.0f} µm a texel); speckles {100 * (speckle > 0.5).mean():.1f}%")


if __name__ == "__main__":
    main()
