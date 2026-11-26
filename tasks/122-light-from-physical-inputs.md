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
the split cells); per pixel one compare in `TABLE_FRAG` with `PROPS_LIGHT`.

## The fourth step, the reference's fixes (2026-11-26)

Results page: `build/notes/light-physical/index.html#step4b`; scratch `build/review122/s4b/`.

- The tracer's sky: a ray goes on past the panes (0.92 each) and the outer casement's
  frames and bars; it takes the sky only where it leaves through a window's outer opening
  (the wall's outer face, 1 cm out), as the Cycles scene's box has it, and is dark through a
  gap in the shell.
- The tracer's lace, as Cycles': a ray passes its open part (0.72) or meets its thread,
  picked at random by those shares; the thread throws `LACE_SCATTER` (0.4) of the light
  reaching either side on through it and as much back, from the sun and one traced ray to a
  side picked at random. Its glow before the wall no longer takes half the sky.

Against Cycles (`--textures off`, the GPU, 960 × 540 at 1,024 samples, 48 to 51 s a view;
the tracer 480 × 270 at 256 paths, 33 to 46 s): the light alone on the props by part and
the way each faces, the cells with 100 pixels or more, tracer over Cycles:

| View | Before: mean | Range | Error factor | After: mean | Range | Error factor |
|---|---|---|---|---|---|---|
| Close (13 cells) | 1.32 | 1.06–1.73 | 1.32 | 1.07 | 0.98–1.21 | 1.08 |
| Low (11 cells) | 1.40 | 1.06–1.84 | 1.40 | 1.03 | 0.77–1.20 | 1.10 |

The lace panels in the close view (three boxes, what the camera sees): before 3.7 to 5.3
times Cycles', after 1.00 to 1.08. At 480 × 270 Cycles' thin parts take the bright window
into their edge pixels (the chairs' wood toward -x in the low view 0.0082 there, 0.0054 at
960 × 540), so its pictures are at 960 × 540. The tracer's 22 points fall to 0.64 of before
(0.49 to 0.99); points in 0.66 s. Left between the two: the tracer's panes pass 0.92 at
every angle (Cycles' glass reflects 0.6 of Fresnel's, so less at a slant), and Cycles'
denoiser. The lace still differs between the references and the app (task 124): the bake's
`lace_lets(h)` 0.33 to 0.72 by the fullness against a sheet of 0.72; its lace cells throw
`LACE_SCATTER` of the window side's sky and sun toward the room only; the shaders' pattern
(`lace_f3`) and `ROOM_FRAG`'s own lace fill.

The bake's sky through the casements' members (`room_light::sky_through`, under
`members_traced`, so `--light physical` only): each of the 40 sky samples of a window takes
its share past both casements' members from a table of 17 × 17 line slopes (±4, bilinear;
4 × 4 lines a sample through `members_let_rect`, the sun's test), made once, and the panes'
0.8464 in place of the glazing's 0.75; in the probes' gather and in the cells' first light.
Against the fixed tracer (the step 4 method: 22 points, 144 probes × 6 axes):

| State | 22 points | Range | Error factor | 864 probe values | Range | Error factor |
|---|---|---|---|---|---|---|
| Before (step 4 as made) | 1.50 | 0.40–2.95 | 1.64 | 1.45 | 0.08–5.25 | 1.65 |
| The sky through the members | 0.74 | 0.26–1.48 | 1.45 | 0.78 | 0.04–2.34 | 1.39 |
| Ideal L2 of the tracer's light | 0.94 | 0.51–1.77 | 1.27 | 1.01 | 0.11–2.34 | 1.07 |

(Against the tracer before its fixes the same atlas was 0.94 and 0.91, the fourth step's
last row.) By direction, before → after, at 0.15, 0.45, 0.75 and 1.05 m:

| Direction | 0.15 m | 0.45 m | 0.75 m | 1.05 m |
|---|---|---|---|---|
| Up | 2.03 → 0.82 | 2.03 → 0.81 | 1.89 → 0.76 | 1.97 → 0.80 |
| Down | 1.52 → 0.79 | 1.27 → 0.78 | 0.93 → 0.66 | 0.93 → 0.70 |
| Toward the hall | 0.91 → 0.80 | 0.83 → 0.76 | 0.83 → 0.76 | 0.84 → 0.77 |
| Toward the window | 2.36 → 0.95 | 2.32 → 0.99 | 1.84 → 0.83 | 1.70 → 0.84 |
| Along the wall, +x | 1.19 → 0.67 | 1.21 → 0.66 | 1.22 → 0.64 | 1.15 → 0.65 |
| Along the wall, -x | 2.33 → 0.89 | 2.21 → 0.87 | 1.98 → 0.80 | 1.73 → 0.78 |

By source at five probes (`pts bakesrc`, 0.15 to 1.05 m): the bake's sky is now 0.84 to
1.33 of the tracer's, most 0.9 to 1.1. What is left short is the light thrown on: by the
walls' and the ceiling's cells 0.4 to 1.1 (most about half), the floor's below the probes at
0.15 m 0.2 to 0.35, the walls' sun patches 0.6 to 0.9, the lace 0.4 to 1.2 (most 0.45 to
0.85). Three bounces in place of one: 0.77 and 0.80 (error factors 1.41, 1.36), so not the
bounces' count. Not found yet.

