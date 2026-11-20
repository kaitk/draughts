# 100: An antique chess clock on the table

Status: todo

A prop on the 3D board's table (task 095), after the taken pieces (task 099): a German
chess clock of about 1900, era-appropriate for the Baltic German manor (the user,
2026-11-20), modelled from the references in `design/props/chess-clock/` (local; its
README lists them): two round drum movements in nickel with brass bezels, white dials
with Arabic numerals and a small seconds dial, blued spade hands, a cast brass rocker with
scrolls joining them on top, on a walnut plinth with a small plaque. An English Jaques
timer was set aside for it.

A modelling session of its own: the mesh as data (`src/model3d/`, as the table's), its
materials in the bake and the lit pass, placed on the table beside the board where it
doesn't hide the board at any view. Later, perhaps: the rocker tipped to the side to
move, and the hands showing the game's clock.

## Acceptance criteria

- [ ] The clock on the table beside the board, lit and shadowed with it, at every view
- [ ] Its dials readable at the rest view on the tablet
- [ ] GPU time and memory against before on the Mac and the A33, in this file
