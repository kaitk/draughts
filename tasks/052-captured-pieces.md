# 052: What each side has captured

Status: in-progress

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

## Acceptance criteria

- [x] Takes drawn in a prototype, at every size, compact included
- [ ] A decision with the user: shown or not, and if shown, where, from a prototype's takes
- [ ] If shown: on the game screen at every size, compact included (task 050)
