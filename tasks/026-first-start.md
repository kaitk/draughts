# 026: Build the first start and the tutorial

Status: todo (after the MVP's menus, 2026-11-07: not in the MVP's scope)

Bring the first start to `prototypes/first-start.html` (task 019): which draughts (two
cards with the starting position: international, the default once it exists, and
Russian), learn the moves or just play, the tutorial, and what to play first. Settings'
tutorial tile opens the tutorial again.

## Work

- The pages as a shell screen, shown on the first launch only (a flag in `settings.txt`).
- The tutorial's steps as data: a position, the move it shows, a title and a line, per
  variant (Russian 7 steps, International 8: majority capture, and how each crowns
  mid-capture). Move hints show the moves here, and go back to the setting after.
- Each step's move is played on the board by tapping, with the hints on; next is lit once
  it is played. Positions checked with `test/perft.py moves`.
- Strings for every title and line.

## Acceptance criteria

- [ ] A fresh install opens on the variant cards; later launches open home
- [ ] Each step can be played on the board and goes on; done leads to a new game's setup
- [ ] Headless tests for the step positions' moves and the flow
