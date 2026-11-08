# The app icon

The winter jump (chosen 2026-11-08, task 028): a 3×3 stone board at three-quarters, a
dark slate piece on the centre square, and the ivory king, two stacked discs of one colour
with plain tops, jumping over it along a pale blue arc, on navy (#06172b at the corners,
#0d2139 at the top). Kings are stacked in Estonia; no piece has a crown or a symbol.

| File | What it is |
| --- | --- |
| `master.png` | The icon, square and opaque. Now the 1254 px original from ChatGPT, `~/Downloads/draughts-store/icon/master-winter-jump-1254.png` |
| `foreground.png` | Optional: the scene alone on transparency, the master's size, the scene in the same place |

Both stay local and out of git (`.gitignore`). The originals are in
`~/Downloads/draughts-store/icon/`, whose `README.md` says how they were made (the prompts
are in `../prompts.md`).

## Making the images again

```sh
cp ~/Downloads/draughts-store/icon/master-winter-jump-1254.png design/icon/master.png
scripts/icon.py            # android/res/mipmap-*/ic_launcher_foreground.png, in git
scripts/icon.py --store    # also play-512.png and apple-1024.png, into ~/Downloads/draughts-store/icon/
```

The script finds the scene on the master (what is brighter than the navy), scales it to
64 dp of the adaptive icon's 108 dp, inside the 66 dp every mask keeps, and centres it.
A refined master with the scene larger or moved needs no change to the script. With a
`foreground.png`, that layer becomes the adaptive foreground; without it, the opaque
master is the foreground, its navy edge matching the background colour (`navy` in
`android/res/values/colors.xml`).

The store icons are framed as the launcher shows the icon: the scene fills 64 of 72 dp.
From the 1254 px master, Apple's 1024 px is upscaled about 15%: a larger master should
replace it before an iOS release.

The monochrome layer (`android/res/drawable/ic_launcher_monochrome.xml`) is drawn by hand
from the scene's geometry, not traced: when the scene changes shape (the king's size, the
arc), redraw it, measuring the new master's corners, pieces, and arc the same way.
