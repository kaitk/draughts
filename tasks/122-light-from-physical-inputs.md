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
