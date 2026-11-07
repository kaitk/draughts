# 025: Build the regrouped settings with the board beside them

Status: todo

Bring settings to `prototypes/settings.html` (rendering.md "Settings", 2026-11-07): the
choices as words in two groups, game (the draughts for a new game, move hints, the
tutorial) and look (background, board, kings), the language in the title row, and home's
board beside them showing what the choices make.

## Work

- `shell/settings.goose`: the groups and rows; the draughts for a new game (international
  dimmed until task 002's 10×10 is on screen, Brazilian until task 023), kings (auto,
  crown, stack; the crown and stack tiles draw their king), the tutorial's tile (task
  026), the language at the title row's right end.
- The board beside them is home's board, drawn with the choices: 10×10 or 8×8, the move
  hints' look on a fixed position (all moves: a capture shown; mistakes only: a wrong
  move's ring and the piece that must capture pulsing). In landscape the choices take
  the width they need at the left and the board the rest; in portrait the board is on
  top and the groups side by side under it.
- Stacked kings are two plain discs, no crown, in the piece shader (rendering.md "Kings").
- `settings.txt` keeps the new values; strings for every new word.

## Acceptance criteria

- [ ] Settings match the prototype in both orientations, on the Mac and the tablet
- [ ] Each choice changes the board beside them at once and survives a restart
- [ ] Headless tests for the new settings and their file

## Settled while scoping (2026-11-08)

- International is the default draughts for a new game once 10×10 is on screen (task
  021); settings' draughts row and the setup's are one setting in `settings.txt`.

## Open for the user
