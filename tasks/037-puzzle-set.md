# 037: A better puzzle set

Status: in-progress

Task 007's 30 International puzzles read like a tutorial: mostly too simple, an odd
curve, and some solved with a capture still due. This task kept the best as a Learn theme
and replaced the rest with a set grouped by theme, with the picker redesigned around it.

Built 2026-11-09 and 10 (the audit, the sources, the prototypes, and each set's
composing notes are in git at 314c3b5; the decisions in `docs/decisions/puzzles.md`):

- International: Learn 12, Captures 10, Crowning 12, Shots 20 (levels 1 and 2), King
  shots 10, Safe move 10; about a third black to move outside Learn. Russian and
  Brazilian have their own sets (`src/puzzles/russian.txt`, `brazilian.txt`), chosen by
  the player's draughts, which the library's switch also sets.
- `theme` and `level` replace `tier`; stars per variant (`stars.<variant>` in the player's
  file). `puzzles::check` refuses an end that isn't quiet and an unlisted solving move
  anywhere in a line; `tools/puzzles.goose find` composes candidates.
- Every puzzle passes `build/puzzles` with the engine agreeing, and `test/perft.py
  puzzles`; the picker is tested headless (`test/shell/picker`, `sizes`, `puzzles`).

## Open

- **Safe move**: black to move in a third (turn some with `find black safe`), and level
  3 threats that are double sacrifices.
- **Shots level 3** (named shots, game finishes) and the later themes. Skeletons that
  play the course lines were written for the Haarlem shot (`W:W28,32,34,37:B10,17,19,23`,
  28-22 17x28 34-29 23x34 32x5), the bomb (`W:W27,28,32,37,38,43:B16,17,18,19,23,29`,
  27-21 16x27 32x12 23x41 12x34), the heel shot (`W:W30,34,38,40,45:B21,22,23,25,28`,
  38-33 28x39 34x43 25x34 40x16), coup Philippe (`W:W27,32,34,38,40,45:B11,12,16,18,23,25`,
  27-22 18x27 32x21 16x27 34-30 25x34 40x16), and the royal shot
  (`W:W27,28,32,38,39,40,45:B12,13,14,18,19,23,24`, 27-22 18x27 32x21 23x34 40x7). `find`
  round the Haarlem core gave candidates, but the two checked (a Haarlem shot and a
  Napoleon's shot) had the engine preferring a quiet move, so neither is in.
- **The look on devices**: the new icons (book, jumps, king, the level bars) and the
  glow-colored bar and marks are shader work the headless tests don't see.

## Acceptance criteria

- [x] A prototype of the library and a theme's page, and the user's pick of a take
- [x] The file's `theme` and `level` in place of `tier`, the picker as picked, and stars
      carried over by id per variant
- [x] Learn: about 12 of today's puzzles, each fixed so no capture is due for either side
      after its line and against any reply
- [x] The first release's themes (Captures, Crowning, Shots levels 1 and 2, King shots),
      about a third black to move, each `source` naming its motif or game, none copied
      position for position from any collection (GoDraughts, lidraughts, books)
- [x] `puzzles::check` refuses a puzzle whose end isn't quiet, and one with an unlisted
      solving move later in a line, not only the first
- [x] Every puzzle passes `build/puzzles` with the computer player's best move solving it
      and no right move it scores as losing material; `test/perft.py puzzles` passes
- [x] A black-to-move puzzle tested headless on the turned board, its panel saying whose
      move it is
- [x] The solver's limits fit the longest line (`MAX_PLIES` is 8, four of the solver's
      moves), with its positions per check measured and recorded here
- [ ] The picker checked on the Mac and the tablet (the main session's screenshots)
- [ ] Children play the set and the levels' order holds (the user)
