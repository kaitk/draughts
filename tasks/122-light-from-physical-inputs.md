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
(`tools/blender_export.goose`, `tools/blender/`), the CPU tracer (`tools/path_trace.goose`)
for points, probes and each step's check. The terms to judge, each with a verdict (go, fit
to the reference, or a camera or art choice), are listed in `build/review120/report.md`.

The order the user set (2026-11-27): the concepts set the look, Cycles is made to match them
by its inputs, then the app is made to match Cycles.

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

## Where it stands (2026-11-27)

Everything is behind the light tuner's `--light physical`; without it the tuner's views and
the app stay byte-identical to the build before each step (checked at every step). Most
detail is on `build/notes/light-physical/index.html` (steps 1 to 7, by anchor `#step2` …
`#step8`) and the pages named below; scratch in `build/review122/`.

The bake (`room_light`):

- Gain 1, no caps or grey balance; the panes' real transmission (two of 0.92). The sun and
  the sky traced through the casements' members with their depth (`members_traced`,
  `sky_through`): the sun into the room at 15° 0.381 of the glazed rectangle (the tracer
  0.369), the bake's sky at the probes 0.84 to 1.33 of the tracer's.
- The rug in the bake, the probes' near limit 0.02 m², the exact gather of near cells
  (`gather_exact`), the table's place (`table_off`), the niches gathering their own cells
  (`niche_faces`), probe volumes in the box windows' spaces (`probe_volumes.goose`,
  `--volumes`), the window wall's settle to 0.8 m (`sill_settle`), the niche's light only
  from its probe at the same height (the floor's halo under the windows, 2026-11-27).
- The stove stops the sun (`stove_stops_sun`) but throws nothing back off its tiles; the
  table's sides take the sun as patches (`table_sides`, task 124).
- The season's air: the sun and the sky by direction from one haze (below).
- L1 probes for the room; an L2 props' atlas (`PROPS_LIGHT`) for the table, chairs and
  board; the lace's light per vertex from task 124's one description.
- Cost on the Mac: the bake 85 to 101 ms at the third step, 178 ms with the volumes,
  246 ms with task 124's lace (the mesh 180 ms).

The surfaces:

- The direction-blind fills gone: `room_shade`, the kept harmonics, the shade's floor of
  the key (step 1); the lace's room-side fill (2026-11-27, then task 124's model); the
  board's harmonics and its window-pattern shade fill (b2f95c62 and the board meter's
  change). Kept, measured: the bounce off the board onto the pieces' sides (the probes
  don't hold it).
- Task 120's light per pixel on, the chairs' hand-made occlusion and the table's two shade
  terms off; the table takes the props' bake's open part alone; the props' sun wrap 0.
- One sun on every surface, its colour by its height (`rooms::sun_color_at`: 3500 K at 10°,
  3950 K at 15°).
- Materials (23f57593 and after): the oak's and the floor wax's clear coat
  (`PHYSICAL_COAT`), the broad sheen off; the table's polish takes its Fresnel share off
  the sun and sees the room's box (`props_seen`, 0d1f3fd4); the wallpaper's print a metal
  over a matt ground, with close-up detail (`--paper-detail`); the woods' toggle
  (`--woods`, ours by default; `picks`, `tuned`); the floor's reflection from task 131's
  baked map.
- ngfx at parity (`tools/light_tune_ngfx.goose`), but for gfx's window light map
  (`build/notes/ngfx-parity/`).

The camera:

- One curve: an AgX fit in `HDR_TONE_FRAG` (grey 0.51 levels off Blender's mean, Cycles
  views 1.2 to 1.5 levels a pixel), no toe.
- The exposure from a meter of the bake's cells (`render3d::meter_of`), no pass; the board
  meter (`board_meter`) takes the exposure down as the board fills the frame (the board view
  −3.57 stops, a walk never).
- A grade per season as data (`render3d::GRADES`): autumn's the light one (white 1.1, 1,
  0.85, power 0.9); winter, spring and summer neutral. The glow's threshold tied to the
  exposure. The view out under its own window exposure (`--window-ev`, −3 with the hazy air).

## How it got here (2026-11-26 to 27)

