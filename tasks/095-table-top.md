# 095: A table under the 3D board

Status: todo

The 3D board floats over a blurred photograph. Set it on a polished table top instead, as
in the concept art (`design/manor/library-table-01.png`, `hall-winter-table-02.png`,
local; task 093): mahogany, deep red-brown with a fine straight grain and a ribbon
figure, polished but soft. Procedural like the board's woods, baked at
setup by the same bake (`src/model3d/looks.goose`, `shaders::BAKE_FRAG`), a look's table
being more data: mahogany in autumn, another wood (walnut, oak) where a season wants it.

- The board's shadow, which exists, falls on the table; the table takes the key light
  and the ambient like the board.
- A soft reflection of the board and pieces in the polish: a blurred, mirrored, faded
  copy, not a mirror.
- The table's far edge, or a round table's curve, softens as if out of focus, with the
  blurred photograph (later perhaps a room, task 093) beyond it.
- A setting, next to the background: the table or none, as some will keep the photograph.

Not the generated tabletop pictures set aside for the 2D board (`agents/design.md`): this
is a lit 3D surface under the 3D board only.

Tune with versions side by side from `tools/board_shot.goose`, as task 094 does.

## Acceptance criteria

- [ ] A procedural mahogany top under the board, lit and shadowed with it, in each season
- [ ] The board's soft reflection in it
- [ ] Its far edge soft against the photograph, at every view and on every screen size
- [ ] A setting for the table, with its strings in every language
- [ ] Shots of each season in this file; GPU time and memory recorded on the Mac and the
      A33 against before
