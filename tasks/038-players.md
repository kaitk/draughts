# 038: Players on one tablet

Status: in progress (built 2026-11-09; the badges' final silhouettes to come; to check on
the Mac and the tablet)

A family shares one tablet: up to four local players, each a badge (an animal on its own
colour), an optional name, and their own look, move hints, setup, computer skill, stars,
and saved game; the language stays per device. No accounts, no network. How it works is
in `docs/architecture/README.md` and `rendering.md` ("Controls"); the decisions in
`docs/decisions/README.md` ("Players"). The takes, the open questions, and the build
notes are in git at 314c3b5.

Built: `src/shell/players.goose`, `who.goose`, `src/badges/`; tests `test/shell/players`
(including a migration killed at each step) and `test/shell/who`.

## What is left

- On the Mac and the tablet: home with the chip (no name, then a name), the card with one
  and four players, a new player's sheet, a hold partway, typing with Android's keyboard
  up, and a fresh install's first run. Sizes: `--size 960x600`, `600x960`, and a phone's
  `--dp 480 --size 1066x480`, `--size 450x1000 --dp 480`.
- Unsure: whether Android's keyboard covers the name field in the tablet's landscape
  (SDL's text input area isn't set: gfx has no call for it), and whether a hidden
  keyboard comes back on a second tap of the field.
- The final badge silhouettes from the user in `assets/badges/` (today's are traced
  placeholders).

## Acceptance criteria

- [x] Up to four players, each with their own look, hints, setup, skill, stars, and game;
      switching in at most two taps; start again and remove as 1.5 s holds
- [x] An older install comes up as player 1 with nothing lost, also when killed mid-way
- [x] Headless tests; every tap 88 dp; strings in English and Estonian
- [x] The badges drawn in `badge()` from SVG files; the chip on home mirroring the X
- [ ] Checked on the Mac at the tablet's and a phone's sizes, then on the tablet over USB
- [ ] The final silhouettes from the user in `assets/badges/`
