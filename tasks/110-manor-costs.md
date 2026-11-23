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

- Ambient occlusion from the screen (2026-11-21, task 107, `build/notes/ssao/`): five
  half-size targets, 22 bytes a pixel (place RGBA16F, facing RGBA8, depth 16, the
  occlusion and its blur RG16F): 8.8 MB at 1600x1000, made when the room first draws it
  and again on a resize; five pipelines more, made with the room's. A frame draws the
  room, the table and the board once more at half size with a fragment shader of a few
  lines, then two full passes at half size (8 taps, 16 taps). Frames (headless,
  1600x1000, `--fps-seconds 4`, before / off / on, two rounds alike,
  `build/ssao/fps.sh`): the room view 6.0 / 6.1 / 6.6 ms, style-01's camera 6.0 / 6.1 /
  6.5, the books close up 3.9 / 4.0 / 4.4, the room waited for the GPU 6.9 / 7.0 / 7.9 to
  8.3. Off on phones; not measured on a device.

- The floor's mirror (2026-11-21, task 107, `build/notes/planar/`): three half-size
  targets, the picture RGBA16F, its 16-bit depth and the map RGBA16F with six mips: 8.3 MB
  at 1600x1000, made when the room first draws it and again on a resize; six pipelines and
  a sampler more, made with the room's. A frame draws the view out, the table and the room
  once more at half size with the room's shader less its sharp reflections, a resolve and
  the mips; the floor drops the box's reflection for one anisotropic tap and one plain.
  Frames (headless, 1600x1000, `--fps-seconds 4`, before / off / half / quarter, two rounds
  alike, `build/planar/fps.sh`): the room view 6.6 / 6.6 / 7.3 / 7.2 ms, style-01's camera
  6.5 / 6.5 / 7.2 / 7.1, autumn-02's 6.8 / 6.8 / 7.4 / 7.3, the window view 6.2 / 6.2 / 6.9
  / 6.8, the room waited for the GPU 7.8–8.2 / 7.7–8.4 / 8.7–9.5 / 8.5. The corners in the
  mirror are 0.2 ms of it. Off on phones; not measured on a device.

- The light fixes (2026-11-21, task 107, `build/light-fixes/fps.sh`, before / after, two
  rounds): the room 7.4 / 7.7 and 7.4 / 7.9 ms, style-01's camera 7.4 / 7.6 and 7.3 /
  7.5, autumn-02's 7.5 / 7.8 and 7.6 / 7.8, the window view 7.0 / 7.3 and 6.9 / 7.2; the
  room waited for the GPU 9.2–10.0 / 9.5–9.8. About 0.2–0.3 ms: the mirror's resolve
  takes a 3 × 3 tent (18 fetches a half-size texel) and the floor a slow wax noise.