The exposure stays 3.08: the room view's brightest floor pixels (1% and 5%) 0.6% lower.
The shots' mean light after over before: close 0.81, low 0.85, room 0.90.

Cost on the Mac (room view, three runs each): the bake 123 to 124 ms before, 129 to 134
after; the table 4.5 ms once (in the first light: 3.7 → 8.4 to 8.6 ms), the probes 63 to
64 → 67 to 70 ms (a bilinear lookup a sky sample). Nothing per frame.

## The fourth step, the bounced light (2026-11-26)

Results page: `build/notes/light-physical/index.html#step4c`; scratch `build/review122/s4c/`
(`pts` modes `srcsum`, `cellcheck`, `frames`). Under `--light physical` only; without it the
close, low and room shots are byte-identical to `build/perf/light_tune-before122`.

Each source's light summed over the 144 probes × 6 axes, bake against tracer (the tracer
split by the first surface a ray meets, the lace's open part looked through): sky 5.05 /
5.37, the lace's thread 2.43 / 2.31, the floor 0.25 / 0.40 and its sun 0.35 / 0.30, the
ceiling 0.71 / 1.00, the walls 0.37 / 0.74 and their sun 1.48 / 2.18 (the stove's tiles 0.58 /
1.02, the wainscot's and sills' ledges 0.02 / 0.30), the niches' lining 0.39 / 0.72, the
casements' members none / 0.82 (sunlit 0.31), the table's top 0.78 / 1.36; all 11.82 / 15.20.
Ruled out: the albedos, the form factors and their cap, the bounces' count, the gather from
the cells, the lace's thread. The cells' own light is 0.5 to 0.8 of the tracer's (the floor
0.63, the ceiling 0.76, the niches 0.48), from what that list lacks.

- The table's place (`room_light::table_off`, set in `render3d::bake_room_light`): the bake
  took the top round the board's middle; it lies `mesh::TABLE_Z` (0.15 m) from it. Its sun
  patch caught 0.68 of the tracer's sun, now 0.90 (the rest the lace's fullness); the
  table's sun at the probes 0.75 → 1.01 (tracer 1.31).
- The niches' probes (`room_light::niche_faces`): the half grid has no row in the niches, so
  their bounced light was the room's 0.3 m before the wall, and toward the room they held
  the sky's negative L1 lobe, clamped to 0: the casements' faces, which read them, were
  black (the fills hid it before). Now they gather the cells themselves (`gather_cells`),
  settle their light toward the room, and the lace throws its light to both sides, as the
  tracer's thread. The middle window's transom 0 → 0.051 (tracer 0.045), the frame 0.004 →
  0.024 (0.013 to 0.018), the bottom rail 0.003 → 0.013 (0.043), a shutter's front 0.129 →
  0.102 (0.101), the head 0.023 → 0.026 (0.051).

