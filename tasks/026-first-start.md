# 026: Build the first start and the tutorial

Status: todo (after the MVP's menus, 2026-11-07: not in the MVP's scope)

Bring the first start to `prototypes/first-start.html` (task 019): which draughts (two
cards with the starting position: international, the default once it exists, and
Russian), learn the moves or just play, the tutorial, and what to play first. Settings'
tutorial row comes back with it (taken out 2026-11-09 so the tablet's landscape fits both
groups; the game group has room for it there only if the look's rows stay as they are),
and its tile opens the tutorial again.

## Work

- The pages as a shell screen, shown on the first launch only (a flag in `settings.txt`).
- The tutorial's steps as data: a position, the move it shows, a title and a line, per
  variant (Russian 7 steps, International 8: majority capture, and how each crowns
  mid-capture). Move hints show the moves here, and go back to the setting after.
- Each step's move is played on the board by tapping, with the hints on; next is lit once
  it is played. Positions checked with `test/perft.py moves`.
- Strings for every title and line.

## References

- GoDraughts (https://godraughts.com/en, its Android app `net.devdad.internationaldraughts`;
  the user, 2026-11-08): a good modern draughts app with an interactive rules tutorial,
  training courses, and coaching from the player's own mistakes. For adults, but worth
  studying for how it teaches.

## Acceptance criteria

- [ ] A fresh install opens on the variant cards; later launches open home
- [ ] Each step can be played on the board and goes on; done leads to a new game's setup
- [ ] Headless tests for the step positions' moves and the flow
