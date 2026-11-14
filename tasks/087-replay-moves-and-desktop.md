# 087: The replay's move shown, the best move, and the desktop's results

Status: in progress (the width cap built 2026-11-14; the replay's look chosen, to build)

The user's notes on the results and the replay (2026-11-14):

1. Make clearer where a move went from and to: a faded piece where it started, perhaps a
   dotted line, and every square the piece went through shaded, not only its ends.
2. Show the ideal next move somehow. Not on a forced move: there, say it is forced (the
   user, 2026-11-14).
3. On a desktop the replay's words (the line over the board, the move's mark and its tip)
   should be larger; the column needn't run from the board to the edge on a 27" screen,
   and the results' list is too wide there. The look on desktops in general; tablets
   are fine.
4. The marks of 1 and 2 come in only once a step's piece has arrived.
5. The game should work on an ultrawide: not look perfect, just not be broken. Width
   capped on desktops everywhere; the photograph blurred there only if it looks too soft.

## Prototype

`prototypes/replay.html` (2026-11-14), its steps working (the arrows and the list),
opened at move 20, white's blunder. `?device=desktop` and `?device=ultrawide` show a 27"
and a 34" ultrawide's full window.

Settled with the user (2026-11-14):

- The move shown: the piece at 30% where it started, its way in dots (dots, a dashed
  line, or none: dots), a larger dot at a capture's stop, and the squares it stood on
  shaded, where it started, each stop, and where it ended, the last a little more;
  neither the squares it passed over (a take shading the whole way was wrong: the user
  meant each stop) nor only its ends, as built. All of it, with the mark's disc, fades
  in over 0.25 s once a step's piece has slid in; a jump or a step back shows it at once.
- The best move as the hint (a ring on its piece, a light ghost and a ring where it
  goes, a ring at each stop), on the board only when asked for: the bulb tile under the
  steps, or a tap on the glass's line for it, turns it on, and it stays on through the
  steps until turned off. Set aside: white dots to a dashed ring, and words only.
- A forced move shows no best move on the board; the glass says "Black must take:
  22x33x24" (or "has one move").
- `?ply=60` opens at black's king capture (30x39x50), where the stops show.

Proposed, for the user (2026-11-14):

- The squares' numbers at the move's stops (30, 39, 50) and at the best move's while it
  shows, as the move list writes them, small and bold in each square's top left corner
  over a dark halo, 20% of a square and 11 dp at least, fading in with the rest;
  `?nums=0` leaves them out. Russian and Brazilian would show `c3` the same way.
- On a phone (landscape under 600 dp, and portrait) the bulb leaves the steps, where a
  fifth tile doesn't fit (a column of four is 400 dp of the Pixel's 432 in landscape;
  in portrait a row of five would be under 88 dp each), and the glass's line for the best
  move becomes a tile a tap tall, the bulb at its left, lit in the glow while the move
  shows. The tablet and a desktop keep the bulb under the steps. The line over the board
  is the short one there, and portrait drops the marks' legend for the moves' rows.
- The glass: under the move shown, after a ?!, ?, or ?? move, "The best was 31-26" with
  the star; then the line for the next move ("Best next for white: 31-26", or forced,
  or "The game ended here").
- A desktop's large window: the steps, the board, and a column of at most 760 dp
  centered as one, the column's words 1.5 times as large, taps 64 dp.
- `prototypes/results.html` on a desktop: at most 1640 dp wide, centered, its words
  larger.

The best moves are the engine's: the shared game played through `ai::judge` at the
judge's depth (a throwaway program in `build/`), so they are real. The shared game's
marks are made up and disagree with the engine's in places (the engine finds 15-20 and
41-36 best where the game marks them ?!), so those two show no "best was".

## Native work

- [x] No desktop window wider than 1.9 times its height (`gui::WIDEST` in `gui::safe`,
      glass bled over the sides); `test/gui/widest`. Shot at 3440 × 1440: home, the 3D
      game (unchanged: its frame already held the panels by the board), the results,
      settings, the replay. The photograph is magnified 1.68× there, sharp enough; no
      blur.
- [x] The best move per position kept in the history (2026-11-14): `ai::Verdict.best_move`
      and `has_best` (the root move with the best exact score), carried by the worker's
      `Thought` to `game::judged` into `Note.best`, written as `best=` (a move per ply,
      `-` for an only move or one not judged), read by `history::moves_of` into
      `replay::Ply.best`. Older lines have none: the replay then shows no best move.
      `test/expected/history.out` blessed with the field.
- [x] The replay's board, its part in the board (2026-11-14): `Board.trace` (set by
      `replay::open`) shades every square of the last move's path and draws the piece at
      `TRACE_GHOST` (30%) where it started; `Board.hint_via` rings a hint's stops while
      its ghost shows (cleared by `show` and `start_move`). Shot on Windows at 1280 × 800
      (`--screen replay --ply 15`, a capture): right.
- [ ] The replay's dots and numbers, drawn as UI over the board after the move's
      animation, as `replay::badge` draws the mark: glow discs along the path from square
      centre to centre, clear of the end pieces (0.42 of a square), 0.3 of a square apart,
      a larger one at each stop; the squares' numbers (`rules::format_square`) at the
      path's squares, and at the best move's while it shows, top left, bold, 20% of a
      square and 11 dp at least, over a dark halo (`gui::shadowed` is the halo's model).
- [ ] The best move on the board while asked for: `Replay.best` (off at first, kept
      through the steps); each frame at rest, where `plies[ply].has_best`,
      `board::glow_on(from)`, `ghost_on(to)`, `hint_via` the stops between; off, glow and
      hint_to -1. The bulb: a fifth step tile under the four, 8 dp further, where a
      landscape board holds five taps (the tablet, a desktop); else the glass's best
      line is the toggle, a thin 44 dp tile with its tap 88 dp (phones, portrait). A
      `--best` dev flag for shots.
- [ ] The replay's glass: the best-was and best-next lines (strings in English and
      Estonian).
- [ ] A desktop's replay and results as the prototype: a capped column and list, larger
      words.
- [ ] Home's menu glass on an ultrawide runs from the window's edge to the capped area's
      (352 px wider at 3440): fine for now, maybe not bled there later.

Then the glass's lines (the best was, best next, forced, the game ended; strings in
`strings/en.txt` and `et.txt`, `replay.*`), the desktop's replay column (at most 760
dp, larger faces) and results (at most 1640 dp), `test/shell/replay` checks (the best
moves read, the bulb's place at test/shell/sizes' sizes, taps 88 dp), and the docs
(`docs/architecture/rendering.md`'s replay and results sections, a decision in
`docs/decisions/rendering.md`).

## Acceptance criteria

- [x] The takes chosen by the user (2026-11-14)
- [ ] Built, with headless tests of the history's best moves and the replay's marks
- [ ] Shot on Windows at 1280 × 800, 2560 × 1440, and 3440 × 1440, then the tablet over
      USB
