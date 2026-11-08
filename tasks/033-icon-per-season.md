# 033: An icon per season

Status: todo (after the MVP; until then one icon, switched by hand: autumn shipped
2026-11-08 for the autumn months, and winter is back in for the winter months and the
release)

The app's look follows the season, picked from the date (`docs/architecture/rendering.md`,
"Seasons and themes"); the launcher icon is one season, the winter jump (task 028). An
autumn jump now exists: the same scene in wood on dark brown,
`~/Downloads/draughts-store/icon/master-autumn-jump-1254.png` (2026-11-08). The icon
could follow the season too. Not in the MVP: it costs the user their home-screen icon
four times a year (below) for a small delight.

## What Android allows

An app has one `android:icon`, fixed in the APK. The only way to change the launcher icon
at run time is to declare one `<activity-alias>` per season, each targeting
`DraughtsActivity` with its own `android:icon` and the `MAIN`/`LAUNCHER` intent filter,
and to enable one and disable the others with
`PackageManager.setComponentEnabledSetting(..., DONT_KILL_APP)` from
`DraughtsActivity` (Java; the Goose program needs only to say which season, or the Java
reads the date itself). Its costs:

- **Launchers treat the switch as an uninstall of one entry and an install of another.**
  The home-screen icon of the disabled alias goes (most launchers remove it; what One
  UI does is to measure), its place in a folder or on a page is lost, and the drawer
  may reorder. For children who find the app by its place on the home screen, this is
  the main cost.
- **It shows only after the launcher refreshes**, from a second to a minute, and only
  once the app has run in the new season: nothing changes the icon while the app is
  closed, short of a scheduled job, which is not worth it.
- **Switching the component that is running** is reported to end the task on some
  versions, even with `DONT_KILL_APP`: switch when the app goes to the background (`onStop`), not at
  start, and only when the season changed.
- **The splash and window colour stay one:** `<activity-alias>` takes no theme, so
  Android 12's splash shows each season's icon on the one `windowSplashScreenBackground`.
  Pick a colour all the icons sit on (a near-black), or accept a seam.
- **The APK grows by each season's foreground set:** about 250 KB each (autumn's five
  PNGs: 9, 18, 31, 68, 123 KB), 750 KB for three more seasons, less as WebP.
- **Play's listing keeps one icon** (`play-512.png`); changing it is a listing update,
  by hand, reviewed. Apple's alternate icons (`setAlternateIconName`) show the user a
  system alert at each change.
- Spring and summer masters don't exist yet: the same composition in birch and in the
  sunset theme, from ChatGPT (`~/Downloads/draughts-store/prompts.md`). The monochrome
  layer stays one if their geometry matches, as autumn's does.

## Defaulting to autumn now

The cheaper option: ship the autumn jump instead of the winter one, with no alias. It is
one commit, written up in `design/icon/README.md` ("Shipping another season"):
`SHIPPED = "autumn"` in `scripts/icon.py`, run it, and the background colour in
`colors.xml` set to #140c09 (renamed from `navy`). The monochrome layer stays.

Measured on the foregrounds as `scripts/icon.py` places them (dp of the 108 dp canvas):

| | Winter | Autumn | Difference |
| --- | --- | --- | --- |
| Scene box on the master | 791 × 635 at +232+303 | 792 × 639 at +231+299 | |
| Board left, right corner (x) | 21.92, 85.92 | 21.92, 85.92 | 0 |
| Board top corner, top face's front corner, side's bottom (y) | 35.11, 77.10, 79.69 | 35.29, 77.23, 79.82 | 0.13 to 0.19 |
| Dark piece left, right (x); top (y) | 47.73, 61.24; 48.0 | 47.78, 61.35; 48.25 | 0.05 to 0.25 |
| King left, right (x); top, bottom (y) | 68.75, 78.75; 45.0, 54.0 | 68.75, 78.75; 45.1, 54.25 | 0 to 0.25 |
| Arc core at x = 36, 44, 52, 60, 68, 72 (y) | 40.12, 32.12, 29.38, 30.88, 37.62, 46.12 | 40.38, 32.12, 29.38, 31.12, 37.88, 46.12 | 0 to 0.25 |
| Arc core at x = 32 (its left foot) | 47.62 | 48.38 | 0.75 |