- Fix 1, the corners' shade baked (2026-11-21, builder 21, `build/notes/builder-21/`;
  `docs/decisions/rendering.md`): `corner_shade` (5.0 ms of the main pass, 0.6 of the
  mirror's) worked out on the CPU into a 4096 × 1013 R8 atlas, 4.1 MB on the GPU, 302 to
  314 ms (five runs) each time the shell's mesh is made or the corners change; the mesh
  made in 12.4 to 13.2 ms (9.8 before: its charts), 73,044 vertices of 56 bytes (47,608
  of 40), so 4.1 MB of vertices against 1.9; fixed CPU buffers of the atlas's 8 MB and a
  chart's 2 MB, touched only by the bake. Metal System Trace, headless 3024 × 1890, the
  room view, before / after, two rounds (the second after first): the main pass 23.57 /
  18.27 and 23.68 / 18.40 ms, the mirror's room 1.87 / 1.30 and 1.81 / 1.20, the frame's
  parts 27.61 / 21.70 and 27.60 / 21.79; the fps counter 27.4–27.7 / 21.1–21.4 and
  27.9–29.0 / 20.8–21.6 ms a frame. The look within a level on average (shots and diffs on
  the page), the game's shot unchanged. The bake's 300 ms is the next thing to pay if a
  slower CPU shows the room: store it with the build (it depends only on the shell and the
  corners), or bake it on the GPU.

- Fix 2, the room's box seen sharply only by the brass and books (2026-11-22, builder 22,
  `build/notes/builder-22/`; `docs/decisions/rendering.md`). Where `room_seen` ran: with
  the mirror, only on a metal (the brass, the books' gilt); every other surface has
  `px` 1, so `sharp` 0 and `room_reflection` returned `room_wide` at once. Its cost was its
  code: cut from the planar shader the main pass fell 18.3 to 14.9-15.0 ms. Its parts cut
  one at a time (main pass, ms, Metal System Trace, headless 3024 × 1890, the room view;
  before 18.24-18.34 over five rounds): the hit's `room_irradiance` 16.1 (one layer of
  probes in it, three taps, 16.7), the windows' loop 17.1, `window_light` at the hit 18.4,
  the irradiance and `window_light` 15.9, all three (the box and its albedo left) 15.8.
  Moving code instead: one call site of `room_irradiance` in a loop for the diffuse, the
  wide and the hit 19.95; the reflection worked out before the diffuse 23.8; the window
  loops counted by `shell.x` 17.8 and 18.3. Now the room's index buffer holds the brass's
  and books' triangles last (`render3d::sharp_last`, when the mesh is made), drawn with
  `ROOM_SHARP` (one pipeline more, made with the mirror's); the rest without its code.
  Two rounds, before / after (the second after first): the main pass 18.24 / 15.40 and
  18.34 / 15.06 ms, the mirror's room 1.28 / 1.23 and 1.19 / 1.20 (unchanged: it never
  had the sharp path), the frame's parts 21.66 / 18.72 and 21.69 / 18.41; the fps counter
  21.0-21.1 / 17.6-17.7 and 20.9-21.0 / 17.6-17.8 ms a frame. The look: 17 shots
  identical but one pixel (a tie-back hook's tip against the wall, 67 levels: the order
  the two are drawn in at an edge), two runs of one build differ by at most 1; the
  game's shot identical. Without the mirror (`room_lit`, phones) the floor sees the box
  sharply, so that shader keeps it whole. Not measured on a device.

