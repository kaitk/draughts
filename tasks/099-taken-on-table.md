# 099: The taken pieces on the table

Status: in-progress (on the `table-top` branch, 2026-11-20: built, to check on the tablet)

With the 3D board on its table (task 095), the pieces each side has taken lie on the
table beside the board, by the side that took them, as players set them down: a loose
row or a couple of short stacks, a little askew, each piece drawn as the board's pieces
are (their material, task 094, and their shadow on the table). It is the first thing to
add to the table, before any prop: a small touch that makes the scene alive (the user,
2026-11-20).

The game already counts what each side has taken (`panel::Taken`, the flat board's
panels). A capture moves the piece from the board to its place on the table, as the
flat board's taken pieces go to the panel. Without the table, nothing changes.

## Done (2026-11-20)

- `src/board/taken3d.goose`: four layouts as data (`taken3d::HEAPS`), each placing a
  piece by its number alone (and the ones before it), so a capture adds one and moves
  none: short askew stacks in two staggered columns (`STACKS`, the game's), a loose wavy
  row with a piece now and then dropped on the one before and a second row past six
  (`ROW`), a heap of seven flat and the rest piled on them (`HEAP`), and coin towers of
  five (`TOWERS`). The kings lie apart, flat, so their crowns show (a stacked king is its
  two discs). The values: where the men's middle lies (out from the board's side, along
  it), the group's turn, spacing, the most a stack holds, how askew, the kings' place,
  and the hash's seed.
- Where: white's catch at the board's right, black's at its left, both on the near half.
  Placed by each player's right hand (the board turned about its middle), black's catch
  lay at the far left under the landscape's way out and moves panels.
- Drawn as the board's pieces, instances in the same pass, with `view3d::Scene.discs` for
  the shadows `TABLE_FRAG` works out (a capsule a disc, and a darker foot). The lit
  shader's shadow lookup is lit past the shadow map's edge (it clamped to the edge's
  texels and darkened the pieces' tops).
- A capture: the pieces stay on the board, see-through, till the mover's last hop, then
  fly to their places in `board::CARRY` (0.5 s, the move that much longer on the table,
  `board::duration(m, table)`), rising `taken3d::ARC`, opaque by a third of the way; an
  undo carries them back (`board::carried`). `test/board/taken3d.goose` checks a capture
  of a man and a king, the undo, a new game, and the board without the table.
- `tools/taken_tune.goose` (`scripts/mac.py tools/taken_tune.goose`, run from `tools/`):
  the layout and its values, what each side took, the kings' look, 8 or 10 squares, the
  turned board, the season, board and table on sliders; P prints the command that shows
  it again and the layout as a `Heap` literal. The game takes `--taken
  stacks|row|heap|towers`.
- Without the table: 3D shots of the game and a tap match before to 1 of 255; nothing is
  laid (`build_scene`'s `table` false). gfx and ngfx agree within 8 of 255 with the table.

Mac shots (local, `build/taken/`): `game-stacks.png`, `game-row.png`, `game-heap.png`,
`game-towers.png` (autumn, Russian, white 3 against 2 pieces), `winter-ngfx.png` (winter's
marble pieces on ngfx), `tuner-kings.png` (stacked kings beside the men). The tablet's
are still to take.

The others' commands, from `tools/`:

```sh
../build/taken_tune --layout row
../build/taken_tune --layout heap
../build/taken_tune --layout towers
```

## Acceptance criteria

- [x] The taken pieces on the table by the side that took them, in the board's pieces'
      material, shadowed, at every view (in portrait the table beside the board is off
      screen, as is most of it; the panels' counts stay)
- [x] A capture carries the piece there; undo and a new game put them back
- [x] Nothing drawn or allocated per frame for them while nothing changes
- [ ] Shots on the Mac and the tablet in this file
