# 103: The score sheet and pencil on the table

Status: todo

A prop on the 3D board's table (task 095): an old sheet of paper the moves are written
on, with a pencil lying across it, near one of the table's near corners (2026-11-20).
References in `design/props/score-sheet/` (local; its README lists them).

- The sheet: `sheet-01.png`, aged paper with a band of oak leaves and acorns round an
  empty cartouche, two ruled columns of 17 lines, no text. Slightly turned, curling a
  little at one edge. Its yellow toned down in the shader with the box's label (task
  102), so neither glows beside the light pieces.
- The moves, written as the game goes: one full move a line, white's in the left column
  and black's in the right, in draughts' numbered notation (`32-28`, `18x23`), the move
  numbers written in by hand. In a handwriting font, each glyph shifted a little at
  random. A move is written a moment after it is played, or once both sides have moved,
  not at once; each one is a redraw, so it stays within drawing only on a change. When
  a sheet is full, a new one is laid on top, so a small pile grows with the game. The
  cartouche may take the date. At the tablet's size the writing need only read as
  writing.
- The pencil: six-sided, sharpened with a knife, a blunt point, modelled (a six-sided
  rod and an uneven cone), not a picture. `pencil-01.png` gives its colours, with the
  body darker, stained and varnished, against the pale bare wood of the cut, which is
  what reads at a few pixels wide. Sometimes laid by the last line written.
- The images the app uses go in git once chosen, cut to the size they show at.

## Acceptance criteria

- [ ] The sheet and pencil on the table, lit and shadowed with it, at every view
- [ ] A game's moves written on it as they are played, an undo taking its line back, a
      new game starting a clean sheet
- [ ] GPU time and memory against before on the Mac and the A33, in this file
