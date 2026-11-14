# 087: The replay's move shown, the best move, and the desktop's results

Status: in progress (the width cap built 2026-11-14; the replay's takes to choose)

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
- [ ] The best move per position kept in the history: `judge` has it (the root move with
      the best exact score), the line needs a field (`best=`, a move per ply, empty where
      forced or not judged). Games already written have none: the replay then shows no
      best move.
- [ ] The replay's board: the faded piece, the shaded stops, the dots, after the move's
      animation; the best move as the hint's ghost and rings (`board::ghost_on`,
      `glow_on`) while asked for, with the bulb tile in the steps' column.
- [ ] The replay's glass: the best-was and best-next lines (strings in English and
      Estonian).
- [ ] A desktop's replay and results as the prototype: a capped column and list, larger
      words.
- [ ] Home's menu glass on an ultrawide runs from the window's edge to the capped area's
      (352 px wider at 3440): fine for now, maybe not bled there later.

## Acceptance criteria

- [x] The takes chosen by the user (2026-11-14)
- [ ] Built, with headless tests of the history's best moves and the replay's marks
- [ ] Shot on Windows at 1280 × 800, 2560 × 1440, and 3440 × 1440, then the tablet over
      USB
