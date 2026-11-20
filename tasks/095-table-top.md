# 095: A table under the 3D board

Status: in-progress (in main, 2026-11-20: settings' Table background;
the device numbers and the merge's settings left)

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

## Done so far (2026-11-19)

- A round table (`mesh::table`): a lathe-turned top 10.5 units in radius (about 90 cm,
  a square being about 4.4 cm), its middle 2.5 behind the board's, rounded over above and
  under a flat band, a short apron. In landscape its far curve shows at the top corners;
  in portrait and on home its far and near rims.
- Mahogany as data (`src/model3d/tables.goose`), baked by BAKE_FRAG's mode 2 into a map
  `side` × `side`/2 (grain along the world's z, where it changes slowly) in eight more
  theme steps: quarter-sawn planks 5.3 wide, a ribbon figure from noise across the grain.
- Its own pipeline (`shaders::TABLE_VERT`, `TABLE_FRAG`), drawn after the board: the
  wood's diffuse with its grain's relief under a smooth polish that takes the key's
  highlight (broadened: the key is a window) and the room's light; a pool of light round
  the board. The board's shadow and its occlusion at its foot are worked out from its
  outline in the shader (the catcher's quad z-fought the table in the 16-bit depth, and
  is left out under a table).
- The board's reflection, without a pass: the mirrored view ray traced against the
  board's outline shows its side, the frame map's mean color lit, in place of the room's
  light, softer the farther the ray goes. The pieces never show in it (the board hides
  them), so no mirrored pass is needed.
- The far rim faded into the photograph, softer the farther past the board.
- Transitions: the kept image moved and scaled left the table as a rectangle sliding over
  the photograph, so a board on a table is drawn again each frame of a transition through
  its view moved where the image would go (`draw3d::moved`), as a camera ease is.
- Second round (2026-11-19, the user): the table a backdrop of its own beside none and the
  photograph, so its far rim stays sharp (the fade went). The board's thick frame makes
  it a small board (about 30 cm), so the table is 16 squares in radius (about 105 cm).
  Three takes to choose from and tune (`tables::LIBRARY`, `HALL`, `BOARD_WOOD`), the
  library's table (library-table-01) the closest reference: old varnish's blotches,
  crazing, scratches, dents, and the rim's wear baked (BAKE_FRAG's table_over), the
  polish's roughness baked with them. Edge profiles of the period (1890 to 1910) over a
  frieze with a bead: thumbnail, reverse ogee, stepped, beside the plain bullnose
  (`mesh::table_profile`). `tools/table_tune` puts a take, the season, and every value
  on sliders, and prints the table as Goose.
- Third round (2026-11-19): the user's take on the board's wood kept (`tables::BOARD_WOOD`),
  the library's and the hall's dropped; flame mahogany added (`tables::FLAME`), after a
  book-matched flame mahogany card table the user liked: the figure swept by a twice
  warped flow, mirrored about a seam. The key light's highlight size is a slider (the
  table's coat.w), and the bake no longer flattens the wood's relief for every take.
- Tried and set aside: the library's and the hall's takes; a straight quarter-sawn grain with a ribbon figure (a new
  workshop's top, not an old manor's); the patina as first baked (grey, matte, the
  scratches chalk lines).
- The polish reflects only the photograph's harmonics, which can't show a window's
  bright shape as the concepts' gloss does: the room's skybox (task 093) would.
- Handed over (2026-11-19): the user likes the feel of both takes, the flame one as tuned
  (`tables::FLAME`), and the sides' straight streaks.

- Fourth round (2026-11-19): the wear on a tile of its own, finer than the top's map
  (BAKE_FRAG's mode 3, wear_at): 512 square over 2 units (256 texels a unit, the top's
  64), scratches, crazing and dents in one map, the scratches' and the dents' normals in
  another, laid twice by TABLE_FRAG, the second turned 0.5 rad and 1.37 times as large,
  so they never repeat together; masked by the top's map's patches (its cavity channel,
  free now): scratches where the top was used, crazing where it was left alone, dents
  anywhere. Chosen over working the scratches out per pixel in TABLE_FRAG: that is 36
  segment tests and a Voronoi a pixel over most of the screen, thousands of operations
  where the tile costs four taps. The polish blotchy (`tables::Table.polish`: its
  roughness and strength by a noise, duller where rougher), the wear in it (the scratches
  and dents in the polish's normal and rougher, the worn rim duller). Cost: 2.8 MB more
  at the full side (two 512 maps with mips), 0.7 MB on a phone (256); its bake 9.3 ms on
  the Mac (M1 Pro, gfx and ngfx alike), once with the table's last band.

## Follow-ups

- Where it stands (2026-11-19, the user): the surface is in a good place. What it needs
  is a couple of props on the table (to decide which) and the setting: the table beside
  the seasonal photograph and the floating board, laid out with the pieces' looks that
  task 094 brings.
- The wear's look at the takes' values: the flame's patina is faint (scratches 0.12),
  so it shows mostly in the highlight; tune it with the polish in the tuner.
- Next, in this order (the user, 2026-11-20), not all in one session:
  1. The taken pieces on the table beside the board (built, 2026-11-20): task 099, the first, before any
     prop, as a small thing that makes the scene alive.
  2. Two tables: the round one, and a writing desk improved on from the concept art
     (`design/manor/library-desk-01.png`, `library-table-01.png`, local), trying the
     desk's usual green leather writing surface. Each look's take is
     `tables::for_look` (the flame mahogany for every look till then).
  3. Props, from the concept art: a book at the side, perhaps a candlestick, and an
     antique chess clock, which would suit it best: a German one of about 1900, as the
     manor is Baltic German, a modelling session of its own (task 100). The pieces' box
     (task 102) and the score sheet with its pencil (task 103) chosen as well
     (2026-11-20). The vase and its lace, books, and a lamp (task 093) after.
  4. The board's light fitted to the room per season, and trying the window's shadow
     across the board from the concept art (task 093's sun streak), in a session of its
     own (2026-11-20). The costlier effects are for desktops, a high-fidelity mode, or a
     toggle of their own, not on by default on the A33 or phones in general, where some
     may not be offered at all.
- The room behind hardly shows at the game's views in landscape, but past the round
  table's edge it does in portrait, on the phone in both views (the user, 2026-11-20):
  the board on its table needs the room in some form, a real floor at least. Till then
  the board on its table is never in front of the season's photograph, which read as
  odd once the board was grounded: the plain fade is behind it (`settings::photo_shown`,
  2026-11-20). Before merging: think the options settings allows through again (the
  user holds the merge, 2026-11-20).
- Settings (2026-11-20, the user's take b of the settings prototype): the table is
  Background's third tile, Table, which only the 3D board shows (`table = on` in the
  player's file; the flat board shows the photo or plain kept under it). Switching it
  bakes only the table's steps and the photograph's (draw3d::table_steps).
- Device numbers (GPU time, memory, prepare time) on the Mac and the A33 against before,
  as the acceptance criteria ask; the table's maps are about 45 MB at the full side
  (2048 square, two maps with mips), 11 MB on a phone.
- Shared (2026-11-20): LIT_FRAG and TABLE_FRAG take the light's functions from
  `shaders::LIGHT_FN`; their tone maps differ and stay apart.

## Acceptance criteria

- [ ] A procedural mahogany top under the board, lit and shadowed with it, in each season
- [ ] The board's soft reflection in it
- [ ] ~~Its far edge soft against the photograph, at every view and on every screen size~~
      Dropped (2026-11-19, second round): the table is a backdrop of its own with a sharp
      rim, and the plain fade, never the photograph, is behind it
- [x] A setting for the table, with its strings in every language
- [ ] Shots of each season in this file; GPU time and memory recorded on the Mac and the
      A33 against before
