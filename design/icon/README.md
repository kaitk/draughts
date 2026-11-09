# The app icon

Two seasons of one icon. The shipped one is autumn, chosen for the release (2026-11-09);
winter shipped before it. An icon that follows the
season by itself costs the child its place on the home screen (task 033).

The winter jump (chosen 2026-11-08, task 028): a 3×3 stone board at three-quarters, a
dark slate piece on the centre square, and the ivory king, two stacked discs of one colour
with plain tops, jumping over it along a pale blue arc, on navy (#06172b at the corners,
#0d2139 at the top). Kings are stacked in Estonia; no piece has a crown or a symbol.

The autumn jump is the same scene in wood: light and dark wood squares, a dark brown
piece, the cream king, a golden arc, on dark brown (#140c09 at the corners).

| File | What it is |
| --- | --- |
| `master-SEASON.png` | A season's icon, square and opaque, 1254 px from ChatGPT: `master-winter.png` is `~/Downloads/draughts-store/icon/master-winter-jump-1254.png`, `master-autumn.png` is `master-autumn-jump-1254.png` beside it |
| `foreground-SEASON.png` | Optional: the scene alone on transparency, the master's size, the scene in the same place |

They stay local and out of git (`.gitignore`). The originals are in
`~/Downloads/draughts-store/icon/`, whose `README.md` says how they were made (the prompts
are in `../prompts.md`).

## Making the images again

```sh
cp ~/Downloads/draughts-store/icon/master-winter-jump-1254.png design/icon/master-winter.png
cp ~/Downloads/draughts-store/icon/master-autumn-jump-1254.png design/icon/master-autumn.png
scripts/icon.py            # the shipped season (SHIPPED, autumn) into android/res/mipmap-* and
                           # ios/icon-1024.png (the iOS bundle's), in git
scripts/icon.py --store    # also play-512.png and apple-1024.png, into ~/Downloads/draughts-store/icon/
scripts/icon.py winter --res /tmp/winter-res --store
                           # another season: its foreground PNGs where --res says (never
                           # android/res), its store icons into ~/Downloads/draughts-store/icon/winter/
```

The script finds the scene on the master: the pixels whose red is more than 37.5 (of 255)
over the mean of the master's four corners, so it works on any background darker than the
scene. It scales the scene to 64 dp of the adaptive icon's 108 dp, inside the 66 dp every
mask keeps, and centres it. A refined master with the scene larger or moved needs no
change to the script. With a `foreground-SEASON.png`, that layer becomes the adaptive
foreground; without it, the opaque master is the foreground, its corners matching the
background colour (`icon_background` in `android/res/values/colors.xml`). The script
prints the corners' colour: #07182c for winter, #140c09 for autumn.

The store icons are framed as the launcher shows the icon: the scene fills 64 of 72 dp.
From the 1254 px master, Apple's 1024 px is upscaled about 15%: a larger master should
replace it before an iOS release.

## Switching the shipped season

In one commit:

1. Set `SHIPPED` in `scripts/icon.py` and run it: it rewrites the five foreground PNGs in
   `android/res/mipmap-*`. With `--store` it also rewrites `play-512.png` and
   `apple-1024.png` in `~/Downloads/draughts-store/icon/`; those are autumn's, and
   winter's are in its `winter/` folder.
2. Set `icon_background` in `android/res/values/colors.xml` to the season's corner colour
   (#06172b for winter, #140c09 for autumn). It is the adaptive icon's background, the
   window's, and Android 12's splash.
3. The monochrome layer stays: the autumn scene matches winter's geometry within 0.25 dp
   (the arc's left foot 0.75 dp lower), finer than the layer's 1.3 dp lines.

## The monochrome layer

The monochrome layer (`android/res/drawable/ic_launcher_monochrome.xml`) is drawn by hand
from the scene's geometry, not traced: when the scene changes shape (the king's size, the
arc), redraw it, measuring the new master's corners, pieces, and arc the same way. Winter
and autumn share one geometry, so one layer serves both.
