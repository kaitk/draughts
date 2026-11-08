# 028: The app icon and the launch screen

Status: in-progress (built; the tablet checks are left)

The app had no icon and no resources: the APK's manifest had a literal label and the
platform's theme, so the launcher showed Android's default, and launch showed a blank
screen before the first frame. Android first; Apple where it costs nothing extra now,
since the release is Android first (task 029).

The prompts, what each store needs, and the store screenshots are in
`~/Downloads/draughts-store/` (`README.md`, `prompts.md`), outside the repo on purpose.

## The icon: the winter jump (2026-11-08)

`~/Downloads/draughts-store/icon/master-winter-jump-1254.png`, 1254 px, made with
ChatGPT (the `README.md` beside it says how). A 3×3 stone board at three-quarters, a dark
slate piece on the centre square, and the ivory king, two stacked discs of one colour
with plain tops (kings are stacked in Estonia; no piece has a crown or a symbol), jumping
over it along a pale blue arc. The background is navy, #06172b at the corners and
#0d2139 at the top. The scene fills 791 × 635 px of the 1254 square.

Chosen from mockups of the candidates on the tablet's real home screen
(`~/Downloads/draughts-store/tablet-home-with-icons.png`): at the tablet's 82 px icon it
reads as draughts better than a lone king, and keeps its contrast better than the autumn
versions.

A refined master may follow: the scene 10 to 15% larger, the king the dark piece's size,
and the scene and the background as separate transparent layers. `scripts/icon.py` makes
every image again from it (`design/icon/README.md`); only the hand-drawn monochrome layer
needs redrawing if the scene changes shape.

## What was built

- **Masters and the script:** the masters stay local and git-ignored in `design/icon/`
  (its `README.md` says where they come from). `scripts/icon.py` measures the scene's box
  on the master (red above the navy), scales it to 64 dp of the 108 dp canvas, inside the
  66 dp safe zone with a dp spare for the arc's glow, and centres it. It writes
  `android/res/mipmap-{mdpi..xxxhdpi}/ic_launcher_foreground.png` (108 to 432 px), and
  with `--store` the Play and Apple icons into `~/Downloads/draughts-store/icon/`. Two
  runs give byte-identical PNGs.
- **Adaptive icon** (`mipmap-anydpi-v26/ic_launcher.xml`): the background the solid
  `navy` colour (#06172b); the foreground the opaque master, scaled and cropped, its
  edge pixels repeated past the master's edge so a launcher's parallax shows no seam;
  the monochrome layer a vector drawn by hand from the scene's geometry (the board's top
  face and side as 1.3 dp lines, broken where the arc and the king stand in front; the
  dark piece and the king's two discs as a face and side bands; the arc a filled taper,
  2 dp at its apex). The board's side is drawn 3 dp thick instead of the scene's 2.3, so
  its lines stay apart. The king keeps the master's size.
- **No legacy mipmaps:** minSdk is 29, and adaptive icons came in API 26, so every device
  that installs the app reads the adaptive icon; aapt2 drops the `-v26` qualifier as
  implied. No `roundIcon` either: launchers mask the adaptive icon to their own shape.
- **Launch:** `Theme.Draughts` (`res/values/themes.xml`), parented on
  `Theme.NoTitleBar.Fullscreen` so the window stays fullscreen, with `windowBackground`
  navy; `res/values-v31` adds `windowSplashScreenBackground` navy, so Android 12+'s splash
  is the icon on navy and hands over to the app on the same colour. No splash image.
- **The build:** `scripts/android.py` runs `aapt2 compile --dir android/res` and passes the
  compiled zip to `aapt2 link` as an input (with `-R`, the overlay flag, aapt2 refuses new
  resources unless `--auto-add-overlay` is added too).
- **Store icons** (`scripts/icon.py --store`), framed as the launcher shows the icon, the
  scene 64 of 72 dp: `play-512.png`, 512 px RGBA, 263 KB; `apple-1024.png`, 1024 px
  opaque, 847 KB. Apple's is upscaled about 15% from the 1254 px master.

## Numbers

| | Size |
| --- | --- |
| APK before (`app/draughts.goose`, the commit before this task's) | 5,775,975 bytes (5640 KB) |
| APK after | 6,055,132 bytes (5913 KB), +279 KB |
| The foreground PNGs, mdpi to xxxhdpi | 11, 22, 35, 71, 125 KB: 266 KB of it |
| The monochrome vector, the adaptive XML, resources.arsc | 1.5, 0.5, 2.1 KB |

## Acceptance criteria

- [ ] The launcher shows the icon on the tablet, round and squircle masks both clean,
      and the themed (monochrome) icon when Android's themed icons are on
- [ ] Launch shows the icon on its background color, then the app, with no white or
      black flash between them
- [x] Recognizable at 48 px (a browser preview of the 72 dp view at 48 and 82 px, circle
      and squircle, and the monochrome at both)
- [x] The APK's size recorded before and after
- [x] The 512 × 512 Play icon and the Apple 1024 × 1024 exported from the same master
