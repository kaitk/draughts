# 124: One model of the lace's light

Status: in-progress

The lace curtains pass the sun and the sky through their pattern, and scatter some of it.
The renderer, the probe bake, the CPU tracer and the Cycles scene each model this their own
way (`room_light::lace_lets`, `LIGHT_FN`'s `lace_shadow`, a sheet passing 0.72 in Cycles),
with terms tuned by eye. Task 122 can't judge the lace's terms until all of them share one
model.

## Where it stands (2026-11-27)

All under the tuner's `--light physical` (`--lace-light old` for the picture before);
without it the reference, close, room and lace views stay byte-identical. Results page
`build/notes/lace-shade/index.html`; scratch `build/lace124/` and `build/lace124b/`.

The one description, in `model3d::room_light`, taken by the bake, the shaders, the tracer
and Cycles (`scene.py --lace described`, from `scene.json`'s `lace`):

- The open part from the mask: the thread covers `LACE_DENSITY` 0.8 of the cloth where the
  mask is 1, more at a slant: a place of mask m lets (1 − 0.8 m)^(1/max(|cos|, 0.5))
  straight through; over the pattern `lace_open_share` (`LACE_MASK_VALUES`,
  `LACE_MASK_SHARES`; 41% thread square on, against the old sheet's 28%).
- The thread scatters its albedo (`surfaces::LOOK.lace_thread`) diffusely, `LACE_THROUGH`
  of it on through and the rest back. `LACE_THROUGH` is 0.65, from a measured cream sheer
  (below).
- The bake: the plane lets through the mean over the folds (`lace_open`,
  `make_lace_slopes`; 0.45 for today's sun, the tracer through the mesh 0.40) and throws
  what the thread stops on by its forward share (`lace_throws`).
- The shaders' shadow as one flat sheet (`lace_flat`, in `shell_glass.w` and
  `shell_case.y`).
- The cloth's light per vertex after each bake (`render3d::lace_on_vertices`; the shader's
  `LACE_DESCRIBED` mixes the two sides by the forward share): the window side sees the
  glazing's sky, its niche's faces and the window wall's cells (`window_wall_light`,
  1e741853); the room side the probes half a cell out without the lace's own light on the
  wall (`Gathered.lace`, `probe_light(..., without_lace)`), less what the folds beside it
  hide, which show the wall and their thread's light (`lace_glow`; below the sill from the
  vertex's own window side, f2833d20). The room side is the one facing into the room
  (91aa2bbe).
- Not used under the description: `lace_lets`, `LACE_SCATTER`, `LACE_NET_STOPS`,
  `LACE_PATTERN_SHOWN`, `shell_glass.w`'s 0.45, `LACE_GLOW`, the lobe, `lace_light`'s
  constant, `LACE_SKY_VIEW`'s shape, `--lace-shade-fill`, `--lace-fold-ao`, the screen's
  occlusion on the lace. They stay for the app's own light, and for the floor's mirrors of
  the lace (`refl_lace`, `planar_lace`, `--mirror-cheap`; at most 4 to 5 levels off, left).
- Cost: the bake 203 → 246 ms on the Mac, the mesh 158 → 180 ms, each bake 7,068 lace
  vertices' light and the window mesh written again; per pixel a few multiplies less.

How it got here, by conclusion (the full measurements are in git before this trim, in
4e69496a's file):

- Before the description the thread's own light (the lace seen solid) was 1.86 times off
  Cycles' (error factor over seven regions); with it 1.53, then 1.43 with the window side
  reading the wall's cells (the window side under the sill had been 4.5 to 5.9 times the
  tracer's, from a probe seeing the window's sky), 1.40 with the folds' cavity. The solid
  measure is unreliable on lit folds (the unsorted lace at full coverage).
- "Sharp and blocky" shadows on the lit cloth were the solid scratch build's artefact; in
  the real render the bars' shadows match Cycles'.
- The probes' two changes (2026-11-27, night): the lace reads the window wall's probe row
  without the lace's own light (the sky's part there 1.40–1.87 → 0.43–1.26 of the tracer,
  B/R 0.59–0.63 against 0.52–0.65), and the table's sides take the sun
  (`room_light::table_sides`, task 122; the middle window's probes' first bounce 0.31–0.33
  → 0.66–0.70 of the tracer). At those probes the bake's sun patches by surface are 0.8 to
  1.7 of the tracer's first bounce, but the stove's tiles 0 (the tracer 11.6–16.8 × 10⁻⁴ by
  its window, 17 of about 30).

## `LACE_THROUGH` from a measured sheer (2026-11-27, night)

