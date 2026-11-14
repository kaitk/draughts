# 087: The replay's move shown, the best move, and the desktop's results

Status: in progress (built and shot on Windows 2026-11-14; the tablet over USB left)

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
- [x] The replay's dots and numbers (2026-11-14): UI over the board, `replay::dots_of`
      and `replay::numbers`, as specified; no bold face in the atlas, so a number is drawn
      twice half a pixel apart over a halo of eight dark copies. They, the mark's disc,
      and the faded piece (`Board.trace_a`) fade in over 0.25 s once the piece has
      arrived (`replay::revealed`, `replay::animating` keeps frames coming); the squares'
      shading still comes in at once, being the board shader's bits (a fade there would
      need a uniform in both renderers' shaders: left out).
- [x] The best move on the board while asked for (2026-11-14): `replay::show_best` sets
      `glow`, `hint_to`, and `hint_via` each frame at rest, their pulse times -1 so they
      stay lit and still (`glow_on` each frame would pulse forever and keep drawing).
      The bulb a fifth step tile where the board's side holds five taps and 48 dp (the
      tablet's 726 dp, the foldable's 527, a desktop), dimmed where the position has no
      best move; else the glass's line, a 44 dp tile with an 88 dp tap. `--best on`.
      `Ply.only` marks a forced position: no best there, the line says it is forced.
- [x] The glass's lines, `replay.best_was`, `replay.next_*`, `replay.take_*`,
      `replay.one_*`, `replay.ended` in English and Estonian; shown where the game has
      best moves. Portrait and a phone's landscape drop the legend; a phone's landscape
      the best-was line.
- [x] A desktop's large window (`gui::large`, 1700 × 1000 dp: the 27" full window and a
      1280 × 800 one): the replay's column 420 to 760 dp, centered with the steps and
      board, its faces a size up (body to label, small to heading) and sizes 1.5×; the
      results at most 1640 dp, centered, a face up, rows 96 dp, panel 480. The replay's
      head keeps its 64 dp tiles and faces.
- [x] "The best was" a tap too on the tablet and a desktop (2026-11-14, the user: ship it
      with this): back one move to where it was best, the best move turned on; lit under
      the mouse, as the next move's line now is. `test/shell/replay` taps it.
- [x] Back at the top left on a desktop's large window (2026-11-14): a head row over the
      board, its left edge at the board's, the line over the board in the row's middle,
      level with back (first under the row, which pushed everything down: the user moved
      it up); the board's top level with the glass's, the title and play from here at the
      column's head. Board 943 dp at 1280 × 800 (was 980; its line the short one there,
      kept clear of back) and 1476 at 2560 × 1440 and 3440 × 1440 (was 1513). Not the tablet: a row there would cost its board
      100 dp of 726. Shot on Windows at 2560 × 1440, 1280 × 800, 3440 × 1440
      (`--touch off`) and the tablet at move 60: right.
- [ ] Home's menu glass on an ultrawide runs from the window's edge to the capped area's
      (352 px wider at 3440): fine for now, maybe not bled there later.

Tests (2026-11-14): `test/drive`'s past games carry best moves (`-` for an only move);
`test/shell/replay` checks the best moves read (61 of 80, the 19 forced with none), the
bulb on, kept through a step, nothing at a forced move and the bulb dimmed there, the
marks' fade (0 while moving, 0.5 at 0.125 s, 1 at 0.25 s), the dots (a quiet move 3, the
four-square capture 27 with 2 at stops, kept 0.42 from the ends and 0.28 from the stops)
and numbered squares, the bulb's place and the taps at every size (88 dp, the line's
tile's tap included), and the desktops (both large, the column 579 dp at 1280 × 800 and
760 at 2560 × 1440 and 3440 × 1440, centered). `test/shell/results` the desktops (the
whole 1580 dp from back to the list's right, rows 96 dp, centered); `test/shell/sizes`
measures each tile by the tap round it.

Shot on Windows (2026-11-14, `build/shots/`, a history from the shared game with the
engine's marks and best moves): the tablet's 1280 × 800 at move 60 (the king's capture,
its stop dot at 39 and numbers 30, 39, 50), 39 (forced, "Black must take: 22x33x24"),
and 19 with the best on ("The best was 27-21", 10-14 on the board); the desktop at
1280 × 800, 2560 × 1440, 3440 × 1440 (`--touch off`), the Pixel's landscape and portrait
(the line a lit tile), the results at 2560 × 1440. Right as the prototype. Quads: 589 at
most on a desktop. The tablet over USB waits for the Mac (no adb on this PC).

## Acceptance criteria

- [x] The takes chosen by the user (2026-11-14)
- [x] Built, with headless tests of the history's best moves and the replay's marks
- [x] Shot on Windows at 1280 × 800, 2560 × 1440, and 3440 × 1440 (2026-11-14)
- [ ] The tablet over USB
