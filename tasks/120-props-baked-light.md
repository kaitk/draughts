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
6,197, room 65 and 4,527, menu 48 and 27,086, board 18 and 169,155 (the top's shade a
little lighter), front 49 and 32,793, close 51 and 47,159, low 74 and 82,161; straight
down unchanged. Time at 3840 × 2160 (`mac_room_bench`, two rounds): the table view 12.85
→ 13.38 ms (+0.53), the corner 14.05 → 14.28 (+0.22). Shots and crops:
`build/notes/props-light/`.
