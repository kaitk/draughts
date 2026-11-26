# 122: The room's light rebuilt from physical inputs

Status: in-progress

Task 120's references (a CPU path tracer and a Blender Cycles render, which agree within
0.8 to 1.6) show the library's shade 2 to 5 times too bright against its lit faces and the
contrast between faces far too small: the front pad over the rear pad 5.5 physically,
about 1.7 today; the column toward the window over toward the room 2.4, today 0.8. The
causes, largest first: the 10× gain on the sun's light thrown off surfaces, with its caps
and grey balance; two fill terms added to every face whatever its direction (`room_shade`,
the kept harmonics); the probes' L1 lobe spreading the floor patches' light onto faces
turned from them; no furniture in the probes' view; the floor left out of the props' bake.

The user's ask (2026-11-26): build the light as a path tracer computes it, ground every
approximation against the path-traced reference, and remove the terms and legacy options
the reference shows aren't needed. Some approximations stay (a game can't trace paths a
frame); each one is kept only with its measured error against the reference. Looks that
were tuned under the old light (the curtains, the lace, the props' materials) may need
retuning, not hacks of their own.

The ground truth: physical inputs (bounce gain 1, no caps, the panes' real transmission),
exposure and white balance set as a camera would; Cycles for pictures
(`tools/blender_export.goose`, `tools/blender/`), the CPU tracer for points, probes and each
step's check. The tracer is scratch in `build/review120/pt/`; it moves into `tools/` first.
The terms to judge, each with a verdict (go, fit to the reference, or a camera or art
choice), are listed in `build/review120/report.md`.

## Baseline (2026-11-26)

The tuner before this task's changes, `build/perf/light_tune-before122` (from 7bf87a8b),
timed with `tools/perf/mac_room_bench.py --full --views down,corner,room,menu,table` under
the quiet lock, two rounds; ms a frame, the spread between rounds in brackets. The down
view's first run was still warming (22.7 ms), so it is from a second batch of two rounds.

| View | 3840 × 2160 | 5120 × 2880 |
|---|---|---|
| Down | 10.9 (±0.0) | 31.3 (±0.3) |
| Corner | 13.8 (±0.0) | 37.2 (±0.2) |
| Room | 13.1 (±0.0) | 35.5 (±0.1) |
| Menu | 12.7 (±0.0) | 35.0 (±0.7) |
| Table | 12.4 (±0.0) | 33.6 (±2.1) |

## The first step: `--light physical` (2026-11-26)

Behind the light tuner's `--light today|physical` (default today, its shots byte-identical
to before): the bake at gain 1 with no grey balance and the panes' real transmission
(`room_light::glazing` 0.75 in place of 0.78: two panes of 0.92 for the 0.88 it was made
with); the fills blind to direction gone (`room_shade`, the kept harmonics, the shade's
floor of the key: all uniforms, so no shader and no pipeline changed); task 120's light per
pixel on, the chairs' hand-made occlusion and the table's two shade terms off; one sun on
every surface (the room's, through the panes, at its 0.6 saturation; the board and props
had 1/4.4 of it, the oak half, the table 0.19 away from the board) and one exposure, 3.08
in place of the board's 1.45 and the room's 2.61, picked so the room's sunlit floor keeps
today's direct sun (its patch 130/96/73 against 139/101/76; its colour's ratios within 2%,
so the white balance's gains stay 1). The cap on thrown light does nothing at gain 1.

Against `build/path_trace points` (light over pi, luminance, no tree in either; the
tuner's columns are TABLE_FRAG's formula on the CPU from its dumped atlas, scratch in
`build/review122/`), each column one more removal:

| Ratio | Today | Bake physical | No fills | Props light | Reference |
|---|---|---|---|---|---|
| Rear pad / seat top, chair 0 | 0.77 | 0.86 | 0.80 | 0.42 | 0.70 |
| Rear pad / seat top, chair 1 | 0.58 | 0.52 | 0.25 | 0.16 | 0.26 |
| Column's room side / window side | 1.53 | 0.62 | 0.42 | 0.44 | 0.43 |
| Top's underside / column's window side | 0.20 | 0.14 | 0.03 | 0.05 | 0.16 |
| Apron's underside / seat top, chair 0 | 0.30 | 0.26 | 0.06 | 0.02 | 0.09 |
| Apron's underside / seat top, chair 1 | 0.29 | 0.26 | 0.05 | 0.08 | 0.06 |
| Front pad / rear pad, chair 0 | 0.97 | 0.88 | 0.81 | 2.01 | 1.67 |
| Front pad / rear pad, chair 1 | 1.64 | 2.08 | 4.78 | 7.01 | 5.22 |
| Points over the reference, geometric mean | 5.18 | 3.73 | 1.34 | 1.27 | 1 |
| Their range | 1.03–18.7 | 1.07–12.7 | 0.23–3.37 | 0.40–3.60 | |

Three bounces in place of one move the physical points about 3%. Left after the step
(props light over the reference): faces turned up too bright, the seat tops 1.6 to 2.1,
the foot's top 2.1, the front rolls 1.3 and 2.2; faces turned down under the table too
dark, the top's underside 0.41, the edge's underside toward the window 0.40; the apron's
underside 0.42 and 2.2, the front pad near its rim 3.6 and 1.2; the pads' middles and the
column within 1.0 to 1.4. Shots and the per-point table: `build/notes/light-physical/`.

Terms this step left in place: the lace's own fill (ROOM_FRAG's lace, the harmonics and
the bounce at full, task 124), the board's and pieces' ambient (the look's harmonics,
their only indirect light), the table's sun wrapped 0.2 past its terminator, the polish's
0.2 of the light as its environment, the view out's own exposure.

