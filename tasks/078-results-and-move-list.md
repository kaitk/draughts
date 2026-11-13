# 078: The results screen, the move list on phones, and the marks explained

Status: in progress

The user's review of task 074's results screen at the Pixel 7a's landscape size
(2026-11-13):

1. The draughts' tiles at the head's right (International, Brazilian, Russian with their
   ratings) are hard to see: the unchosen ones are glass on a bright background.
2. The move list's setting (Off, Moves, Marks) is on the results screen and in settings:
   once is enough, in settings, and what Moves and Marks do is unclear there.
3. **A**: on phones the moves of the game in progress show nowhere (the Pixel 7a and the
   iPhone). In landscape at least, and in some form in portrait, there should be a line
   of the last move, opening the whole list (task 074's take d and open question 3).
4. **B**: a mark (?!, ?, ??, the star, the only move) explains itself when touched, or
   under the mouse.
5. **C**: a past game opens from the results screen with its whole move list, and beside
   it a board to replay it on; a game replayed counts neither as the game to resume nor in
   the results (task 074's open question 9, the prototype's `view=replay`).

Task 074 carries the rest of the history's work; this one these points.

## Steps

- [x] 1 and 2 fixed in the app: the tiles readable, the setting only in settings with a
      line saying what each choice shows
- [x] A, B, and C prototyped in `prototypes/history.html`, for the user to choose
      (2026-11-13, below)
- [ ] The chosen takes built, checked on the Mac at the Pixel's and the iPhone's sizes,
      then on a phone

## Acceptance criteria

- [x] The results screen's head readable on every season's background
- [x] The move list's setting in one place, its choices explained
- [ ] A phone in landscape shows the last move and opens the list; portrait as chosen
- [ ] A mark explains itself on a touch and under the mouse
- [ ] A past game's moves listed and replayed on a board, touching neither resume nor the
      results

## Notes

- 1 and 2 (2026-11-13): the draughts' tiles on one glass as the puzzles' switch; the move
  list's line beside its tiles where the group's width leaves room. Under them always,
  the tablet's landscape preview went from 242 to 137 dp; beside, it keeps its size in
  every stacked landscape, and portrait's board gives up 24 to 36 dp (`test/shell/sizes`).
  The results panel's freed room shows the levels on a phone in landscape. Checked on
  the Mac at the Pixel 7a's landscape (four themes) and portrait, and the tablet's size.

## Takes to choose

The prototype is `prototypes/history.html` (2026-11-13). The device's insets follow the
window's size unless `&device=pixel`, `iphone`, `a33`, or `none` names them: the Pixel 7a
at 1066 × 480 dp (its 52 dp cutout and 37 dp gesture bar), the iPhone 13 mini at 812 ×
375 pt (50 at each side and 21 at the foot in landscape; 50 at the top and 34 at the foot
in portrait), the tablet at 1280 × 800 with none.

### A: the moves on a phone

Landscape, `?view=game&take=d` (`&open=1` the sheet; `&grid=1` all phones side by side):
task 074's take d with `fit=row`, the moves under the captured pieces and the earlier
rows faded, as the user directed. A tap on the rows opens the sheet over the screen's left
part; the board stays whole and playable.

- Pixel 7a, safe 1014 × 443 dp: the column 204 dp, the catch 79 (two rows), the moves 88
  (two rows), the board 395; the sheet 350 dp wide, 6 rows.
- iPhone 13 mini, safe 712 × 354: the built column (336 dp) would leave −12 dp under it.
  The tiles are a tap high (88, not 96), so the column is 188; the catch has no room as a
  panel and shows as counts at the line's head; the line is 106 dp with two rows. The
  board is 232 dp, held by the width (two 192 dp panels and four gaps), not by the take.
  The sheet is 278 dp wide with 5 rows, the foot's two accuracies on one line.

Portrait, `?view=game&take=d&port=strip|bar` (`&open=1`): the game as built in portrait,
the last move in a tap of at least 88 dp that opens the moves as a sheet rising from the
foot to the board's middle, under a dim scrim; its head, the scrim, or the line closes it.

- `port=strip`: a 56 dp strip under the play row with the last moves on one line, the
  newest lit by a chevron at the right. Its tap runs 8 dp into the gap above and 24 into
  the bottom margin, 88 in all. The Pixel's 73 dp of slack holds it, so the board stays
  432; on the iPhone the board is already held by the height, and goes from 256 to 192
  (−25%).
- `port=bar`: the last move in the bar's second row, between what each side has taken
  (pieces where both fit beside it, else counts). It costs nothing on either phone; its
  tap is 200 × 92 dp, from under the tiles to the board's top.
- The sheet: 9 rows on the Pixel, 5 on the iPhone.

### B: marks explained

Everywhere a mark shows: the game's panel (take a), take d's sheet, the replay's list
and its board, the foot's counts, and the results list's `??` column.

- `&explain=pop` (default): a tip with the mark in its coloured disc, its name, the move
  (`20. 33-29`), and one line: best "No move here was better", ?! "There was a better
  move", ? "This move gave away some of the chance to win", ?? "This move lost much of the
  chance to win"; a count names them all ("Blunders: moves that lost much of the chance to
  win"). Under the mouse it shows while the pointer is on the move. On touch the whole
  move (about 80 × 31 dp) is the target, under the 88 dp rule: the lists' rows take no
  other tap, and the tip names the move it explains, so a miss is clear. The next tap
  anywhere only closes the tip and goes no further, unless it lands on another mark,
  which moves the tip there. In the replay a tap on a move jumps there, and the line
  above the list explains its mark in the same words. The results list's head reads
  "?? blunders" over its column; a touch on a count shows the tip and doesn't open the
  game. `&tip=N` pins ply N's tip open, `&tip=foot` the foot's, `&tip=games` the results'.
- `&explain=legend`: the four marks with short words ("best", "not the best", "a
  mistake", "a blunder") at the list's foot, two to a line, 56 dp. Nothing to find or
  dismiss, which suits a child who doesn't know that a mark can be touched; it costs one
  row in the Pixel's sheet (6 to 5). Both could ship together: the legend in the sheet and
  the replay, the tip under the mouse.

### C: a past game's replay

`?view=replay&ply=0..110`, from a row on the results screen (`?view=games`). The board
shows the position at a move, with that move's mark in a disc on its square, beside the
whole list. Four steps: to the start, back, on, to the end. A tap on a move jumps there;
the rows are 34 dp, under the 88 dp rule, since a miss only shows the neighbouring move
and the steps put it right. A line over the list says what the move shown was ("20.
33-29 ?? Blunder: this move lost much of the chance to win"), and each side's accuracy
heads its column. A "Doesn't count" pill sits by the title "Replay". The board takes no
moves, and there is no hint, undo, or turn panel, so nothing reads as a game in play.
The game becomes neither the one to continue nor a new result; the card shows the rating
change it made when played ("Rating then: 1031 → 1023").

- Tablet, 1280 × 800: the steps a column of four 88 dp taps at the board's left, the
  board 752, at its right a 356 dp column: back and the title, the game's card (result,
  opponent, date, side, the rating then, the move shown), and the list, 356 × 454 dp,
  11 rows.
- Pixel 7a in landscape: the same order, the board 395; the game in the head's second
  line ("Lost to Medium · 1050 · Today"), the list 447 × 295 dp with 5 rows under the
  move shown.
- Pixel 7a in portrait: the head, the board 416 dp (432 would leave the list 284), the
  steps a row of four under it (99 × 88 each), the list 432 × 300 dp with 5 rows.

### Open questions

1. Portrait: the strip (several moves, but the iPhone's board 25% smaller) or the bar's
   line (only the last move, no cost)?
2. Marks: the tip, the legend, or both (the legend in the sheet and the replay, the tip
   under the mouse)?
3. The results list: does a touch on the `??` count show its tip, as prototyped, or open
   the game like the rest of the row, with the column's head as the only key?
4. The replay in landscape: the steps at the board's left, as prototyped (the left thumb,
   apart from the list), or a row under the list?
5. The iPhone 13 mini's landscape board is 232 dp because two 192 dp panels share the
   width: narrower panels there would be a change to the game screen, outside this task.