Each step's conclusion and the numbers still relevant; the full tables are in git before
this trim (c765addf's file) and on the pages named.

- Step 1, the physical bake and one exposure. Against the tracer's 22 points round the
  table (the props' light over the reference, geometric mean): today 5.18 (1.03–18.7), all
  of step 1 1.27 (0.40–3.60). Three bounces in place of one move them about 3%.
- Step 2, one camera curve and the probes measured. No toe kept (it squares the shade's
  error). The excess was the window: its mesh lets 0.37 of the glazed rectangle's sun in at
  15°, the bake took 0.86.
- Step 3, the casements' depth in the bake and L2 props' probes. What was left was the
  probes' own gather from below (0.14 to 0.21 of the tracer's light downward).
- Step 4, the rug, the near limit, the exact gather, the table's open part: the 22 points
  0.94 (error factor 1.27), the 864 probe values (144 probes × 6 axes) 0.91 (1.32); ideal L2
  of the tracer's light 0.93 and 1.00. The tracer's sun got Cycles' disc.
- Step 4b, the tracer fixed (its sky past the panes, its lace as Cycles'; the props then
  1.03 to 1.07 of Cycles') and the bake's sky through the members: the points 0.74, the
  probes 0.78 (error factor 1.45, 1.39). Left short: the light thrown on (the walls' and
  ceiling's cells about half, the floor's below the probes 0.2 to 0.35).
- Step 4c, the bounced light by source (bake / tracer, summed over the probes): sky 5.05 /
  5.37, the walls' sun 1.48 / 2.18 (the stove's tiles 0.58 / 1.02), the casements' members
  none / 0.82, all 11.82 / 15.20. The table's place and the niches' probes fixed; the points
  and probes unchanged (0.74, 0.78).
- Step 4d, probe volumes: the 11 window-space points seen from the room 0.16 → 1.06 of the
  tracer (error factor 6.34 → 1.36); the frame cost within the runs' spread (under 0.6 ms).
  A bug on the way (15de6719) fixed in 374362c4.
- Step 5, the camera: AgX and the meter (EV 6.77 under the clear sun). The tuner's light
  then 0.44 to 0.72 of Cycles' in sun and shade alike: light, not the camera.
- Step 6, the season's grade (`build/notes/autumn-grade/`): autumn's first grade (EV −3.6,
  white 1.3, 1, 0.6, power 0.8) took the 12 regions of the autumn reference from 1.50 to
  0.80 stops off; one exposure can't hold the reference's flat sun against its shade (its
  floor's sun over shade 8.9, Cycles' 20 or more). Replaced by the light grade with the
  season's air.
- Fixes (`build/notes/stove-and-arc/`): the stove stops the sun (no magenta glaze left); the
  lace's forward cone off; the sills' yellow front band (the probes behind the face) fixed
  by the settle.
- Step 7, varnish and the sun's colour: the sunlit regions' chroma on Cycles' within 0.01.
  Redone for the wallpaper and the table's sun (`#step8`); the wallpaper close up
  (`build/notes/wallpaper-close/`) and engraved (`build/notes/wallpaper-engraved/`,
  `--paper-mask engraved`, the user's call whether the app takes it).
- The woods' toggle (`build/notes/wood-in-app/`): picks or tuned cost the down view 12.7 →
  14.3 ms.
- The lace's room side from the probes, not the old fill (in shade 61.9 times the paper
  before, 2.8 after; `build/notes/curtains-stove/`). The stove's sunlit tiles near white
  (0.981 against the reference's 0.838) are the low sun square on them, not the glaze.
- Cycles takes the app's sun (`room_scene::sun_take`) and wood (`build/notes/latest-look/`).
- The indirect light (`build/notes/indirect-light/`): every probe held 0.52 of the
  tracer's sun bounce, from the tree outside (0.85; the tuner's own shots are compared with
  Cycles under `--tree 0,11,70,1`) and the stove throwing nothing back (0.77). The stove's
  faces as patches (f56d4987) took it to 0.88 but left purple blotches: dropped for the new
  stove. On the surfaces the sky's part read 1.1 to 1.3 over (the lookup half a cell out
  sees more window).
- Tried and dropped: the sun's patches gathered as areas (the probes over the floor's sun
  read too little already, 0.76 → 0.56); the walls' coat seeing the room's box sharply.
- The table's polish sees the room's box: the casement's shadow band on the top 99 64 47 →
  54 23 11 (Cycles 49 21 9).
- The board: its ambient from the props' probes (b2f95c62), the board meter, and its sun
  in the shade by `window_open` alone (`build/notes/board-light/`, `board-meter/`).
- The sun scorching and the outside white (the user, 2026-11-27, night): not a regression
  (the stable builds from 6dd8dc5d to 64458ab1 measure within a few levels; `build/sunreg/`).
  The orange the user tuned was the default light's own sun and curve; the physical
  light's warm look came from its inputs. The season's air and the window exposure (below)
  put the floor's sun and the view out on the reference at the reference view.

## The season's air: the sun, the sky and the view out from one haze (2026-11-27, night)

Results page `build/notes/sky-look/index.html`; scratch `build/sky-look/` (`cy.sh`,
`cam2.py`, `shot.sh`, `lin.py`).

- The warmer room seen earlier that day was no build of the app: the stable builds from
  6dd8dc5d to 64458ab1 measure within a few levels at the reference view. It was Cycles
  through the tuner's camera (`build/notes/app-camera/`, the export at 0d1f3fd4, EV 4.17,
  autumn's grade).
