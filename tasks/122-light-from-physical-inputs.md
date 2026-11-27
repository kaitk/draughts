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

## Fixes: the stove, the lace's cone, the sills (2026-11-26)

Under `--light physical` only; without it the close, low, room and reference views are
byte-identical to `build/perf/light_tune-before122` with `--base-wood today` (the reference
view a level at most, no pixel over 8). Results page: `build/notes/stove-and-arc/index.html`
(its first section); scratch `build/review122/fixes/`. Measured as the diagnosis did: the HDR
target through `--tone-probe 16`, 5 × 5 pixel means, the stove view at 1536 × 1024.

- The stove stops the sun's rays in the bake (`room_light::stove_stops_sun`,
  `meets_stove`: its body as three planes and its top). At today's sun 13% of the sun into
  the room went through it (6.58, 4.60, 3.23 of 49.1, 34.3, 24.1), 26% at 8° up. The stove's
  lower front against the tracer (× 4.2, the calibration at C):

| Point | Before | After | Tracer × 4.2 |
|---|---|---|---|
| A, front, lower | 0.0078 (G/R 0.40) | 0.0191 (0.56) | 0.0166 (0.54) |
| B, cut, lower | 0.0108 (0.13) | 0.0452 (0.65) | 0.044 (0.65) |
| D, front, mid | 0.0119 (0.43) | 0.0206 (0.61) | 0.022 (0.59) |
| C, front, upper | 0.0217 (0.62) | 0.0213 (0.64) | 0.022 (0.60) |

  No magenta is left: over the stove's lower body G/R under 0.4 in 10,191 pixels before, 0
  after (the 1,159 left are the oak beside it); the reference view's right edge 36 magenta
  pixels before, 0 after. So the second step (probes inside the stove taking a neighbour's
  light) wasn't needed.
- The lace's forward cone off (`render3d::window_view.y = 0` in the tuner's
  `physical_light`): at the old sun the shot is byte-identical to the build before with
  `--lace-scatter 0`; over the band (76,778 pixels where the cone gave half the light or
  more) the median luminance 0.0128 → 0.0024, 2.91 → 0.55 of the tracer (× 4.7); the
  diagnosis's 23,402 pixels, 3.44 → 0.49.
- The sills' yellow front band: the probes' light, from behind the face. The sill's nose
  stands 8 cm out of the window wall (`SILL_NOSE`), so its front reads the probes 0.45 m
  before the wall as well as those 0.15 m before it; only the latter were settled toward
  the room. Those 0.45 m out see the windows' sky from behind the face: L0 (86.5, 74.2,
  86.5) and L1·n (−69.7, −68.9, −90.8) × 10⁻³, blue below zero and clamped. With
  `room_light::sill_settle` the window wall's settle reaches 0.8 m (`WALL_NEAR`, the half
  grid's row 0.75 m out with it). The light on the front (× 10⁻³, the HDR target's light
  term): before 15.5, 4.05, 0 (G/R 0.26, B/R 0), after 25.1, 12.6, 6.8 (0.50, 0.27); the
  tracer's light there G/R 0.45, B/R 0.22. Over the wainscot below it: tracer 1.55, after
  0.92, before 0.65 (red) to 0.12 (blue). The shot changes only on the sills' fronts and
  the lace's tie-backs (3,939 pixels over 8 levels).
- Other solids the bake's sun passes through (a scratch count of the sun into the room
  that crosses each, at seven places and three heights): the bookcases' sides 3% at 8° up,
  0 otherwise; the sills' noses 6 to 10% at 18° up and higher (the rays land on the
  wainscot below in place of the nose's top), 0 at today's sun. The shutters are already in
  the reveals' test; the doors' frames, a few centimetres out, weren't counted. Not fixed:
  no fault measured from them.

Cost: the bake's ray test a few planes per ray, the settle no more work; nothing per frame.

## The seventh step, varnish and the sun's colour (2026-11-26)

Under `--light physical` only; without it the reference view and the close, low, room and
menu views are byte-identical to the build before (with `--base-wood today`; the reference
view within one level in a few pixels, none over 8). Results page:
`build/notes/light-physical/index.html#step7`; scratch `build/review122/s7/`. Measured with
`--volumes off`, autumn's grade as made; the regions' chroma as the xy distance from D65
("sat"), in the light before the camera and in the graded shot; Cycles' gloss as its light
less its diffuse passes.

