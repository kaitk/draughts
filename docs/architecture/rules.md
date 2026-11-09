# Rules

## Variants

Estonian kabe is Russian draughts on 8×8, and International draughts on 10×10. English
checkers is rarely played in Estonia, so it comes last. The engine takes the variant as
data:

| | Russian | International | Brazilian | English (engine only, for now) |
| --- | --- | --- | --- | --- |
| Board | 8×8 | 10×10 | 8×8 | 8×8 |
| Men capture backward | yes | yes | yes | no |
| Kings | flying | flying | flying | one square |
| Must take the most pieces | no | yes | yes | no |
| Man reaching the last row mid-capture | crowned, keeps capturing as a king | crowned only if the move ends there | crowned only if the move ends there | move ends, crowned |
| Moves first | white | white | white | black |

Brazilian is International's rules on 8×8. International's crowning is FMJD's Official
Rules (Annex 1), art. 3.5 (a man is crowned when it "reaches and stops" on the far row)
and art. 4.15 (one that passes over the far row during a capture and ends elsewhere
"remains a man"); FMJD Annexes, February 2018:
<https://www.ffjd.fr/fichiers/reglements/FMJD_Annexes_2018_en.pdf>. No federation plays
10×10 otherwise; "Polish draughts" is another name for International.

Common to all four: capturing is compulsory, a capture continues while it can, and
captured pieces come off after the whole move, so no piece is jumped twice (the Turkish
strike rule).

Under the majority rule a piece that can take fewer than another has no move, though a
child sees it can take; `rules::can_take_from` tells such a piece from one with no
capture, for the board to say why (rendering.md, "States"). Checked on the board with
several capturing pieces, equal and unequal, a king and a man, and captures through a
shared first stop, in International, Brazilian, and Russian (`test/board/several`,
2026-11-09). A man's capture that reaches or passes the far row, tapped and dropped on the
turned board, alone, going on past it, and beside a longer capture, is checked in
`test/board/stuck`; the board shows a far-row square passed as a stop the piece waits on
(rendering.md, "States").

Flying kings must land, after a capture, on a square from which the capture goes on, if
any such square exists. Russian states this rule; in International and Brazilian the
majority rule already gives it. A capture is one move per start square, end square, and
set of pieces taken, however many paths lead there.

## Representation

The engine is `rules/` (namespace `rules`): pure Goose with no graphics, so the app, the
computer player, and the tests share it.

- **Bitboards with ghost bits.** One bit per dark square, with an unused bit before each
  odd row. Square (x, y), a1 being (0, 0), is bit `y * h + x / 2 + (y + 1) / 2`, where
  `h` is the dark squares per row (4 or 5): 36 bits for 8×8, 55 for 10×10. Every
  diagonal step is then a fixed shift (up-left `+h`, up-right `+h + 1`, down-left
  `-(h + 1)`, down-right `-h`), and a step off the board lands on a ghost bit or outside
  the board mask. All plain moves of men come from two shifts per direction.
- **Position** (`rules::Position`): pieces per side as two `u64`, kings as one `u64`,
  the side to move, and the variant. It is a value: undo keeps old positions, and
  `rules::play` returns a new one.
- **Variant as data** (`rules::Variant`, in `rules::VARIANTS`): board size, starting rows,
  whether men capture backward, flying kings, the majority rule, what crowning mid-capture
  does, who moves first, and how squares are written. English is implemented from the
  same fields and checked by perft, though the app doesn't offer it yet.
- **Move** (`rules::Move`): start and end square, the bitboard of pieces taken, whether
  it crowns, and the stops from start to end, for showing the move. `rules::generate`
  fills a `rules::Moves` buffer the caller owns (512 moves), so generating allocates
  nothing.

## Text

Positions read and write as in PDN: `W:W31,32,K46:B1,2`, the side to move, then each
side's pieces with `K` before a king. Squares are numbered from the top-left dark square,
row by row (on 10×10, 1 is b10 and 46 is a1). Russian and Brazilian write squares as
a1..h8 instead. Reading accepts either form for every variant, ranges such as `31-50`,
spaces, and a trailing `.`. Moves print as `32-28`, or a capture's stops, `28x19x10`
(`c3:e5:c7` in Russian and Brazilian).

## Checks

Move generation matches the published International perft counts through depth 10
(258,895,763), English through depth 11 (85,242,128), and Brazilian through depth 11:
7, 49, 302, 1469, 7473, 37628, 187302, 907830, 4431766, 21560022, 105491257, the counts
of two independent generators that count a capture once per start, end, and set of
pieces taken (<https://damforum.nl/viewtopic.php?t=2666>). Russian has no published
table: its counts agree with an independent Python generator (`test/perft.py`) through
depth 10: 7, 49, 302, 1469, 7482, 37986, 190146, 929899, 4570586, 22444032. Running and
extending the tests: [development](../development.md#test-the-rules).