| State | 22 points | Range | Error factor | 864 probe values | Range | Error factor |
|---|---|---|---|---|---|---|
| Before (the tuner's atlas) | 0.74 | 0.26–1.48 | 1.45 | 0.78 | 0.04–2.34 | 1.39 |
| Before (`pts`'s bake, no tree) | 0.76 | 0.26–1.55 | 1.43 | 0.80 | 0.04–2.36 | 1.37 |
| The table's place (`pts`) | 0.75 | 0.20–1.61 | 1.43 | 0.80 | 0.19–2.28 | 1.36 |
| The niches' probes too (`pts`) | 0.75 | 0.20–1.62 | 1.43 | 0.80 | 0.20–2.28 | 1.36 |
| After (the tuner's atlas) | 0.74 | 0.20–1.55 | 1.46 | 0.78 | 0.20–2.27 | 1.38 |
| Ideal L2 of the tracer's light | 0.94 | 0.51–1.77 | 1.27 | 1.01 | 0.11–2.34 | 1.07 |

Left short: the casements' members have no cells (5% of the probes' light); the walls'
relief in the sun (the stove's faces, the ledges), which the planar bins can't hold; the
lace's fullness (task 124). The shots' mean after over before: close 1.02, low 1.04, room
1.02. Cost on the Mac: the bake 132 to 140 ms before, 134 to 141 after (the probes 68 to 74
→ 69 to 75 ms); nothing per frame.

## The fourth step, probe volumes (2026-11-26)

The space between a box window's two panes (0.2 m deep) takes light the grid can't hold: its
probes are 0.3 m apart and the row in the niche stands before the inner pane, so the outer
casement's frames read the room's side. Under `--light physical` only (`--volumes off` to
compare); without the flag the close, low and room shots are byte-identical to
`build/perf/light_tune-before122` (with `--base-wood today`). Results page:
`build/notes/light-physical/index.html#step4d`; scratch `build/review122/s4d/` (`pts` modes
`cavity`, `cavsrc`; `cav.py`).

The design (`src/model3d/probe_volumes.goose`, ROOM_FRAG's `PROBE_VOLUMES`):

- Storage: a fixed table of boxes (`room_light::Volume`: its plan box, probes along x, y and
  up, a fade, its block's column and row; `MAX_VOLUMES` 8). The probes go into the same
  atlas, in `VOLUME_ROWS` (10) rows after the grid's: first a row with the table (three texels
  a volume in the room's frame, written by `render3d::volume_table`), then each volume's block
  laid out as the grid's (height slices side by side, the colours one over the other), packed
  in shelves. No new texture or slot; the atlas is 390 × 88 with volumes, 390 × 78 without.
  `light_grid.w` is the count. The atlas's reads are sized by `textureSize`, so the grid's read
  is right with either height.
- The bake: after the grid, each volume's probes gather as the grid's do, with the same
  functions: `gather_cells` (the cells, split near) and the sun's patches, seen through the
  niche as niche k's probes, times what the inner casement and pane let through (0.92 × the
  members' share square on); the sky through the outer casement alone (`outer_lets`, the
  sky's table of slopes made from the outer members at the outer pane) and pane; and the
  space's own surfaces (`cavity_light`): each inner member's back in 0.25 m pieces, the lining's
  two sides, the sill and the head, lit by that sky and by the sun's rays traced from the outer
  pane past the outer members to the first inner member, lining or sill. Each probe is
  settled exactly toward the room and, on the edges, toward the lining, the sill or the head
  (as the grid's `near_faces`). Light bounced inside the space is not carried on.
- The shader: the grid's light first, then a loop over the table (counted by the uniform):
  a volume whose box holds the surface point (1 cm slack for the half floats) takes over by
  its fade (0: a hard edge, as each face of a window's space is a pane or a wall); the last
  in the table wins, so the finest go last. Its lookup is the grid's, half its own step out
  along the normal. L1 (the room's three texels a colour). L2 for the props is designed, not
  built: the props' atlas would take the same rows with its seven blocks and TABLE_FRAG's
  `grid_light` the same loop; no prop stands in a window.
- The define per tier: the desktop's HDR pipelines of the paint, sills and metals take
  `PROBE_VOLUMES` while `room_light::volumes_on` (made again when it changes, as with
  `PROPS_LIGHT`); ngfx has the same three modules (`r3d_hdr_*_volumes`). The other groups and
  tiers read the grid only.
- Later, many volumes: the loop costs two texel reads a volume a pixel; past a handful, a
  coarse index (a texture over the grid's cells naming the finest volume or brick there) makes
  it one read, and fixed-size bricks (4 × 4 × 4 probes) in an atlas let a volume be any shape.

The window volumes: 7 across the niche (0.19 m), 20 up from the sill to the lining's head
(0.125 m), one deep at the middle between the panes; 3 windows × 140 probes. Chosen by the
measure: 3 across 1.37 (0.54–2.53, error factor 1.59), 5 across 1.30 (1.55), 7 across 1.06
(1.36); 10 up in place of 20, 1.21 (1.56).

The reference: the room's mesh draws only the faces that show from the room, so each casement
member's box stands open toward the outside, and the tracer and Cycles took the space's
light as if the inner casement had no back. `room_scene::casement_backs` closes them (paint) in
`tools/path_trace.goose` and `tools/blender_export.goose` (`--backs off` as before). The 22
points move 1.03 (1.00–1.07, 32,768 paths). Against the tracer with the backs (light over pi,
luminance, without the surface's own sun; `pts cavity`):

| Point | Tracer | Before | After |
|---|---|---|---|
| Outer frame, room side, 1.2 m | 0.243 | 0.044 | 0.271 |
| Outer frame, room side, 2.0 m | 0.232 | 0.045 | 0.273 |
| Outer frame, room side, 2.8 m | 0.298 | 0.028 | 0.256 |
| Outer transom, room side | 0.449 | 0.051 | 0.474 |
| Outer bottom rail, room side | 0.472 | 0.012 | 0.630 |
| Outer sash stile, room side | 0.415 | 0.081 | 0.298 |
| Outer meeting strip, room side | 0.448 | 0.023 | 0.391 |
| Lining between the panes, left, 1.5 m | 0.137 | 0.088 | 0.343 |
| Lining, left, 2.5 m | 0.157 | 0.052 | 0.250 |
| Lining, right, 1.5 m | 0.159 | 0.080 | 0.154 |
| Sill between the panes | 0.523 | 0.074 | 0.258 |
| Inner casement's backs (four points, unseen) | 0.17–0.36 | 0.06–0.09 | 0.04–0.15 |
| Inner frame and transom, room side (unchanged) | 0.036–0.052 | 0.044–0.051 | 0.044–0.051 |

The 11 points seen from the room over the tracer: before 0.16 (0.03–0.65, error factor 6.34),
after 1.06 (0.49–2.50, 1.36). Against the tracer with the backs open (as before): before
0.36 (2.84), after 2.44 (2.53). Left: the lining reads 1.6 to 2.5 times (its probe 0.09 m in
front sees the sunlit sash backs nearer than the lining does), the sill 0.49 (no bounce inside
the space), the backs low (settled toward the room; no visible face reads them).

The 22 points and the 144 probes: unchanged (the grid's part of the atlas is the same to the
last digit with and without volumes). The shots: room view 4,471 pixels more than 8 levels
apart, stove 298, all in the windows.

A bug on the way: in 15de6719 the other groups still sized their atlas reads by the grid, so
with the taller atlas they read the wrong rows (the rainbow over the room in the reference
view, `--plan-eye 6.5,4.3,1.4 --plan-at 2.655,5.403,1.4 --fov 73`); fixed in 374362c4.

Cost on the Mac: the bake 134 to 141 ms before, 178 after (the volumes 43 to 48 ms: 420 probes
each gathering the cells; the sky's table for the outer members once, a few ms). Per pixel in
the paint's, sills' and metals' groups: two texel reads and about 12 operations a volume (3),
and six bilinear reads more inside a window's space. Timed
(`tools/perf/mac_room_bench.py`, `--light physical`, volumes off against on, 3840 × 2160, a
batch of two rounds and one of three): room −0.43 and +0.65 ms (round 2 of the first; its
first round was warming), corner +0.55 and +0.15, table +0.35 and −0.53, on 15.4 to 16.4 ms:
within the runs' spread, under 0.6 ms (4%).

## The fifth step, the camera (2026-11-26)

All under `--light physical`; without it the close, low and room shots stay byte-identical
to `build/perf/light_tune-before122` (with `--base-wood today`), the phone tier's room and
menu views within a level (none over 8). Results page:
`build/notes/light-physical/index.html#step5`; scratch `build/review122/s5/`.

- AgX, a short fit, as the one camera curve (`HDR_TONE_FRAG`'s `agx`, `--camera-toe agx`,
  now the default under the flag): Rec.709 to AgX's inset Rec.2020 in one matrix, log2 over
  0.18's −10 to +6.5 stops, a degree-8 polynomial fitted to Blender 5.3's AgX on grey, the
  2.4 power, the outset and the way back to Rec.709 in one matrix. Against Blender's AgX
  (OCIO) on the same linear picture: grey 0.51 levels mean, 1.6 at most; six Cycles views
  with textures at EV 6.79 1.19 to 1.54 levels a pixel (99th percentile 2.6 to 3.5), their
  16 regions' mean −0.14 to +1.00; the tracer's five views 1.37 to 1.66. The common
  real-time fit (Filament's) is 2.2 to 3.9. Cost: about 58 ALU operations and 9
  transcendentals a pixel in the tone pass, against today's 8 (under the shoulder) to 25
  with 3 divides; not timed.
- The exposure from a meter: the log-average luminance of the light leaving the room's
  surfaces, the bake's 1,208 cells by area, once at the bake (`render3d::meter_of`), exposed
  to 0.18 times 2 to `--camera-ev` (a slider). Chosen over a read of the picture: no pass,
  no delay, and no pumping as the eye walks. It gives 0.001646, EV 6.77 in all (35.5 times
  Frame's 3.08; the fourth step's EV 1.62). The views' own log-averages over it: close
  0.52, low 0.45, room 1.80, hall 1.37, stove 1.49, corner 1.36 (mean +0.04 stops).
- White balance against Cycles at the same EV: the tuner's R/G over Cycles' 0.84 to 1.09
  in the sun, 1.00 to 1.15 in the shade, B/G 0.77 to 1.26 and 0.82 to 1.16, no shift common
  to the views: the gains stay 1, and today's grade (1.02, 1, 0.97) is left out under AgX.
  The tuner's luminance is 0.44 to 0.72 of Cycles' in both, its pictures 10 to 16 levels
  darker on average: light, not the camera.
- The glow: at the meter's exposure today's glow (0.06 over 1, before the exposure) took
  in every sunlit surface (17% of the room view's pixels over 4 levels, today 2.4%). Under
  AgX its threshold, knee and cap are now in the picture's light (`render3d::glow_exposure`)
  and the tuner's `AGX_GLOW` is 0.006 from 16 (AgX's white), knee 8: the room view 1.7%
  over 4 levels (mean 0.47, today 0.62), the menu view 9.2% (today 7.3%; the table's
  physical sun, as with the fourth step's curve, 18.8%). The eye's veil is added over the
  exposure, as it was. No shader change for either.
- The Cycles batch (close, low, stove, hall, corner, room; textures on, 256 samples, GPU,
  960 × 540, 26 to 50 s a view) through AgX at EV 6.77, beside the tuner's and the
  tracer's: the page's views. At this EV the windows and the lace are white in all three;
  at `--camera-ev -2` the view out keeps its colour.
- Seen, not looked into: the stove's glaze, lower front, goes magenta-black in the tuner
  under the flag at these exposures (with the old shoulder too): the HDR target there has
  almost no green.

## The sixth step, the season's grade (2026-11-26)

Under `--light physical` only; without it the reference's view and the close, low, room and
menu views are byte-identical to the build before, and `--grade none` gives the fifth step's
picture byte for byte. The probe volumes are off in every shot (`--volumes off`). Results
page: `build/notes/autumn-grade/index.html`; scratch `build/review122/s6/`.

- A grade per season as data, `render3d::Grade` in `render3d::GRADES` (by `looks`' season):
  `ev`, stops over the meter (added to `--camera-ev`, so the glow's threshold follows it);
  `white`, the white balance's gains on the light; a look on AgX's curve before its 2.4
  power as Blender's AgX looks take it, `(v * slope + offset) ^ power`, then `saturation`
  round its luminance. `HDR_TONE_FRAG`'s `agx` reads them from two more vectors of
  `HdrTone`. The tuner's `--grade season|none` (season by default; P prints it). Winter,
  spring and summer are neutral, not tuned.
- Autumn: `ev` −3.6, `white` 1.3, 1, 0.6, `slope` 1, `offset` 0, `power` 0.8, `saturation` 1.
  The meter's exposure EV 6.91 → 3.31 at the reference's view.

The reference, `Autumn Light in the Manor Library.png` (ChatGPT's repaint of the fifth
step's shot at the same framing, `agents/design.md`), against ours, region by region on the
same pixels: the mean of the sRGB-decoded pixels (display-linear: the reference is a
picture, not light), its Rec.709 luminance Y and CIE xy. The door's lit and shaded parts
are the pixels over the 70th (under the 35th) percentile of their box in both pictures;
the floor's sun likewise; the rest are boxes (`regions.py`).

| Region | Reference Y | Before | After | Today's light | After, stops off |
|---|---|---|---|---|---|
| Wallpaper in shade | 0.0157 | 0.0615 | 0.0106 | 0.0064 | −0.57 |
| Wainscot | 0.0123 | 0.0440 | 0.0081 | 0.0027 | −0.60 |
| Ceiling | 0.1185 | 0.5054 | 0.1131 | 0.1530 | −0.07 |
| Floor in shade | 0.0344 | 0.0695 | 0.0120 | 0.0051 | −1.52 |
| Floor's sun | 0.3074 | 0.8797 | 0.5220 | 0.2839 | +0.76 |
| Door lit | 0.5962 | 0.9682 | 0.7422 | 0.6549 | +0.32 |
| Door in shade | 0.1291 | 0.4081 | 0.0803 | 0.1771 | −0.68 |
| Lace lit | 0.3035 | 0.8755 | 0.5336 | 0.2974 | +0.81 |
| Lace in shade | 0.1613 | 0.6996 | 0.2807 | 0.0485 | +0.80 |
| The view out | 0.3496 | 0.8420 | 0.4994 | 0.3608 | +0.51 |
| Chairs' tapestry | 0.0685 | 0.1074 | 0.0171 | 0.0548 | −2.00 |
| Rug | 0.0306 | 0.0947 | 0.0156 | 0.0143 | −0.97 |

Over the 12 regions, |stops| off the reference: before 1.50 (+0.65 to +2.12), after 0.80
(−2.00 to +0.81), today's light 0.88; xy's distance 0.051 → 0.025 (today 0.027); the whole
picture's mean |difference| 69.4 → 23.8 levels (today 26.2). The wallpaper in shade xy
0.461, 0.404 against 0.460, 0.395; the ceiling 0.436, 0.395 against 0.418, 0.383.

| Ratio (display-linear) | Reference | Before | After | Today's light |
|---|---|---|---|---|
| Door lit / in shade | 4.62 | 2.37 | 9.24 | 3.70 |
| Floor's sun / in shade | 8.94 | 12.66 | 43.38 | 55.32 |
| Lace lit / in shade | 1.88 | 1.25 | 1.90 | 6.13 |
| Ceiling / wallpaper | 7.54 | 8.21 | 10.70 | 24.02 |
| Wainscot / wallpaper | 0.78 | 0.72 | 0.77 | 0.42 |
| Floor in shade / wallpaper | 2.19 | 1.13 | 1.14 | 0.81 |
| Tapestry / wallpaper | 4.36 | 1.75 | 1.62 | 8.60 |
| Lace in shade / wallpaper | 10.27 | 11.37 | 26.56 | 7.62 |

The fit (`fit.py`, the AgX fit in numpy on the HDR target from `--tone-probe` brackets,
which gives the tuner's shot within 0.97 levels mean): log luminance and xy of 8 regions,
not the lace (its own fill, below), the ceiling (its albedo) or the view out. Exposure and
white balance alone: EV −1.56, gains 1.06, 1, 1.0, error 5.85 (neutral 9.22); with the look
(power 0.8 to 1.35 and saturation 0.8 to 1.4, Blender's looks' range: Golden's power 0.8,
Punchy's 1.35 and 1.4; the gains held to red 0.9 to 1.3, blue 0.6 to 1.0): EV −3.6, gains 1.3,
1, 0.6, power 0.8, saturation 0.99, error 4.00. Slope and offset (0.9 to 1.1, ±0.01) went to
their limits for 3.23 and are left at 1 and 0. Free, the fit runs to power 0.47 and EV −6.3,
another tone curve, not a camera.

What the camera can't match, as each region's exposure that would put it on the reference
(stops over the meter, through AgX at the fitted white balance): the floor in shade −0.84,
the tapestry −0.57, the rug −1.43, the wainscot −1.47, the wallpaper −1.59, the door in shade
−2.09, the ceiling −2.74, the lace in shade −3.95, the door lit −4.05, the floor's sun −4.54,
the lace lit −4.71; 4.1 stops from end to end, which one exposure can't hold:

- Sun against shade: the sunlit regions need 2.5 to 3 stops less than the shaded ones. The
  power 0.8 takes about half of it; the rest is the light. Against Cycles (the fifth step)
  the tuner's light is 0.44 to 0.72 of Cycles' in sun and shade alike, and the probes' bounced
  light 0.5 to 0.8 of the tracer's (the fourth step): the shade's bounce is short, not the
  sun too strong. The reference's flat sun is also ChatGPT's: its floor's sun over its floor
  in shade is 8.9, Cycles' room view's floor patches over its shade some 20 or more.
- The sun patches' colour: AgX takes a bright warm patch toward white. The reference's
  floor's sun xy 0.417, 0.383 (about 3200 K), ours after 0.365, 0.368 (4400 K); its lit
  door 0.359, 0.359 (4500 K), ours 0.337, 0.348. The light: the sun at 0.6 of its key's
  saturation (`ROOM_SUN_AS_MADE.x`, the first step) lights the white door at xy 0.352, 0.371
  in the HDR target (4800 K). Full saturation would take the floor's sun from 0.352 to 0.367
  in x; the rest is AgX's desaturation of highlights, which the reference doesn't have.
- The ceiling over the wallpaper: 12.2 in the light, the albedos' luminance 0.389 over
  0.050 (7.7), so the ceiling takes 1.6 times the wallpaper's light, from the floor's sun
  patches. The reference wants about 5.5 in the light. With the grade the ceiling lands on
  the reference (−0.07 stops) and the wallpaper 0.57 under: a darker ceiling, the user's
  offer, would be an albedo of about 0.65 of today's (the material), but the wallpaper's
  shortfall is the same bounce shortfall, which would lift both.
- The floor in shade and the tapestry: 1.5 and 2.0 stops under after the grade, 0.75 and
  1.0 stops more than the wallpaper. The floor's shade in the reference holds the windows'
  reflections, ours less of them (the floor in shade over the wallpaper 2.19 against 1.14);
  the tapestry faces the room away from the window, lit by the bounce alone.

The lace (task 124's input). Its light split by term on the HDR target (scratch builds with
`ROOM_FRAG`'s lace's room-side fill, and its sky behind, removed), luminance × 1000:

| | Lace lit | Lace in shade | Wallpaper | Ceiling |
|---|---|---|---|---|
| Physical, all | 315.2 | 70.1 | 1.73 | 21.1 |
| Of it the room-side fill | 81.1 (26%) | 65.2 (93%) | | |
| Of it the sky behind (`lace_light`) | 93.1 (30%) | 0.15 (0%) | | |
| Today's light, all | 303.3 | 48.0 | 6.17 | 152.1 |
| Of it the room-side fill | 62.7 (21%) | 42.5 (89%) | | |

- The room-side fill is `(sh_eval(nf) * params.z + shade.rgb) * fill`: the old room's
  harmonics (`rooms::harmonics`, `params.z` 1 for the room in both lights) and the room's
  even bounce (`rooms::Room.bounce`, `SurfacesBlock`'s `shade`), at full in both lights; the
  first step took their like off every other surface but left them on the lace. The lace's
  other terms are the same in both lights: `--lace-shade-fill` 0.5 and `--lace-fold-ao` 1.5
  (`lace_shade`, only the share of that fill kept where neither sun nor sky reaches it and in
  the folds' valleys), the sun on its back with `LACE_GLOW` and the forward scatter. The
  bake's `lace_lets` and `LACE_SCATTER` light the room from the lace, not the lace itself;
  `lace_shadow` is its shadow on the room.
- So in the light the lace in shade is 40 times the wallpaper under `--light physical` and
  7.8 under today's (the walls kept their fills there: the wallpaper 3.6 times, the ceiling
  7.2 times brighter); without the fill it would be 2.8. The meter, set by the darker walls,
  exposes the lace 2.5 to 3 stops over the reference's, which AgX takes to white: lit 0.876
  and in shade 0.700 before the grade, 1.25 between them against the reference's 1.88.
  Today's light was better because its lace sat under the shoulder (lit 0.297, in shade
  0.049), not through a term of its own: its lit over shade is 6.1, past the reference.
- What the physical lace must give: in shade about 7.8 times the wallpaper in the light
  (the reference through AgX; today's light 7.8). Without its fill it is 2.8 (4.9 × 10⁻³),
  so the room's light on its front should add about 8.6 × 10⁻³ here, 0.13 of the fill it
  has: about what the probes give a surface there, not the old harmonics and bounce. Lit
  over shade about 2.7 in the light by the reference through AgX, and 14 in Cycles' room
  view (lit 18.9 and in shade 1.35 times its ceiling; the tracer 17.0 and 1.38; the fifth
  step's tuner 7.7 and 3.3): ours is short where lit (0.41 of Cycles' over the ceiling: the
  light through it from behind) and over in shade (2.4 times; the lowest left panel 5.4
  times: the fill). The reference is flatter than Cycles here as everywhere (sun against
  shade above). With the grade the lace's lit over shade is 1.90 (the reference 1.88), but
  the whole lace is still 0.8 stops over the reference's: the fill.

The glow, tied to the exposure (`render3d::glow_exposure`, the grade's `ev` in it), and the
sills. The share of pixels the glow raises over 4 levels (shots with and without it),
before → after: the reference's view 1.8% → 0.2% (mean 0.39 → 0.52 levels), the room view
5.2% → 0.2%, the menu view 21.9% → 7.5% (mean 4.61 → 1.45, the table's sun). The windows
keep their glow, the lace and the sunlit floor no longer take it. The sills' yellow front
band (the reference's view, x 100 to 380) isn't the glow (the same with it off): its light
in the HDR target is 2.34 : 1 : 0.07 in red, green and blue, almost no blue, as the stove's
magenta has almost no green; before 163, 116, 33, after 73, 41, 10. A light fault, not
looked into here.

Seen in the close and low views: the grade darkens them with the rest (their log-averages
are 0.52 and 0.45 of the meter's), the rug and the chairs' shade 1 to 2 stops under the
reference's in its own view already; that is the shade's bounce above, not the grade.

## Acceptance criteria

- [x] The CPU tracer in `tools/` (the room's triangles from `model3d`, physical inputs, a
      points mode and a picture mode), its numbers agreeing with Cycles' as in task 120
      (2026-11-26: `tools/path_trace.goose`; its points equal the scratch tracer's
      `points-phys.txt` to the last digit or two, its views' means within 0.9 to 1.1 of the
      scratch's; 22 points × 4,096 paths in 0.6 s, a 480 × 270 picture at 64 paths in 10 s
      on the Mac's 10 threads. The old gains' mode is left out: it needs the tree's sun
      factors from the tuner's GPU, and the tuner itself now shows the old light's error)
- [ ] The bounce's gain, caps and grey balance gone; exposure and white balance set as a
      camera (2026-11-26, the fifth step: AgX at a metered exposure under `--light physical`;
      the sixth: a grade per season, autumn's fitted to the autumn reference)
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
