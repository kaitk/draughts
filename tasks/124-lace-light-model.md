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
