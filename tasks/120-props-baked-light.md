# 120: The props' light baked per vertex

Status: in-progress

The room's surfaces read a baked probe grid (10,140 probes 0.3 m apart, a constant and a
direction per colour, `model3d::room_light`, rebaked in about 88 ms when the sun, the table
or the tree changes). The games table and its chairs don't: they take four samples on the
table's axis (`render3d::probes_on_table`), so a chair is lit as if it stood in the table's
middle, knows nothing of where it stands or of itself, and its curved pads barely change
with direction. The chairs' round 2 (task 107, 2026-11-25) showed it: they read light and
evenly lit, and the back's top is lighter than its foot by the axis samples' heights, not
by anything round it. Their shade was patched by hand into the vertices' occlusion. The
user's ask: real light for the props on high-end desktops, which also works on Mali, and
scales to many more props. Radiance cascades were considered: they solve lights and scenes
that change each frame; ours are fixed, so a bake gets the same for nothing a frame, and
the cascades' idea (fine near, coarse far) can shape the bake instead.

The plan to check:

- What the props hide doesn't depend on the sun, since the furniture doesn't move: bake it
  once per mesh, in the background at startup or shipped (rays from each vertex against the
  room and the props; about 32 rays a vertex). Each vertex keeps a direction and how much it
  sees (RGBA8, 4 bytes: 0.1 MB for the two chairs, about 4 MB for a furnished room of a
  million vertices, against the vertices' own 40 bytes each).
- The sun's part stays in the probe grid. When it is rebaked, each vertex's light is the
  grid sampled where it stands, seen through its baked direction: a CPU loop of a few
  milliseconds per million vertices, no rays.
- Low-end Android GPUs (the tablet's Mali the example, fragment-bound, task 115): the final colour per vertex (RGBA8, scaled),
  one interpolated attribute, no texture taps or harmonics in the fragment shader: cheaper
  than the four samples' harmonics a pixel the table pays now.
- High-end desktops: the same baked direction feeding the grid's lookup per pixel, and two
  more bands of harmonics if they show (54 bytes a vertex as a per-vertex store, so per
  pixel from the grid only). A define per tier, no new pipelines.
- The walls and floor keep the grid per pixel: their meshes are a few large quads.

The user agreed to the approach (2026-11-25) on one condition: it mustn't trade much
quality on desktop GPUs. The per-vertex colour is for low-end Android GPUs (Mali the example, not the only target); the desktop tiers keep the
per-pixel lookup, and nothing there gets coarser than today.

## Acceptance criteria

- [ ] The bake's cost measured: rays a vertex against the result (the chairs' self-shade,
      the seat under the back, the table over the chairs), its time once at startup, and
      whether to ship it
- [ ] The chairs and the table lit by it on the Mac, against today's shots
      (`build/notes/chairs-2-build/`): the back's gradient and the flat cushions judged by
      the user; the hand-made occlusion in `chairs.goose` removed where the bake covers it
- [ ] The tablet's per-vertex colour measured there against today (task 115's view), once
      the room is more or less done: mobile is tuned after the high end is settled (the
      user, 2026-11-25), to 30 fps at native resolution, rendering 1,474,560 pixels (0.8 of the test
      tablet's resolution: 1536 × 960 at 16:10, 1619 × 911 at 16:9, 1810 × 815 at 20:9),
      upscaled, only as the last resort, on any device
- [ ] The memory in `render3d::room_bytes` and task 071; the costs in task 110
- [ ] A decision in `docs/decisions/rendering.md`, the light's description in
      `docs/architecture/rendering.md`
- [ ] Then the chairs' cloth and wood strengths as sliders in the tuner's Table section,
      if they still need tuning (the user, 2026-11-25: not just darker)
- [ ] The shell's props take it too (2026-11-25), after the table and chairs: the doors
      and their handles, the shutters, the bookcases and books, the stove, the curtains.
      `ROOM_FRAG` reads the grid per pixel already; it takes the bake's direction and open
      part from a storage buffer as the table does, the walls, floor and ceiling left out
      (a few large quads). Each object's hand-made shade (the mouldings', the curtains'
      folds) removed where the bake covers it, each behind a tuner flag with its own
      shots, judged by the user one by one

