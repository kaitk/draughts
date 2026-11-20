#!/usr/bin/env python3
"""Make the board pictures settings' Board, Pieces, and Background rows show, one atlas,
with tools/board_shot.goose and ImageMagick.

    tools/assets/board_thumbs.py          write design/boards/boards.jpg and boards-6x6.astc

Each season's board in its wood, stone, and carved look (docs/architecture/rendering.md,
"Settings"; the looks are looks::of's) is shot headless with build/board_shot, built here
with the pinned Goose, at SHOT, then cut to a tile's picture: the season's own board (the
material Auto) whole, and each material's board at its near left corner close up, as the
settings prototype's `.thumb.corner` (a background 290% wide at 3% 93%). The cells are
CELL pixels, the picture's 76 × 50 dp at about 2.1 pixels a dp, the densest screen's;
sixteen across and four down by the app's theme (autumn, winter, spring, summer,
theme.goose's order). Across: the four boards (Auto, Wood, Stone, Carved); then on each of
the four, in that order, a light and a dark piece close up, Matching, then Classic
(board_shot's --classic); then the board's near left corner on its table
(tables::for_look's, shot wider so the table shows past the board), as the settings
prototype has them (scene::BOARD_PICTURES). The atlas is in git as the JPEG and the ASTC file the
app embeds (src/native/background.c); its PNG master stays in build/.

It needs astcenc (docs/development.md).
"""
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent / "scripts"))
from native import GOOSE, ROOT  # noqa: E402

OUT = ROOT / "design/boards"
WORK = ROOT / "build/board-thumbs"
SHOOTER = ROOT / "build/board_shot"
ASTCENC = ROOT / "build/astcenc-5.7.0/bin/astcenc"

SHOT = (1600, 1200)     # the shot, 4:3 as the prototype's shots
CELL = (160, 105)       # a picture's texels: scene::THUMB_W × THUMB_H
PICTURE = (76.0, 50.0)  # the picture in dp, whose shape the crops take
CORNER_SIZE = 2.9       # the corner's crop: the shot 290% of the picture's width,
CORNER_AT = (0.03, 0.93)  # placed as CSS background-position places it
# A board's crop elsewhere than the corner, by (season, material): none, every tile at the
# corner (2026-11-13: summer's carved oak at its tree of life was tried and set back).
CROP_AT = {}

# By theme (autumn, winter, spring, summer), with the material that is the season's own
# (Auto), as looks::OWN_MATERIAL has it.
SEASONS = [("autumn", "wood"), ("winter", "stone"), ("spring", "carved"), ("summer", "wood")]
MATERIALS = ["wood", "stone", "carved"]
# The pieces' crops in the shot's pixels: a light piece near and a dark one far, side by
# side; and the table's shot, wider, and its crop round the board's near left corner.
LIGHT_AT = (321, 640, 168, 220)
DARK_AT = (511, 285, 168, 220)
TABLE_SHOT = (2400, 1200)
TABLE_AT = (60, 420, 1140, 750)
TABLE = "flame"         # tables::for_look's, every look's for now


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


def crop(shot, at, out):
    x, y, w, h = at
    run("magick", shot, "-crop", f"{w}x{h}+{x}+{y}", "+repage", out)


def pieces(shot, out):
    """A light piece and a dark one side by side, close up."""
    light, dark = out.with_suffix(".l.png"), out.with_suffix(".d.png")
    crop(shot, LIGHT_AT, light)
    crop(shot, DARK_AT, dark)
    run("magick", light, dark, "+append", "-filter", "Lanczos", "-resize", f"{CELL[0]}x{CELL[1]}!", out)


def table(shot, out):
    """The board's near left corner on its table."""
    crop(shot, TABLE_AT, out)
    run("magick", out, "-filter", "Lanczos", "-resize", f"{CELL[0]}x{CELL[1]}!", out)


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    run(GOOSE, "build", "-o", SHOOTER, "tools/board_shot.goose", cwd=ROOT)
    rows = []
    for season, own in SEASONS:
        cells = []
        for m in MATERIALS:
            shot = WORK / f"{season}-{m}.png"
            run(SHOOTER, shot, "--size", f"{SHOT[0]}x{SHOT[1]}", "--season", season, "--material", m)
        whole(WORK / f"{season}-{own}.png", WORK / f"{season}-0.png")
        cells.append(WORK / f"{season}-0.png")
        for k, m in enumerate(MATERIALS):
            corner(WORK / f"{season}-{m}.png", WORK / f"{season}-{k + 1}.png", CROP_AT.get((season, m), CORNER_AT))
            cells.append(WORK / f"{season}-{k + 1}.png")
        looks = [own, *MATERIALS]
        for m in looks:
            classic = WORK / f"{season}-{m}-classic.png"
            run(SHOOTER, classic, "--size", f"{SHOT[0]}x{SHOT[1]}", "--season", season, "--material", m, "--classic")
            on_table = WORK / f"{season}-{m}-table.png"
            run(SHOOTER, on_table, "--size", f"{TABLE_SHOT[0]}x{TABLE_SHOT[1]}", "--season", season, "--material", m,
                "--table", TABLE)
        for kind in ("matching", "classic"):
            for m in looks:
                shot = WORK / (f"{season}-{m}.png" if kind == "matching" else f"{season}-{m}-classic.png")
                cell = WORK / f"{season}-{m}-{kind}-cell.png"
                pieces(shot, cell)
                cells.append(cell)
        for m in looks:
            cell = WORK / f"{season}-{m}-table-cell.png"
            table(WORK / f"{season}-{m}-table.png", cell)
            cells.append(cell)
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
    (ROOT / "src/native/background.c").touch()


if __name__ == "__main__":
    main()