What greyed the table, the wainscot and the paper's sun patch, before the change:

| Region | Ours: sun's specular / environment | Cycles: gloss | Light sat, ours / Cycles | Shot sat, ours / reference |
|---|---|---|---|---|
| Wallpaper in the sun | 44% (the broad sheen 34%) / 1% | 37% (sun 0%) | 0.093 / 0.106 | 0.111 / 0.175 |
| Table top in the sun (close) | 23% / 2% | 10% (sun 2%) | 0.115 / 0.128 | 0.062 / – |
| Table top (reference view) | 6% / 2% | 25% | 0.133 / 0.123 | 0.089 / 0.142 |
| Table edge (close) | 10% / 6% | 53% | 0.119 / 0.100 | 0.105 / – |
| Wainscot in the sun | 14% / 0% | (no coat then) | 0.121 / 0.146 | 0.092 / 0.205 |
| Wainscot in shade (far) | 0% / 7% | (no coat then) | 0.122 / 0.154 | 0.165 / 0.177 |
| Floor in the sun | 6% / 27% | 30% | 0.135 / 0.141 | 0.104 / 0.155 |

- The broad sheen (`sheen_look`, roughness 0.8 at strength 2 on the paper and the paint):
  34% of the paper's light in the sun. No such lobe is in Cycles.
- The polish's highlight widened to a window's (`coat.w` 0.35; the room's 0.06 floor on
  alpha): the sun's white over the whole lit top, 23% of its light.
- Not the environment term: too small, not too large. Both shaders put a mean albedo (0.2;
  `room_wide`'s 0.06 to 0.41) on the probes' light, which is already the light arriving from
  r's side: 2 to 9% of the light where Cycles' gloss is 10 to 53%.
- The sun at 0.6 of the key's saturation: 4425 K; the direct sun at 15 degrees, 3954 K.
- The camera: AgX with the grade takes chroma out of the sunlit regions and adds it to the
  shade (above); the reference keeps the sun saturated (0.155 to 0.205), its look.

The change (23f57593):

- The table and the chairs' wood (TABLE_FRAG's `PROPS_LIGHT`): the sun's lobe at the
  polish's own roughness widened by half the sun's angular radius (0.0023, Karis's widening
  for a disc) in place of coat.w; the environment the probes' light toward r with no albedo.
  Fresnel and the diffuse under the coat as before (f0 0.04, the wood times 1 − F).
- The panelling oak and the floor's wax (ROOM_FRAG's `PHYSICAL_COAT` on the walls' and
  floor's HDR pipelines, `render3d::physical_coat`, `--coat on|off`; ngfx's seven
  `r3d_hdr_*_coat` modules): the oak's coat over a quarter of the grain's relief, the sun's
  lobe as above, `room_wide` the light arriving as it is. The oak keeps its field's roughness
  (0.42 mean). The broad sheen off under the flag (`PHYSICAL_SHEEN`, a uniform).
- Cycles' panelling had no gloss (`oak_panels`' specular 0): now a clear coat at the oak's
  roughness on a quarter of the relief.
- Tried and taken out: the oak seeing the room's box sharp (SHARP_BOX's `room_seen`) showed
  crisp images of the floor's sun patches in the panels (`box_sun` isn't blurred by the
  lobe); Cycles at the oak's roughness has only a soft sheen.

After, both with the coat:

| Region | Ours: specular + environment | Cycles: gloss | Light sat, ours / Cycles | Shot sat, before → after |
|---|---|---|---|---|
| Wallpaper in the sun | 15% + 8% | 37% | 0.134 / 0.132 | 0.111 → 0.146 |
| Table top in the sun (close) | 0% + 10% | 10% | 0.140 / 0.149 | 0.062 → 0.078 |
| Table top (reference view) | 0% + 10% | 26% | 0.149 / 0.144 | 0.089 → 0.097 |
| Table edge (close) | 0% + 25% | 54% | 0.117 / 0.125 | 0.105 → 0.110 |
| Wainscot in the sun | 13% + 3% | 42% | 0.146 / 0.141 | 0.092 → 0.103 |
| Wainscot in shade (far, close, low) | 38%, 38%, 41% | 41%, 53%, 57% | 0.104 / 0.133 (far) | 0.165 → 0.142 (far) |
| Floor in the sun | 6% + 26% | 30% | 0.158 / 0.162 | 0.104 → 0.116 |
| Floor in shade | 9% | 20% | 0.149 / 0.159 | 0.165 → 0.170 |