- Cycles had the hazy sun (0.25 of the clear sun) under a clear sky's blue light, the same
  in every direction and under the horizon. Blender's sky model (multiple scattering;
  `tools/blender/sky_model.py` integrates its sun and sky for one aerosol density,
  `scene.py --sky`) gives the sun and the sky from one air: at aerosol 40 the sun is 0.13
  of the clear sun (R/G 1.96, B/G 0.26), the sky toward it about 9 times brighter for that
  sun than the export's and warm. `scene.py --view-out pictures` adds the lawn (albedo 0.08,
  0.10, 0.035), the tree line and the oak as cards lit by the sun and sky; `blender_export
  --tree on` the maple.
- Options through the tuner's camera, metered: with the light grade (white 1.1, 1, 0.85,
  power 0.9) aerosol 40 puts the floor's sun on the reference's (185 133 89 against 191 132
  91, both saturation 0.52), the floor in shade 93 49 18 (79 42 19). The ceiling goes
  orange (saturation 0.80 against 0.50): with ground and trees in place of the plain sky
  under the horizon it is lit by the floor's sun and the warm trees; the maple doesn't
  change it (0.80). The user's picks: aerosol 40, the light grade, the maple in Cycles, a
  camera window exposure.
- The app (`--season-air hazy`, the default under `--light physical` in autumn; `clear` the
  picture before): the sun from the model; the bake's sky by direction,
  `room_light::sky_along` from `model3d::outside_light` (Cycles' panorama of the outside
  from just past the middle window at 1.9 m, 5° cells over ±85° by −30 to 90°, over the
  sun's luminance; `tools/blender/outside_table.py`), in the probes', the cells' and the
  probe volumes' sky gathers; autumn's grade the light one (`render3d::GRADES`,
  `app_camera.py`'s copy); the view out at Cycles' light (`OUTSIDE_PHYSICAL` 2.07 on
  `room.outside`) under the camera's window exposure (`render3d::window_ev`, `--window-ev`,
  −3 by default with the hazy air, the Window EV slider; not on the reflections). Without
  `--light physical` the reference and menu views are byte-identical to 64458ab1.
- The app over Cycles in linear light, the same air (tone probes against Cycles' combined
  light, the reference view, no tree outside): the paper in shade 0.62, the far wainscot
  1.82, the ceiling 0.68, the floor in shade 1.18, the floor's sun 0.90, the lit door 0.82,
  the door in shade 0.89, the lit lace 0.74, the lace in shade 1.37, the view out 0.86, the
  tapestry 1.11, the rug 2.22. Through the camera: the floor's sun 190 137 91 (the
  reference 191 132 91), the view out 195 174 144 (192 151 117). The camera's meter EV
  4.19 → 3.87.
- The lace's thrown light (`--lace-source 0` against 1): the paper in shade ×1.67, the
  ceiling ×1.33, the lace in shade ×1.27, the tapestry ×1.20, the wainscot ×1.14, the rest
  within 5%. The paper is short of Cycles' even with it, so the room's own light is shorter
  still than the 0.62: the two errors still hide each other. The wainscot's and the rug's
  surplus are not the lace's.

## Open

Numbers are the app over Cycles in linear light at the reference view under the hazy air
(above), unless said.

- The lace's forward light thrown into the room at several times Cycles' share (task 124):
  with `LACE_THROUGH` 0.65 the paper pier gains 1.13 of its no-throw light against Cycles'
  0.13; under the hazy air the lace adds ×1.67 to the paper in shade and ×1.33 to the
  ceiling. Suspect, unmeasured: counted twice, as `gather_cells` takes the lace cells (from
  `LACE_C0` on, under `niche_faces`) by `abs(dot)` to both their sides and the cloth's
  `lace_glow` carries the same light. Measure the bake's lace as a source against the
  tracer at the probes first.
- With it, the room's own light short: the paper in shade 0.62, the ceiling 0.68 of
  Cycles', while the lace adds ×1.67 and ×1.33 to them. Earlier leads: the probes' sun
  bounce 0.52 of the tracer's (0.77 of it the stove), the casements' members with no cells
  (5% of the probes' light), the walls' relief in the sun.
- The far wainscot 1.82 and the rug 2.22 of Cycles', not from the lace.
- The sunlit lace folds read black without the forward share, where Cycles' keep most of
  their light (task 124).
- The floor's pale band between the rug and the near window's wainscot, 1.7 to 2.1 of
  Cycles' and blue: the baked reflection's lookup (task 131, step 3c).
- The stove's sun waits for the new stove: its sunlit tiles throw nothing in the bake (the
  tracer's 11.6 to 16.8 × 10⁻⁴ at the lace's probe row by its window). With it: its outline
  from `stove.goose` for `meets_stove`, probes inside solids walled, prop faces settled.
