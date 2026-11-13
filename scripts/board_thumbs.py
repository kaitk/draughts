#!/usr/bin/env python3
"""Make the board pictures settings' Board row shows, one atlas, with build/board3d and
ImageMagick.

    scripts/board_thumbs.py          write design/boards/boards.jpg and boards-6x6.astc

Each season's board in its wood, stone, and carved look (docs/architecture/rendering.md,
"Settings"; the looks are looks::of's, the flags task 080's table) is shot headless with
build/board3d --shot at SHOT, then cut to a tile's picture: the season's own board (the
material Auto) whole, and each material's board at its near left corner close up, as the
settings prototype's `.thumb.corner` (a background 290% wide at 3% 93%). The cells are
CELL pixels, the picture's 76 × 50 dp at about 2.1 pixels a dp, the densest screen's;
four across (Auto, Wood, Stone, Carved) and four down by the app's theme (autumn, winter,
spring, summer, theme.goose's order). The atlas is in git as the JPEG and the ASTC file the
app embeds (src/app/background.c); its PNG master stays in build/.

Build board3d first (poc/3d/board3d.goose's header), and astcenc (docs/development.md).
"""
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "design/boards"
WORK = ROOT / "build/board-thumbs"
BOARD3D = ROOT / "build/board3d"
ASTCENC = ROOT / "build/astcenc-5.7.0/bin/astcenc"

SHOT = (1600, 1200)     # board3d's frame, 4:3 as the prototype's shots
CELL = (160, 105)       # a picture's texels: scene::THUMB_W × THUMB_H
PICTURE = (76.0, 50.0)  # the picture in dp, whose shape the crops take
CORNER_SIZE = 2.9       # the corner's crop: the shot 290% of the picture's width,
CORNER_AT = (0.03, 0.93)  # placed as CSS background-position places it
# Where a board's carving shows little at the corner, its crop elsewhere: summer's carved
# oak has only a small sun there, its tree of life in the near side's middle (2026-11-13).
CROP_AT = {("summer", "carved"): (0.5, 0.97)}

# By theme (autumn, winter, spring, summer): board3d's flags for each material, and which
# material is the season's own (Auto), as looks::of has them.
SEASONS = [
    ("autumn", {"wood": ["--autumn", "0"], "stone": ["--autumn", "3"], "carved": ["--autumn", "2"]}, "wood"),
    ("winter", {"wood": ["--winter", "1"], "stone": ["--winter", "0"], "carved": ["--winter", "2"]}, "stone"),
    ("spring", {"wood": ["--theme", "spring", "--spring", "0"], "stone": ["--theme", "spring", "--spring", "3"],
                "carved": ["--theme", "spring", "--spring", "1"]}, "carved"),
    ("summer", {"wood": ["--summer", "0"], "stone": ["--summer", "6"], "carved": ["--summer", "7"]}, "wood"),
]
MATERIALS = ["wood", "stone", "carved"]


def run(*args, cwd=None):
    subprocess.run([str(a) for a in args], check=True, cwd=cwd, capture_output=True)


def whole(shot, out):
    """The whole board, cover-cropped to the picture's shape across the shot's width."""
    w, h = SHOT
    ch = round(w * PICTURE[1] / PICTURE[0])
    run("magick", shot, "-crop", f"{w}x{ch}+0+{(h - ch) // 2}", "+repage",
        "-filter", "Lanczos", "-resize", f"{CELL[0]}x{CELL[1]}!", out)


def corner(shot, out, at=CORNER_AT):
    """The near left corner: the picture's window on the shot scaled to CORNER_SIZE of its
    width, at CORNER_AT, in the shot's pixels."""
    w, h = SHOT
    bw = CORNER_SIZE * PICTURE[0]
    bh = bw * h / w
    scale = w / bw
    x = -at[0] * (PICTURE[0] - bw) * scale
    y = -at[1] * (PICTURE[1] - bh) * scale
    cw, ch = PICTURE[0] * scale, PICTURE[1] * scale
    run("magick", shot, "-crop", f"{round(cw)}x{round(ch)}+{round(x)}+{round(y)}", "+repage",
        "-filter", "Lanczos", "-resize", f"{CELL[0]}x{CELL[1]}!", out)


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    rows = []
    for season, flags, own in SEASONS:
        cells = []
        for m in MATERIALS:
            shot = WORK / f"{season}-{m}.png"
            run(BOARD3D, "--shot", shot, "--size", f"{SHOT[0]}x{SHOT[1]}", *flags[m], cwd=ROOT / "poc/3d")
        whole(WORK / f"{season}-{own}.png", WORK / f"{season}-0.png")
        cells.append(WORK / f"{season}-0.png")
        for k, m in enumerate(MATERIALS):
            corner(WORK / f"{season}-{m}.png", WORK / f"{season}-{k + 1}.png", CROP_AT.get((season, m), CORNER_AT))
            cells.append(WORK / f"{season}-{k + 1}.png")
        row = WORK / f"{season}-row.png"
        run("magick", *cells, "+append", row)
        rows.append(row)
        print(season, "shot")
    master = WORK / "boards.png"
    run("magick", *rows, "-append", "-alpha", "off", master)
    run("magick", master, "-quality", "88", "-sampling-factor", "4:2:0", "-strip", OUT / "boards.jpg")
    run(ASTCENC, "-cl", master, OUT / "boards-6x6.astc", "6x6", "-thorough", "-esw", "rgb1")
    for f in ("boards.jpg", "boards-6x6.astc"):
        print(f, (OUT / f).stat().st_size, "bytes")
    # background.c #embeds the atlas, and the build keeps its object while the .c file is
    # unchanged: touch it, or the app goes on showing the old pictures (2026-11-13).
    (ROOT / "src/app/background.c").touch()


if __name__ == "__main__":
    main()
