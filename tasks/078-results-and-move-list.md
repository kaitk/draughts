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

The user's correction of C (2026-11-13): "the way 'replay doesn't count' is done seems
odd here? my whole point was to let the game be replayed at any point and THAT doesn't
count and isn't stored or used for AI toughness changes or rating (the only place where
that text would be needed)." So the replay only shows, and "Play from here" plays the game
on from any move, a game that doesn't count.

## Steps

- [x] 1 and 2 fixed in the app: the tiles readable, the setting only in settings with a
      line saying what each choice shows
- [x] A, B, and C prototyped in `prototypes/history.html`, for the user to choose
      (2026-11-13, below)
- [x] C built: a past game's replay, checked on the Mac at the Pixel's sizes and the
      tablet's (2026-11-13, notes)
- [x] A and B built (the phone's move line, the marks' tips and legend), checked on the
      Mac at the Pixel's, the A33's, and the iPhone's sizes (2026-11-13, notes)
- [ ] A and B checked on a phone (the Pixel 7a, the A33, the iPhone 13 mini)
- [x] The legend under the replay's list
- [x] Play from here: the replay's pill gone, a button playing on from the move shown, a
      game that counts for nothing and says so on its way out; checked on the Mac at the
      Pixel's sizes, the tablet's, and a desktop's (2026-11-13, notes)
- [ ] Play from here checked on a phone

## Acceptance criteria

- [x] The results screen's head readable on every season's background
- [x] The move list's setting in one place, its choices explained
- [x] A phone in landscape shows the last move and opens the list; portrait as chosen
      (on a phone still to check)
- [x] A mark explains itself on a touch and under the mouse (a legend in the lists one
      opens, a tip on the always-shown panel)
- [x] A past game's moves listed and replayed on a board, touching neither resume nor the
      results (on a phone still to check)
- [x] Play from here at any move but the end of a game that ended there: the same
      draughts, opponent, level and skill, side, and side to move; its game written
      nowhere, moving no rating, skill, or count, the game in progress kept and resumed as
      it was; the replay's info sign beside the button opening a card that says it
      doesn't count and why, at every size, costing the list no rows (on a phone still
      to check)

## Notes

- 1 and 2 (2026-11-13): the draughts' tiles on one glass as the puzzles' switch; the move
  list's line beside its tiles where the group's width leaves room. Under them always,
  the tablet's landscape preview went from 242 to 137 dp; beside, it keeps its size in
  every stacked landscape, and portrait's board gives up 24 to 36 dp (`test/shell/sizes`).
  The results panel's freed room shows the levels on a phone in landscape. Checked on
  the Mac at the Pixel 7a's landscape (four themes) and portrait, and the tablet's size.
- C (2026-11-13): `src/shell/replay.goose`, opened from a results row (the whole row);
  how it works in `docs/architecture/rendering.md` ("A game's replay"), why in
  `docs/decisions/rendering.md`. The steps, back, and the moves are offered to the keys'
  focus; Left and Right step from anywhere (`gui::claim_sideways`, new), and the focus on
  a move shows it. New strings `replay.title`, `replay.no_count`, `replay.start`; four
  chevron icons (`gui::FIRST`..`LAST`). Room at the sizes (`test/shell/replay`): the
  Pixel 7a's landscape (480 dp, its cutout and bar) the board 395 dp, the column 447 dp,
  12 moves listed in view; its portrait the board 432 dp; a 20:9 phone at 540 dp 450
  (landscape) and 492 (portrait); the tablet's landscape 752 with 30 moves in view; a
  9:16 phone at 480 dp 329 and 284. A frame's quads at most 347 of 512 (a foldable's
  landscape, Estonian). `test/shell/sizes` checks it at every size, all in place.
  Headless shots at the Pixel's landscape and portrait, the tablet, Estonian, the start,
  and Left with the keys: `build/notes/078-replay/`, taken from a history of the
  prototype's game (`--history`, `--screen replay --ply 39`).
