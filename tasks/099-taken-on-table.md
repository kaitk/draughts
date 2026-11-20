# 099: The taken pieces on the table

Status: todo

With the 3D board on its table (task 095), the pieces each side has taken lie on the
table beside the board, by the side that took them, as players set them down: a loose
row or a couple of short stacks, a little askew, each piece drawn as the board's pieces
are (their material, task 094, and their shadow on the table). It is the first thing to
add to the table, before any prop: a small touch that makes the scene alive (the user,
2026-11-20).

The game already counts what each side has taken (`panel::Taken`, the flat board's
panels). A capture moves the piece from the board to its place on the table, as the
flat board's taken pieces go to the panel. Without the table, nothing changes.

## Acceptance criteria

- [ ] The taken pieces on the table by the side that took them, in the board's pieces'
      material, shadowed, at every view
- [ ] A capture carries the piece there; undo and a new game put them back
- [ ] Nothing drawn or allocated per frame for them while nothing changes
- [ ] Shots on the Mac and the tablet in this file
