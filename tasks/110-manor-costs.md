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
