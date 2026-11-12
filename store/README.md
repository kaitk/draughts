# Store materials

What goes into Google Play Console and App Store Connect for Draughts, drafted so it can
be pasted in. Images (the icons, the feature graphic, screenshots) stay local in
`~/Downloads/draughts-store/` (below, "Screenshots and the feature graphic").

| File | What it is |
| --- | --- |
| `listing-en.md` | Play's listing in English: title, short and full description |
| `listing-et.md` | The same in Estonian, with notes on the wording |
| `play-console.md` | Play's App content answers: Data safety, ads, content rating (IARC), target audience and the Families Policy, the other declarations, the store settings, and the account |
| `app-store.md` | The App Store's listing (English only) and App Store Connect's answers: App Privacy, age rating, the category, export compliance, the privacy manifest, review notes, and what the iOS build still needs |
| `privacy/index.html` | The privacy policy, English and Estonian on one standalone page, for both stores |
| `preview/` | `play.html` and `app-store.html`: the two stores' pages as they would look, on a phone and on the web, in English and Estonian |

## Previews

```sh
store/preview/build.py      # check every text's limit, copy the images, fill the pages
open store/preview/play.html store/preview/app-store.html
```

`build.py` reads the texts from the files above and the images from
`~/Downloads/draughts-store/` (scaled down into `preview/img/`, not in git), so a page
shows what would be pasted. Each page switches language and device set (`?lang=et`,
`?set=tablet` or `?device=ipad`, `&full=1` for the whole phone page in one screenshot)
and lists each text's length against its limit beside it. They approximate the stores'
layouts of 2026-11; the consoles' own previews have the last word. Screenshots of them
are in `~/Downloads/draughts-store/preview/`.

## Play's image rules