## The bake's cost (2026-11-25)

`model3d::prop_occlusion`: for each vertex, cosine-weighted rays over the hemisphere round
its normal against the props' own triangles (the table and both chairs; the shell is the
probes'), a hit at t counting 1 - (t / reach)², so it fades into the probes' light at the
reach. Each vertex keeps the open part and the mean open direction. The triangles sit in
a uniform grid walked cell by cell (Amanatides and Woo). `tools/prop_bake.goose` times it
on the Mac (one core, -O2) and compares it with a bake of 1024 rays: 39,831 vertices
(the table 9,755, the chairs 30,076), 73,472 triangles.

| Rays | Time (1-unit cells) | Open's mean error (max), chairs | Direction's mean error |
|---|---|---|---|
| 8 | 351 ms | 0.034 (0.31) | 8.2° |
| 16 | 694 ms | 0.020 (0.18) | 4.9° |
| 32 | 1,324 ms | 0.012 (0.10) | 3.0° |
| 64 | 2,531 ms | 0.007 (0.06) | 1.9° |
| 128 | 4,850 ms | 0.004 (0.05) | 1.2° |

At a reach of 0.5 m; the table's errors are the same within 0.002. The reach barely
changes the time (32 rays: 1,243 ms at 0.25 m, 1,385 ms at 1 m). The grid's cell: 32 rays
take 6,212 ms in cells of 4 units, 2,541 in 2, 1,324 in 1, 827 in 0.5, 748 in 0.35 and 787
in 0.25 (from 1,035 triangle tests a ray to 33): below 0.5 the walk itself is the cost,
so cells of 0.5 units (1.6 cm). The direction's largest errors (up to 110°) are at
vertices that see almost nothing, where the direction carries no light.

The decision (2026-11-25): 32 rays, and shipped. Under a second on the Mac, two to three
on the tablet's slower cores, is too long at startup; the props change only in the tuner,
so a build step bakes the app's mesh into a file of 4 bytes a vertex (160 KB), refused
when it doesn't match the mesh, and the tuner bakes again itself when a slider changes
the mesh.

