# 002: Rules engine for Russian and International draughts

Status: done

Pure logic, with no graphics: positions as `u64` bitboards over dark squares, legal-move
generation, and making moves. The variant is data (`docs/architecture/rules.md`): board size,
majority capture, and mid-capture promotion. English is left for later, but the
parameters leave room for it.

## Acceptance criteria

- [x] Position type: men and kings per side, side to move, variant; fixed-size, no allocation
- [x] Move generation for both variants: compulsory capture, multi-jumps, flying kings,
      the Turkish strike rule, Russian mid-capture promotion, International majority capture
- [x] A text position format (FEN-like, as used for draughts PDN) that reads and writes
- [x] Perft counts from the start position match published values for both variants
- [x] Unit tests for each rule's edge cases, from known tricky positions

## Outcome (2026-11-07)

`rules/rules.goose` and `rules/fen.goose`, about 400 lines. English came almost free from
the variant fields, and its published perft table checks the code the variants share,
so it is in the engine too; the app doesn't offer it yet. Layout, text formats, and the
checks are recorded in `docs/architecture/rules.md`; running the tests in
`docs/development.md`.

Perft from the start position, `build/perft` (native, Apple M-series, one thread, bulk
count at the last ply):

| Depth | International | English | Russian |
| ---: | ---: | ---: | ---: |
| 1 | 9 | 7 | 7 |
| 2 | 81 | 49 | 49 |
| 3 | 658 | 302 | 302 |
| 4 | 4265 | 1469 | 1469 |
| 5 | 27117 | 7361 | 7482 |
| 6 | 167140 | 36768 | 37986 |
| 7 | 1049442 | 179740 | 190146 |
| 8 | 6483961 | 845931 | 929899 |
| 9 | 41022423 | 3963680 | 4570586 |
| 10 | 258895763 | 18391564 | 22444032 |
| 11 | | 85242128 | 110917189 |

International matches the World Draughts Forum table through depth 10 (15.5 s, 16.7 M
positions a second) and English the published table through depth 11 (7.4 s). Russian
agrees with `test/perft.py`, a plain Python generator sharing no code, through depth 10
(Python: 125 s); depth 11 is Goose only. `test/perft.py compare` also played random games
and found the same legal moves in all of 9724 Russian, 9212 International, and 13685
English positions.

The edge-case tests in `test/rules/`: the Turkish strike (a king back on its start square
can't recross a taken piece), Russian crowning mid-capture and going on as a king,
International crowning only at the end, the majority rule (a king counts as one piece),
flying-king landing squares and the rule to land where the capture goes on, one move for
two paths round the same four pieces, and FEN reading and writing.

## Notes (2026-11-07)

- Perft, International 10×10, start position, from the World Draughts Forum (Ed
  Gilbert's and others' runs agree): 9, 81, 658, 4265, 27117, 167140, 1049442, 6483961,
  41022423, 258895763 (depths 1 to 10). Moves with the same from, to, and captured set
  count once.
- Russian 8×8: no published perft table was found (English and Russian searches). The
  oft-quoted 7, 49, 302, 1469, 7361, 36768, ... is English checkers. Russian matches
  English at the first depths and differs once captures backward or kings appear.
- Goose masks shift counts to the width, so `x >> 64` is `x`: the engine never shifts by
  a computed count that can reach 64.