- The wainscot's panel edges under the windows shine: the brightest 1% 5.7 times Cycles'
  (0.080 against 0.014 over the sill; view `--plan-eye 4.5,6.1,1.0 --plan-at 4.5,7.4,0.35
  --fov 70`, Cycles' `build/indirect/c/wainscot.exr`). The light on the bevels 1.8 to 2.3
  times the tracer's and bluer explains about 2 of it; not the coat's box reflection nor
  `--panel-ao`. Next: each term at those pixels against Cycles' passes.
- The board's colours against the old light, measured before the season's air: the sunlit
  maple 226 175 122 against 244 158 88, maple over walnut 2.37 against 3.20, the sun over a
  piece's shade 1.79 stops against 1.96. Not yet split into the light's colour, the woods'
  albedo, or AgX near its top.
- The other seasons' air and grade: only autumn has them; winter, spring and summer are
  neutral.
- The phone tier: the props' light a colour a vertex from the props' atlas
  (`PROPS_VERTEX`), designed only; the walls' coat the same define.
- Smaller: the bake's `PAPER_ALBEDO` still the old mean; the engraved wallpaper mask the
  user's call; the sunlit table top paler than Cycles' (AgX's shoulder) to look at again
  under the light grade.

## Handover

In this order:

1. With task 124: the bake's lace as a source against the tracer at the probes (the
   thread's light alone, `LACE_THROUGH` 0.65 against 0), the `abs(dot)` double count
   checked first; fix, then the "app over Cycles" list above measured again
   (`build/sky-look/lin.py`).
2. The room's own light with the lace right: where the paper's and the ceiling's
   shortfall comes from, source by source against the tracer (`build/indirect/pts/`'s
   modes), compared with Cycles under `--tree 0,11,70,1` or with Cycles' maple
   (`blender_export --tree on`).
3. The far wainscot's and the rug's surplus.
4. The floor's band (task 131, step 3c), then the wainscot's panel edges.
5. The board's colours under the light grade, measured again before any change.
6. The other seasons' air and grade: ask the user for the order and references.
7. Once the look is settled: the user's pick against the old light, the old options
   removed, the decision and the architecture docs, the phone tier, the timings against
   the baseline.

The stove's sun waits for the new stove.

## Acceptance criteria

- [x] The CPU tracer in `tools/` (the room's triangles from `model3d`, physical inputs, a
      points mode and a picture mode), its numbers agreeing with Cycles' as in task 120
      (2026-11-26: `tools/path_trace.goose`; its points equal the scratch tracer's
      `points-phys.txt` to the last digit or two, its views' means within 0.9 to 1.1 of the
      scratch's; 22 points × 4,096 paths in 0.6 s, a 480 × 270 picture at 64 paths in 10 s
      on the Mac's 10 threads. The old gains' mode is left out: it needs the tree's sun
      factors from the tuner's GPU, and the tuner itself now shows the old light's error)
- [x] Under `--light physical`, the bounce's gain, caps and grey balance gone; exposure and
      white balance set as a camera (2026-11-26: step 1's bake; AgX at a metered exposure;
      a grade per season; 2026-11-27: autumn's air and light grade)
- [x] The direction-blind fills gone, or each kept with its measured need (2026-11-27:
      `room_shade` and the kept harmonics in step 1, the lace's fill, the board's harmonics
      and shade fill; the bounce onto the pieces' sides kept, the probes don't hold it)
- [ ] The probes' light toward the room side and down within a stated error of the
      reference (L2 for the props, the rug and the table in the bake, done; on 2026-11-26
      the 144 probes × 6 axes 0.78 of the tracer, error factor 1.38, down 0.66 to 0.79; the
      sun's bounce 0.52 on 2026-11-27)
- [ ] Task 120's per-pixel light the default on desktops, the chairs' hand-made occlusion
      removed (both under `--light physical` since 2026-11-26); the sliders for the chairs'
      cloth and wood only if still needed
- [ ] Each term the review listed kept, fitted or removed, with the reference's numbers
- [ ] Shots of the tuner's views against Cycles' on a results page in `build/notes/`, the
      user's pick before the old light's options are removed (the pages exist, latest
      `build/notes/sky-look/`; the pick not yet made)
- [ ] The low-end Android tier (a colour per vertex, task 120) designed as a define, tuned
      after the desktop look is settled; times with `tools/perf/mac_room_bench.py`
- [ ] The wainscot's panel edges under the windows within a stated factor of Cycles' (5.7
      times on the brightest 1% on 2026-11-27)
- [ ] The board's colours in the board view as rich as the old light's (the sunlit maple
      226 175 122 against 244 158 88, maple over walnut 2.37 against 3.20 on 2026-11-27)
- [ ] The decision in `docs/decisions/rendering.md`, `docs/architecture/rendering.md`
      updated in the same commit