The sunlit regions' chroma lands on Cycles' within 0.01. The varnish greys the wainscot in
shade in Cycles as in ours (Cycles' far wainscot 0.154 without the coat, 0.133 with): at
0.42 its reflection of the windows is a broad sheen. Cycles with the oak's coat at 0.2 (the
table's polish) gathers it into the windows' images and leaves the panels deeper: a material
choice; the app would then need the windows sharp in the oak's and the table's reflections
(an analytic window term, about 40 ALU, no reads; the band of the window in Cycles' table
top is what the probes can't hold).

The wallpaper (gold over ground by luminance, the gold's sat): the albedo 1.65 (0.077); in
the sun our light 1.50 (0.100) before, 1.64 (0.140) after, Cycles 1.54 (0.136), the shot
1.36 → 1.49 (0.112 → 0.146); in shade our light 1.52 → 1.39, Cycles 1.33; the reference 5.00
in its sun, 4.33 in shade. The gold is a dielectric (roughness 0.52 against the ground's
0.66), not a metal; the mask's contrast is the same in the sun and in shade (1.65, 1.56), so
no mip blurs it: the blur in the sun was the patch's soft edges and the sheen. The
reference's print is a material choice (a gold of 4 to 5 times the ground's albedo).

The sun's colour by its height (`rooms::sun_color_at`, `tools/sun_color.py`): a 5778 K sun
through a clear sky (Rayleigh, Angstrom's 0.08 and 1.3, the ozone's Chappuis band) at Kasten
and Young's air mass, CIE 1931 to Rec.709, at the key's luminance (the meter moved 0.01 EV):
2160 K at 3 degrees, 3500 K at 10, 3950 K at 15, 4610 K at 30, 5110 K overhead. The tuner's
`--sun-color height|key`, the export's and the tracer's `room_scene::light_of` (Cycles' sun
26.4, 18.4, 13.0 → 27.3, 18.6, 9.0). The floor's sun in the light 3800 → 3540 K (Cycles 3960 →
3650 K), in the shot 4780 → 4630 K (the reference 3210 K: AgX turns bright patches toward
white). The lit door is about 1250 K cooler than Cycles' before and after: not the sun, not
looked into.

The grade: autumn's as made against the reference's regions, error 3.99 before, 4.27 after;
refitted from it EV −3.81, white 1.3, 1, 0.63, power 0.8, saturation 1.0, error 4.25: kept
as made. Stops off the reference: the wallpaper −0.58 → −0.16, the wainscot −0.60 → −0.09,
the floor's sun +0.61 → +0.60, the lit door +0.27 → +0.25; the wainscot's xy 0.467, 0.389 →
0.443, 0.385 (the reference 0.482, 0.383).

The rug matches its source (the albedo's xy 0.403, 0.361, `rug.png` 0.402, 0.363, Cycles
0.402, 0.362). Its bluest tenth, B/R: the source 1.00, our albedo 0.78, our light through AgX
with a neutral white 0.57, with autumn's (blue 0.6) 0.25, Cycles without the grade 0.32, the
reference 0.36. The room's warm light takes about a quarter of the navy's blue, the grade's
white half of the rest. Unchanged.

Cost per pixel: the table an add in place of a multiply and a max, a multiply less; the
walls about 12 ALU more on the oak, about 5 fewer in `room_wide`; the floor about 5 fewer; no
texture reads. Timed (`mac_room_bench.py`, table and corner at 3840 × 2160, two batches):
table −1.2 ms, corner −2.1 ms on 23 to 25 ms with a spread of ±5 to 8 ms between rounds
(something else loaded the GPU; the physical views were 15 to 16 ms in the fourth step), so
no difference found. Phones (designed): the same define on the phone tier's walls and floor
costs nothing more; the table's environment there from the props' vertex colour
(`PROPS_VERTEX`).

## Step 7 redone: the wallpaper and the table's sun (2026-11-26)

The user's verdict on step 7: the wallpaper "super muddy and unreadable", its print to look
gold on a ground much bluer than ours, as the reference at 300% shows; the wood muddy; the
table's colours wrong. Judged now against the reference's 300% crops (plausible parts) and an
independent look, not Cycles, whose materials are copied from the app. Under `--light
physical` only; without it the close, low, room and menu views are byte-identical to the
step-7 build, the reference view within a level (none over 8). Results page:
`build/notes/light-physical/index.html#step8`; scratch `build/review122/s8/`
(`paperstat.py`, `fitpaper.py`, `fittable.py`).

- The wallpaper's print a metal over a matt ground (ROOM_FRAG's paper under `PHYSICAL_COAT`,
  `Shell.tile.w`; `render3d::paper_metal`, `paper_ground`, `paper_gold`; the tuner's
  `--paper-metal`, `--paper-ground`, `--paper-gold`): the mask's gold is bronze powder, its
  colour f0, roughness 0.42; the ground takes no sun lobe and no reflection (step 7's coat
  laid the room's light at F 0.04 over a ground of albedo 0.05, a veil as bright as a
  sixth of it). Both colours fitted through the light and autumn's grade (the grade gives
  our shot within 0.65 levels) to the reference's print and ground in two boxes: ground
  sRGB 0.226, 0.207, 0.261 (from 0.259, 0.22, 0.192), gold 0.686, 0.612, 0.43.
