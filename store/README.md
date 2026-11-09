# Store materials

What goes into Google Play Console and App Store Connect for Draughts, drafted so it can
be pasted in. Images (the icons, the feature graphic, screenshots) stay local in
`~/Downloads/draughts-store/` (below, "Screenshots and the feature graphic").

| File | What it is |
| --- | --- |
| `listing-en.md` | Play's listing in English: title, short and full description |
| `listing-et.md` | The same in Estonian, with notes on the wording |
| `play-console.md` | Play's App content answers: Data safety, ads, content rating (IARC), target audience and the Families Policy, the other declarations, the store settings, and the account |
| `app-store.md` | The App Store's listing (English only) and App Store Connect's answers: App Privacy, age rating, the Kids category, export compliance, the privacy manifest, review notes, and what the iOS build still needs |
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

The current sets, outside git, taken 2026-11-09 from `main` at `1824780`, each scene in
English and Estonian:

| Folder | Size | For | Made with |
| --- | --- | --- | --- |
| `screenshots/play-0.2/phone/` | 1080 × 1920, 9:16, laid out at 548 dp (a 1080 px phone at the 0.75 density floor) | Play's phone slot | The Mac app, `--frames` |
| `screenshots/play-0.2/tablet/` | 2560 × 1440, 16:9 | Play's 7" and 10" tablet slots | The Mac app, `--frames` |
| `screenshots/app-store-0.2/iphone-6.9/` | 1320 × 2868 | The App Store's iPhone 6.9" set | An iPhone 16 Pro Max simulator, iOS 26.4, headless |
| `screenshots/app-store-0.2/ipad-13/` | 2064 × 2752 | The App Store's iPad 13" set | An iPad Pro 13-inch (M4) simulator, iOS 26.4, headless |

The seven scenes, in the order to upload, each a season so all four show:

1. `01-home-3d-winter`: home on the 3D board, winter, with the player's chip
2. `02-game-autumn`: International on the flat board, a selected man's capture of two
   shown with move hints on, autumn
3. `03-game-3d-summer`: the same position on the 3D board, summer
4. `04-puzzles-spring`: the library of six themes, some solved, spring
5. `05-puzzle-winter`: a Shots puzzle (55), black to move, after the first move and the
   reply, the capturing man selected, winter
6. `06-settings-autumn`: settings; on Play's phone the Look tab (a local build), on the
   iPhone the Game tab
7. `07-computer-summer`: the computer's setup, summer

The player is made up (Mia the fox, with some stars): `play-0.1/player-1.txt` and
`settings.txt`, written into the Mac's app data (copied aside first and put back after)
and into each simulator's container. The Mac's shots come from one batch of 28 runs
(about 4 minutes of windows); the phone's Look tab needs a second, local build with
`group: i64 = 1` in `src/shell/settings.goose`'s `Settings`, never committed: no flag
picks the tab. The simulator draws the Dynamic Island into its framebuffer, so the iPhone
shots have it painted over with the background just below it, mirrored
(`iphone-6.9-raw/` keeps them as taken). The scripts that took them are kept beside the
sets.

`play-0.1/feature-graphic-draft.png` (1024 × 500, no alpha) is the only feature graphic, a
first draft: the autumn photograph softened and dimmed, the flat board at the right, and
the wordmark "Draughts" in Libertinus Sans (`assets/fonts/`) beside home's king. Play's web
page puts the title beside it, so the wordmark repeats it; and the Estonian listing may
have its own, with "Kabe" (Play takes a feature graphic per language). The older sets
(`play/`, `apple-*`, `play-0.1/`, before the 3D board, the sixth theme, and the Russian
puzzles) are superseded.

The icons: `icon/play-512.png` and `icon/apple-1024.png`, from `scripts/icon.py --store`.

## Placeholders

Replace these everywhere in this folder before anything is published:

| Placeholder | Value |
| --- | --- |
| `{DEVELOPER}` | The developer name on Play, a personal games identity; on the App Store an individual's legal name is shown instead; open |
| `{CONTACT_EMAIL}` | The contact address both stores show or ask for; open |
| `{PRIVACY_URL}` | `https://kaitk.github.io/draughts/privacy` (to confirm) |
| `{SUPPORT_URL}` | The App Store's required support page, a page with the contact address; `https://kaitk.github.io/draughts/` (to confirm) |

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

The application id and bundle id are `io.github.kaitk.draughts` (2026-11-08), set as
`APP_ID` in `scripts/android.py` and `scripts/ios.py`, and the version as `VERSION_CODE`
and `VERSION_NAME` (Android) and `VERSION_NAME` and `BUILD_NUMBER` (iOS) beside it.
`docs/development.md`, "Release builds", says how the AAB is built and signed.
