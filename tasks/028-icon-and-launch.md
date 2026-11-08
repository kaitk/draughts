# 028: The app icon and the launch screen

Status: done

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
  on the master (red more than 37.5 of 255 over the mean of its four corners), scales it
  to 64 dp of the 108 dp canvas, inside the 66 dp safe zone with a dp spare for the arc's
  glow, and centres it. It writes
  `android/res/mipmap-{mdpi..xxxhdpi}/ic_launcher_foreground.png` (108 to 432 px), and
  with `--store` the Play and Apple icons into `~/Downloads/draughts-store/icon/`. Two
  runs give byte-identical PNGs.
- **Any season's master** (2026-11-08): the script first took a fixed red threshold
  (17.6%) tuned to the navy; it now measures against the master's corners and takes a
  season, `design/icon/master-SEASON.png`, writing only the shipped one (`SHIPPED`,
  winter) into `android/res`; another season goes to `--res DIR`. Winter's output is
  byte-identical to before: the box is 791 × 635 at +232+303 for any red cut from 43 to
  46, and the corners' red is 6.75, so the cut is 45 as before. The autumn master's box
  is 792 × 639 at +231+299. Shipping autumn instead, and its numbers, are in task 033.
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
  is the icon on navy and hands over to the app on the same colour. No splash image. The
  window draws its bars' backgrounds itself (`windowDrawsSystemBarBackgrounds`), with
  `navigationBarColor` navy.
- **The first frame's signal** (2026-11-08): `DraughtsActivity` puts a view of the theme's
  `windowBackground` over the whole window (on the decor view, so it spans the bars' area
  too) and, on API 31+, takes Android's splash with
  `getSplashScreen().setOnExitAnimationListener` instead of letting it fade, so it stays.
  The program calls `draughts_first_frame()` (`app/launch.c`) at the top of the loop when
  `gfx::frame_count()` is 2, the first `frame()` after the one whose pass drew the first
  frame, since `frame()` presents what the pass before it drew; the C gets the activity
  with `SDL_GetAndroidJNIEnv` and `SDL_GetAndroidActivity` and calls its `firstFrame()`,
  which removes the splash and hides the view on the UI thread. On the Mac the C is an
  empty function. If the signal never comes, both go after 3 s. On API 29 and 30 there is
  no system splash; the starting window is the theme's navy, and the view keeps it.
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

`am start -W`'s `TotalTime`, cold, `--screen game`, on the tablet (2026-11-08; Android
counts to the window's first draw, which the view makes, not to the program's frame):

| | TotalTime (ms) |
| --- | --- |
| Before the first frame's signal, 4 runs | 201, 203, 212, 217 (mean 208) |
| With it, final build, 9 runs | 197 to 241 (mean 217) |

## On the tablet (2026-11-08, Android 16, One UI, 240 dpi)

- **The launcher:** the icon shows in the app drawer at about 80 px in One UI's squircle,
  the scene filling about 85% of its width, its edges clean. One UI has no round mask; the
  round one was checked in the browser preview only. With themed icons on (One UI's
  "apply palette to app icons", `settings put system colortheme_app_icon 1` and a
  launcher restart), the launcher draws the monochrome layer: board, pieces, and arc read,
  though the drawing is lighter and finer than the bold glyphs of the apps beside it.
- **Launch** (cold start with `am start -W`, `screenrecord`, two runs): `TotalTime` 208
  and 232 ms. The splash, the icon on navy, shows for about 150 ms; then it fades out
  over 150 to 200 ms, onto black in one run and onto the home screen and then black in
  the other; black holds 150 to 260 ms; then the app's first frame. Android removes the
  splash at the window's first draw, but the window is SDL's `SurfaceView`, whose hole
  shows what is behind it (black, or nothing yet) until SDL presents; the theme's navy
  `windowBackground` is never seen there. The theme can't fix it. A fix needs a signal
  from the program's first presented frame: hold the splash until then
  (`getSplashScreen().setOnExitAnimationListener`, API 31) or cover the surface with a navy
  view and remove it then. `SurfaceView.setResizeBackgroundColor`, which would colour the
  layer behind, is not public. Recorded in [findings](../docs/goose-findings.md).
- **Launch with the signal** (`--screen game`, recorded with `screenrecord` and checked
  frame by frame, 2026-11-08): the splash, the icon on navy, shows from the launcher's
  zoom until the app's first frame, 400 to 460 ms in each of 30 cold starts, and the
  frame after it is the whole game screen. No frame is black or white in any run. One
  smaller flash was fixed on the way: as Android handed its splash over, the navigation
  bar's area showed the launcher's dark taskbar for one to three frames (11 to 35 ms),
  in 3 of 5 runs with the view inside SDL's layout. The old `Theme.NoTitleBar` doesn't
  let the window draw behind the bars, so that area showed what was behind the window.
  Moving the view to the decor (1 of 5) or a navy `navigationBarColor` alone (4 of 5;
  with the decor, 2 of 6) didn't end it; `windowDrawsSystemBarBackgrounds` with the navy
  `navigationBarColor` did, 9 of 9 runs clean. Without the signal, the same day's build
  showed the icon for 35 to 150 ms, its fade, then black for 250 to 370 ms in each of
  four runs. Going home and back still shows the game. Android 10 and 11 (API 29, 30),
  which get only the view, weren't tried; no device here runs them.

## Acceptance criteria

- [x] The launcher shows the icon on the tablet, round and squircle masks both clean,
      and the themed (monochrome) icon when Android's themed icons are on (round in the
      browser preview; One UI has only the squircle)
- [x] Launch shows the icon on its background color, then the app, with no white or
      black flash between them (on the tablet, Android 16; above)
- [x] Recognizable at 48 px (a browser preview of the 72 dp view at 48 and 82 px, circle
      and squircle, and the monochrome at both)
- [x] The APK's size recorded before and after
- [x] The 512 × 512 Play icon and the Apple 1024 × 1024 exported from the same master
