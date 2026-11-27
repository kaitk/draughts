# The light tuner's camera on a Cycles render: the picture `--light physical` would make of
# Cycles' light, for side-by-side comparisons where only the light differs (task 122).
#
#   python3 tools/blender/app_camera.py LIGHT --log TUNER_LOG --out OUT.png
#       [--ev EV | --exposure K] [--units U] [--grade autumn|none] [--white R,G,B]
#       [--look SLOPE,OFFSET,POWER] [--saturation S] [--compare TUNER.png]
#
# LIGHT is Cycles' combined light: scene.py's OUT-combined.npy, an .npz with `comb`, or the
# EXR itself (read through Blender's own Python, which has OpenImageIO; $BLENDER_PYTHON or
# the first under /Applications/Blender.app). Or the tuner's own linear light from
# `--tone-probe K` shots, `--probe K:PNG,K:PNG,...` in place of LIGHT: each pixel from the
# largest K under white, so the darks keep their levels (64, 4 and 0.0625 cover the room).
#
# The camera: the tuner's log line "the camera's meter M, its exposure K over Frame's F: EV E"
# (--log) gives the exposure. The tuner's linear light (the HDR target) is the light times
# F (Frame's exposure and the room's), so a probe is exposed by K, and Cycles' light by
# U × 2^E. U, Cycles' radiance in the light's units, is 1 (--units): the export gives Cycles
# the sun's irradiance as the shaders' sun.light, and on the sunlit door (matt paint) the
# tuner's sun alone (--baked 0,0,0,0) is 1.060 of Cycles' direct light in the reference view
# and 1.053 in a second, its colour equal (R/G 2.02, B/G 0.22 against 0.23): task 122's
# 0.95, the panes' Fresnel at the slant that only Cycles has (2026-11-27). Coated surfaces
# differ by their coats, not the units (the floor 1.13 to 1.25, the stove 1.20 to 1.24).
# The season's grade (render3d::GRADES, copied below: change both together) or the flags.
#
# Then HDR_TONE_FRAG's camera_curve and agx (src/render3d/shaders/passes.goose), in its
# order: light × exposure × the white's gains; Rec.709 into AgX's inset; log2 over 0.18's
# -10 to +6.5 stops; the degree-8 polynomial; (v × slope + offset) ^ power; the saturation
# round the luminance; ^2.4; AgX's outset into Rec.709; sRGB; 8 bits. Not ported: the glow
# (strength 0.006 over AgX's white, at most 3 levels in the reference view; --glow
# 0,16,8,0.65 turns it off in the tuner), the eye's veil (off as made), the dither (half a
# level) and SMAA, which runs on the 8-bit picture (shoot the tuner with --aa msaa to
# compare like for like at the edges).
#
# --compare prints the levels against the tuner's own shot. The port's check: the tuner's
# probes (64, 4, 0.0625; --aa msaa, glow off) through this give its shot within 0.30 levels
# on average, 4 at most, in the reference and close views (build/notes/app-camera/).
import argparse
import glob
import os
import re
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

# render3d::GRADES by season: the white's gains, slope, offset, power, saturation (its ev is in
# the tuner's exposure already).
GRADES = {"autumn": ((1.3, 1.0, 0.6), (1.0, 0.0, 0.8), 1.0), "none": ((1.0, 1.0, 1.0), (1.0, 0.0, 1.0), 1.0)}
UNITS = 1.0

# HDR_TONE_FRAG's agx, its numbers as the shader writes them. PRE and POST as rows (the shader
# sums columns).
PRE = np.array([[0.5448147, 0.3737874, 0.0813979], [0.1404170, 0.7541376, 0.1054455], [0.0888104, 0.1788717, 0.7323179]])
POST = np.array([[1.9648874, -0.8559884, -0.1088990], [-0.2993134, 1.3263980, -0.0270846], [-0.1643526, -0.2381840, 1.4025366]])
POLY = [-0.008484016, 0.8965809, -15.11457, 131.6423, -557.5602, 1276.883, -1578.567, 990.8947, -248.0705]
LUMA = np.array([0.2126, 0.7152, 0.0722])


def agx(c, white, look, saturation):
    c = (c * np.asarray(white, np.float64)) @ PRE.T
    t = np.clip((np.log2(np.maximum(c, 1e-10)) + 12.47393) * (1.0 / 16.5), 0.0, 1.0)
    v = np.zeros_like(t)
    for p in reversed(POLY):
        v = v * t + p
    slope, offset, power = look
    v = np.maximum(v * slope + offset, 0.0) ** power
    lum = (v @ LUMA)[..., None]
    v = np.maximum(lum + saturation * (v - lum), 0.0) ** 2.4
    return v @ POST.T


