# 002: Rules engine for Russian and International draughts

Status: todo

Pure logic, with no graphics: positions as `u64` bitboards over dark squares, legal-move
generation, and making moves. The variant is data (`docs/architecture/rules.md`): board size,
majority capture, and mid-capture promotion. English is left for later, but the
parameters leave room for it.

## Acceptance criteria

- [ ] Position type: men and kings per side, side to move, variant; fixed-size, no allocation
- [ ] Move generation for both variants: compulsory capture, multi-jumps, flying kings,
      the Turkish strike rule, Russian mid-capture promotion, International majority capture
- [ ] A text position format (FEN-like, as used for draughts PDN) that reads and writes
- [ ] Perft counts from the start position match published values for both variants
- [ ] Unit tests for each rule's edge cases, from known tricky positions

## Notes (2026-11-07)

- Perft, International 10×10, start position, from the World Draughts Forum (Ed
  Gilbert's and others' runs agree): 9, 81, 658, 4265, 27117, 167140, 1049442, 6483961,
  41022423, 258895763 (depths 1 to 10). Moves with the same from, to, and captured set
  count once.
- Russian 8×8: no published perft table was found (English and Russian searches). The
  oft-quoted 7, 49, 302, 1469, 7361, 36768, ... is English checkers. Russian matches
  English at the first depths and differs once captures backward or kings appear. So
  check Russian against an independent generator written separately (for example a
  plain Python one in `test/`, with no shared code), and record the agreed numbers here.
- Layout idea: one bit per dark square with a ghost bit before each odd row, index
  `y * h + x / 2 + (y + 1) / 2` with `h` = squares per row (4 or 5). Then every diagonal
  step is a fixed shift: up-left `+h`, up-right `+h + 1`, down-left `-(h + 1)`,
  down-right `-h`, and the ghost bits fall outside the board mask. 36 bits for 8×8, 55
  for 10×10. Goose masks shift counts to the width, so `x >> 64` is `x`: never shift
  by a computed count that can reach 64.
- Russian kings landing after a capture must pick a square from which the capture
  continues, if any exists. International leaves this to the majority rule.
