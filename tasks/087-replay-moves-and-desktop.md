# 087: The replay's move shown, the best move, and the desktop's results

Status: in progress (built and shot on Windows 2026-11-14; the tablet over USB left)

The user's notes on the results and the replay (2026-11-14): make clearer where a move
went from and to; show the ideal next move (on a forced move, say it is forced); larger
words and a narrower column and results list on a desktop; the marks only once the piece
has arrived; and an ultrawide not broken, the width capped on desktops.

## Built (2026-11-14)

Settled with the user in `prototypes/replay.html` (`?device=desktop|ultrawide`,
`?ply=60` for a king's capture), then built:

- The move shown: the piece at 30% where it started (`Board.trace`), its way in dots with
  a larger dot at each stop (`replay::dots_of`), the squares it stood on shaded, and the
  squares' numbers at its stops (`replay::numbers`). The dots, numbers, mark, and faded
  piece fade in over 0.25 s once the piece has arrived; the shading comes at once (a fade
  there would need a uniform in both renderers' shaders).
- The best move per position kept in the history (`best=`, `ai::Verdict.best_move`,
  `replay::Ply.best`; older lines have none) and shown as the hint while the bulb is on
  (a fifth step tile where the board's side holds it, else a tile on the glass's line).
  A forced position shows no best move and says so; "The best was" is a tap back to where
  it was best.
- No desktop window wider than 1.9 times its height (`gui::WIDEST`, `test/gui/widest`).
  A desktop's large window (`gui::large`): the replay's column 420 to 760 dp centered with
  the board, faces a size up, back in a head row over the board; the results at most
  1640 dp, centered.
- Tests: `test/shell/replay`, `test/shell/results`, `test/shell/sizes`, and the history's
  best moves in `test/drive`. Shot on Windows at the tablet's size, the Pixel's, and
  1280 × 800, 2560 × 1440, and 3440 × 1440 (`--touch off`): right as the prototype.

## Left

- The tablet over USB.
- Home's menu glass on an ultrawide runs from the window's edge to the capped area's
  (352 px wider at 3440): fine for now, maybe not bled there later.

## Acceptance criteria

- [x] The takes chosen by the user (2026-11-14)
- [x] Built, with headless tests of the history's best moves and the replay's marks
- [x] Shot on Windows at 1280 × 800, 2560 × 1440, and 3440 × 1440 (2026-11-14)
- [ ] The tablet over USB
