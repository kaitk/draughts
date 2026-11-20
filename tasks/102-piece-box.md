# 102: The pieces' box on the table

Status: todo

A prop on the 3D board's table (task 095), after the taken pieces (task 099): the
wooden box the set came in, standing open at the table's far edge, behind the board and
partly cut off by the screen's edge (2026-11-20). It is the most likely thing on a real
table during a game and the cheapest prop: rounded boxes in a wood the board already
has. References in `design/props/piece-box/` (local; its README lists them).

- Shape: a plain box of about 1900 with slightly rounded edges, its lid tipped back on
  two small brass hinges, inside two compartments, one for each colour. It holds the
  set in stacks: for 20 pieces a side, 2 by 2 stacks of five in each compartment, so the
  inside is about 4.4 pieces wide, 2.3 deep, and a little over five pieces high, about
  40% of the 10x10 board's width. It may run off the screen. A few pieces left in it.
- Wood: the cherry of the board's frame, as if box and board were made as one set, a
  little duller and darker so it stays behind the board.
- Inside the lid, the one side of it that faces the player: a printed maker's label,
  `lid-label-01.png`, with its text set in our own font (a word in a picture needs a
  thought: the string rule wants it in `strings/`, or the label holds only a monogram).
- Along the box's front: a thin worn gold line, perhaps a small flourish, drawn as metal
  from a black-and-white mask, not from a picture with gold's light painted in. The
  mask is still to make (ChatGPT, from `gilt-frame-01.png`, and a long 5:1 strip for the
  front).
- Placed so it never hides the board or the taken pieces, at any view. The images the
  app uses go in git once chosen, cut to the size they show at.

## Acceptance criteria

- [ ] The box on the table, open, lit and shadowed with it, at every view
- [ ] Its label and gold line read as such at the rest view on the tablet
- [ ] GPU time and memory against before on the Mac and the A33, in this file