The tonemap isn't one camera either: the room's surfaces take a toe by luminance (under
0.04 it becomes 12.5 y²), the props a toe on their least channel. With the fills gone the
room's shade falls into its toe: in the shots the hall wall's paper is 3.6 levels against
the plain tracer's 13.9, the rug in shade 4.3 against 13.1, while the props, under the
other toe, land on the plain tracer (the low view's rear back pad 20.6 against 20.1, the
close view's column 6.5 against 7.8).

## The second step (2026-11-26)

All under `--light physical`; without it the close, low and room shots stay byte-identical
to `build/perf/light_tune-before122` (with `--base-wood today`). Results page:
`build/notes/light-physical/index.html#step2`; scratch `build/review122/`.

- The preset sets its values from the room as made (`physical_light`), so the printed
  command line (now with `--light`, `--camera-toe`, `--props-wrap`; `--print` prints it
  on the first frame) gives the same picture again: byte-identical.
- One camera curve: the surfaces write linear light into the HDR target (Frame's toe ways
  2) and `HDR_TONE_FRAG`'s `camera_curve` takes the toe and the shoulder in one place, for
  AgX later. Measured against the tracer through each curve (18 boxes in the three views,
  the tracer's light averaged before the curve): mean |difference| 5.6 levels with the
  luminance's toe, 7.2 the least channel's, 8.2 none; the larger level over the smaller
  2.29, 1.57, 1.45. No toe is kept: the luminance's toe squares the light under 0.04, so
  it squares the error too and puts the tracer's own shade at 0.1 to 0.7 levels. Cost: a
  uniform compare a pixel in the HDR output and in the tone pass.
- The props' sun wrap (0.2 in `TABLE_FRAG`) is `props_look.y` under PROPS_LIGHT, 0 under
  the flag (`--props-wrap`). No point moves: all 22 are in the sun's shadow in the
  tracer. On the sunlit pixels it changes the light is 0.67 of the tracer's at 0 and 0.80
  at 0.2 (close view): those faces carry the window's sun excess below, so they don't
  decide it. No cost.
- The 22 points stay at 1.27 (0.40 to 3.60): neither change moves them.

The probes against the tracer (196 probes round the table, six directions, with and
without the props, an ideal L1 and L2 from the tracer's light):

| Direction | 0.15 m | 0.45 m | 0.75 m | 1.05 m | Ideal L1 | Ideal L2 |
|---|---|---|---|---|---|---|
| Up, probes / tracer | 1.11 | 1.35 | 1.61 | 1.76 | 1.04–1.24 | 1.00–1.03 |
| Down | 1.00 | 0.59 | 0.92 | 3.11 | 1.17–2.04 | 0.97–1.12 |
| Toward the hall | 1.52 | 1.52 | 0.76 | 0.90 | 0.33–0.80 | 0.96–1.03 |
| Toward the window | 0.42 | 0.78 | 1.00 | 1.17 | 0.87–1.03 | 1.01–1.04 |

By source (the probes' mean over the tracer's, 0.15 to 1.05 m): the sky alone 0.90 to
1.15, the sun alone 1.9 to 2.6, the sun's patches without a bounce 2.2 to 3.3. The cause:
at this sun (15° up) the window's mesh lets 0.37 of the bake's glazed rectangle's sun into
the room (0.55 square to the wall: the frames' and bars' depth), the bake 0.86. The room's
own sun patches carry it too: the sunlit door 1.55 to 1.6 times the tracer's, the table's
top 1.8 (exposure lowered so nothing clips). At the points: the seat tops' excess is the
gather (probes 1.7 to 2.3 times the tracer at their lookup points, ideal L1 1.07 to 1.46);
the column's room side, the rear pads, the edge's underside toward the window are the L1
lobe (ideal L1 0.15 to 0.41, L2 0.98 to 1.03); the top's underside is the props' open
part (0.42); the foot's top misses the table's top over it (past the bake's 0.5 m).

Emulated on the 22 points: the sun times 0.43 alone 0.66 (0.01 to 2.09), worse, as the
faces turned down lose the floor's light and their L1 goes under zero; with L2's share as
a factor 0.67 (0.04 to 1.61), a crude emulation. Not made, as design choices for the user:
the window's sun traced through its mesh in the bake and in the room's sun patches (halves
the sun at this angle, changes the patches' look and the exposure set on them; a few ms a
bake), and L2 probes (2.25 times the atlas, 18 texel reads a lookup in place of 6).

## The third step (2026-11-26)

Both under `--light physical`; without it the close, low and room shots stay byte-identical
to `build/perf/light_tune-before122` (with `--base-wood today`). Results page:
`build/notes/light-physical/index.html#step3`; scratch `build/review122/s3/`.

- The sun through the casements' members with their depth. The bake traces each of its
  1,080 sun rays (8 × 8 lines over the ray's cell) through the casements' boxes
  (`room_shell::casement_members`, as `casement_quiet` builds them, and the lunette), the
  panes' 0.8464 in place of the glazing's 0.75; `LIGHT_FN`'s `casement` widens each
  member's band by its depth along the sun's line. The switch is `rooms::Room`'s `panes.w`
  (`--casement-depth off` for the flat members). Against the tracer's mesh at 15°: the
  bake's sun into the room 0.856 of its glazed rectangle before, 0.381 after, the tracer
  0.369; the shader's casements 1.13 of the tracer's line by line before, 1.000 after
  (0.05% of lines differ). The visible patches were 1.13 too bright, not the second step's
  1.55 to 1.8 (box means mixing in indirect light and gloss): the door's fully lit pixels
  are 0.93 of the tracer's before and after.
- L2 probes for the props: the bake gathers the second band of the same lights (through
  the half grid too) into a props' atlas of nine harmonics, 7 RGBA16F texels a probe before
  the settle (390 × 182, 555 KiB), only with `render3d::props_light`. `TABLE_FRAG`'s
  `PROPS_LIGHT` (the desktop's tiers) reads it in the room atlas's slot; `ROOM_FRAG` and
  its atlas unchanged (the dumped atlas byte-identical).

Per change, over the tracer (the geometric mean counting a ratio under 0.05 as 0.05; the
error factor the mean of the larger over the smaller; probes: 180 round the table not under
its top × 6 axes, against the tracer without the props):

| State | 22 points | Range | Error factor | 1,080 probe values | Range | Error factor |
|---|---|---|---|---|---|---|
| Before (L1, members flat) | 1.26 | 0.32–3.03 | 1.64 | 1.16 | 0.00–15.7 | 1.88 |
| L2 alone | 1.14 | 0.13–2.62 | 1.65 | 1.13 | 0.00–17.8 | 1.71 |
| The window alone (L1) | 0.64 | 0.00–1.82 | 2.00 | 0.65 | 0.00–7.65 | 2.04 |
| Both | 0.68 | 0.03–1.72 | 1.72 | 0.66 | 0.00–5.31 | 1.72 |
| Ideal L2 of the tracer's light | 1.00 | 0.23–2.31 | 1.32 | 1.01 | 0.64–2.06 | 1.06 |

(The second step's 1.27, 0.40–3.60 for "before" is the same atlas against another run of
the tracer's samples.) With ideal L2 probes the points would be 1.00, so most of what is
left is the probes' own gather, mainly the light from below: the probes' light downward at
0.15 to 0.75 m is 0.14 to 0.21 of the tracer's, which L1's lobe hid; with L2 the faces
turned down get it (the aprons' undersides 0.13 and 0.06, the top's underside 0.03). The
floor's cells' light is about right, but the probes 0.15 m over them gather 0.14 to 0.32 of
the tracer's light from below (the near limit, 0.3 m; no rug in the bake, 1.7 times the
floor's albedo). Scratch builds, not kept: the near limit 0.02 m² gives the points 0.80,
the rug in the floor's cells 0.77, both 0.88 (0.09–1.73, error factor 1.41; probes 0.74),
with three bounces too 0.90. A shortfall near the floor stays even then (the probes' total
0.72 and 0.79 of the tracer's at 0.15 and 0.45 m), not yet found. The two smaller causes
move two points: the top's underside's open part as 1 (0.03 to 0.07) and the table's top
in the probes' view of the foot (1.72 to 0.84) together give 0.67 (0.06–1.26), error
factor 1.67. Neither is made.

The exposure stays 3.08 (EV 1.62): the members' depth changes how much of a patch is lit,
not the sun on a lit spot; the floor patches' brightest pixels are 2% lower (the bake's
indirect part), which by the first step's rule is 3.16, 0.04 EV.

Cost: the bake 85 to 101 ms on the Mac (the sun's rays 0.1 to 0.8 ms, the half grid 21 to
29, the probes 46 to 58), the L2 part only with the props' light; per pixel one divide in
`shell_open` and about a dozen operations a `casement` call, and in `TABLE_FRAG` with
`PROPS_LIGHT` 28 bilinear reads in place of 12 (two lookups of 7 texels × 2 slices) and
about 40 more multiply-adds. The phone's tier, designed only: the props' light a colour a
vertex from the same props' atlas on the CPU after each bake (`grid9` at each vertex half a
step out along its open direction, times its open part), read under a `PROPS_VERTEX`
define: no texture and no per-pixel reads.

## The fourth step (2026-11-26)

All under `--light physical`; without it the close, low and room shots stay byte-identical
to `build/perf/light_tune-before122` (with `--base-wood today`). Results page:
`build/notes/light-physical/index.html#step4`; scratch `build/review122/s4/`.

- The rug in the bake (`room_light::rug_in_bake`): its extent and albedo are
  `room_light::RUG_HALF`, `RUG_IN` and `RUG_ALBEDO`, which `tools/path_trace.goose` reads
  too; the floor's cells take it by the share they cover, the floor's sun patches where
  they land on it.
- The probes' near limit 0.02 m² in place of 0.09.
- The exact gather (`room_light::gather_exact`): a cell nearer a half-grid probe than two of
  its sides is gathered as 8 × 8 small ones; the table's own sun patch, which lies in its
  top's plane, is no longer hidden by the top from the probes over it (its height rounded
  under the plane).
- The table takes the props' bake's open part alone (`render3d::props_profile_ao` off,
  `props_look.z`), not its profile's hand-made occlusion times it, as the chairs do.
- The tracer's sun has its disc: each shadow ray goes to a point of a disc 0.004653 rad in
  radius, as Cycles' 0.53° sun.

The probes are now checked against the tracer with the table's top in its view, as the
bake has it; step 3's reference had no props, which made the probes at 0.15 and 0.45 m read
0.71 and 0.77 where, with the top, they are 0.79 and 0.87. 36 of the 180 probes are left
out: the row 3 cm before the lace (it reads the lace's own glow) and those on the table's
top at 0.75 m (0.1 mm over the sunlit top). Per change, over the tracer:

| State | 22 points | Range | Error factor | 864 probe values (144 × 6) | Range | Error factor |
|---|---|---|---|---|---|---|
| Before (step 3 as made) | 0.68 | 0.03–1.69 | 1.72 | 0.76 | 0.02–2.38 | 1.55 |
| The rug in the bake | 0.77 | 0.07–1.70 | 1.53 | 0.81 | 0.07–2.40 | 1.45 |
| The near limit 0.02 m² too | 0.87 | 0.09–1.70 | 1.41 | 0.87 | 0.07–4.65 | 1.39 |
| The exact gather too | 0.89 | 0.11–1.70 | 1.34 | 0.91 | 0.07–2.40 | 1.32 |
| The table's open part alone too | 0.94 | 0.23–1.89 | 1.27 | 0.91 | 0.07–2.40 | 1.32 |
| Ideal L2 of the tracer's light | 0.93 | 0.25–1.66 | 1.33 | 1.00 | 0.64–1.70 | 1.05 |

By direction, before → after, at 0.15, 0.45, 0.75 and 1.05 m:

| Direction | 0.15 m | 0.45 m | 0.75 m | 1.05 m |
|---|---|---|---|---|
| Up | 1.15 → 1.15 | 1.23 → 1.23 | 1.23 → 1.24 | 1.27 → 1.29 |
| Down | 0.15 → 0.89 | 0.24 → 0.60 | 0.31 → 0.44 | 0.36 → 0.70 |
| Toward the hall | 0.79 → 0.84 | 0.74 → 0.77 | 0.81 → 0.82 | 0.72 → 0.83 |
| Toward the window | 0.97 → 1.00 | 1.08 → 1.10 | 1.12 → 1.13 | 1.10 → 1.14 |
| Along the wall, +x | 0.77 → 0.80 | 0.78 → 0.81 | 0.83 → 0.85 | 0.81 → 0.90 |
| Along the wall, -x | 0.85 → 0.91 | 0.95 → 0.99 | 0.97 → 1.00 | 0.90 → 0.99 |

The near-floor hunt, probe by probe and source by source (scratch `pts bakesrc`: the
bake's own sources at seven probes, each an exact clamped-cosine sum toward six axes,
against the tracer's light split by the first surface each ray meets):

- The floor at 0.15 m as point cells gave the light down 0.43 to 1.96 of the tracer's from
  probe to probe; the exact gather fixes it (down at 0.15 m 0.15 → 0.89 with the rug and
  the near limit).
- The table's sun patch was hidden from the probes over it (down at 1.05 m over the
  table: tracer 0.0077, bake 0.0002); fixed in the exact gather.
- The bake's sky at the probes is 1.6 to 2.4 times the tracer's (lace removed in both): its
  sky samples see the glazing flat, as its sun did before step 3. Through L2 the excess
  from above also takes light from below (the atlas's down 0.0012 where its sources sum to
  0.0029 and the tracer 0.0030). Traced through the casements' members (a 17 × 17 table of
  slopes per sky sample, made once, under a millisecond) it is 0.8 to 1.0 of the tracer's
  with the inner casement only and far below with both: the tracer stops a sky ray at the
  inner pane, Cycles doesn't. Not made; kept in `s4/sky-members-and-experiments.diff`.
- The tracer's lace glows with half the sky behind every point, also before the wall;
  traced from what reaches its back (as Cycles' translucent lace) its glow at the probes
  falls 2 to 3 times, to the bake's. Against that tracer: The points before 0.87 (0.04–1.72), after all the changes 1.23 (0.37–1.92, error factor 1.38); the probes 1.01 → 1.21.
- Not found: toward the hall at 0.15 m the hall wall's sun patches reach the probes at 0.7
  of the tracer, at 0.75 m at 1.2.

The two smaller causes: the top's underside's 0.42 was the table mesh's own occlusion (0.5
on the underside) times the bake's open part (0.84: the chairs' seats within the reach take
0.16, the base 0.01; not the floor or the reach); with the bake alone the point goes 0.11 →
0.23 of the tracer, the edge's undersides 0.48 → 0.62 and 0.62 → 0.80. The foot's top
(1.70, 1.89 with the bake alone): the bake already hides the top's view from the probes
under it; the tracer's light at its lookup point with the top is 1.29, so what is left is
the trilinear lookup mixing in probes outside the top's disc. The props' reach at 1 m: the
foot 1.89 → 1.35, the seats' front rolls 1.11 → 0.61 and 0.89 → 0.75, all 22 points 0.94
(error factor 1.27) → 0.87 (1.28). Not made.

The joint of the column and the top (`--plan-eye 4.9,4.9,0.45 --plan-at 4.254,5.83,0.62
--fov 40`, the tracer's view `joint`): linear luminance of the column's top over the
underside beside it, the tuner 1.39 before, 0.16 after; the tracer, one albedo for the
table, 0.89 to 0.98. With the base-wood check's light ratio of about 7 before, the tuner's
albedo ratio is about 0.2, so its light's ratio after is about 0.8.

The sun's disc: `shell_sun.x` 0.0055 is how fast half the tuner's penumbra widens behind an
edge, beside a constant 3 cm; the sun's disc gives 0.00465. Across the door patch's left
edge (10% to 90%): the tuner 8.9 px, the tracer with a point sun 1.8 px, with the disc 10.7.

The exposure stays 3.08: the floor patches' brightest 1% and 5% moved under 0.1%.

Cost: the bake 103 to 104 ms before, 118 to 121 after on the Mac (the half grid 29 → 45 ms,
the split cells); per pixel one compare in `| State | 22 points | Range | Error factor | 864 probe values (144 × 6) | Range | Error factor |
|---|---|---|---|---|---|---|
| Before (step 3 as made) | 0.68 | 0.03–1.69 | 1.72 | 0.76 | 0.02–2.38 | 1.55 |
| The rug in the bake | 0.77 | 0.07–1.70 | 1.53 | 0.81 | 0.07–2.40 | 1.45 |
| The near limit 0.02 m² too | 0.87 | 0.09–1.70 | 1.41 | 0.87 | 0.07–4.65 | 1.39 |
| The exact gather too | 0.89 | 0.11–1.70 | 1.34 | 0.91 | 0.07–2.40 | 1.32 |
| The table's open part alone too | 0.94 | 0.23–1.89 | 1.27 | 0.91 | 0.07–2.40 | 1.32 |
| Ideal L2 of the tracer's light | 0.93 | 0.25–1.66 | 1.33 | 1.00 | 0.64–1.70 | 1.05 |_FRAG` with `PROPS_LIGHT`.

## Acceptance criteria

- [x] The CPU tracer in `tools/` (the room's triangles from `model3d`, physical inputs, a
      points mode and a picture mode), its numbers agreeing with Cycles' as in task 120
      (2026-11-26: `tools/path_trace.goose`; its points equal the scratch tracer's
      `points-phys.txt` to the last digit or two, its views' means within 0.9 to 1.1 of the
      scratch's; 22 points × 4,096 paths in 0.6 s, a 480 × 270 picture at 64 paths in 10 s
      on the Mac's 10 threads. The old gains' mode is left out: it needs the tree's sun
      factors from the tuner's GPU, and the tuner itself now shows the old light's error)
- [ ] The bounce's gain, caps and grey balance gone; exposure and white balance set as a
      camera
- [ ] The direction-blind fills gone, or each kept with its measured need
- [ ] The probes' light toward the room side and down within a stated error of the
      reference (L2, or gathering with visibility), the props in the probes' view, the
      floor in the props' bake
- [ ] Task 120's per-pixel light the default on desktops, the chairs' hand-made occlusion
      removed; the sliders for the chairs' cloth and wood only if still needed
- [ ] Each term the review listed kept, fitted or removed, with the reference's numbers
- [ ] Shots of the tuner's views against Cycles' on a results page in `build/notes/`, the
      user's pick before the old light's options are removed
- [ ] The low-end Android tier (a colour per vertex, task 120) designed as a define, tuned
      after the desktop look is settled; times with `tools/perf/mac_room_bench.py`
- [ ] The decision in `docs/decisions/rendering.md`, `docs/architecture/rendering.md`
      updated in the same commit
