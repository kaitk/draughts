#!/usr/bin/env python3
"""Make the app icon's images from its master, with ImageMagick.

    scripts/icon.py            write android/res/mipmap-*/ic_launcher_foreground.png
    scripts/icon.py --store    also the Play and Apple icons, into ~/Downloads/draughts-store/icon/

The master is design/icon/master.png, kept local (design/icon/README.md). The scene's box
is measured on it, the pixels brighter than its navy, and the box is scaled to SCENE_DP
and centred in each image, so a new master with a larger or moved scene needs no edits
here. design/icon/foreground.png, the scene alone on transparency at the master's size and
place, is used for the adaptive icon's foreground when it exists; otherwise the opaque
master is, its navy matching the background colour (android/res/values/colors.xml).

The monochrome layer is drawn by hand (android/res/drawable/ic_launcher_monochrome.xml)
from the same box: a scene that changes shape needs it redrawn.
"""
import argparse
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MASTER = ROOT / "design/icon/master.png"
FOREGROUND = ROOT / "design/icon/foreground.png"
RES = ROOT / "android/res"
STORE = Path.home() / "Downloads/draughts-store/icon"

SCENE_DP = 64          # inside the 66 dp safe zone, with a dp spare for the arc's glow
CANVAS_DP = 108        # the adaptive icon's layers
VISIBLE_DP = 72        # what a launcher shows of them, and what the store icons show
SCENE_RED = "17.6%"    # red above this is the scene; the navy stays below it
DENSITIES = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}


def magick(*args):
    return subprocess.run(["magick", *map(str, args)], check=True,
                          capture_output=True, text=True).stdout


def scene_box(master):
    """The scene's centre and its larger side, in master pixels."""
    box = magick(master, "-channel", "R", "-separate", "+channel",
                 "-threshold", SCENE_RED, "-format", "%@", "info:")
    w, h, x, y = map(int, re.fullmatch(r"(\d+)x(\d+)\+(\d+)\+(\d+)", box.strip()).groups())
    return x + w / 2, y + h / 2, max(w, h)


def render(src, box, size, scene_px, out, png):
    """src scaled so the scene's box is scene_px wide, centred in a size-px square; past
    the master's edge, its edge pixels or, for the foreground, transparency."""
    cx, cy, side = box
    out.parent.mkdir(parents=True, exist_ok=True)
    magick(src, "-virtual-pixel", "edge" if src == MASTER else "transparent",
           "-define", f"distort:viewport={size}x{size}+0+0",
           "-distort", "SRT", f"{cx},{cy} {scene_px / side} 0 {size / 2},{size / 2}",
           "+repage", "-strip", "-define", "png:exclude-chunks=date,time",
           "-define", "png:compression-level=9",
           f"{png}:{out}")
    print(f"{out} ({out.stat().st_size // 1024} KB)")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--store", nargs="?", const=STORE, type=Path, metavar="DIR",
                    help=f"also write play-512.png and apple-1024.png (default {STORE})")
    args = ap.parse_args()
    if not MASTER.exists():
        raise SystemExit(f"{MASTER} is missing: design/icon/README.md says where it comes from")
    box = scene_box(MASTER)
    fg, png = (FOREGROUND, "PNG32") if FOREGROUND.exists() else (MASTER, "PNG24")
    for density, size in DENSITIES.items():
        render(fg, box, size, size * SCENE_DP / CANVAS_DP,
               RES / f"mipmap-{density}/ic_launcher_foreground.png", png)
    if args.store:
        # Full-bleed squares the stores mask themselves, framed as the launcher shows the icon.
        # Play wants 32-bit PNG; Apple wants no alpha.
        render(MASTER, box, 512, 512 * SCENE_DP / VISIBLE_DP, args.store / "play-512.png", "PNG32")
        render(MASTER, box, 1024, 1024 * SCENE_DP / VISIBLE_DP, args.store / "apple-1024.png", "PNG24")


if __name__ == "__main__":
    main()