Read 2026-11-09 from Play Console Help
([9866151](https://support.google.com/googleplay/android-developer/answer/9866151),
[1078870](https://support.google.com/googleplay/android-developer/answer/1078870)); check
them again before an upload.

| Image | Rule |
| --- | --- |
| Any screenshot | JPEG or 24-bit PNG, no alpha; each side 320 to 3,840 px, the longer at most twice the shorter; up to 8 per device type; at least 2 across device types to publish; the real app, alt text up to 140 characters |
| Phone | The general rule; for a game to be recommended, at least 3 at 16:9 landscape (at least 1920 × 1080) or 9:16 portrait (at least 1080 × 1920), the app's UI in the first three |
| 7" and 10" tablets, Chromebooks | At least 4, each side 1,080 to 7,680 px, 16:9 landscape or 9:16 portrait, and no text that isn't part of the app (Play's pages may crop it) |
| Feature graphic | 1024 × 500, JPEG or 24-bit PNG, no alpha; required; the main content central, away from the edges Play may crop; no device pictures or store badges, and no branding that only repeats the icon |
| Icon | 512 × 512, 32-bit PNG with alpha, at most 1,024 KB |
| Video | Optional, one YouTube URL; recommended for games, which some Play surfaces show only with one |

The tablet's own 16:10 (2560 × 1600) doesn't fit the tablet slots, so the tablet's shots
are taken at 16:9: `--size 1280x720`, 2560 × 1440 on the Mac's Retina screen. The App
Store's rules are in `app-store.md`, "Screenshots".

## Screenshots and the feature graphic

A new set, taken 2026-11-10 from `main` at `cc18fec` for the lookout and the hint, the
captured pieces, the library's switch, and settings' glass tabs, waits for the user's
approval in `2026-11-10/`: `play/phone/`, `play/tablet/`, `app-store/iphone-6.9/` (and
`-raw/`), and `app-store/ipad-13/`, with the names and sizes below; its own `upload/` of
flattened copies; a contact sheet per device type (`contact-*.png`); `check.txt`, each
image against the rules; and the `scripts/` that made them. Its Play shots ran the
headless copy with each run's own folder as the storage folder, so the made-up player
never touched the Mac's files, and the phone's Look tab from `--xlook 1`, a flag in the
copy only, in place of a second build. Until it is approved, the sets below stay current.

The current sets, outside git, taken 2026-11-09 from `main` at `78c7029`, each scene in
English and Estonian, with 04 and 06 retaken from `503e27a` for settings' new layout and
privacy note and the library's centring, and 03 from `96d70e0` for the 3D board's capture
pips (the old ones in each set's `replaced/`; the 0.2 sets, from `1824780`, kept beside
them):

| Folder | Size | For | Made with |
| --- | --- | --- | --- |
| `screenshots/play-0.3/phone/` | 1080 × 1920, 9:16, laid out at 548 dp (a 1080 px phone at the 0.75 density floor) | Play's phone slot | The app's headless copy, `--frames` |
| `screenshots/play-0.3/tablet/` | 2560 × 1440, 16:9 | Play's 7" and 10" tablet slots | The app's headless copy, `--frames` |
| `screenshots/app-store-0.3/iphone-6.9/` | 1320 × 2868 | The App Store's iPhone 6.9" set | An iPhone 16 Pro Max simulator, iOS 26.4, headless |
| `2026-11-12/upload/app-store/ipad-13-landscape/` | 2752 × 2064 | The App Store's iPad 13" set, landscape, in place of the portrait one (the user, 2026-11-12) | The app's headless copy at `--size 2752x2064 --inset 0,0,0,15.5`, from `dcc1f17`; its `scripts/` say how |
| `upload/app-store-0.3/iphone-6.3/` | 1206 × 2622 | The App Store's iPhone slot as it is since 2026-11 (medium display, 6.1" and 6.3") | The 6.9" set scaled, `magick -resize 1207x2622^ -gravity center -extent 1206x2622` |
| `screenshots/app-store-0.3/ipad-13/` | 2064 × 2752 | The App Store's iPad 13" set | An iPad Pro 13-inch (M4) simulator, iOS 26.4, headless |

Upload from `~/Downloads/draughts-store/upload/`: the same sets flattened to 24-bit RGB
(the Play and iPad shots are RGBA, though opaque, and both stores refuse alpha), made with
`magick IN -background black -alpha remove -alpha off -type TrueColor OUT`.

The seven scenes, in the order to upload, each a season so all four show:

1. `01-home-3d-winter`: home on the 3D board, winter, with the player's chip
2. `02-game-autumn`: International on the flat board, a selected man's capture of two
   shown with move hints on, autumn
3. `03-game-3d-summer`: the same position on the 3D board, summer; in the 2026-11-10
   set, that position without black's 22, so no capture is due: the lookout on (the
   player at easy), white's man on 30 drained grey as black's 24 could take it, the hint
   ready with its three pips, and the captured pieces in the bar
4. `04-puzzles-spring`: the library of six themes, some solved, spring
5. `05-puzzle-winter`: a Shots puzzle (55), black to move, after the first move and the
   reply, the capturing man selected, winter
6. `06-settings-autumn`: settings; on Play's phone the Look tab (a local build), on the
   iPhone the Game tab
7. `07-computer-summer`: the computer's setup, summer

The player is made up (Mia the fox, with some stars): `play-0.1/player-1.txt` and
`settings.txt`, written into the Mac's app data and into each simulator's container (each
copied aside first and put back after). Play's shots come from one batch of 28 runs of the
app's headless copy (`agents/testing.md`; about a minute, no window), its loop's break
also waiting for 6 s of the clock so every fade has finished (`mkxshot-0.3.py` makes it);
the phone's Look tab needs a second, local build with `group: i64 = 1` in
`src/shell/settings.goose`'s `Settings`, never committed: no flag picks the tab. The
simulator draws the Dynamic Island into its framebuffer, so the iPhone shots have it
painted over with what the app draws there, the season's photograph alone:
`island_fill.py` takes the same cover crop from `design/backgrounds/masters/` and fits its
blur and colour to the pixels around the island (`iphone-6.9-raw/` keeps them as taken).
The scripts that took them are kept beside the sets.

The feature graphic is `feature-0.2/feature-render-close-name.png` (1024 × 500, no alpha;
chosen by the user 2026-11-09): the autumn 3D board close at a low angle, rendered
headless from a copy of the app without its UI, with home's king and "Draughts" in
Libertinus Sans top-left over the blurred forest. Its `README.md` and `fgshot.py` say how
it was rendered. The Estonian listing may take its own, with "Kabe" (Play takes a feature
graphic per language). `play-0.1/feature-graphic-draft.png`, the flat first draft, is
superseded. The older sets
(`play/`, `apple-*`, `play-0.1/`, before the 3D board, the sixth theme, and the Russian
puzzles) are superseded.

The icons: `icon/play-512.png` and `icon/apple-1024.png`, from `scripts/icon.py --store`.

## Placeholders

Replace these everywhere in this folder before anything is published (the developer name
and the contact email are filled in):

| Placeholder | Value |
| --- | --- |
| `{DEVELOPER}` | Gideonic: the developer name on Play (the user, 2026-11-09); on the App Store an individual's legal name is shown instead |
| `{CONTACT_EMAIL}` | kaitkasak@proton.me: the contact address both stores show or ask for (the user, 2026-11-10; Gmail was blocked), also the Play developer account's login |
| `{PRIVACY_URL}` | https://kaitk.github.io/draughts/privacy/ (live 2026-11-09, from the `gh-pages` branch) |
| `{SUPPORT_URL}` | https://kaitk.github.io/draughts/ (the App Store's support page, live 2026-11-09, `gh-pages`) |

```sh
grep -rn '{DEVELOPER}\|{CONTACT_EMAIL}\|{PRIVACY_URL}\|{SUPPORT_URL}' store/   # what is left
```

## Publishing the privacy policy

Both stores need it at a public URL that isn't a PDF and that names the app.
`privacy/index.html` needs nothing else: no scripts, no fonts, no images. On GitHub Pages
for the repo `kaitk/draughts`, it shows at `https://kaitk.github.io/draughts/privacy/`
when the site is built from a branch or folder holding `privacy/index.html`. Check the URL
opens logged out before giving it to a store.

## The app's identity

The application id is `io.github.kaitk.draughts` (2026-11-08), set as `APP_ID` in
`scripts/native.py`. The bundle id is `io.github.kaitk.draughts.app`,
`BUNDLE_ID` in `scripts/ios.py`: a free team on a locked Apple ID holds the plain one, so
the suffixed one is kept for good (2026-11-12, `tasks/046-app-store-release.md`). Nobody
checks a reverse-domain id against the domain, so nothing need be served at its address. The version is `VERSION_NAME` in `native.py`, shared by
both platforms, with the build numbers `VERSION_CODE` in `scripts/android.py` and
`BUILD_NUMBER` in `scripts/ios.py`.
`docs/development.md`, "Release builds", says how the AAB is built and signed.
