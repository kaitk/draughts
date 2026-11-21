# 110: The manor scene's costs, made affordable

Status: todo (planned 2026-11-20; after the look of the epic 107 is settled)

The manor scene's work (the epic 107) goes for the look first and leaves its costs here,
to pay them down once the look is chosen (the user, 2026-11-20). They are fine on the
branch for now. Ways to pay them, as the user sees it: bake beforehand and store the
results, or keep baking at run time behind a loader when the room or a look is chosen
(task 101's progress bar), and per render tier (`AGENTS.md`).

## The costs so far (the Mac, 2026-11-20)

- The room's oak (task 104's note): the wood bake's two fields, floor and wainscot, four
  2048² RGBA8 textures with mips, 85 MiB, baked in 45 to 48 ms (about 120 ms the first
  time after a shader change), only with the room on. At 1024², 21 MiB.
- The tree's map (task 105): 512² RGBA8 with mips.
- The wallpaper's mask (task 104): 1024² R8 with mips, 1.33 MiB; decoded from the
  embedded PNG, mipped on the CPU and uploaded in about 12 ms, once with the room's bake;
  the PNG adds 0.6 MB to every build (the Mac app 20.9 to 21.5 MB), though only the tuner
  shows the room. One more texture tap a pixel on the paper.
- The `branches` wind (task 105): six value noises and 4 texture taps a pixel where the
  window's pattern is on; not measured on a device.
- Dust in the sunbeam (task 104's follow-ups): not measured.
- ngfx's 5 ms more on shadow-map frames with the pattern on (task 107): not reproduced.
- No frustum culling: every object is drawn whenever a frame is, only back faces culled.
  Cheap while the room is a few draws; as the room and the outside fill up, test each
  object's bounds against the view, at least for the frames that redraw the kept backdrop
  and the home screen's pans.
- The light tuner's frames with the wind on (its counter, F; headless, the Mac,
  2026-11-20): the room's view (`--view room --room-surfaces on`) and the board's alike,
  about 293 fps, 3.4 ms a frame, worst 4 to 5 ms, at 1600x1000 and at 2560x1600; waited
  for the GPU each frame (`--fps-wait`), 4.2 to 4.4 ms. The same with the window off, the
  wind still, or the shadow map not drawn again each frame, and up to 5120x3200: a
  Metal System Trace shows the GPU 98 to 99.9% busy throughout, so it clocks down to
  fill the time and the frame time hides the load. In those traces, a frame of the
  room's view at 1600x1000 took about 1.8 ms of fragment work in the main pass, 0.7 ms
  of vertex work and a 0.4 ms blit; at 2560x1600 3.9, 2.9 and 1.4 ms. The main pass's
  vertex work is large for a few draws: look at it first. Measure the room's costs in
  such traces at one GPU performance state, or by the counter only once a frame passes
  about 3.4 ms; and in a window at the display's rate, which needs the user's screen.

- The tree's map over the whole window (2026-11-20, `build/notes/plans/shell.md` step 2):
  with the panelled wall's room shown 512 × 1024 RGBA8 with mips, 2.7 MiB, baked in about
  90 ms (the game's 512² cut 85 to 88 ms: growing the tree costs most, not the texels);
  with the library's shell over its three windows 2048 × 768, 8.0 MiB, about 100 ms. Only
  in the room's view; the game keeps its 512², 1.3 MiB.
- The library's shell (2026-11-20, task 109's note): one mesh of 11,902 triangles (23,804
  vertices of 40 bytes, 0.95 MB, and 0.14 MB of indices) in one draw, and its glass and
  lace, 48 triangles, in a second, blended; made on the CPU in about 0.4 ms once when the
  room turns on and turned by `ROOM_VERT`, so nothing is made again when the key moves
  (the panelled wall's room, 6,760 triangles, was rebuilt in the frame loop then). Two
  more masks, the plaster's tone and the lace's, 1024² R8 with mips, 1.3 MiB each; their
  PNGs add 0.92 MB to every build (the Mac's draughts_ngfx 25.27 to 26.43 MB with the
  code). The room's oak bake read 180 to 220 ms in this session (45 to 48 ms before; the
  first after a shader change and the GPU shared with other work: measure again).
- The shell's light (`shaders::LIGHT_FN`'s `shell_light`, only in the room's pipeline):
  three windows, each the niche's outline and, where it lets light through, two
  casements with their bars and the lace; not weighed apart (a scratch copy without it).
