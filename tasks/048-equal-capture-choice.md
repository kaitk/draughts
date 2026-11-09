# 048: A report of a forced capture with a king

Status: todo

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

- [ ] Both captures playable through taps in the game screen, each landing for the king
- [ ] The report explained or fixed
