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