The user chose published data. Kotey, Wright and Collins (2009a, ASHRAE Transactions; their
Table 2 as reproduced in the 2016 ASHRAE Winter Conference paper OR-16-C056) measured nine
drapery fabrics with a spectrophotometer and integrating sphere, solar-weighted, square on.
Their cream sheer: openness (beam-beam) 0.45, beam-total reflectance 0.19, beam-total
transmittance 0.80. Their yarn model takes the yarn's reflectance as the fabric's over
1 − openness (Joong's thesis, eq. 3.3), so the yarn sends 0.355 on and 0.19 back:
`LACE_THROUGH` 0.65 (0.355 / 0.545). The denser white fabrics in the same table split 0.31
(IIIL) to 0.43 (IL, IIL): a thin open yarn scatters more forward. The sheer is the one like
the lace. All three take it from `room_light` (the shaders' uniform, the bake's
`lace_throws` and `lace_glow`, the tracer), the exporter's `scene.json` too; Cycles rendered
with the earlier scene and only `through` changed (`build/lace124b/cyscene65`,
`c/t65-reference*`).

As seen, the app over Cycles at 0.31 → at 0.65: the lit panel 0.62 → 0.73, the middle panel
0.90 → 1.04, the near panel in shade 0.78 → 0.77 (B/R 0.49 against 0.39, bluer: its room
light sent back is 1 − it), the wainscot under the near window 0.77 → 0.87. The room in
shade moved away: the far wainscot 1.41 → 1.57, the floor 1.62 → 1.75, the paper pier 0.69
→ 0.90, the ceiling 0.78 → 0.83; the meter's EV 4.33 → 4.19.

Each renderer with the forward share at 0 (`c/t0-reference*`, a scratch tuner), the light at
0.31 and 0.65 over that at 0:

| Region | App 0.31 | App 0.65 | Cycles 0.31 | Cycles 0.65 |
|---|---|---|---|---|
| Far wainscot | 1.27 | 1.57 | 1.13 | 1.25 |
| Paper pier | 1.54 | 2.13 | 1.06 | 1.13 |
| Floor in shade | 1.19 | 1.39 | 1.10 | 1.20 |
| Ceiling | 1.10 | 1.21 | 1.04 | 1.08 |
| Lit panel | 11.6 | 14.9 | 1.18 | 1.27 |

So the bake throws several times Cycles' share of the lace's forward light into the room
(the pier gains 1.13 of its no-throw light against Cycles' 0.13), and without it the room's
own light is short (the pier 0.48 of Cycles'): the two errors hide each other. Under task
122's hazy air the same holds (the lace adds ×1.67 to the paper in shade, ×1.33 to the
ceiling; the paper still 0.62 of Cycles').

## Decisions (2026-11-27)

- Cycles renders the lace's real mask (`scene.py --lace described`), not a plain sheet: the
  reference for the lace is Cycles with our pattern and our density rule (`LACE_DENSITY`,
  the slant power), which the app, the tracer and Cycles share, so no comparison tests that
  rule.
- `LACE_THROUGH` from a source, not tuned against Cycles (which takes the same value): the
  measured sheer above.
- Both probe changes went ahead (done above).

## Open

- The forward light thrown into the room at several times Cycles' share (the table above).
  Suspect, unmeasured: with `niche_faces` the lace cells (from `LACE_C0` on) throw their
  light to both their sides (`gather_cells`' `abs(dot)`), so what the thread sends forward
  may reach the room twice, once as the cells' and once as `lace_glow`'s on the cloth.
- The sunlit folds read black without the forward share: with it at 0 Cycles' lit panel
  keeps most of its light (the flanks' window sides the eye sees), the app's almost none.
  As seen now the lit panel is 0.73 of Cycles', under the hazy air 0.74.
- The lace in shade 1.37 of Cycles' under the hazy air (task 122); the near panel in shade
  bluer (B/R 0.49 against 0.39).
- The stove's share at the lace's probe row (window 0's room side 0.33–0.69 of the tracer):
  waits for the new stove (task 122).
- The window side's cavity share is the room side's phase mirrored, not traced (1.15–1.47
  of the tracer under 0.6 m); the per-vertex light carries the cloth's mean colour, not
  each vertex's.
- The folds drawn out of order (2026-11-27): low along the window wall (`--plan-eye
  5.0,6.45,1.25 --plan-at 2.5,6.95,0.55 --fov 40`) a far fold's triangles paint over a near
  one's in stair-stepped blocks, in every build and the default light too. The lace pipeline
  blends (premultiplied, depth test, no depth write, no culling) in the mesh's own order
  (`window_indices_by_group`); the described light makes it show more. A fix sorts back to
  front: per view, or a few presorted orders chosen by the view's direction at the draw.

## Handover

1. The bake's lace as a source against the tracer at the probes: the tracer's thread's
   light alone, `LACE_THROUGH` 0.65 against 0, the `abs(dot)` double count checked first.
   Fix, then the table above and task 122's "app over Cycles" list measured again.
2. The lit flanks: why the app's sunlit folds go dark without the forward share where
   Cycles' don't.
3. The folds' draw order.
4. Then the second criterion: the light under the lace against Cycles with a stated error.

Tools, all scratch (not in git):

- `build/lace124b/tree/`: a copy of the sources for dump builds (copy the checkout's changed
  files in first); `render3d.dump`'s `LV|` dump of each lace vertex below 1.2 m; `lv*.txt`
  the dumps (`lv-nosun`, `lv-nosky` from `--key 30,18,0,0.85` and `--baked 0,1,0,0`).
- `build/lace124b/pt/ptl`: the tracer with `lacelight FILE --rays N [--no-sky] [--no-sun]
  [--depth N]` and `firstsrc` (`path_trace_lace.goose`); `ppts.txt` the probe row's points
  (6.85 m), `tl2k.txt` the vertices at 2,048 rays a side.
- `cmpv.py` (vertices against the tracer), `cmp3.py` and `cmp3p1.py` (the row by sky and
  sun), `cmpsrc*.py`; `build/lace124/meas.py` and `solid.py` for the reference view against
  Cycles (`build/lace124/shot.sh BIN TAG reference` shoots).
- `build/lace124b/cy.sh SCENE TAG [flags]` renders Cycles at the reference view (the quiet
  lock); `cynosky/` the scene with the sky off, `cyscene65` with `through` 0.65.

## Acceptance criteria

- [x] One description of the lace (open part from its mask, the thread's transmission and
      scattering) used by the bake, the shaders, the CPU tracer and the Cycles scene
      (2026-11-27, `LACE_THROUGH` from a measured sheer the same night)
- [ ] The light under the lace in the tuner within a stated error of the reference (the
      room's light thrown from the lace several times Cycles' share on 2026-11-27)
- [x] The lace's hand-tuned terms kept, fitted or removed, as in task 122