def encode(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c < 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def decode(s):
    return np.where(s <= 0.04045, s / 12.92, ((s + 0.055) / 1.055) ** 2.4)


def blender_python():
    if os.environ.get("BLENDER_PYTHON"):
        return os.environ["BLENDER_PYTHON"]
    found = sorted(glob.glob("/Applications/Blender.app/Contents/Resources/*/python/bin/python3*"))
    if not found:
        sys.exit("app_camera: no Blender Python for the EXR; set BLENDER_PYTHON or pass scene.py's -combined.npy")
    return found[-1]


# The EXR's combined layer (a multilayer EXR is multipart: a pass a part), as scene.py reads it.
READ_EXR = """
import sys, numpy as np, OpenImageIO as oiio
inp = oiio.ImageInput.open(sys.argv[1]); part = 0
while inp.seek_subimage(part, 0):
    s = inp.spec(); names = list(s.channelnames)
    if 'Combined.R' in [n.split('.', 1)[-1] for n in names] or any(n.endswith('Combined.R') for n in names):
        k = [i for i, n in enumerate(names) if n.endswith('Combined.R')][0]
        px = np.asarray(inp.read_image(oiio.FLOAT)).reshape(s.height, s.width, s.nchannels)
        np.save(sys.argv[2], px[:, :, k:k + 3].astype(np.float32)); sys.exit(0)
    part += 1
sys.exit('no Combined layer')
"""


def cycles_light(path):
    if path.endswith(".npy"):
        return np.load(path).astype(np.float64)
    if path.endswith(".npz"):
        return np.load(path)["comb"].astype(np.float64)
    with tempfile.TemporaryDirectory() as d:
        out = os.path.join(d, "combined.npy")
        subprocess.run([blender_python(), "-c", READ_EXR, path, out], check=True)
        return np.load(out).astype(np.float64)


def merge_probes(spec):
    # Each pixel from the largest K whose reading is under white (250 of 255).
    pairs = sorted(((float(a), b) for a, b in (s.split(":", 1) for s in spec.split(","))), reverse=True)
    light, done = None, None
    for k, path in pairs:
        s = np.asarray(Image.open(path).convert("RGB")).astype(np.float64) / 255.0
        lin = decode(s) / k
        if light is None:
            light, done = lin, s.max(axis=2) < 250 / 255.0
        else:
            light = np.where(done[..., None], light, lin)
            done = done | (s.max(axis=2) < 250 / 255.0)
    return light


def tuner_camera(log):
    m = re.search(r"its exposure ([-0-9.e]+) over Frame's ([-0-9.e]+): EV ([-0-9.e]+)", open(log).read())
    if not m:
        sys.exit(f"app_camera: no camera line in {log} (the tuner prints it under --light physical)")
    return float(m.group(1)), float(m.group(3))


def floats(s, n):
    v = [float(x) for x in s.split(",")]
    assert len(v) == n, s
    return v


def main():
    a = argparse.ArgumentParser(description="The light tuner's camera on a Cycles render (see the header).")
    a.add_argument("light", nargs="?", help="Cycles' combined light: -combined.npy, .npz or .exr")
    a.add_argument("--probe", help="K:PNG,... the tuner's --tone-probe shots in place of LIGHT")
    a.add_argument("--log", help="the tuner's log, for its exposure")
    a.add_argument("--ev", type=float, help="the camera's EV (the log's 'EV'), for Cycles' light")
    a.add_argument("--exposure", type=float, help="the tone pass's exposure (the log's 'its exposure'), for probes")
    a.add_argument("--units", type=float, default=UNITS, help="Cycles' radiance in the tuner's light's units (1)")
    a.add_argument("--grade", default="autumn", choices=sorted(GRADES))
    a.add_argument("--white", help="R,G,B the white balance's gains (the grade's)")
    a.add_argument("--look", help="SLOPE,OFFSET,POWER on AgX's curve (the grade's; --grade-ev's picks change POWER)")
    a.add_argument("--saturation", type=float)
    a.add_argument("--out", required=True)
    a.add_argument("--compare", help="the tuner's shot: print the levels against it")
    f = a.parse_args()
    if (f.light is None) == (f.probe is None):
        sys.exit("app_camera: give Cycles' LIGHT or --probe")
    k, ev = tuner_camera(f.log) if f.log else (None, None)
    k = f.exposure if f.exposure is not None else k
    ev = f.ev if f.ev is not None else ev
    if f.probe:
        if k is None:
            sys.exit("app_camera: --probe needs --log or --exposure")
        c = merge_probes(f.probe) * k
    else:
        if ev is None:
            sys.exit("app_camera: Cycles' light needs --log or --ev")
        c = np.maximum(cycles_light(f.light), 0.0) * f.units * 2.0 ** ev
    white, look, saturation = GRADES[f.grade]
    white = floats(f.white, 3) if f.white else white
    look = floats(f.look, 3) if f.look else look
    saturation = f.saturation if f.saturation is not None else saturation
    pic = np.rint(encode(agx(c, white, look, saturation)) * 255.0).astype(np.uint8)
    Image.fromarray(pic).save(f.out)
    print(f"{f.out}: exposure {'%.4f' % k if f.probe else '2^%.4f × %.3f' % (ev, f.units)}, white {tuple(white)}, "
          f"look {tuple(look)}, saturation {saturation}")
    if f.compare:
        ref = np.asarray(Image.open(f.compare).convert("RGB")).astype(np.int32)
        d = np.abs(pic.astype(np.int32) - ref)
        print(f"against {f.compare}: mean {d.mean():.3f} levels, p99 {np.percentile(d, 99):.0f}, "
              f"p99.9 {np.percentile(d, 99.9):.0f}, max {d.max()}, within 2: {100 * (d.max(axis=2) <= 2).mean():.2f}%")


if __name__ == "__main__":
    main()
