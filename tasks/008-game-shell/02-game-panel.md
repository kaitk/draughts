# 008-02: The game panel

Status: todo

The panel from 01 working, as rendering.md ("Controls", "Game screen") and
`prototypes/game.html` show it.

## Work

- The side to move on top: a piece of its color with a glow ring, no text.
- The move-hints toggle beside it (`docs/product.md`): mistakes only or moves, one tap.
- Undo (a stack of positions, as `docs/architecture/README.md` says), restart, and back
  (to home once 03 exists; until then it does nothing). Hint shows one good move: the
  computer player's (task 006) when it exists; until then a capture that must be made,
  or else nothing.
- A celebration on a win: a few drifting sparks and the winner's piece, from the solved
  screen's style (`prototypes/solved.html`), then restart or back.
- Buttons can't be confused with the board: a press that starts on the panel never
  moves a piece, and the reverse.

## Acceptance criteria

- [ ] Side to move and the hints toggle, in both orientations
- [ ] Undo, hint, restart, and back working; tested headless where they change the game
- [ ] A celebration on a win
- [ ] Checked on the Mac and the tablet; idle still draws nothing
