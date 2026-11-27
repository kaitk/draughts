# 131: One reflected world, baked from the room

Status: in-progress

Every glossy surface sees the same room: the room as it is drawn, baked from a point or a few
into a map at the light's bake, blurred into a level for each roughness, and read along the
reflected ray corrected to the room's box (box-projected, "parallax-corrected" probes). It
replaces the analytic box in its three copies (room.goose's `room_seen`, table.goose's
`props_seen_at`, `niche_seen`'s fallback), the sharp/wide smoothstep and each material's own
share of sharpness, and the glass's photograph harmonics.

Why (the user, 2026-11-27, from task 130's floor and `build/notes/reflections/`): the app had
five reflected worlds. Against Cycles' panoramas the analytic box's paper and floor read up to
2× and 4–6× too bright (hand-set albedos), it holds no stove, books, lace or furniture, and each
glossy material needed its own patch. The sun moves only with a rebake, so the reason a cube
map was rejected (2026-11, `docs/decisions/rendering.md`: "a pass per face, and the room
changes with the sun") no longer holds.

Measure each step against Cycles' panoramas (`tools/blender/scene.py --pano X,Y,H`) and the
tuner's `--env-pano`, from the same points.

## Where it stands (2026-11-27)

The floor's wax reads the baked map; nothing else does yet. `--refl off` gives the box back.

- [x] 1. The bake (`render3d_gpu::refl_pass`): the room drawn from the box's middle, 1 m up,
  in six 90° views of 128² (`MIRROR_PASS` with `PHYSICAL_COAT`, the view out first), packed
  into a 256² octahedral RGBA16F map (`REFL_PACK_FRAG`; not a cube: ngfx's translator reads
  only `sampler2D`), baked again on `refl_key`. Against Cycles' panorama, each region over the
  ceiling's ratio: the paper 1.0–1.05 (the old box 1.1–1.9), the wainscot 0.6, the window
  0.73, the floor by the wall 0.4–0.9. It shows the bookcases, doors, lace, stove, table and
  chairs.
- [x] 2. The levels (`REFL_FILTER_FRAG`): six, roughness 0, 0.2 … 1, the GGX lobe in 256
  samples, each from the mip its share of the lobe spans (filtered importance sampling, no
  bias; Křivánek's +1 spread the glow into a haze).
- [x] 3. The lookup (`refl_seen`), and 3b, the grazing lobe: `floor_reflection` takes four
  taps up the reflection's vertical plane at the GGX slope's quartiles, each at the lobe's
  width across (0.7 α × the look's sine), weighted by Fresnel and masking, none under the
  floor, no tilt toward the normal (one round lookup spread each window over the floor:
  5–13× too bright in shade). The floor's image error against Cycles 0.13 (16 importance
  samples 0.26); the shade 1.01× Cycles'; the window corner's glow 8.2 (Cycles 10.7). Page
  `build/notes/reflections/grazing.html`.
- [ ] 3c. The floor's pale band (the user, 2026-11-27): in the reference view the floor
  between the rug and the near window's wainscot reads grey-blue, almost as light as the
  lace, where Cycles' is dark and warm. Measured (`build/lace124/meas.py`'s units, the
  stable tuner at 887db847, tree off): by the wainscot 2.07 of Cycles' light, B/R 0.31
  against 0.07; nearer the camera 1.72, B/R 0.30 against 0.09; with `--refl off` 0.90 and
  1.12. The baked reflection's lookup there, not the lace. Crops:
  `build/lace124b/strip.png` (now, `--refl off`, Cycles).
- [ ] 4. The brass, the gilt, the glaze, the window hardware, the table, chairs, board and
  pieces, the glass on the same lookup; the old box code and its patches removed.
- [ ] 5. Phones (its size, the A33), ngfx at parity, the bake's time; the decision and the
  architecture docs.

## Open

- The floor's band (step 3c), cause not measured.
- The middle window's glow before the rug 2.2× Cycles'.
- The bake's floor reads lighter and more orange than the room's.
- The lookup's cost: inside the quick bench's spread, not measured on its own.

## Handover

1. Step 3c: what the four taps read at the band's points (`--env-pano 4` from a floor point
   there) against Cycles' glossy pass; fix, then the middle window's glow.
2. Step 4, material by material against Cycles' panoramas, removing each one's box code.
3. Step 5, then the docs.

## Acceptance criteria

- [ ] One reflection lookup for every glossy material, no per-material sharpness patches
- [ ] Its panorama within Cycles' (region by region, as `build/notes/reflections/`)
- [ ] The floor's reflections of the doors and the windows read as the concepts' matt floor
      (the shade 1.01× Cycles' on 2026-11-27; the band by the near window open)
- [ ] Bake time, memory and frame cost recorded, on the Mac and the A33
- [x] `docs/decisions/rendering.md` records it replacing the cube map's rejection;
  `docs/architecture/rendering.md` describes it (2026-11-27, bbb393ff; under "The physical
  light", to be widened with steps 4 and 5)
