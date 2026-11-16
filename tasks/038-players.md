# 038: Players on one tablet

Status: in progress (built 2026-11-09, checked on the devices; the badges' final
silhouettes to come)

A family shares one tablet: up to four local players, each a badge (an animal on its own
colour), an optional name, and their own look, move hints, setup, computer skill, stars,
and saved game; the language stays per device. No accounts, no network. How it works is
in `docs/architecture/README.md` and `rendering.md` ("Controls"); the decisions in
`docs/decisions/README.md` ("Players"). The takes, the open questions, and the build
notes are in git at 314c3b5.

## What is left

The final badge silhouettes from the user in `assets/badges/` (today's are traced
placeholders), drawn by `badge()` from the SVG files; then `test/run_tests.py --bless
badges` (`agents/testing.md`).

## Acceptance criteria

- [x] Up to four players, each with their own look, hints, setup, skill, stars, and game;
      switching in at most two taps; start again and remove as 1.5 s holds
- [x] An older install comes up as player 1 with nothing lost, also when killed mid-way
- [x] Headless tests; every tap 88 dp; strings in English and Estonian
- [x] The badges drawn in `badge()` from SVG files; the chip on home mirroring the X
- [x] Checked on the Mac and the tablet (the user, 2026-11-16)
- [ ] The final silhouettes from the user in `assets/badges/`