The app doesn't draw the room's props yet (only the light tuner sets `Gpu.chairs`; the
room on the home screen is task 106's), so the shipped file is made when it first does;
until then the tuner bakes for itself, under a second, only with the light on.

## The light per pixel (2026-11-25)

Behind the light tuner's `--props-light on|kept` (default off; the Table section's "Light
per pixel"): the table's room pipelines (`table_room`, the HDR `h.table`, the floor
mirror's `planar_table`, and ngfx's) in a `shaders::PROPS_LIGHT` variant. `TABLE_VERT`
reads each vertex's open direction and open part from a storage buffer by
`gl_VertexIndex` (`render3d::props_open`, a `vec4` a vertex, 0.64 MB: ngfx's translation
takes only `vec4` buffers); `TABLE_FRAG` reads the probe grid where the pixel is, toward
that direction turned as far as the pixel's normal turns from the mesh's (the top's map),
as `ROOM_FRAG`'s `baked_light` does, times the open part, and the polish's reflection
likewise. The grid's box and the atlas come in a block and a texture slot of their own
(`PropsLight`, binding 3; slot 11, 10 in the mirror), so no shared block changed. The
chairs take the bake in place of their hand-made shade; the table keeps its profile's,
and `on` drops its two analytic terms (the base under the top, the edge's underside),
`kept` keeps them.

Two fixes to the bake from the first shots: a dashed near-black line along the rim under
the top, where the bead's top row touches the slab. Hits nearer than 1.6 mm aren't counted
(`NEAREST_HIT`), and each vertex is averaged once with its neighbours on the mesh
(`smooth`): the low view's new near-black pixels (under 6 where today's are 12 or more)
fell from 569 to 240, and the line reads as a soft crease at 100%.

Off, every view is today's within 1 level, none over 8; the game's shot unchanged. On, at
1920 × 1080 against today (largest difference in levels, pixels over 8): corner 63 and
6,197, room 65 and 4,527, menu 48 and 27,086, board 18 and 169,155 (the top's far part about
5 levels darker), front 49 and 32,793, close 51 and 47,159, low 74 and 82,161; straight
down unchanged. Time at 3840 × 2160 (`mac_room_bench`, two rounds): the table view 12.85
→ 13.38 ms (+0.53), the corner 14.05 → 14.28 (+0.22). Shots and crops:
`build/notes/props-light/`.

## Review: why the props look flat (2026-11-26)

The user judged `on` flat: the chairs and the table's base the same all round, "like an
unshaded 1990s object", where a photo of a period room lit by a window shows strong falloff
by direction and dark undersides. An independent review (scratch tools and numbers in
`build/review120/`) measured, with no bug found in the wiring (the bake reaches the pixels,
in the right space, on the right vertices):

- The chair's rear back pad rises 18 mm over a flush frame: the bake leaves it open (0.93
  at 11 mm from the rim, 0.99 at 20); the roundness it had before was the hand-made 40 mm
  edge darkening (0.45 at the rim), not occlusion. The front pad the bake does darken (0.40
  open at 9 mm, 0.78 at 28, its foot over the seat 0.75 to 0.87 out to 100 mm).
- The flatness is the indirect light's, in today's look too: the probes are directional
  (at a chair 0.085 from above, 0.029 from below, green, over pi), but two terms blind to
  direction are added to every face beside them, `room_shade` (0.034) and the look's
  harmonics times `room_mix.y` (0.005 to 0.018): about as large as the grid, they take the
  chair's up/down ratio from 2.9 to 1.8 and the base's room/window ratio from 3.0 to 1.6.
  With `on` the shaded parts got lighter (the right chair's back pad 30%).
- Under and beside the table the indirect light comes from the room side and from above:
  the low sun's floor patches lie 1.6 to 2.3 m into the room, and `under_table` cuts the
  window's sky from the probes under the top. Whether the sky against the bounced sun is
  balanced right is open.
- The base under the top loses its sky twice (the probes' `under_table` and the bake);
  the chair's frame shows a step at its closed line's seam (duplicate vertices, each its
  own ray turn).
- Missing against a path tracer: the window as a compact source (L1 smears it), the
  blockers' own light (the cream cloth's crease between seat and back), the props in the
  probes' view.

Next (the user, 2026-11-26): a CPU path-traced reference of the room with its meshes, the
sun through the windows and the sky, several bounces, at points on the chairs and the base,
before any redesign; then the redesign in steps checked against it. The shell's props'
unfinished work waits in a stash.

## The path-traced reference (2026-11-26)

A CPU path tracer of the room (`build/review120/`, scratch): every triangle of the shell, the
glass and lace, the table and chairs, in two uniform grids; Lambertian surfaces with
`room_light`'s albedos; the sun by a shadow ray at every hit through the panes (0.88, the
bars being geometry), the tree's factor and the lace's; the sky for rays leaving through the
glass; up to 10 bounces. The sun's light thrown off a surface keeps `room_light`'s own gain
and caps, so its numbers compare with the probes'. 23 points × 4,096 paths in 0.62 s; a
480 × 270 picture of the close view at 512 samples in 170 s on four processes.