- The light tuner's frames with the shell (headless, the Mac, 2026-11-20, `--fps-seconds
  4`): at 1600x1000 the room's four views 375 to 440 fps uncapped (2.3 to 2.7 ms), 3.3 to
  3.8 ms with the GPU waited for (G); the panelled wall's room 4.7 ms and the board's view
  6.6 ms in the same minutes. The numbers swing by two between runs (the GPU's clock, and
  other agents on the same GPU): at 1600x1000 the views' main passes all read about 3.2
  ms of fragment work in later traces, the board's too, so the GPU clocks down to fill
  the frame. Loaded to 3840x2400 all views alike, 42 to 48 fps (21 to 24 ms waited); its
  Metal System Trace, the main pass's medians: the shell's room view 0.19 ms vertex and
  5.8 ms fragment, the panelled wall's 0.12 and 8.1, the board's view 0.25 and 8.0. So the
  shell costs no more a pixel than the board and table do; vertex work stays small at 12k
  triangles. An earlier trace in a quieter minute: the room view at 1600x1000, 0.14 ms
  vertex and 1.5 ms fragment at 370 fps.
- The view out of the shell's windows (2026-11-21, `model3d::view_out`): one draw of 898
  triangles before the room, unlit; the band 2048 × 336 and the oak 584 × 392, RGBA8 sRGB
  with no mips, 3.5 MiB (3,668,224 bytes), decoded and uploaded once with the room's bake
  (with the panelled wall's room too); their PNGs add 0.7 MB to every build (the Mac's
  draughts_ngfx 26.43 to 27.24 MB). The sky is worked out a pixel (an asin, an acos and
  three exps) over all it shows. The light tuner's counter, headless at 1600x1000: the
  room view 2.3 to 2.8 ms with it and 2.4 to 2.7 without (noise); from the games table at
  the middle window 1.5 to 1.7 ms against 1.2 to 1.6, waited for 2.9 to 3.0 against 2.6
  to 2.8. In the kept image, so nothing on a still frame.

- The table's shadow from the key's map (2026-11-21, task 107): 4, 9 or 16 compared
  taps a table pixel by tier, a table pipeline per shadow filter. The light tuner's
  counter, headless at 1600x1000, the user's low angle waited for 5.8 to 6.2 ms before,
  6.0 to 6.5 after, the game camera within noise: perhaps 0.2 to 0.3 ms on the Mac.
  Not measured on a device.

- The curtains (2026-11-21, task 107, `build/notes/curtains-build/`): six lace panels of
  1,152 triangles (6,912, drawn blended with the glass in one draw, no depth write) and
  their rods, brackets, finials, cords and hooks, about 530 opaque triangles a window
  (the shell 11,338 to 14,518); made in about 1.7 ms once with the shell (0.5 before).
  The lace a 1024 × 1408 R8 texture with 8 mips, 1.9 MB (the old mask 1.3 MB); three
  ways of it embedded while the choice is open, 0.7 MB of PNG each (about 2.1 MB in every
  build, 1.8 MB more than the stand-in). The lace a pixel: one textureGrad, its own
  `window_light` (the shell's niche, two casements, the tree) and a pow; the room's other
  pixels one more textureLod and a few smoothsteps where the key crosses a panel. The
  light tuner's counter, headless at 1600x1000, two rounds: uncapped, the room view 1.6 to
  1.7 ms before and 2.2 after, the window view 1.5 and 2.1 (about 0.5 ms, the lace's
  blended overdraw); waited for the GPU, 3.0 to 3.2 against 3.2 to 3.3, and 3.0 to 3.6
  against 3.1 to 3.4 (noise). The game's shot and the renderer check unchanged.

- The games table's base (2026-11-21, task 107, `build/notes/games-table-build/`): 6,480
  triangles (3,563 vertices) in the table's mesh and draw, the table 11,520 to 18,512
  (the top's underside closed, 512); the column 2,592 (54 profile spans, 24 round), each
  leg 972 (41 sections of 12 points, a capped end); 0.6 MB of vertices and indices for
  the table, made once with it. Drawn wherever the table is, in the game too, where the
  top hides it. The room's floor works out the base's shadow a pixel (the column and
  three segments a leg, past a distance check), the base the top's. The light tuner's
  counter, headless at 1600x1000, two rounds, before and after: style-01's camera
  2.1 ms both, waited 2.8 to 2.9 both; the base's close-up 2.1 to 2.3 ms, waited 2.8 to
  2.9; the room view 2.2 both; the board's view 3.3 to 3.4 ms, waited 4.0 to 4.1 (about
  0.1 ms, the base's vertices behind the top). Fewer column segments or 8-point leg
  sections would save 0.4k and 1.3k triangles if a device shows it.

- The library's light, round 1 (2026-11-21, task 107, `build/notes/light-round-1/`): the
  probes baked on the CPU in about 57 ms (the first after a start 67 to 69), each time the
  sun, the room's light, the tree or the table changes; 12,555 probes in a 465 × 81
  RGBA16F atlas, 0.3 MB, and fixed CPU buffers of about 1.6 MB (the atlas in floats and
  half floats, the patches, the tree's map at mip 3); six texture taps a room pixel. The
  reflection: the shell's box met per pixel and, for the floor and the brass, the sun
  through the windows at the hit (`window_light`) and the three windows' rectangles. The
  glow: three quarter-size passes and a full-size add, two RGBA16F targets (at 1600 × 1000
  1.5 MB). The light tuner's counter, headless at 1600x1000, two rounds, before and after:
  the room view 2.2 to 3.6 ms, waited 2.9-3.0 to 4.5; the window view 2.0 to 3.3, waited
  2.7 to 4.1; style-01's camera 2.1 to 3.6, waited 2.8-2.9 to 4.4; the board's view 3.4
  to 3.5, waited 4.1 to 4.3. Weighed by a scratch build without the reflection: 2.5 ms
  against 3.6 at style-01's camera, so the reflection is about 1.1 ms of the 1.5 (its
  shader's weight even where a uniform turns it off); the glow and the bake's lookup
  within noise. To cut first: the sun at the reflected hit (one `window_light` a floor
  pixel), or the reflection as a variant only the high mode compiles.

- The leftovers (2026-11-21, task 107, `build/notes/leftovers/`): the probes 10,140 in a
  390 × 78 atlas (0.24 MB), baked in about 45 ms (57 before); the shell's tree map with
  the limbs' wider blur 187 ms (172 before); the mesh's triangles unchanged (14,518).
  The light tuner's counter at the room view, headless 1600x1000, two rounds: 3.6 ms
  before, 3.7 after (the floor's door terms, a few operations a floor pixel).

- The bookcases and their books (2026-11-21, task 107, `build/notes/bookcases-build/`):
  the shell's mesh 14,518 to 18,818 triangles in the same draw, the two cases' carcasses
  about 420 (the wainscot they replace taken off) and 388 books at 10 each (3,880); made
  in about 2.6 ms once with the shell (1.9 before), the shelves filled on the CPU then.
  The books' atlas 1024 × 928 RGBA8 with 4 mips, 5.1 MB on the GPU, decoded and mipped
  on the CPU once with the room's masks; its PNG adds 0.97 MB to every build (the Mac's
  draughts_ngfx 30.23 to 31.27 MB with the code). The colour table is 40 vec4s more in
  the room's block (0.6 KB). A book pixel: one texture tap and a few mixes, the room's
  other pixels nothing (the reflections test one more box). The light tuner's counter,
  headless at 1600x1000, two rounds, before and after: the hall view, the room view,
  style-01's camera and the cases from the room's middle all 3.4 ms (4.0 to 4.1 with the
  GPU waited for), both: within noise, the GPU clocking down to fill the frame. The
  probes' bake unchanged (about 47 ms). Not measured on a device. To pay later: ASTC for
  the atlas (about 0.4 MB on the GPU at 6 × 6), the books only in the views that see them.

- The books' tone (2026-11-21, task 107, `build/notes/books-tone/`): the atlas the same
  size on the GPU, its PNG 0.97 to 1.03 MB (each volume's own tone and more wear); 384
  books (18,778 triangles, 40 fewer). `ROOM_FRAG`'s `case_shade`, for a lit pixel: a few
  comparisons that leave at once outside the cases, a short loop over seven heights
  inside. The light tuner's counter on the cases from the room's middle, two rounds,
  before and after: 3.4 ms (worst 3.5 to 5.3) both, within noise. Not measured on a
  device.

- The night run's follow-ups (2026-11-21, task 107, `build/notes/choices-2026-11-21/`):
  the tie-backs about 920 triangles each (the shell's mesh 18,778 to 24,322: the cord's
  loop, run and tails as 8- and 6-sided tubes, two balls for the knot, a lathe a tassel);
  the panels 1,152 to 1,512 triangles each below 0.83 m at 12 columns a fold (glass and
  lace 6,924 to 9,084); the mesh made in about 3.2 ms once with the shell (about 2.7 before).
  Lace f3 one more PNG, 0.88 MB, in every build (the four ways about 3 MB); still one
  1.9 MB texture on the GPU. The oak's tint a few operations a texel in its bake; the
  ceiling's colours two vec4s more in the room's block. The light tuner's counter,
  headless at 1600x1000, two rounds, before and after: the room view 4.0 to 4.1 ms, the
  window view 3.7 ms, both. Fewer sides on the cord, or the knot and hook's balls at 6 × 4,
  would save about half the tie-backs' triangles if a device shows it.

- Step 1's fixes and the corners (2026-11-21, task 107, `build/notes/ao-fixes/`): the
  table's own map, a 1024 × 512 DEPTH16 texture (1 MB on the GPU), drawn with the table's
  mesh (about 7,000 triangles) only when the room and the table show and the key or the
  table changed, never in the game; `TABLE_FRAG` and `ROOM_FRAG` read it with 9 taps where
  it reaches. `corner_shade`, a few dozen operations a room pixel (its niche, door and
  bookcase terms only near them); `base_hides`, four legs' two segments a floor pixel
  within 0.43 m of the column; the highlight's `window_open` already worked out for the
  diffuse. The light tuner's counter, headless at 1600x1000, two rounds, before and
  after: the room view, style-01's camera and the table's feet all 3.4 to 3.5 ms, at the
  Mac's floor and within noise. Not measured on a device.

- Step 2 of the morning's order (2026-11-21, task 107, `build/notes/tieback-top/`): the
  tie-back's settling, about 4.5 ms once when the shell is made (20 settles in 0.09 s
  built at -O2), shared by the six; the shell's mesh 24,322 to 30,274 triangles (the knot
  a swept trefoil, 768 a tie-back, the ring, run and tails longer), the lace 9,084 to
  12,540 (20 rows over the hem's 6 a panel, from 14 and 5); the mesh made in about 9.8 ms
  (3.2 before). Lace f3 the default: no cost of its own (the four ways' PNGs were in
  already). The 0.95 m top: no cost. Fewer sides on the knot, or 120 steps (3.5 ms, the
  same shape), if a device shows it.

- The books' rounded spines (2026-11-21): four strips a spine for two, 1,536 triangles
  more for the 384 books (the shell 30,274 to 31,810); the mesh's making time within its
  noise. The swept mouldings' smooth normals cost nothing.

- The light's bounces (2026-11-21, task 107, `build/notes/bounce/`): the bake 47 to about
  90 ms on the CPU (the sun's rays 0.1 ms, the first light 3.4, each of the three bounces
  6.2 to 6.6, the half grid's gather 21, the probes 46), only when the sun, the room's
  light, the tree or the table changes and held while a slider drags; about 0.2 MB of
  fixed buffers more (`room_light::Bounce`). The table's room shader a pipeline more (made
  with the room's). Frames (headless, 1600x1000, `--fps-seconds 4`, two rounds alike):
  the room view 5.6 to 6.0 ms, style-01's camera 5.5 to 6.0, the table's base 5.2 to 5.5,
  the room waited for the GPU 6.5 to 6.9; most of it the corners' boxes (the old
  `corner_shade` 1.2 ms of the 5.6, the new about 1.6). Unrolled over nine boxes the
  corners' code made the room's shader 157 ms a frame even where it returned at once:
  one loop the compiler can't unroll keeps it to one copy (`agents/goose.md`'s rule on a
  big function's call sites). Not measured on a device.

Add each new cost here as it lands, with its numbers.

## Ways to pay, only where a cheap measurement shows a cost (the user, 2026-11-20)

The cameras are few and mostly still, and the home screen is one scene that can be
cheated around (the kept backdrop drawn once, baked light), so none of this is done ahead
of need; the biggest cost first, when it shows.

- Normal or parallax maps in place of geometry where the shape is shallow (mouldings,
  joints, plaster); tessellation not, as phones' GPUs pay dearly for it.
- Levels of detail for meshes, and smaller textures or mips for what is seen only from
  afar.
- Frustum culling (above).
- Not a deferred renderer: it pays off with many lights, and the scene has one sun, its
  bounce and the ambient; its G-buffer costs memory bandwidth, which the A33's tiled GPU
  is short of, and makes MSAA harder. With many small lights (candles, a chandelier) a
  tiled or clustered forward pass would be the step instead.

## Acceptance criteria

- [ ] Each cost above measured on the Mac and the A33 (task 071's way for memory)
- [ ] For each, a choice recorded: baked offline and stored, baked at run time behind a
      loader, cut per tier, or kept as it is
- [ ] The 3D standard tier's memory and startup no worse than before the epic 107, or the
      difference agreed with the user
