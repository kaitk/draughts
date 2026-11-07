# Rules

## Variants

Estonian kabe is Russian draughts on 8×8, and International draughts on 10×10. English
checkers is rarely played in Estonia, so it comes last. The engine takes the variant as
data:

| | Russian | International | English (later) |
| --- | --- | --- | --- |
| Board | 8×8 | 10×10 | 8×8 |
| Men capture backward | yes | yes | no |
| Kings | flying | flying | one square |
| Must take the most pieces | no | yes | no |
| Man reaching the last row mid-capture | crowned, keeps capturing as a king | crowned only if the move ends there | move ends, crowned |

Common to all three: capturing is compulsory, a capture continues while it can, and
captured pieces come off after the whole move, so no piece is jumped twice (the Turkish
strike rule).

## Representation

- A position is `u64` bitboards over the dark squares: men and kings for each side, plus
  side to move and the variant. 8×8 uses 32 bits, 10×10 uses 50.
- A move is a from-square, a to-square, a bitboard of captured pieces, and the path for
  animation. Moves are generated into a fixed-size buffer.
- Positions read and write as text in the FEN format used by PDN.
- Move generation is checked with perft counts against published values (task 002).