- Measured in the reference view (two boxes of paper in shade; the print over the ground
  by luminance, and the local contrast, luminance p90/p10 over a 31 px mean):

| | Print / ground | Local contrast | Ground (sRGB levels) | Print |
|---|---|---|---|---|
| Reference | 4.33, 3.16 | 2.32, 2.46 | 32 17 6, 34 18 7 | 70 43 22, 65 38 17 |
| Step 7 | 3.02, 1.76 | 1.39, 1.45 | 35 20 7, 37 19 4 | 63 41 22, 50 28 10 |
| Now | 4.20, 3.33 | 3.05, 3.20 | 36 21 10, 31 14 3 | 79 50 24, 60 33 13 |

  The reference's ground is not blue in the picture (B/R 0.13 to 0.15, its print 0.11):
  "bluer" is against the print, where ours had a ground more orange than the print (B/R 0.05
  against 0.10). To read as the reference's warm near-black under a 3500 K sun and autumn's
  blue gain 0.6, the albedo itself must be bluish. The independent look: the mud gone, the
  contrast the reference's; the print a little dusty (its blue taken down a quarter after);
  our motifs about 1.5 times the reference's and denser (the tile is 0.9 m; a real paper's
  is 0.65 m, `--wallpaper-tile`), not changed. Not done: the bake's `PAPER_ALBEDO` is still
  the old mean (the paper's share of the bounce is small).
- The table: the handover's diagnosis (the top's albedo several times too light) doesn't hold.
  Our albedo on the top (the diagnosis patch's view 10) is 0.093, 0.052, 0.033, Cycles'
  diffuse colour there 0.085, 0.050, 0.034. On a common scale (the floor in shade), the
  top's light was 1.60 times Cycles' (the floor's sun 1.08, the lit door 0.81), and in it
  the sun's diffuse 1.53 times: our polish took its Fresnel off the view's side only, where
  Cycles' coat also reflects its share of the sun before it reaches the wood (a quarter for
  a 15° sun on a level top). TABLE_FRAG under `PROPS_LIGHT` now takes it off: the top 1.29
  times Cycles'. The polish's reflection is not the top's paleness (with the polish off the
  top's light moves −2% to −17%).
- What still separates the top from the reference is the reference's light: its top, lit by
  the same 15° sun at the same angle as its floor, is about 2.7 stops under its floor's sun,
  dappled; in Cycles and ours it is in full sun (95% direct). AgX then takes our lit wood
  toward the shoulder (xy 0.381, 0.373 against the reference's 0.443, 0.380), the open
  "sun patches kept warm" grade question. A darker, more saturated wood
  (`--table-wood 0.34,0.2,0.13,0.1`) is on the page as a variant: more saturated, but
  redder than the reference's orange-brown.
- New tuner flags for the fits: `--table-wood`, `--table-coat` (tables::Table's wood and
  coat).

Cost: the paper a multiply of the specular and of the Fresnel a pixel on the walls; the table
a Fresnel and a multiply-add a pixel under `PROPS_LIGHT`. Not timed (no measurable size).

## Step 7b: the wallpaper close up (2026-11-26)

The user: the print loses its depth close up. Worked from ChatGPT's material specification (a
bronze-powder print on a matt distemper paper, its grain and print relief, roughness 0.42 to
0.65) and the reference `Victorian Ochre Floral Wallpaper.png` at 300% (its material only; our
mask's motifs and tile kept). Under `--light physical` only, the tuner's `--paper-detail
LINES,POWDER,GRAIN,RELIEF` (`render3d::paper_detail`, the block's old unused `paint_steps`; on
as 1,1,1,1; 0,0,0,0 is c988f308's picture exactly). Results page
`build/notes/wallpaper-close/index.html`; scratch `build/review122/wp/`.

- ROOM_FRAG's `paper_close`: the print's outline cut sharp at the mask's 0.4 over a pixel; its own
  lines deepened about the print's mean away from the outline; the metal's tone a little uneven,
  tarnished browner in low patches, burnished to small pale flecks; the ground's albedo mottled
  and grained; a bump of the docx's heights (print 40 µm, grain 20 µm). All of it fades out as a
  mask texel (0.88 mm) falls under a pixel, so the room's distance keeps the flat print.
- The grain: the mask's G (`render3d::paper_grain`, three tileable value noises), RG8 instead of
  R8 only with the flag (+1.4 MB), read at the mask's scale and six times finer.
- Tried and dropped: the docx's ochre binder between the powder (in shade a diffuse binder
  outshines a metal reflecting the dark room: the close print turned orange and brighter than
  from afar), the ground showing through the powder in hollows and a strong mottle on the print
  (read as dirt and sponge in the independent look), the relief at 5× (embossed outlines).

| Shade, 0.8 m | Print (sRGB) | Ground | Print / ground | Print CV | Ground CV |
|---|---|---|---|---|---|
| Reference (flat, unlit) | 112 79 47 | 53 51 47 | 1.62 | 0.137 | 0.112 |
| Before | 113 72 33 | 50 32 24 | 2.23 | 0.076 | 0.048 |
| After | 113 72 33 | 50 32 24 | 2.23 | 0.123 | 0.070 |

At 0.45 m the same: the means within a level, the print's variation 0.076 to 0.114. The
reference view under `--light physical` within a level of c988f308 at 1536 × 1024 (none over
8), 4 levels at 3840 × 2560 (none over 8). Without the flag the close, low, room, menu and
reference views and the three close views are within a level of c988f308 (none over 8). Open:
the reference's depth is mostly its dark veins and centres, which our mask hardly has (a new
mask with the same motifs would be needed); short fibres in the ground's grain. Cost: not
timed (three taps of one texture and some arithmetic on the walls' pixels near enough).

## Step 7c: the wallpaper engraved (2026-11-27)

Step 7b's open point: the reference's depth close up is mostly engraved lines inside the
motifs, which our mask hardly has. The user: try redrawing the flowers, shown on the wall
before signing them off for the app. A new mask with the same motifs, layout and tile, in the
light tuner only: `--paper-mask today|engraved` (`render3d::paper_png`, read from
`design/materials/wallpaper_engraved.png`; today the default). Made by
`tools/materials/wallpaper_engrave.py` from the app's mask: midribs from the print's skeleton
(its serrations blurred away first, only where the print is a leaf's width, so stems stay
solid), side veins off them slanted to the tip, and the mask's own soft lines (the petals'
partings, the cups) made sharp and dark, the only lines in the flower heads (the print's
densest parts). The print between the lines is brightened to keep its mean over 4 texels.
Results page `build/notes/wallpaper-engraved/index.html`; scratch `build/review122/eng/`.

- Tried and dropped: lines from a ridge filter (cracks), hatching by a line integral of noise
  (dirt), a dark eye with dots and petal rays from each head's middle (the heads are three-
  quarter views with no single eye; the eye landed off the cup and the rays wandered).