- The grid in open air against it (green, faces toward the window, the room, down): toward
  the window 0.9 to 1.05 of the reference (the sky and the units agree); toward the room
  1.4 to 2.8 times too bright; down 2.4 to 5.8. The light of the sun's floor patches is
  overstated on faces turned from it (the L1 lobe, 0.25 + 0.5 cos, gives a point-like patch
  a quarter on faces at 90°; no furniture in the patches' view). At a chair the window/room
  ratio is 2.2 in the reference and 0.83 in the grid: the grid turns it round.
- At the props, none of the points in the sun, today and `on` are 1.5 to 16 times the
  reference, worst in shade and turned down: the rear pad's middle 0.021 to 0.025 against
  0.070 to 0.095 today; the seat under the back 0.018 to 0.025 against 0.12; the apron's
  underside 0.002 to 0.004 against 0.035; the top's underside 0.007 against 0.050. Ratios:
  front pad over rear pad 2.5 (today 1.0 to 1.7); the seat's top over the apron's underside
  11 to 18 (today 3.5); the column over the top's underside 4.7 (today 1.5).
- `on` without `room_shade` and the kept harmonics comes to 0.9 to 1.6 times the reference on
  lit faces and the pads' ratio to 2.2 to 2.4; the places turned down and the creases stay
  1.6 to 9 times too bright: the grid's own error, and the floor left out of the props' bake
  (the apron's underside 0.97 open).

The review's inventory of the light's terms that a physical light wouldn't have, each with a
verdict against the reference (go, fit to it, or a camera or art choice), is in its report
and goes into the plan for the light's rebuild (the user, 2026-11-26: build the light as the
path tracer computes it, ground every approximation against it, remove what it shows isn't
needed). A Blender Cycles render of the same scene is the second check.

## The two references against each other (2026-11-26)

A Blender Cycles render of the same scene (`tools/blender_export.goose`, `tools/blender/`;
close, front and low views, `build/notes/cycles120/`) with physical inputs: no bounce gain,
no caps, no fills, the sun as `sun.light`, two panes of 0.92, the lace a sheet passing 0.72.
The CPU tracer in the same physical mode, measured as Cycles is (the light alone on the
props' pixels by the normal's largest axis), comes within 0.8 to 1.6 of it: the low view's
seat turned away 0.0085 (Cycles) and 0.0097, up 0.0119 and 0.0168, down 0.0038 and 0.0035;
the top's underside 0.0033 and 0.0040. The tracer's darker undersides before were its points
deep in shade against Cycles' means over the visible pixels, near the rims. No bug found in
either.

The bake's gain of 10 on the sun's light thrown on, with its caps and grey balance, makes
the shade 2 to 3.6 times brighter and halves the up/down contrast (the seat's 3.1 in Cycles,
1.9 with the gains): the largest single flattener. Today's look against the physical light,
each place over a lit face so exposure drops out: the rear pad 2.3 times too bright, the
column's room side 2.9, the top's underside 4.7, the apron's underside 5.4. The physical
ratios: front pad over rear pad 5.5 (today about 1.7), the column toward the window over
toward the room 2.4 (today 0.8), the column over the top's underside 7.2 (today 1.5).

The ground truth for the light's rebuild: physical inputs (gain 1, no caps, real panes),
exposure and white balance set as a camera; Cycles for pictures, the CPU tracer for points,
probes and each step's check. The lace needs one model shared by both before either can
judge its terms.

## What follows (2026-11-26)

The user agreed: the light under the bake is rebuilt in task 122, the Blender pipeline is
task 123, the lace's model task 124. This task's bake is done and stays behind the tuner's
`--props-light`; it becomes the default, with the chairs' hand-made occlusion removed, in
task 122. The shell's props (doors, shutters, bookcases, curtains) wait in a git stash
("task 120: shell props' light, unfinished") until the light under them is right.

The sun and the props move between seasons (the user, 2026-11-26), and the trees will
differ too. The props' bake depends on where they stand against each other, so it is one
bake per season's arrangement (about 0.8 s on one core at 32 rays, or shipped per season),
not one for all; the probes are rebaked with each season's sun as today.
