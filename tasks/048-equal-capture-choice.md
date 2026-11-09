# 048: A report of a forced capture with a king

Status: done (not reproduced; covered by tests)

Reported from the tablet (2026-11-09, not seen by the user themselves): in a game
against the computer, International, playing black, two captures each took one piece,
one of them with a king, and the player says the app forced the worse one.

The rules allow either: the majority rule forces only the capture taking the most
pieces, and a king may land on any free square beyond the piece it takes unless a
landing square lets it go on. Checked the same day: on `B:W23,44:B18,K46` the engine
(`build/perft international 1 FEN --moves`) and the independent `test/perft.py moves`
both give the man's capture and the king's four landings. So if it happened, the cause
is likely in the game screen (which piece a tap selects when several can capture, the
must-capture ring, the hints on mistakes only, a capture's landing taps) or a position
where the "worse" capture took more pieces.

- Write a headless game-screen test (`test/game/`) with black to move, a king and a man
  each able to take one, playing each through taps, with hints on mistakes only and on
  all moves.
- Ask the user for a screenshot of the position if it happens again.

## Acceptance criteria

- [x] Both captures playable through taps in the game screen, each landing for the king
- [x] The report explained or fixed: not reproduced; what remains is below

## Findings (2026-11-09)

No cause found in the rules or the game screen; nothing there plays a capture the
player didn't choose.

- `test/game/choice.goose`: black against the computer on the turned 10×10 board, a
  king with one capture and several landings and a man that can also take one, in three
  positions: `B:W23,44:B18,K46`, `B:W12,23,31:B18,K46` (the king's nearest landing is
  taken back), `B:W19,23,41:B18,K46` (its furthest is). Every capture and every landing
  is played by a tap on the piece and a tap on the square and by a drag, with hints on
  mistakes only and on all moves, and each is the one chosen; a tap on a piece only
  selects it; a landing tapped with nothing or the man selected, and a square no capture
  ends on, play nothing, and every capture can be chosen after them. On the 3D board
  (raised, turned) each capture of the last two is tapped through the perspective and
  dragged, and each is the one chosen.
- The engine against `test/perft.py` on 3000 random International positions with black
  to move, 40% kings: no difference. Both read the rule the same way (a king lands where
  it can go on taking if it can), which the majority rule implies anyway.
- Read and ruled out: `board::press` and `release` play only a move whose last square is
  the one tapped or dropped on (`follow`), never on selecting; `snap` moves only a press
  or drop off the dark squares, to the nearest square within 0.9 of one; the computer's
  move and take back clear the selection (`start_move`, `show`); a press during the
  computer's move or while it animates is ignored, and an answer to a dropped ask too.

## Second pass (2026-11-09)

The hunt in the game screen and the board package again, headless; nothing found.

- Which piece a tap or press selects: `board::press` selects the piece pressed when it
  has a move, whichever else can capture; a target of the selected piece is played only
  through `follow`, and only for the selected piece.
- The must-capture rings (`choice`, now): on mistakes only none up front; after a square
  no capture ends on, tapped with the king selected, both the king and the man ring with a
  count of one each, and the piece the king takes rings beside them; with move hints both
  show their count of one from the start. The mistake flashes, keeps the king selected,
  plays nothing, and every capture is still chosen after it.
- A king's landing taps (`test/game/aim.goose`, new): every capture of
  `B:W12,23,31:B18,K46`, each of the king's four landings and the man's two, by a tap on
  the piece and a tap at 25 points spread over the landing square, to 0.4 of a square from
  its center, and by a drag dropped there, on the turned flat and 3D boards at the tablet's
  size in landscape and portrait: all 1200 play the capture aimed at.
- The turned board: `board::hit` and `center` agree turned, and `aim` sweeps it.
- On the 3D board a dragged piece is held where the finger took it, on the plane of its
  lifted top (`game::touch`), so the drop is the square under the piece, not under the
  finger. A stacked king (the 3D board's kings by default) held by its lower disc and
  dropped with the finger on the field's point lands up to about a third of a square back
  along its way: aimed at the far corner of a landing, it can take the neighboring
  landing of the same capture. That is a landing, not the other capture, and the board
  shown in the app is flat unless 3D is chosen; recorded, not changed.

What remains: a capture the player saw as one piece may have taken two (the king must
then land where it goes on, and the majority rule forces that capture), or the computer
was the one that lost its king. A screenshot or the position, and which side's king, if
it happens again.

