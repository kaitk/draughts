# Google Play materials

What goes into Play Console for Draughts, drafted so it can be pasted in. Images (the
512 px icon, the feature graphic, screenshots) stay local in `~/Downloads/draughts-store/`
(below, "Screenshots and the feature graphic").

| File | What it is |
| --- | --- |
| `listing-en.md` | The store listing in English: title, short and full description |
| `listing-et.md` | The same in Estonian, with notes on the wording |
| `privacy/index.html` | The privacy policy, English and Estonian on one standalone page |
| `play-console.md` | The App content answers: Data safety, ads, content rating (IARC), target audience and the Families Policy, the other declarations, and the store settings |

## Play's image rules

Read 2026-11-09 from Play Console Help
([9866151](https://support.google.com/googleplay/android-developer/answer/9866151),
[1078870](https://support.google.com/googleplay/android-developer/answer/1078870)); check
them again before an upload.

| Image | Rule |
| --- | --- |
| Any screenshot | JPEG or 24-bit PNG, no alpha; each side 320 to 3,840 px, the longer at most twice the shorter; up to 8 per device type; at least 2 across device types to publish |
| Phone | The general rule; for a game to be recommended in formats that use screenshots, at least 3 at 16:9 landscape (at least 1920 × 1080) or 9:16 portrait (at least 1080 × 1920) |
| 7" and 10" tablets, Chromebooks | "Large screens": at least 4, each side 1,080 to 7,680 px, 16:9 landscape or 9:16 portrait, and no text that isn't part of the app (Play's pages may crop it) |
| Feature graphic | 1024 × 500, JPEG or 24-bit PNG, no alpha; required |
| Icon | 512 × 512, 32-bit PNG with alpha, at most 1,024 KB |

The tablet's own 16:10 (2560 × 1600) doesn't fit the tablet slots, so the tablet's shots
are taken at 16:9: `--size 1280x720`, 2560 × 1440 on the Mac's Retina screen.

## Screenshots and the feature graphic

In `~/Downloads/draughts-store/screenshots/play-0.1/`, outside git, taken from the app on
the Mac with `--frames` (2026-11-09):

| Folder | Size | For |
| --- | --- | --- |
| `tablet/` | 2560 × 1440, 16:9 | The 7" and 10" tablet slots |
| `phone/` | 1080 × 1920, 9:16, laid out at 548 dp (a 1080 px phone at the 0.75 density floor) | The phone slot |
| `tablet-16x10/` | 2560 × 1600 | The tablet's own shape, for anything but Play |

Each holds the same six, in the order to upload: `01-home-en` (home with the player's
chip), `02-game-en` (International, a selected man's capture of two shown with move hints
on), `03-puzzles-en` (the library of five themes, some solved), `04-puzzle-en` (Shots,
black to move, after the first move and the reply, the capturing man selected),
`05-settings-en` (the seasons' photographs; on the phone the Look tab), and
`06-computer-et` (the computer's setup in Estonian). All are autumn, the season by date.
The Estonian listing can use the English set (Play shows the default language's
screenshots where a translation has none) or a full Estonian set from the same script
with `--lang et`.

`feature-graphic-draft.png` (1024 × 500, no alpha) is a first draft for the user: the
autumn photograph softened and dimmed, the board from the tablet's home shot at the
right, and the wordmark "Draughts" in Libertinus Sans (`assets/fonts/`) beside home's king
at the left, with no other text.

The folder keeps what made them. `shoot.sh tablet phone tablet-16x10`, run from `app/`
after building, writes a made-up player (Mia the fox, with some stars) from its
`player-1.txt` and `settings.txt` into the Mac's app data, so copy that folder aside
first and put it back after. The phone's settings on the Look tab need a second, local
build, `../../build/draughts-look`, with `group: i64 = 1` in `src/shell/settings.goose`'s
`Settings`, never committed: no flag picks the tab. `feature.sh` makes the feature
graphic with ImageMagick.

## Placeholders

Replace these everywhere in this folder before anything is published:

| Placeholder | Value |
| --- | --- |
| `{DEVELOPER}` | The developer name on Play, a personal games identity; open |
| `{CONTACT_EMAIL}` | The contact address Play shows on the listing; open |
| `{PRIVACY_URL}` | `https://kaitk.github.io/draughts/privacy` (to confirm) |

```sh
grep -rn '{DEVELOPER}\|{CONTACT_EMAIL}\|{PRIVACY_URL}' store/   # what is left to fill in
```

## Publishing the privacy policy

Play needs it at a public URL that isn't a PDF and that names the app. `privacy/index.html`
needs nothing else: no scripts, no fonts, no images. On GitHub Pages for the repo
`kaitk/draughts`, it shows at `https://kaitk.github.io/draughts/privacy/` when the site is
built from a branch or folder holding `privacy/index.html` (Pages for a private repo needs
a paid plan; a public repo of its own, holding only the page, works on any plan). Check the
URL opens logged out before giving it to Play.

## The app's identity

The application id is `io.github.kaitk.draughts` (2026-11-08), set as `APP_ID` in
`scripts/android.py`, and the version as `VERSION_CODE` and `VERSION_NAME` there.
`docs/development.md`, "Release builds", says how the AAB is built and signed.