- A and B (2026-11-13): `src/game/sheet.goose`, the layouts in `panel.goose`
  (`row_fit`, `bar_tiles`, `portrait_sheet`); how it works in
  `docs/architecture/rendering.md` ("The moves panel"), why in `docs/decisions/rendering.md`.
  No new strings: the sheet's head is `settings.moves` ("Move list"), the legend
  `mark.*`, the tip `mark.*_tip` split at its colon. Two chevron icons more
  (`gui::CHEVRON_UP`, `CHEVRON_DOWN`, 43 and 44); the line and the sheet use the
  replay's `FWD` and `PREV`. Dev flags `--moves off|list|marks`, `--sheet on`, `--tip N`.
  Room at the sizes (`test/shell/moves_line`), safe area in dp:
  - Pixel 7a, 540 dp (1141 × 498 landscape, 540 × 1099 portrait): the column 204 dp
    (back and settings 90 × 96 each), the catch 88 (two rows), the line 192 × 134 (three
    rows of 31 dp); the flat board 450 dp as before, the 3D
    board 656 dp across with the line and without; the sheet 334 dp wide (228 on the 3D
    board), 8 rows; portrait the line's tap 200 × 92 dp, the board 492 as before, the
    sheet 540 × 562 dp (618 on the 3D board), 10 rows.
  - Galaxy A33, 512 dp, insets assumed (80 px notch, 135 px bar): the line 192 × 148, the
    board 464, the sheet 274 dp wide.
  - iPhone 13 mini at its density floor, 500 dp (949 × 470 landscape): the catch fits as
    on the Pixel and the line is 106 dp tall, the board 422 dp, the sheet 252 dp. Only at
    its points (375 dp, 712 × 354, the prototype's size) do the tiles go to a tap high and
    the catch to counts at the line's head, as prototyped; its portrait there is compact,
    with no line.
  - The frame's quads at most 239 of 512 (portrait, the sheet open, the 3D board).
  - Portrait's catch beside the line: pieces where both rows fit their side at 70%
    (`TAKEN_LEAST`), else counts; a phone's late game (27 taken) shows counts, a
    tablet's pieces.
  - The legend under the replay's list costs it two rows on a phone (one where the four
    marks fit one line, a wide portrait): 30 moves in view to 26 on the tablet, 8 to 4 on
    a 9:16 phone's portrait at 480 dp (`test/shell/replay`).
  Headless shots: `build/notes/078-phone/` (Pixel, A33, iPhone, flat and 3D, sheets open
  and closed, the list alone, the tablet's tip). Built with the ngfx build too (the icons'
  shader).