- 0.8 m in shade: the print's CV 0.089 to 0.143 (the close-up reference 0.137), its mean and
  the ground unchanged; 2 m: 0.110 to 0.155, the print within 2 levels. The reference view: the
  frame's mean within 0.03 levels, the room view's within 0.04; the print's edge contrast in
  step 7's boxes 0.253, 0.270 to 0.245, 0.265 (the reference 0.256, 0.242), the local contrast
  2.57, 3.20 to 2.50, 3.14: the lines average out from afar.
- Without the flag or with `today`, the default light and `--light physical` match a build of
  164afb1a byte for byte (one default-light run differed by a level in 3 pixels, run-to-run).
- Size: the PNG 613 KB against 593 KB; the texture's size and format on the GPU unchanged.
- Open: some veins wiry or stubby where a hand would draw a smooth curve; narrow leaves get
  none; no dotted eyes. The user's call whether the app takes it (it would replace
  `wallpaper_mask.png`).

## The woods' toggle: ours, the docx's finish, the picks (2026-11-27)

The light tuner's `--woods WAY|WAINSCOT,TABLE,FLOOR` and the Wainscot section's three rows, under
`--light physical`, live: `today` as made; `ours`, our maps stained to the docx's anchors by
luminance (each map's 5th to 95th percentile, as `scene.py`'s `finished_wood`) with the base's
roughness in the docx's range and the docx's coat as a second lobe over the base's
(`render3d::Wood`, ROOM_FRAG's `wood_oak` and `wood_floor`, TABLE_FRAG's `wood_finish`); `picks`,
oak_veneer_01, sapele_veneer and herringbone_parquet read at run time from
`build/wood-candidates/` (`tools/wood_pictures.goose`, `src/native/tuner_jpeg.c`; ours where
they aren't there) under the same finish, their normal maps scaled to our fields' mean slope;
`tuned`, the floor's herringbone tuned toward the parquet (`surfaces::TUNED_FLOOR_OAK`,
`TUNED_PLANK`, `TUNED_PLANKS`): planks 3.5 cm by 28 cm (from 7 by 42; the parquet's 3 to 3.8 by
26 to 30 at its 3.4 m tile), their tones 0.32 (0.2) and warmth ×2.5, rings 2 mm (3), pores 0.9
(0.6), the trees' tones 0.15 (0.1), the stain's range 0.024 to 0.080 (0.029 to 0.073). The floor
in shade straight down, plank-scale variation, grain, dark tail: ours 0.189, 0.153, 0.600; the
parquet 0.236, 0.110, 0.704; tuned 0.220, 0.167, 0.640. Results page
`build/notes/wood-in-app/index.html`; scratch `build/wood-app/`.

