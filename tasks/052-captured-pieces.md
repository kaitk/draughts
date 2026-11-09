# 052: What each side has captured

Status: done

Nothing on screen says how many pieces, and which (men or kings), each side has taken so
far (the user, 2026-11-09). Possibly fine as it is, but no place for it is known yet:
the panel, beside each side's turn piece or clock, a small tray at the board's edge, or
only on the win's card. The user suggests the left side.

## Takes (2026-11-09)

`prototypes/game-captured.html` draws two places, each in three looks, early in a game
(one taken each) and late (12 taken, a black king among them), flat and raised, on the
tablet, a phone, and the smallest iPad window (compact). Black's catch (the white pieces)
sits toward black's side of the board, white's toward white's.

- **a, in the left side.** Landscape: a third row in the left panel, between settings and
  start over, where the flat screen's panel is empty; the raised screen's short corner
  panel has no room, so a small glass panel under it. Portrait: a row under the bar's
  three tiles, white's catch at the left, black's at the right (the bar 52 dp taller,
  which a phone's portrait has to spare). Compact: the bar's empty middle, between back
  and the two tiles at the right.
- **b, on the table at the board's left.** Landscape, flat: a slim glass tray (44 dp)
  down the board's left edge, black's catch from the top, white's from the bottom; both
  panels narrow to 192 dp for it, the board 744 dp. Raised (and task 054's take b): bare
  pieces in the free corner under the left panel, beside the board's near left corner, as
  pieces set aside on a table. Portrait: a strip over the board at the left and one under
  it (beside the camera buttons when raised). Compact: a column beside the board, which
  gives up about 10 dp.
- **Looks** (`&look=`): `row`, the app's own pieces small (32 dp on the tablet), each
  covering half the one before, kings after a gap; `pile`, discs stacked and seen from the
  side, the men's pile and the kings' beside it; `count`, a small piece and a number, a
  crowned one for kings. Small kings wear the crown in both views: a stack that small
  reads as a shadow. Natively all three are cheap: the row is more instances of the
  pieces' quad, a pile ellipses in the same shader, a count digits from the atlas.

Every view (the main checkout's path):

- `file:///Users/kaitkasak/projects/personal/draughts/prototypes/game-captured.html?grid=1&cap=a&look=row&state=late`
  (the sizes side by side; its header changes cap, look, state, flat, and season)
- `file:///Users/kaitkasak/projects/personal/draughts/prototypes/game-captured.html?grid=1&cap=b&look=pile&state=late`
- `file:///Users/kaitkasak/projects/personal/draughts/prototypes/game-captured.html?grid=1&cap=a&look=count&state=early`
- `file:///Users/kaitkasak/projects/personal/draughts/prototypes/game-captured.html?cap=a&look=row&state=late`
  (one screen at the window's size; `&view=3d` raised; the switcher at the bottom right
  changes cap, look, state, flat, frame, btns, and the season)
- `file:///Users/kaitkasak/projects/personal/draughts/prototypes/game-captured.html?cap=b&look=pile&state=late&view=3d`

Open choices for the user:

1. Shown at all, or only on the win's card.
2. The place: a (inside the left panel or bar) or b (beside the board, on the table).
3. The look: the pieces in a row, piles, or a count.
4. Raised, take a needs a panel the raised layout doesn't have; whether the piles of b
   should be drawn in 3D by the renderer, as real pieces beside the board, rather than
   in the UI.

## Chosen (the user, 2026-11-09)

Take a's `row` look: the app's pieces small, overlapping, kings after a gap. Flat
landscape: a small glass panel under the left corner panel (task 054 gave the flat screen
the 3D one's corner panels). 3D landscape: a one-line bar above the board, at the top
between the corner panels. Portrait: a row under the bar's tiles. Compact: the bar's empty
middle.

## Built (2026-11-10)

- **Counts** (`game::taken`): the variant's start pieces of each color less those on
  the board, so a position set up from `--fen` counts what it lacks as taken. Kings apart
  from the undo history the board keeps (and the saved game keeps): a piece of the side
  not moving that was a king before a move and is gone after it was taken as a king.
  Counted once the move has shown, not as it starts (`game::count_taken`, cached on the
  game by its position and history length), and again after undo or start over.
- **Drawn** as more of the pieces' quad instances over the UI (`panel::taken`, into the
  overlay the turn piece and clocks use), the man or the crowned king of the app's own
  look; each covers 48% of the one before (a step of 0.52 of a piece), the kings after a
  gap of 0.3. A row too long for its room takes smaller pieces, to 70%, then closes up.
  Pieces 32 dp on a tablet, 26 on a phone, 22 compact. `panel::OVER` went from 4 to 96
  (40 taken at most, twice for a transition's two screens): 4.6 KB of storage buffer, no
  allocation, and the screen draws only when something changed, as before.
- **Placed** (`Layout.taken`, `taken_as`, `taken_d`, set by the layouts for the game
  only, `game: true`):
  - flat landscape: its own glass under the left corner panel, 12 dp under it, two rows
    with 14 dp above and below, black's catch (the white pieces) over white's, as black's
    side of the board is above; on a turned board the other way. Where the height is
    short the rows shrink to 3/4, then go to one line (the 20:9 phone at 480 dp with its
    gesture bar);
  - 3D landscape: one line on glass as wide as it holds, at the top between the corner
    panels, white's catch at the left and black's at the right as portrait's row;
  - portrait, flat and 3D: the bar 52 dp taller, a row under its tiles, white's catch at
    the left, black's at the right, as the prototype;
  - compact: the bar's middle between back and settings, two rows as the flat panel's.
  A catch's own glass shows once anything has been taken; the bar's row is part of the
  bar.

## Decisions

- **A king taken counts as a king**, crowned in the row, as the child saw it taken, even
  if it was crowned during the game; a man counts as a man. The history reaches
  `board::MAX_HISTORY` (512) moves back; kings taken before that would count as men.
- **The 3D bar never shrinks the board at rest.** Where the board at rest clears the bar
  by half a gap (every tablet and iPad, the 9:16 phone) the bar is above it, and the board
  clears it as it clears the panels, also in the top view and the zoom: the tablet's top
  view (74°) is 2% smaller (806 × 708 to 788 × 692 dp), its zoomed top view 3%. A phone's
  3D board reaches the top margin, and the bar there would have shrunk it 11% (718 to 639
  dp at 540 dp), so on a phone in landscape it goes where the flat screen's goes, under the
  left corner panel, which the board's near edge clears (narrowed by a few dp to clear it,
  to 3/4 at most); the line above the board only where neither fits.
- **Portrait's row costs the board 52 dp where height holds it** (the prototype's "a
  phone's portrait has to spare" holds on 20:9 phones and the tablet, which are unchanged):
  flat 579 to 527 dp on the foldable, 647 to 595 at 4:3, 425 to 373 on the 9:16 phone at
  480 dp, 336 to 284 with the Pixel 7a's insets; 3D 651 to 586 and 735 to 670 dp wide.
- **Black's catch on top** in the flat panel and compact's rows only follows the board's
  turn (against the computer as black); the 3D bar and portrait's row stay white's catch at
  the left, as the 3D board turns after each move against a friend.
- **Glass only once something is taken**: an empty panel at a game's start looked like a
  missing control.

## Tests

`test/game/taken`: the counts at the start, after an exchange of men, a man taking a
king, a king taking a man, a man crowned, moved off the edge, and taken as a king, undo
giving the king back, and a set-up position; then the game screen, counts changing only
once the capture has shown, the rows in the panel, white's pieces over black's and turned
the other way. `test/shell/sizes`: at every size (phones with insets, the tablet with its
bar, the iPads with theirs, the iPad's smallest window), late in a game (14 white men
and a white king taken, 12 black men), flat and 3D, every taken piece inside the safe area and off
every tile, camera button, and the board. `test/game/corners`: where the 3D screen puts
them, clear of the panels, buttons, and the board.

## Acceptance criteria

- [x] Takes drawn in a prototype, at every size, compact included
- [x] A decision with the user: take a's row (2026-11-09)
- [x] On the game screen at every size, compact included (task 050), checked headless;
  shots in the session's scratchpad (`054-052/before`, `after`), not yet on the tablet