- Play from here (2026-11-13, the user's correction): `shell::play_from_here` and
  `leave_trial` (`src/shell/shell.goose`), the game in progress set aside in
  `shell.parked` (`saved.goose`'s `Parked`: its image, hints, and marks, 53 KB; the shell
  went from 532 to 586 KB, where a second `game::Game` would have added 132), the label
  `panel::no_count`, the button and its fit `replay::play_fit`. How it works in
  `docs/architecture/rendering.md` ("A game's replay", "A game played from a replay"),
  why in `docs/decisions/rendering.md` and `ai.md`. New string `replay.play` ("Play from
  here", "Mängi siit edasi"); dev flag `--go here`. Choices:
  - The button: the replay's head, at its right end, its icon (the computer's head or a
    friend's two figures) beside its word, or over it in a smaller face; on a phone the
    title, then back's width, give way first; on the tablet's 356 dp column a row over
    the glass. In the head at every phone size `test/shell/sizes` has, the title beside it
    but on a 9:16 phone's landscape at 480 dp (no title; in Estonian back a square too);
    a row on the tablet's landscape (with its bar too, in English), the foldable's and
    4:3's landscape, and the iPads'. Dimmed at the end of a game that ended there.
  - Clocks: none, as the history keeps no clock setting.
  - Start over: back to the replay's position, to try the line again; leaving is back.
  - Back (the panel's, the end card's, Escape, Android's): the replay, at the move it
    showed. Settings return to the game.
  - The moves list numbers on from the replay's move (`Game.ply0`): from move 30 "16.",
    from move 11 "6…". The panel numbers a game from where it began (`game::first_ply`),
    which also fixed a game whose history dropped an odd number of moves.
  - The label: a pill in the glow color with dark ink, centered on the way out's top
    edge (`l.left` in every layout), half in the margin above it: 135 × 25 dp in English,
    152 in Estonian; no panel moves and the board keeps its size at every size.
  - Room in the replay (`test/shell/replay`): the tablet's landscape 26 to 20 moves in
    view (the row), the Pixel's landscape at 540 dp 14 to 10 and portrait 12 to 8 (the
    game's line now heads the glass), a 9:16 phone's portrait at 480 dp 4 to 2; every
    board as before.
  Headless shots: `build/notes/078-play-from-here/` (the replay at the Pixel's landscape,
  portrait, Estonian, the end, the tablet; the game from move 39 at the Pixel's landscape
  flat and 3D, portrait in Estonian, the tablet, and a desktop).
- The note in place of the game screen's pill (2026-11-13, the user found the pill on
  the way out confusing): `replay::note`, under play from here at the glass's top, an
  info sign (a faint disc with an "i") and the words in the small face; `replay.no_count`
  now its short text ("A game from here doesn't count", "Siit mängitud mäng ei lähe
  arvesse"), new `replay.no_count_why` the whole ("... it isn't saved and doesn't change
  your rating", "... seda ei salvestata ja reiting ei muutu"). `panel::no_count` is gone;
  `Game.no_count` stays. `test/shell/sizes` checks it inside the safe area and the glass,
  clear of the board, the tiles, and every word, icon, and rule at every replay size:
  whole at every tablet, desktop, foldable, 4:3, phone size at 540 dp, and a 20:9 phone's portrait at 480 dp (one line in a
  tablet's portrait, two on the Pixel, three in a landscape column), short in the game's
  line's place on the phones' landscape at 480 dp and the iPhone 13 mini's, and a 9:16
  phone's portrait at 480 dp with insets. Its cost (`test/shell/replay`): the tablet's
  landscape 20 to 16 moves in view, the Pixel's landscape at 540 dp 10 to 8; in portrait
  the board instead: the tablet 752 to 729 dp, the Pixel 492 to 472, a 20:9 phone at 480
  dp 432 to 390, the foldable 519 to 493, 4:3 587 to 561. Headless shots:
  `build/notes/078-no-count-note/` (the Pixel's landscape and portrait in English and
  Estonian, the tablet in both orientations and Estonian, a desktop, a 9:16 phone at 480
  dp, the iPhone 13 mini's landscape with the short note, and the game from a replay with
  no pill).
- The note into a card behind an info sign (2026-11-13; on the Pixel 7a's landscape the
  note left the list about three rows): `replay::info`, an 88 dp tap at play from here's
  right with a 28 dp disc, opens `replay::why`, the mark tips' card (`game::card`, split
  out of `game::tip`, now with a width) under it: `replay.no_count` over
  `replay.no_count_why`'s words after its colon. Touch, Enter, Escape and back, and the
  mouse dismiss it as the mark tip. The short note in the game's line's place is gone; the
  game's line is back everywhere, and the portrait board takes back what it gave. The
  sign's width comes out of the head: on a 9:16 phone's landscape at 480 dp the button
  then loses its icon, its word alone on two lines (`replay::WORDS`, `gui::labelled` with
  `NO_ICON`), as a row would leave that list nothing; a sign at the glass's top right
  corner was tried for it and dropped (the game's line ran under it). The sign is focus
  group 1 (the steps 2, the list 3), so Tab takes 4 presses to the list from nothing.
  `--tip why` opens the card for shots. Rows in view (`test/shell/replay`, its faces),
  before and after: the Pixel's landscape 3.3 to 4.6, portrait 3.0 to 3.6 (board 472 to
  492 dp); the tablet's landscape 7.9 to 9.7, portrait 3.0 to 3.1 (board 729 to 752);
  the iPhone 13 mini's landscape 3.1 to 2.9 (the game's line back in the glass); a 9:16
  phone's landscape at 480 dp 1.8 to 2.1. In Estonian, test faces, the tablet's portrait
  drops 3.0 to 2.1 and 4:3's and the foldable's portrait 1.7 to 0.7, the sign taking the
  room that held the game's line under the title (the board takes back 23 to 26 dp); the
  real font's shots keep the title. Headless shots: `build/notes/078-no-count-tip/` (the
  Pixel's landscape and portrait in English and Estonian, closed and open, the tablet in
  both orientations, open, and Estonian, the iPhone 13 mini's landscape, a 9:16 phone's
  landscape at 480 dp in English and Estonian open). The desktop's hover wasn't shot:
  headless, `--touch off --mouse` drew the touch layout.
- Left for A and B: the phones themselves; a tip in the sheet and the replay (the legend
  there for now); the line in a small window's compact bar (none).
- Left for C: the prototype's
  game card on the tablet ("Rating then: 1031 → 1023") left out; a game begun from a set
  position (`first=black`, the dev flag `--fen`) doesn't replay, as the history keeps no
  start, and its list stops at its first move; the 3D board chosen still replays on the
  flat one.

## Takes to choose

The prototype is `prototypes/history.html` (2026-11-13; removed 2026-11-13, in git history at 086f47d; `prototypes/game.html`, `results.html`, and `replay.html` show what was built). The device's insets follow the
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

### Chosen (the user, 2026-11-13)

1. Portrait: the bar's line (only the last move, no cost to the board).
2. Marks: both. The legend at the foot of the lists one opens (the phone's sheet, the
   replay); the tip on the always-shown moves panel (tablet, desktop), under the mouse or
   a touch.
3. The results list: a touch anywhere on a row, its `??` count too, opens the game; the
   column's head is the key.
4. The replay in landscape: the steps at the board's left, as prototyped.
5. The iPhone's narrow landscape board: task 079.

The marks' words and tips are in `strings/` as `mark.*` and `mark.*_tip` (2026-11-13).