- Without `--light physical` the reference, close, low, room and menu views are within a level of
  the build before (2 pixels, none over 8); with it and `--woods today` the reference and close
  views are byte-identical.
- Against Cycles, ours over today on the wainscot ×1.42 in the app, ×1.86 in Cycles: the app
  keeps the panels' own tone and grime after the stain, `finished_wood` drops them.
- Time (`mac_room_bench.py`, 3840 × 2160, physical): the down view 12.7 ms today, 14.3 ms with
  picks or tuned (the floor's coat lobe and the box's tap under the mirror); the table view's
  rounds drift more than any difference.

## The lace's room side and the stove in the sun (2026-11-27)

The user: the curtains more like the reference, not as bright; the stove's sunlit tiles near
white. Under `--light physical` only; without it the reference and room views are
byte-identical to the build before. Measured at the reference view with the weaker autumn sun
and the season's grade; results page `build/notes/curtains-stove/index.html`, scratch
`build/review122/lace/`.

- The lace's room side took the old fill (the harmonics and the room's even bounce at full,
  22 times the probes' light there). Now `--lace-fill probes` (the default; `old` the picture
  before, within a level): the probes' light as `baked_light` reads it, computed on the CPU
  after each bake (`render3d::probes_on_lace`, the block's `physical`): toward the room half a
  cell out, plus the light on its back over the piers toward the window, as the tracer's
  thread takes both sides; the folds' share at 1 (not 1.5); `--lace-shade-fill` no longer
  applies. In light over the wallpaper beside it: in shade 61.9 before, 2.8 with the room
  side alone, the tracer 7.6 (its lace a sheet 72% open, ours about 42% thread).
- Display-linear Y, reference / before / after: lace lit 0.304 / 0.662 / 0.512, in shade
  0.161 / 0.419 / 0.081, the far window's 0.291 / 0.646 / 0.395. The shade now half the
  reference's: what is left is the probes' shortfall near the window and task 124's model.
- The stove: its sunlit tiles 0.981 against the reference's 0.838; in light 3.2 times the lit
  door's (the face square to the low sun), which AgX takes to white. Albedo hardly moves it
  (`--stove-glaze 0.45`: 0.904), the coat's highlight points back at the windows: the sun's
  angle, not the glaze. `--stove-glaze K` stays at 1 for trying a creamier glaze.
- `tools/room_scene.goose` has the reference view, for `path_trace picture reference`.

## Cycles on the app's sun, and the latest look (2026-11-27)

Cycles is the reference look from here on, so it now takes what the app takes under `--light physical`. Results page:
`build/notes/latest-look/index.html`; scratch `build/latest-look/`.

- The sun: `room_scene::sun_take` (autumn's `PHYSICAL_SUN`, 0.25 and colour as at 8 degrees) for the exporter
  (`--sun-take`) and the path tracer (`--sun-clear` the old). Cycles' diffuse direct on the sunlit floor is 0.95 of what
  the app's key gives there (the panes' Fresnel at the slant), its colour equal (R/G 1.839 against 1.840).
- `scene.py`: `--paper physical` with the engraved mask by default; a finished wood's base specular 0 by default;
  `--wood ours|picks` (`tools/blender/woods/`): the floor's wax v4's and its stain ×0.75 in linear light, one step
  darker (sun patches 228 182 136 → 224 177 130 against the reference's 216 152 106; the shade 59 27 11 → 50 24 8
  against 67 35 15). The app's `--woods` take the same floor, and the wood matt under its coat (the base's lobe was
  the veil Cycles' s1 took off); the default light unchanged (a level in 3 pixels, run to run).
- Cycles metered at 8.15 for the weaker sun (its frame's log-average as at 6.91 under the clear sun: −1.24 stops); the
  app's meter rose 0.81.
- Why the app's picks were less orange on the woods page: Cycles was graded a stop over the user's pick and had the
  clear sun, whose bounce makes most of the shade's light; with both on the hazy sun what is left is the app's light in
  shade, bluer (B/R before the grade 0.39 against 0.23 on the wainscot): against Cycles, measured by the sun at full and
  a quarter, its sun's bounce 0.5 to 0.8 times and its sky 0.8 to 1.75 times. The probes' criterion below.

## The indirect light: the stove's sun, tried and dropped (2026-11-27)

The handover's largest error: the app's shade bluer than Cycles' (wainscot B/R 0.39 against
0.23). Measured with the scratch tracer (`build/indirect/pts/`, modes `room`: the reference
view's shell points on a 96 × 64 grid, the tuner's dumped atlas as `baked_light` reads it
against the tracer at the surface, rgb; `allprobes`: every grid probe per axis; `atlascmp`: the
tuner's atlas against pts's own bake), sky and sun split by baking with `--key 30,18,0,0.85`
(no sun) and `--baked 0,1,0,0` (no sky). Results page `build/notes/indirect-light/`.

- In shade the atlas's light was 0.7 to 0.95 of the tracer's, its blue 1.0 to 1.25 and its red
  0.6 to 0.85: the sky's part 1.1 to 1.4 times the tracer's, the sun's bounce 0.25 to 0.6.
- Not the probes' places: the tracer's own light at the probes, mixed as the lookup mixes
  them, gives the surfaces' sun bounce 0.9 to 1.25. The probes' values are short: every probe,
  every height and axis, holds 0.52 of the tracer's sun bounce.
- Two causes, each measured to the digit against pts's bake: the tree outside (`light_tree`,
  the tuner's bake only; the tracer and Cycles have none) 0.85, so compare the app with Cycles
  under `--tree 0,11,70,1`; and `stove_stops_sun`, which drops every ray meeting the stove and
  throws nothing back off its sunlit tiles, 0.77.
- Tried (f56d4987): the stove's sunlit faces as sun patches of their own. The probes' sun bounce
  0.52 → 0.88, the light on the far wall's paper B/R 0.64 → 0.50 (tracer 0.49); but purple
  blotches round the stove's sunlit patches (the user, the same day): the probes beside it 0.016
  → 0.36, their L1 lobe 1.7 times the constant, so a face turned from the patches read red
  −0.14, green −0.09, blue −0.014, clamped. Dropped and removed: a scheme for this stove's four
  faces alone, and a new stove design replaces this one (the handover, 2026-11-27).
- An independent review of the bake's stove code: the sun patches are points at their bins' mean
  (`gather_near` caps them at 0.14 m), about 2 times too bright at a probe 0.15 m over a 0.25 m
  floor bin, for every patch, not the stove's alone; the purple came from prop faces having no
  `settle` (the room's planes are settled, so their negative lobes point into the wall) and
  from probes inside the stove's body, which `probe_place` doesn't wall. Kept: `stove_stops_sun`
  (without it the sun lands inside the stove, the old purple stove) and `wall_albedo`'s stove
  line. With the new stove: its outline exported by `stove.goose` for `meets_stove` (the bake
  copies today's planes), probes inside solids walled, prop faces settled, patches gathered as
  areas.

Left: the sky's part 1.1 to 1.3 over on the surfaces though equal at the probes (task 122's
`srcsum`, 5.150 against 5.151): the lookup half a cell out sees more of the windows than the
surface does (the ceiling 1.27, the wainscot 1.28). Against Cycles before the camera (`--tone-probe`,
each over its sunlit door, tree off, the stove's sun on): the far wall's paper 1.07 of Cycles'
light, B/R 0.38 against 0.23, where Cycles' paper in shade is over half the print's warm metal
reflection (B/R 0.14) and its matt ground alone B/R 0.39; the wainscot 1.30, B/R 0.16 against
0.08; the lace in shade 2.26 (task 124).

## The table's polish: the room seen sharply (2026-11-27)

The user: the table washed out and over-bright against Cycles and against the old light, its
edges, base and the chairs' backs without Cycles' shine. Measured in the close view (`--tree
0,11,70,1`, the table's top in a box of 320 × 110 px, its darkest quarter the casement's shadow
band): the polish alone made the band's veil. With its strength 0 the band went 103 70 51 →
53 27 16 (sRGB; Cycles 49 21 9); in linear light the polish was 0.87 of the band's light, B/R
0.87, Cycles' coat 0.24, B/R 0.25. TABLE_FRAG under `PROPS_LIGHT` lit the polish with the
probes' light toward r, the light over the half of the room r faces, the windows' with it. On
the brightest 5% of the rim Cycles' light is 0.91 its coat's, the base's 0.46, the chairs'
backs' 0.13 to 0.33: the windows seen sharply in the curved polish.

- TABLE_FRAG's `props_seen_at` and `props_reflection` (`render3d::props_seen`, the tuner's
  `--props-seen`, on under `--light physical`): ROOM_FRAG's `room_seen` for the props, the box
  met along r, its face's surface (the wainscot, the paper's mean, the doors' paint, the ceiling,
  the floor's) lit by the props' probes there, the windows as soft rectangles of the view's light
  with their casements; taking over from the probes' light as the lobe narrows (alpha 0.45 to
  0.08). Not in it: the sun's patches on the walls, the bookcases. The box's values ride at the
  end of `PropsLightBlock`, which ngfx packs last.
- The table's wood `ours` by default (`--woods` ours,ours,tuned): the user's pick.

| Close view, sRGB | Top, shadow band | Top, sunlit | Rim, brightest 5% | Base, brightest 5% |
|---|---|---|---|---|
| Before (`--props-seen off`) | 99 64 47 | 243 206 179 | 222 161 123 | 105 65 42 |
| After | 54 23 11 | 240 209 185 | 220 158 115 | 112 76 51 |
| Cycles | 49 21 9 | 214 144 101 | 213 142 98 | 93 58 39 |

Left: the sunlit top paler and less saturated than Cycles' though its colour in linear light is
Cycles' (B/R 0.13 against 0.11): our camera exposes it brighter, AgX takes it to the shoulder
(step 7's open grade question). The chairs' wood and tapestry warmer in Cycles (the user). The
default light byte-identical (the table-window view). Cost: not timed; a box intersection, a
probe read and the windows' casement on the props' pixels.

## The floor's halo under the windows (2026-11-27)

The user: a halo on the floor along the wainscot under the windows. Measured with the scratch
tracer's `line` mode (floor points under the middle window, out from the wall's face; the
atlas as `baked_light` reads it against the tracer, tree off): within 0.13 m of the wall the
floor read 1.7 to 10 times the tracer (0.023 to 0.039 against 0.002 to 0.004), from 0.16 m
on 0.8 to 1.3. With `--niche-light off` it was gone: task 128's `niche_above_below` gave
every walled probe in a niche's column, down to the floor, the niche's light, and the floor
and the wainscot beside the wall blend toward them. Now only the niche's probe at the same
height (past the glass) or the next one up or down: the floor beside the wall 0.0023 (the
tracer 0.0023 to 0.0038); the atlas changes only in the walled probes at 0.15 and 0.45 m and
the top row, so the bottom rail's reading (the probe just under the sill) is task 128's.

Left: the wainscot under a window reads about 2 times the tracer (0.0019 against 0.0005 to
0.0012) and its panels' bevels shine in its coat (the brightest edges 2.4 times with the coat
than without; Cycles shows none): the probes 0.15 m before the wall stand past the sill's
nose and see the window the wainscot under the sill doesn't.

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
