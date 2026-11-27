# 124: One model of the lace's light

Status: in-progress

The lace curtains pass the sun and the sky through their pattern, and scatter some of it.
The renderer, the probe bake, the CPU tracer and the Cycles scene each model this their own
way (`room_light::lace_lets`, `LIGHT_FN`'s `lace_shadow`, a sheet passing 0.72 in Cycles),
with terms tuned by eye. Task 122 can't judge the lace's terms until all of them share one
model.

## Acceptance criteria

- [x] One description of the lace (open part from its mask, the thread's transmission and
      scattering) used by the bake, the shaders, the CPU tracer and the Cycles scene
- [ ] The light under the lace in the tuner within a stated error of the reference
- [x] The lace's hand-tuned terms kept, fitted or removed, as in task 122

## Progress

- 2026-11-26 (task 122): the CPU tracer's lace is Cycles' model (a sheet with 0.72 open,
  its thread throwing `LACE_SCATTER` of the light reaching either side on through it and as
  much back); the lace panels in the close view agree within 1.00 to 1.08. The bake and the
  shaders still take their own (`tasks/122-light-from-physical-inputs.md`, "The fourth step,
  the reference's fixes").

## The one description (2026-11-27)

Under the tuner's `--light physical` (`--lace-light old` for the picture before); without it
the reference, close, room and lace views are byte-identical to the build before (run to run,
the base itself moves 14 pixels of the reference view's tie-backs). Results page:
`build/notes/lace-shade/index.html` (the 2026-11-23 page there is now
`shade-fill-2026-11-23.html`); scratch `build/lace124/`.

The four models before: the bake's plane letting `lace_lets(h)` 0.33–0.72 through and
throwing `LACE_SCATTER` 0.4 of the rest toward the room; the shaders' shadow (the mask at
`LACE_PATTERN_SHOWN` 0.75 over `LACE_NET_STOPS` 0.2 and a thread letting `shell_glass.w`
0.45) and cloth (its albedo in full from the room side, 0.45 of it from the window side with
`LACE_GLOW` 0.6, a Henyey-Greenstein lobe and a constant `lace_light` by `LACE_SKY_VIEW`'s
shape; reflection and transmission 1.45 times the albedo); the tracer's and Cycles' grey sheet
72% open at any slant, 0.4 forward and 0.4 back.

`model3d::room_light` now describes it once:

- The open part from the mask: the thread covers `LACE_DENSITY` 0.8 of the cloth where the
  mask is 1 (the shader's coverage, kept), more at a slant: a place of mask m lets
  (1 − 0.8 m)^(1/max(|cos|, 0.5)) straight through. Over the pattern that is
  `lace_open_share`, from the field's mask in eight bins (`LACE_MASK_VALUES`,
  `LACE_MASK_SHARES`; 41% thread square on, against the old sheet's 28%). Over the mean
  instead it was 0.37 in place of 0.43 at the power 1.9.
- The thread scatters its albedo (`surfaces::LOOK.lace_thread`, linear) diffusely,
  `LACE_THROUGH` 0.31 of it on through and the rest back: the shaders' 1 : 0.45 normalised.
  A choice, not measured: with no lace to measure, the earlier ratio kept.
- Cycles (`scene.py --lace described`, from `scene.json`'s `lace`): the mask on the uv as
  `lace_place` lays it, the slant from the incoming ray, a translucent and a diffuse closure.
  `--lace sheet` the old, `--lace off` none, `--lace-seen solid|front|back` the thread's own
  light for the camera only.
- The tracer: the same rule, the pattern's share at each crossing (`lace_open_share`).
- The bake: the lace's plane lets through the mean over its folds as a sine holding 1.2 m of
  cloth on the width it hangs at (`lace_open`, `make_lace_slopes`): for today's sun 0.45
  across the heights; the tracer through the exact mesh, rays from 0.6 m before the wall that
  cross a panel, 0.40 (0.36 to 0.41 by window; `build/lace124/pt/`). What the thread stops
  it throws on by its albedo's forward share (`lace_throws`).
- The shaders' shadow: the same as one flat sheet, `lace_flat` (the folds' mean slant, 1.78,
  and the density, 0.71, that lets `lace_open`'s mean through on the mask's blurred value),
  in `shell_glass.w` (negative) and `shell_case.y`. The folds' ±20% across the panel kept:
  the slant's own spread over a fold is about that.
- The cloth's light per vertex after each bake (`render3d::lace_on_vertices`, the window mesh
  updated): its window side what it sees of the glazing's sky (`lace_sky`), its niche's faces
  (`lace_niche`) and the wall (the probes toward the window), by form factors from the
  geometry (`lace_views`, at the mesh's making), a sight line along the wall losing to each
  fold it crosses; its room side the probes' light half a cell out, less the share the folds
  beside it hide (`fold_hidden`'s share itself), which show the wall through their holes and
  their thread's light (`lace_glow`, the bake's lace cells). The shader (`LACE_DESCRIBED`,
  the HDR lace pipeline's variant) mixes the two sides by the forward share; the sun on the
  room side passes the cloth first (`lace_self`).
- Not used under the description: `lace_lets`, `LACE_SCATTER`, `LACE_NET_STOPS`,
  `LACE_PATTERN_SHOWN`, `shell_glass.w`'s 0.45, `LACE_GLOW`, the lobe, `lace_light`'s
  constant, `LACE_SKY_VIEW`'s shape, `--lace-shade-fill`, `--lace-fold-ao`, and the screen's
  occlusion on the lace (its folds counted twice). They stay for the app's own light.

The thread's own light, the lace seen solid (the tuner's scratch build with coverage 1,
Cycles' `--lace-seen solid`), linear light over Frame's exposure × 1000, reference view:

| Region | Before | After | Cycles | Before / Cycles | After / Cycles |
|---|---|---|---|---|---|
| Near panel, low, in shade | 4.92 | 2.57 | 0.96 | 5.12 | 2.68 |
| Near panel, by the tie | 4.79 | 9.45 | 5.88 | 0.81 | 1.61 |
| Near panel, high, the window behind | 21.1 | 15.8 | 16.3 | 1.29 | 0.97 |
| Lit panel | 133.7 | 45.4 | 67.3 | 1.99 | 0.67 |
| Lit panel, low | 4.14 | 13.7 | 11.9 | 0.35 | 1.15 |
| Middle window, left panel (shade) | 8.66 | 10.3 | 7.86 | 1.10 | 1.30 |
| Middle window, right panel (lit) | 126.5 | 42.8 | 84.5 | 1.50 | 0.51 |

Error factor (the geometric mean of each ratio or its inverse): before 1.86, after 1.53. By
side (`--lace-seen front|back`): the room side 1.4 to 2.6 times Cycles' in shade, B/R 0.32
against 0.13 to 0.27; the window side 0.86 to 1.25 in shade but 3.7 at the near panel's foot,
0.56 to 0.78 where lit.

The pixels as seen (the regions of the earlier 2.26): the lace in shade 2.54 → 1.60 times
Cycles', B/R 0.50 against 0.38; lit 1.50 → 0.63; the middle panel 2.19 → 0.88. These take the
view out behind the lace too (the tuner's park, Cycles' sky box).

The room under the lace: its sun through the lace on the door 0.55 of the light without the
lace's shadow (before 0.65), Cycles 0.62; on the floor's sun patch 0.71 (0.75), Cycles 0.79.
The bake's sun through the lace 0.72 → 0.45 at the rod, with the thread's forward share now
thrown on: the meter's exposure EV 4.17 → 4.32, the ceiling 0.87 → 0.79 of Cycles', the
wainscot 1.57 → 1.41, the floor in shade 1.42 → 1.30.

Cost: the bake 203 → 246 ms on the Mac (the probes' sky through the lace's folds, its open
share a table), the mesh 158 → 180 ms (the lace's form factors), each bake 7,068 lace
vertices' light and the window mesh written again; per pixel the lace's own a few multiplies
less than before, the shadow one branch.

Left (the second criterion not met):

- The lace's room side in shade 1.4 to 2.6 times Cycles' and bluer: the probes' light half a
  cell before the window wall, as task 122's surfaces there (an L1 probe beside a bright
  window gives its dim side too much, bluish). Next: gather the cells, the sky and the sun's
  patches at the lace's places one-sided, as the bake gathers the probes, in place of the
  probes there.
- The lit panels 0.5 to 0.7: the sun on the cloth in the tuner is as bright at its peak as
  Cycles' (99th percentile 0.26 against 0.27) but over less of it (median 0.0074 against
  0.0155): the shadows of the casements' members on the cloth sharp and blocky in the tuner
  (as before), and the niche's sunlit faces' light on its back by one mean a window.
- The near panel's foot 2.7: both sides' probes by the floor and the wall.
- The floor's cheap mirror (`--mirror-cheap`) and the floor's mirror of the lace keep the old
  lace.

## The near panel's foot (2026-11-27)

The user: the lace below the window considerably lighter than Cycles', evenly pale grey-beige
to the hem, where Cycles' is dark and warm, about as dark as the wainscot behind it.

Measured at the lace's own vertices below 1.2 m (a scratch dump from `lace_on_vertices`)
against the CPU tracer at the same points, the same description, 256 cosine rays a side
(`build/lace124/pt/path_trace_lace.goose`, mode `lacelight`; `build/lace124/cmp_lv.py`):

- The window side just below the sill (0.6–0.8 m) was 4.5 to 5.9 times the tracer's, B/R 1.03
  against 0.40: nearly all of it the probes' light toward the window at the cloth (0.010 to
  0.011 against the tracer's 0.0022 to 0.0027 for the whole side), which takes the window's
  sky above the sill. Through the folds' holes (the room side's cavity term) it lifted the room
  side there to 1.24 to 1.84.
- Fixed (1e741853): the window side sees the window wall's own light, the bake's wall cells'
  (`room_light::window_wall_light`, bilinear, the niches' holes out), not a probe. After: the
  window side at 0.6–0.8 m 0.90 to 1.01 of the tracer, below 0.6 m 0.2 to 0.3 (its share of
  the thread's light about a tenth there); the room side below the sill 0.7 to 1.1. The
  thread's own light against Cycles: the near panel's foot 2.68 → 1.39, by the tie 1.61 →
  0.86, the middle window's panel in shade 1.30 → 1.00; the error factor over the seven
  regions 1.53 → 1.43. Without `--light physical` the views as before (within the base's own
  run-to-run pixels at the tie-backs); `scripts/test.sh ui` passed.
- Left, not fixed: the room side's colour. Its level is right but its B/R is 0.40 to 0.43
  against the tracer's 0.16 to 0.27 (the pixels 0.22 against 0.13): the probes' colour in
  the shade, the whole room's (task 122's "the app's shade bluer than Cycles'": the sky's
  part 1.1 to 1.4, the sun's bounce 0.5 to 0.8). That is why the foot still reads grey-beige
  against Cycles' warm brown. A general probe fix, not one for the lace; the user to decide.
- Left: the lace's window side below 0.6 m 0.2 to 0.3 of the tracer and the lit panels'
  lower parts 0.1 (the floor between cloth and wall, and the room's light seen back through
  the folds' holes, are not in it: a cavity term on the window side as the room side has, its
  hidden share from the folds' other phase, is the next step); the lit panels 0.45 to 0.6
  (the sun's shadows on the cloth sharp and blocky). The per-vertex light carries a share of
  the cloth's mean colour, not each vertex's own colour.
- The results page has the foot's crops before, after and Cycles
  (`build/notes/lace-shade/index.html`).
- 2026-11-27, after merging the floor's wax and baked reflection (75265a04): the reference view
  reshot (build/lace124/a/merged-reference*) against c0bd47f3's build. The lace regions'
  light is unchanged to the digit (near in shade 0.86 of Cycles', lit 0.56, middle 0.81), so
  the open items above stand. Only the floor moved: its patch in shade 1.30 → 1.63 of Cycles'.

## The folds' cavity and the lit flanks (2026-11-27, evening)

Under `--light physical` only; without it the reference and lace views match `build/stable`
(0 and 1 pixels, as a rerun of it). Scratch `build/lace124b/` (a source copy, `tree/`, for
dump builds; the tracer's copy `pt/` with `--rays N`, `--no-sky`, `--no-sun`, `--depth N`;
`cmp*.py`); results page `build/notes/lace-shade/index.html`, first section.

- The room side below 0.6 m was mostly `lace_glow` (0.0027, B/R 0.62): the lowest band's light,
  its sky seen from the band's middle, carried down to the hem, where the tracer's window side
  is 0.0004 to 0.0006. Now (f2833d20) below the sill the folds' glow comes from the vertex's own
  window side, and above it from the band, its sun all above the sill. The window side's view of
  the wall meets the folds at their other phase (`FOLD_HIDDEN` less the room side's hidden
  share): through them the room's light and their thread's. In shade, over the tracer: the
  window side under 0.6 m 0.31–0.40 → 1.15–1.47 (B/R 0.34–0.37 against 0.12–0.15), at 0.6 to
  0.84 m 0.65–0.96 → 0.92–1.34; the room side under 0.6 m 0.77–1.56 → 0.54–1.06, B/R 0.38 →
  0.30 (the tracer 0.16–0.20).
- The lit panels: the shader took the side the eye sees as the room side; at the reference
  view's slant the eye sees some flanks' window side, sunlit, which took the sun through the
  cloth first (`lace_self`). Now (91aa2bbe) the room side is the one facing into the room. As
  seen, over Cycles: the lit panel 0.57 → 0.68 (its brightest quarter 0.45 → 0.59), the
  middle window's right panel's brightest quarter 0.39 → 0.58 (99th percentile 0.56 → 0.82),
  the middle panel 0.82 → 0.93, the foot 0.86 → 0.83. ngfx at parity on the lace (it differs
  from gfx only on the floor, which has no baked reflection on ngfx yet).
- "Sharp and blocky" was the solid scratch build's artefact: at full coverage the unsorted
  lace draws far folds over near ones. In the real render the bars' shadows match Cycles'. The
  solid measure is unreliable on the lit folds for the same reason. Against Cycles with its sky
  off (`build/lace124b/cynosky`), the sun's light on the lit thread was 0.38–0.42 of Cycles',
  the lit door 0.83.
- The floor's reflections of the lace (`refl_lace`, `planar_lace`) keep the old model: with
  `LACE_DESCRIBED` in both, at most 4 levels in the reference view and 5 in a low view onto the
  floor (no pixel over 8). Left as it is.

The room side's colour, measured, not changed (the user to decide). At the point the lace reads
the probes (6.85 m, settled toward the room) the tracer gives B/R 0.15–0.24, the probes
0.29–0.34: the sky's part 1.4–1.9 times the tracer's, the sun's bounce 0.3–1.1. Two causes:

- The probes 0.15–0.35 m before the window wall take the lace cells' light on the wall behind
  (`gather_cells`' `behind_lace`, `lace_on_wall`), which the wall needs; the lace reads it as
  the room's, and its cavity term already counts its neighbours. Without it the sky's part has
  the tracer's colour (B/R 0.59–0.63 against 0.56–0.65), 0.43–1.26 of its level.
- The sun's bounce toward the window wall is short: without the lace's own light the probes hold
  0.29–0.35 of the tracer's first two bounces by the stove (window 0), 0.39–0.61 at the middle
  window, 0.20–0.91 at the far one; the tracer's sun there is 0.75–0.95 first bounce. Task 122's
  0.52, worst at the wall.

Proposed: (1) keep the lace's light on the wall apart from what the lace reads (a second value
for that row, or the lace reading it without); (2) measure the first bounce patch by patch at
those probes against the tracer (the floor's patches 0.15–0.45 m away, gathered as points
capped at 0.3 m; the stove's faces) before changing the gather.

Error factor of the thread's own light over the seven regions (the solid measure): 1.43 → 1.40.
Left: the probes' colour above; the lit panels 0.6–0.7; the window side's cavity share is the
room side's phase mirrored, not traced (it reads 1.15–1.47 of the tracer under 0.6 m).

## Decisions (the user, 2026-11-27)

- Cycles renders the lace's real mask (`scene.py --lace described`), not a plain sheet: the
  reference for the lace is Cycles with our pattern and our density rule (`LACE_DENSITY`, the
  slant power), which the app, the tracer and Cycles share, so no comparison tests that rule.
- `LACE_THROUGH` (0.31, the old shaders' 1 : 0.45 normalised) is to be worked out again, not
  kept as a choice. All three renderers take it, so no comparison so far tests it. What moves
  with it: the backlit lace about in proportion, the lace in shade a little the other way
  (its room light sent back is 1 − it), and the light the bake throws into the room
  (`lace_throws`), so the camera's meter.
- Both probe changes proposed above go ahead: (1) the lace reads the window wall's probe row
  without the lace's own light on the wall (`lace_on_wall`); (2) the sun's bounce toward the
  window wall located patch by patch against the tracer's first bounce, then fixed.

## Handover (2026-11-27)

Next session, in this order:

1. Probe change (1). The row the lace reads (6.85 m, half grid row 1, `gather_cells`'
   `behind_lace` for probes 0.15–0.35 m before the wall) takes `lace_on_wall` into `ey`, which
   the wall's face needs and the lace must not get. Ways: a second value for that row (the
   half grid's `ey` with and without it), or `lace_into_mesh` reading the row less the lace's
   part. Measured target: without it the sky's part at that row has the tracer's colour (B/R
   0.59–0.63 against 0.56–0.65). The wall's own reading must stay as it is: check the window
   wall's pixels in the reference view against the build before. This is a probe change: it
   moves `docs/architecture/` and maybe a decision only if it touches the app's light; under
   `--light physical` only, record it here and in task 122.
2. Probe change (2). Without the lace's light the probes at that row hold 0.29–0.35 of the
   tracer's first two sun bounces by the stove (window 0), 0.39–0.61 at the middle window,
   0.20–0.91 at the far one; the tracer's sun there is 0.75–0.95 first bounce. Measure each
   patch's share at those probes in the bake against the tracer's first bounce (`--depth 1`)
   before changing anything. Suspects: the floor's patches 0.15–0.45 m away gathered as points
   with their distance held to `gather_near`'s 0.3 m (task 122 tried areas and dropped them on
   a whole-room measure, not this row's), the stove's sunlit faces throwing nothing
   (`stove_stops_sun`; a new stove is planned, so measure, don't special-case it).
3. `LACE_THROUGH`: worked out from a source, not tuned against Cycles (Cycles takes the same
   value). A thin white lace's forward and back split: a published diffuse transmittance and
   reflectance of thin white woven fabric, or the user's photographs of a real lace lit from
   behind and from the room at one exposure. Ask the user which before choosing. Then the
   same value in `room_light`, the tracer, and `scene.json`'s `lace` (the exporter), Cycles
   rendered again (`build/lace124b/cy.sh`), and the measures above redone.

Not this task's, seen on the way: the floor's band between the rug and the wainscot under the
near window, 1.7 to 2.1 times Cycles' and blue, comes from the baked reflection (task 131's
step 3c), not the lace.

Tools, all in `build/lace124b/` (scratch, not in git):

- `tree/`: a copy of the sources (toolchains and goose_gfx linked in) for dump and scratch
  builds; copy the checkout's changed files into it first. `render3d.dump` holds
  `lace_into_mesh` with the `LV|` dump (each lace vertex below 1.2 m: point, normal, F_sky,
  F_open, hidden, probe, wall, back, front, glow); `lv*.txt` the dumps (`lv-nosun`, `lv-nosky`
  from the tuner's `--key 30,18,0,0.85` and `--baked 0,1,0,0`, which add up to the whole).
- `pt/ptl`: the tracer with `lacelight FILE --rays N [--no-sky] [--no-sun] [--depth N]`
  (`path_trace_lace.goose`, built in `pt/`); `ppts.txt` the probe row's points (6.85 m),
  `tl2k.txt` the vertices at 2,048 rays a side, `tp*.txt` the row by part.
- `cmpv.py` (vertices against the tracer, in shade), `cmp3.py` (the row by sky and sun),
  `cmp2.py`; `build/lace124/meas.py` and `solid.py` for the reference view against Cycles
  (`build/lace124/shot.sh BIN TAG reference` shoots). The solid measure is unreliable on lit
  folds (the unsorted lace at full coverage).
- `cy.sh SCENE TAG [flags]` renders Cycles at the reference view (the quiet lock);
  `cynosky/` the scene with the sky off, `c/nosky-reference*` its render.
- `page2.py` wrote the results page's first section.

## The probes' two changes (2026-11-27, night)

Under `--light physical` only; without it the reference view is byte-identical to 1512581a's
build (both changes). Scratch `build/lace124b/` (`cmp3p1.py`, `cmpsrc*.py`, `pb*.txt`, `pt1*.txt`).

Change (1): the half grid keeps the lace's light on the wall apart (`Gathered.lace`, the share
of `ey` that `lace_on_wall` adds), the bake writes it for the probes that settle to the window
wall's face (`room_light::bake`'s `lace_wall`, `render3d::light_lace_wall`), and the lace's room
side reads the probes without it (`probe_light(..., without_lace)`). The wall reads them as
before: in the reference view only the lace's pixels and their reflection moved. At the row
(6.85 m) over the tracer, toward the room: the sky's part 1.40–1.87 → 0.43–1.26, B/R 0.66–0.77
→ 0.59–0.63 (the tracer 0.52–0.65), the same to the digit as the earlier build without
`lace_on_wall`; the sun's part 0.29–1.12 → 0.19–0.73, the whole 0.51–1.30 → 0.26–0.92. At the
lace's vertices in shade the room side 0.53–1.20 → 0.33–0.81 of the tracer, B/R 0.28–0.33 →
0.24–0.30. As seen against Cycles: the near panel in shade 0.83 → 0.72, the lit panel 0.68 →
0.62, the middle panel 0.93 → 0.91.
