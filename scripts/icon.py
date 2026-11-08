#!/usr/bin/env python3
"""Make the app icon's images from a season's master, with ImageMagick.

    scripts/icon.py                  write android/res/mipmap-*/ic_launcher_foreground.png
    scripts/icon.py --store          also the Play and Apple icons, into ~/Downloads/draughts-store/icon/
    scripts/icon.py autumn --res DIR --store
                                     another season's foreground PNGs into DIR, and its store
                                     icons into ~/Downloads/draughts-store/icon/autumn/

The season is SHIPPED unless named; only SHIPPED is written into android/res. Its master is
design/icon/master-SEASON.png, kept local (design/icon/README.md). The scene's box is
measured on it, the pixels whose red is more than SCENE_ABOVE over the mean of the master's
four corners (its background), and the box is scaled to SCENE_DP and centred in each image,
so a new master with a larger or moved scene, or another background, needs no edits here.
design/icon/foreground-SEASON.png, the scene alone on transparency at the master's size and
place, is used for the adaptive icon's foreground when it exists; otherwise the opaque
master is, its corners matching the background colour (android/res/values/colors.xml), which
the script prints.

The monochrome layer is drawn by hand (android/res/drawable/ic_launcher_monochrome.xml)
from the same box: a scene that changes shape needs it redrawn.
"""
import argparse
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ICON = ROOT / "design/icon"
RES = ROOT / "android/res"
STORE = Path.home() / "Downloads/draughts-store/icon"

SHIPPED = "winter"     # the season in android/res; design/icon/README.md says how to switch
SCENE_DP = 64          # inside the 66 dp safe zone, with a dp spare for the arc's glow
CANVAS_DP = 108        # the adaptive icon's layers
VISIBLE_DP = 72        # what a launcher shows of them, and what the store icons show
SCENE_ABOVE = 37.5     # red more than this over the corners' (of 255) is the scene
DENSITIES = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}


def magick(*args):
    return subprocess.run(["magick", *map(str, args)], check=True,
                          capture_output=True, text=True).stdout


def corners(master):
    """The mean of the master's four corner pixels, as 0..255 RGB."""
    mean = "+".join("p{%s,%s}.%%s" % (x, y) for x in ("0", "w-1") for y in ("0", "h-1"))
    rgb = magick(master, "-format",
                 ",".join("%%[fx:255*(%s)/4]" % mean.replace("%s", c) for c in "rgb"), "info:")
    return [float(v) for v in rgb.split(",")]


def scene_box(master, background_red):
    """The scene's centre and its larger side, in master pixels."""
    threshold = (background_red + SCENE_ABOVE) / 255 * 100
    box = magick(master, "-channel", "R", "-separate", "+channel",
                 "-threshold", f"{threshold:.3f}%", "-format", "%@", "info:")
    w, h, x, y = map(int, re.fullmatch(r"(\d+)x(\d+)\+(\d+)\+(\d+)", box.strip()).groups())
    print(f"{master.name}: the scene {w}x{h}+{x}+{y}")
    return x + w / 2, y + h / 2, max(w, h)


def render(src, edge, box, size, scene_px, out, png):
    """src scaled so the scene's box is scene_px wide, centred in a size-px square; past
    the master's edge, its edge pixels (edge) or, for the foreground, transparency."""
    cx, cy, side = box
    out.parent.mkdir(parents=True, exist_ok=True)
    magick(src, "-virtual-pixel", "edge" if edge else "transparent",
           "-define", f"distort:viewport={size}x{size}+0+0",
           "-distort", "SRT", f"{cx},{cy} {scene_px / side} 0 {size / 2},{size / 2}",
           "+repage", "-strip", "-define", "png:exclude-chunks=date,time",
           "-define", "png:compression-level=9",
           f"{png}:{out}")
    print(f"{out} ({out.stat().st_size // 1024} KB)")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("season", nargs="?", default=SHIPPED,
                    help=f"which design/icon/master-SEASON.png (default {SHIPPED}, the shipped one)")
    ap.add_argument("--res", type=Path, metavar="DIR",
                    help=f"write the foreground PNGs under DIR (default {RES}, for {SHIPPED} only)")
    ap.add_argument("--store", nargs="?", const=True, type=Path, metavar="DIR",
                    help=f"also write play-512.png and apple-1024.png (default {STORE}, "
                         "or a folder named for a season that isn't shipped)")
    args = ap.parse_args()
    master = ICON / f"master-{args.season}.png"
    foreground = ICON / f"foreground-{args.season}.png"
    if not master.exists():
        raise SystemExit(f"{master} is missing: design/icon/README.md says where it comes from")
    if args.res is None and args.season != SHIPPED:
        raise SystemExit(f"{args.season} isn't shipped: pass --res DIR to try it, or switch "
                         "as design/icon/README.md says")
    background = corners(master)
    print(f"{master.name}: the corners #{''.join(f'{round(c):02x}' for c in background)}")
    box = scene_box(master, background[0])
    fg, png = (foreground, "PNG32") if foreground.exists() else (master, "PNG24")
    for density, size in DENSITIES.items():
        render(fg, fg == master, box, size, size * SCENE_DP / CANVAS_DP,
               (args.res or RES) / f"mipmap-{density}/ic_launcher_foreground.png", png)
    if args.store:
        store = args.store if args.store is not True else \
            STORE if args.season == SHIPPED else STORE / args.season
        # Full-bleed squares the stores mask themselves, framed as the launcher shows the icon.
        # Play wants 32-bit PNG; Apple wants no alpha.
        render(master, True, box, 512, 512 * SCENE_DP / VISIBLE_DP, store / "play-512.png", "PNG32")
        render(master, True, box, 1024, 1024 * SCENE_DP / VISIBLE_DP, store / "apple-1024.png", "PNG24")


if __name__ == "__main__":
    main()
