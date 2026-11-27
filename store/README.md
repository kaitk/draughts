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
| `release-notes.md` | Each version's notes: the GitHub release's, Play's "What's new" in English and Estonian, and the App Store's |
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
layouts; the consoles' own previews have the last word.

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

The App Store's rules are in `app-store.md`, "Screenshots".

## Screenshots and the feature graphic

All images stay outside git in `~/Downloads/draughts-store/`. Upload from its `upload/`:
the sets flattened to 24-bit RGB, since both stores refuse alpha, with
`magick IN -background black -alpha remove -alpha off -type TrueColor OUT`.

The App Store's set for 0.9.4, from `main` at `f03173a8`, is in `2026-11-27/`:
`app-store/iphone-6.9/` (and `-raw/`) and `app-store/ipad-13-landscape/`, with `upload/`
(the iPhone 6.3" set among them), contact sheets, `check.txt`, and `scripts/` with a
README. After App Review's second 5.6 rejection (0.9.0, 2026-11-23), it shows only what a
reviewer reaches in minutes from a fresh install: a player with 5 of the 12 Learn puzzles
solved, so the other themes and the daily puzzles show locked, and every scene in winter,
the season the date gives from 1 December. Play keeps the 0.9.0 set below.

The set for 0.9.0, from `main` at `e77693f`, is in `2026-11-16/`: `play/phone/`,
`play/tablet/`, `app-store/iphone-6.9/` (and `-raw/`), and `app-store/ipad-13-landscape/`,
with its own `upload/` (the iPhone 6.3" set among them), a contact sheet per device type,
`check.txt` (each image against the rules), and the `scripts/` that made them, with a
README saying how. It replaces `2026-11-14/`, never uploaded. App Review rejected 0.8.0
on 2026-11-16 under Guideline 5.6, features "hidden during review", while the App Store
still showed the 0.3 screenshots, whose home differs from the build's; so every set
uploaded shows only what that platform's build shows. The iPad's shots come from a
headless copy that reports itself as iOS, since the desktop's draws a close button on
home that iOS has not. The App Store's sets are English only, as its listing is
(`app-store.md`); Play's are in English and Estonian. The sets before it:

| Folder | Size | For | Made with |
| --- | --- | --- | --- |
| `screenshots/play-0.3/phone/` | 1080 × 1920, 9:16, laid out at 548 dp (a 1080 px phone at the 0.75 density floor) | Play's phone slot | The app's headless copy, `--frames` |
| `screenshots/play-0.3/tablet/` | 2560 × 1440, 16:9 | Play's 7" and 10" tablet slots | The app's headless copy, `--frames` |
| `screenshots/app-store-0.3/iphone-6.9/` | 1320 × 2868 | The App Store's iPhone 6.9" set | An iPhone 16 Pro Max simulator, iOS 26.4, headless |
| `upload/app-store-0.3/iphone-6.3/` | 1206 × 2622 | The App Store's medium iPhone slot (6.1" and 6.3") | The 6.9" set scaled, `magick -resize 1207x2622^ -gravity center -extent 1206x2622` |
| `2026-11-12/upload/app-store/ipad-13-landscape/` | 2752 × 2064 | The App Store's iPad 13" set, landscape | The app's headless copy at `--size 2752x2064 --inset 0,0,0,15.5`; its `scripts/` say how |

The seven scenes, in upload order, each a season so all four show:

1. `01-home-3d-winter`: home on the 3D board, with the player's chip
2. `02-game-autumn`: International on the flat board, a selected man's capture of two
   shown with move hints on
3. `03-game-3d-summer`: a position on the 3D board with the lookout on, a threatened man
   drained grey, the hint ready, and the captured pieces in the bar
4. `04-puzzles-spring`: the library, some themes solved
5. `05-puzzle-winter`: a Shots puzzle mid-solution, the capturing man selected
6. `06-settings-autumn`: settings
7. `07-computer-summer`: the computer's setup

How they are made:

- The player is made up (Mia the fox): `play-0.1/player-1.txt` and `settings.txt`,
  copied into the app data or the simulator's container, the originals put back after.
- Play's and the iPad's shots are one batch of runs of the headless copy
  (`agents/testing.md`), each waiting 6 s of the clock so every fade has finished. Play's
  phone shows settings' Look tab, which needs a local build with `group: i64 = 1` in
  `src/shell/settings.goose`'s `Settings`, never committed.
- The simulator draws the Dynamic Island into its framebuffer, so `island_fill.py` paints
  it over with the season's photograph from `design/backgrounds/masters/`.
- The tablet's own 16:10 doesn't fit Play's tablet slots, so its shots are 16:9:
  `--size 1280x720`, 2560 × 1440 on a Retina screen.

The feature graphic is `feature-0.2/feature-render-close-name.png` (1024 × 500, no
alpha): the autumn 3D board close at a low angle, rendered headless without the UI, with
home's king and "Draughts" over the blurred forest; its `README.md` and `fgshot.py` say
how. The Estonian listing may take its own, with "Kabe". The App Store's optional
product-page art is in `apple-header-0.1/`, with its own `README.md`. The icons are
`icon/play-512.png` and `icon/apple-1024.png`, from `tools/assets/icon.py --store`.

## Placeholders

The values to put in place of these wherever they are left in this folder:

| Placeholder | Value |
| --- | --- |
| `{DEVELOPER}` | Gideonic: the developer name on Play; on the App Store an individual's legal name is shown instead, and is the copyright's (`app-store.md`) |
| `{CONTACT_EMAIL}` | kaitkasak@proton.me: the contact address both stores show or ask for, also the Play developer account's login |
| `{PRIVACY_URL}` | https://kaitk.github.io/draughts/privacy/ (from the `gh-pages` branch) |
| `{SUPPORT_URL}` | https://kaitk.github.io/draughts/ (the App Store's support page, `gh-pages`) |

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
the suffixed one is kept for good (2026-11-12). Nobody
checks a reverse-domain id against the domain, so nothing need be served at its address. The version is `VERSION_NAME` in `native.py`, shared by
both platforms, with the build numbers `VERSION_CODE` in `scripts/android.py` and
`BUILD_NUMBER` in `scripts/ios.py`.
`docs/development.md`, "Release builds", says how the AAB is built and signed.