- Fix 3, a pipeline per material group (2026-11-22, builder 23, `build/notes/builder-23/`;
  `docs/decisions/rendering.md`): the room's mesh sorted into the floor's, the walls' and
  the metals' index ranges, each drawn with a shader holding only its group's code, the
  glass and lace with theirs; the phone's pipelines without the screen's maps (`NO_SSAO`),
  the mirror's without the floor; the tonemap a define (`LINEAR_OUT`); the tuner's views
  pipelines of their own. Twelve room fragment shaders where there were five (five more
  with the views, the tuner's alone). Metal System Trace, headless 3024 × 1890, the room
  view, GPU ms by Metal's own encoder labels (`build/b23/passes.py`): the sort alone
  changed nothing (main pass 14.98 / 14.96); the split before the views were cut, two
  rounds, main pass 14.99 / 11.48 and 14.97 / 11.48, mirror 1.30 / 0.75, frame's parts
  18.34 / 14.44 and 18.33 / 14.42. Each group alone in the main pass (scratch builds, the
  rest of the pass 1.25): floor 5.66, walls 3.42, glass 0.78, metals 0.10. The walls' shader
  with only the plaster's code 0.10 faster, without the oak's 0.26: the walls stay one
  group. The views' code 0.55 (11.50 / 10.94, two rounds). Final, two rounds before / after
  (the second after first): main pass 14.78 / 10.86 and 14.78 / 10.83, mirror 1.29 / 0.78
  and 1.29 / 0.73, frame's parts 18.09 / 13.69 and 18.10 / 13.72; the fps counter
  17.3-17.9 / 12.9 and 17.3 / 12.9 ms a frame. At 1512 × 945, two rounds: main pass 5.02
  / 3.57, mirror 0.88 / 0.55, frame's parts 6.84-6.85 / 5.15-5.16. The look: 17 shots
  within a level (two runs of one build differ as much), the phone's tier against the old
  build with the screen's maps and the mirror off within a level, the game unchanged. Not
  measured on a device.

- Fix 4, a resolution budget for the 3D scene (2026-11-22, builder 24,
  `build/notes/builder-24/`; `docs/decisions/rendering.md`): drawn into a given target (the
  light tuner, the planned high mode), the scene is drawn at most 4.1 MP
  (`render3d::HIGH_SCENE_PIXELS`, the one constant, the user to choose from the page) and
  scaled up by Catmull-Rom from five bilinear taps; the UI at the screen's pixels. One
  RGBA8 target at the scene's size more (16.4 MB at 4.1 MP), two pipelines. Metal System
  Trace, headless 3024 × 1890, the room view, GPU ms by encoder labels, two rounds
  interleaved: before / after (0.85) the main pass 10.85-10.86 / 8.19-8.20, the frame's
  parts 13.66-13.68 / 10.88-10.94, the fps counter 12.8-12.9 / 10.1 ms a frame;
  `--scene-scale 1` the same as before (13.68-13.69, the room's shot identical). The sweep
  (main pass / upscale / frame's parts / fps): 0.85 cubic of nine taps 8.21 / 0.43 /
  11.11 / 10.2-10.3, 0.85 bilinear 8.22 / 0.12 / 10.77 / 9.9-10.0; 0.75 cubic nine taps
  6.65 / 0.44 / 9.33 / 8.4-8.5, five taps 6.65-6.68 / 0.30-0.31 / 9.10-9.19, bilinear 6.65
  / 0.11-0.12 / 8.92-8.98 / 8.1-8.2; 0.67 cubic 5.54 / 0.43 / 7.85-7.87 / 7.2, bilinear
  5.54 / 0.11 / 7.55 / 6.8. At 1512 × 945 (under the budget) 5.13 / 5.12, 4.4 ms both.
  The floor's 5.7 ms by scratch builds without each part, the main pass at native
  (10.86 with all), two rounds alike: the scratches 1.00 ms (at most 4 levels in the room
  view and a floor close-up at 1600 × 1000), the wax's and wear's three value noises 0.82
  (64 levels, mean 0.7), the mirror's lookup 0.79 (182, mean 7.2: the floor's
  reflection), the door and wall terms 0.36 (21, mean 0.03), the sun's contact shadow on
  the floor 0.25 (nothing seen), the boards' tilt in the reflection 0.18 (53, mean 0.5), the
  joints 0.04, `base_hides` nothing; the mirror, tilt, wax, joints and scratches together
  2.92. Candidates to cut, the user's call: the scratches, the floor's contact shadow,
  the wax's noises (one noise, or a small texture). Not measured on a device.

- The painted wood's own pipeline and the quiet paint (2026-11-22, builder 25,
  `build/notes/builder-25/`; `docs/decisions/rendering.md`). Metal System Trace, headless
  3024 × 1890, GPU ms by encoder labels, two rounds alike. The room view at
  `--scene-scale 1`: the main pass 10.86 before, 10.66-10.67 with the split alone (the
  walls' shader without the paint's code), 11.10-11.11 with the quiet paint; the frame's
  parts 13.68, 13.50-13.52, 13.99-14.00; the fps counter 12.8-12.9, 12.6-12.7, 13.1 ms a
  frame. At the 4.1 MP budget: the main pass 8.19 / 8.41-8.43, the frame's parts 10.94-10.95
  / 11.17-11.22, the fps counter 10.1-10.2 / 10.3. The salon door's view at native: the
  main pass 5.43 / 5.68, the fps counter 7.1 / 7.4 ms. The quiet paint's parts, by
  scratch builds and flags against 11.10: without its fillets 10.98 (0.12), the old mesh
  with the quiet shader 10.92 (the mesh 0.18 in all), without the tile's fetch 11.06
  (0.05), without the fillets' normal hold 11.10 (nothing); the shader 0.25 over the old
  paint's. The mesh 35,074 to 37,906 triangles, made in 12-14 ms either way; the corners'
  map 16,623 to 18,159 charts in 0.29 s either way (its atlas 1,013 to 985 rows); the
  relief tile 25 ms on the CPU at the room's bake and 1.4 MB on the GPU. The look: the
  old paint (J) within a level of before but two pixels at a coplanar seam (the
  architrave's side against the wainscot's end, now drawn by another pipeline); the rest
  of the room unchanged but the painted pieces and their reflection in the floor; the
  game's shot unchanged (max difference 0, both renderers). Not measured on a device.

- The sills' own pipeline and the limestone (2026-11-22, builder 26,
  `build/notes/builder-26/`; `docs/decisions/rendering.md`). Metal System Trace, headless
  3024 × 1890, GPU ms by encoder labels, two rounds alike; before / the split alone (the
  old stone in its own pipeline) / the limestone. The room view at `--scene-scale 1`: the
  main pass 11.11 / 10.92-10.93 / 10.94-10.95, the frame's parts 13.97-14.07 /
  13.82-13.84 / 13.83-13.88, the fps counter 13.1 / 12.9 / 12.9-13.0 ms a frame. The
  middle sill close up (`--plan-eye 4.3,6.55,1.15 --plan-at 4.55,7.2,0.8 --fov 30`),
  native: the main pass 5.93-5.94 / 5.76 / 5.78-5.79, the fps counter 7.7 / 7.5 /
  7.5-7.6. At the 4.1 MP budget, before / the limestone: the room's main pass 8.41 /
  8.28, the fps counter 10.3 / 10.1-10.2; the sill's 4.58 / 4.47, 6.3 / 6.1-6.2. The split
  saved 0.18 ms (the walls' shader lost the stone's code), the limestone costs 0.02-0.03
  over it. The mesh unchanged (37,906 triangles, only the sills' uv); the tile 67 ms on
  the CPU when the shell first shows, 5.6 MB on the GPU, not made for the game's room. The
  old stone (I) the split's exactly and before's within a level but dots along its sharp
  arris; the game's shot unchanged (both renderers). Not measured on a device.

- The window view (2026-11-22, builder 27, `build/notes/builder-27/`;
  `docs/decisions/rendering.md`). Metal System Trace, headless 3024 × 1890, GPU ms of the
  main pass by encoder labels, two rounds alike; `--scene-scale 1` unless said. The room
  view: before 10.94-10.95, every step at 0 11.08, all on 11.94-11.95; each alone over
  the all-off 11.08: the hang 11.17-11.18, the lace's sun 11.08-11.09, the lace's light
  below 11.77-11.78, the veil 11.08, the film 11.16-11.17, the scratches 11.16-11.17, the
  dust 11.08-11.09 (it shows only in the table-window view). The table-window view
  (`--plan-eye 3.75,4.5,1.15 --plan-at 4.0,7.4,1.42 --fov 60`): before 4.58, off 4.75, all
  5.04-5.05; the hang 4.83-4.84, the lace's sun 4.74-4.76, the light below 4.79, the veil
  4.75, the film and the scratches 4.87 each, the dust 4.76. At the 4.1 MP budget, before
  and all: the room 8.28-8.32 and 9.04-9.05, the table-window view 3.59 and 3.94. The
  first build's light below (a second `lace_shadow` call) was 12.39 on and 11.34 off;
  keeping it out of the tree's lookup made the all-off 11.45. The glass's tile 80 ms on
  the CPU once with the shell, 1.4 MB on the GPU. All off matches before; the game's shot
  unchanged (both renderers). Not measured on a device.

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

## Next, by tool (2026-11-23; `build/notes/plans/next-2026-11-24.md`)

Measure under `agents/perf.md` (the atomic quiet lock; re-baseline the four views first,
the last numbers were disturbed by parallel jobs). Codex takes the measurable ones whose
look must stay identical; the look-changing ones go behind a tuner flag for the user.

- [x] Dropped (2026-11-23): retried by Codex with the turned corners and failed again; the
      full mirror target stays. Was: The mirror's scissor retried with the floor's corners turned with the room
      (`b75892aa` rejected it with the unturned corners fixed in `6aa05f8d`; the thin-strip
      view saved 1.06 ms at 4K with 64 texels). Prompt: `build/notes/plans/codex-02-mirror-rect.txt`
- [ ] The glass and the lace split into two shaders and two draws, after the tie-back work.
      Prompt: `build/notes/plans/codex-04-glass-lace-split.txt`
- [x] Tried and rejected (2026-11-23, codex-ssao 423b66a1, `docs/decisions/rendering.md`;
      GTAO not tried). Was: SSAO faster and steadier: a half-size depth-only prepass (positions and normals from
      depth, or last frame's depth reprojected), a steadier upsample, a cheaper read-back; GTAO
      only if it pays. Fixes its grain on bright surfaces (the door behind its handle, the
      sills) and its shimmer in motion. 2.7 ms in the corner view at 4K, passes 1.2-1.4.
      Prompt: `build/notes/plans/codex-05-ssao.txt`
- [ ] What runs with nothing on screen using it: the view out, shadow maps, glow, haze; the
      game's view and near-table menu shots. Then the mirror world simplified (crude shapes,
      each material's dominant colour, baked light; no small props ever), as a flagged trial
      - The mirror's share (2026-11-23, branch mirror-cheap; Metal System Trace headless, the
        mirror's draw, resolve and five mips; page `build/notes/mirror-cheap/`): at 3840 ×
        2160 down 0.99 of 11.5 ms, corner 1.22 of 16.2, room 1.15 of 15.1, menu 0.74 of
        15.1; at 5120 × 2880 down 1.34 of 19.1, corner 1.50 of 25.9, room 1.41 of 23.9, menu
        1.02 of 23.9. The draw itself 0.4-1.0, the resolve 0.2-0.5, the mips 0.1.
      - Skipped where the table's top fills the screen (`table_hides_screen`): the board view
        1.55 ms to none at 4K (frame 28.7 to 27.5 ms, two rounds), 1.95 to none at 5K (trace
        49.6 to 47.7); the four views unchanged, shots within a level.
      - The cheap mirror world, light tuner `--mirror-cheap on` (off; gfx only), the
        mirror's passes by the trace, then the frame (ft, two rounds A B A B): at 4K down
        0.99 to 0.57 ms (frame 10.60 to 10.21), corner 1.22 to 0.79 (14.97 to 14.70), room
        1.15 to 0.78 (14.54 to 14.10), menu 0.74 to 0.66 (14.02 to 13.82); at 5K down 1.34
        to 0.74 (18.19 to 17.57), corner 1.50 to 1.05 (24.61 to 24.56), room 1.41 to 1.04
        (23.18 to 22.94), menu 1.02 to 0.86 (23.18 to 22.84). Shots against today's at 4K
        (largest difference; pixels over 8 and over 32 levels): corner 50, 151k, 8.4k;
        grazing (`--plan-eye 6.0,1.0,0.6 --plan-at 6.0,8.0,0.0`) 38, 216k, 90; room 48,
        124k, 3.7k; menu 1, none; down 2, none. The default is the user's call.
- [ ] The floor's remaining shading: the sun through the windows (5.9 ms straight down at
      4K before the pieces), the mirror lookup (2.5), the probes (2.3), the corners' map
      (2.4 straight down only, to check). The oak's textures are not the cost
      (`build/notes/oak-textures/`: RG8 and compression save memory, not time)
      - Why it is slow (2026-11-23, the user's question): these are costs by removal, and
        they sum to more than the whole frame (about 10.6 ms straight down at 4K), so they
        overlap. The likely cause is one large floor shader limited by its registers: each
        feature adds registers, fewer pixels run at once, and every part slows. Not measured
        yet. The reflection is two costs: drawing the mirror (about 1 ms, the passes) and the
        floor reading it (2.5 ms), so about 3.5 ms in all.
      - [ ] Next: an Xcode GPU frame capture of the straight-down view at 3840 × 2160 (not
        Metal System Trace, which gives only time per pass): the floor pipelines' register
        count and occupancy, the cost of each line, and their stall reasons (memory or
        arithmetic). Then the fix by what it shows: the floor's work split further by area
        (as the sun's pieces did), or the per-pixel reads (the probes, the corners' map, the
        mirror's taps) made cheaper. Profiling on the RTX 4090 (Nsight) set aside for this:
        a different GPU kind (immediate-mode, not tile-based) and far faster, so it would
        hide the cost. Brief: `build/notes/plans/claude-floor-capture.txt`

## Acceptance criteria

- [ ] Each cost above measured on the Mac and the A33 (task 071's way for memory)
- [ ] For each, a choice recorded: baked offline and stored, baked at run time behind a
      loader, cut per tier, or kept as it is
- [ ] The 3D standard tier's memory and startup no worse than before the epic 107, or the
      difference agreed with the user