Everything is within 0.25 dp but the arc's left foot, all finer than the monochrome
layer's 1.3 dp lines: it fits autumn as drawn (checked by drawing it over both).

Contrast (WCAG ratio, from 7 × 7 px patches of the 432 px foreground; the tile is the mean
of its four edge midpoints, winter #0f243e, autumn #1b100d):

| | Winter | Autumn |
| --- | --- | --- |
| Light square vs dark square | 3.65 | 4.01 |
| Dark square vs the tile | 2.75 | 2.36 |
| Dark piece vs its square | 2.51 | 2.25 |
| King vs the tile | 11.77 | 11.88 |
| Arc's apex vs the tile | 8.04 | 7.86 |
| The tile vs mid-grey (#808080) | 3.92 | 4.71 |
| The tile vs a dark wallpaper (#1a2130) | 1.04 | 1.16 |
| The tile vs the tablet's green wallpaper (#63af89) | 5.91 | 7.11 |

This autumn jump holds its contrast as well as winter, unlike the earlier autumn
candidates task 028 set aside: a little more between squares and against light
wallpapers, a little less for the dark piece; both tiles merge into a dark wallpaper.
The preview of both at 82 and 48 px in a squircle, on mid-grey, dark, and the tablet's
wallpaper, was made in a scratch folder (2026-11-08); make it again from the foregrounds
(`scripts/icon.py autumn --res DIR`) to judge on the tablet.

## The autumn icon on the tablet (2026-11-08)

This used the APK built from `6b20e66` (`colors.xml` at #140c09, autumn's foregrounds),
with the tablet in English (en-GB).

- **The launcher.** The app drawer shows the autumn jump on dark brown, labelled
  "Draughts" (`launcher-drawer.png`, `drawer-icon.png`). Its tile reads #1a0f0d.
  - The home screen has no pinned Draughts icon, and none was added.
  - The dock's recent-apps slot first showed the old winter icon, navy, from the
    launcher's cache (`launcher-home.png`, `dock-icon.png`). After the app had run once
    it showed autumn (`dock2.png`).
  - `aapt2 dump badging` gives `application-label:'Draughts'` and
    `application-label-et:'Kabe'`.
- **The launch.** It was recorded from the drawer with `screenrecord`, once in landscape
  and once in portrait (`launch1.mp4`, `launch2.mp4`; `splash-land.png`,
  `splash-port.png`).
  - The launcher's zoom fades into brown in about 0.1 s. The screen then holds a flat
    #150b09 (#140c09 through the encoder) with the autumn icon in the middle: Android's
    splash, and then the window's cover. This lasts 0.53 s in landscape and 0.46 s in
    portrait, and the next changed frame is the app's first frame.
  - No frame is navy or black. In the bottom 6%, where the taskbar fades out, the colour
    goes from the wallpaper's green through brown-grey to the brown, and blue never
    leads.
  - On the splash, the icon's squircle is a shade lighter than the screen, about
    #1d110d against #150b09: the foreground's own backdrop over `icon_background`. It
    shows only up close.

The files named are in
`/private/tmp/claude-501/-Users-kaitkasak-projects-personal-draughts/d9f11ac9-ef2c-4a62-bf58-8c3587116c29/scratchpad/tabletround/`,
out of git.

## Acceptance criteria

- [x] The user decides: winter stays, autumn becomes the one icon, or the icon follows
      the season (2026-11-08: one icon, autumn now and winter for the winter months)
- [x] If one icon: shipped as `design/icon/README.md` says, checked on the tablet's home
      screen and splash (2026-11-08: the drawer, the dock, and the splash; above)
- [ ] If per season: a master per season with the same geometry; one alias per season in
      `AndroidManifest.xml`; the switch in `DraughtsActivity` on going to the
      background, only when the season changed; the splash colour chosen for all; what
      One UI does to a home-screen icon on a switch, measured on the tablet; the APK's
      size before and after
