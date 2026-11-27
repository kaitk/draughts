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

## Steps

- [x] 1. The bake (2026-11-27, `render3d_gpu::refl_pass`): the room drawn from the box's middle,
  1 m up, in six 90° views of 128² (its groups and the table in `MIRROR_PASS` with
  `PHYSICAL_COAT`, the floor too, the view out first), each packed into a 256² octahedral
  RGBA16F map (`REFL_PACK_FRAG`; octahedral, not a cube: ngfx's translator reads only
  `sampler2D`), its mips tents as the mirror's. Baked again on `refl_key` (the box map's key, the
  woods, the paper). Its panorama (`--env-pano 8,...`) beside Cycles' at the floor and the middle,
  each region over the ceiling's ratio: the paper 1.0–1.05 (the old box 1.1–1.9), the wainscot
  0.6, the window 0.73, the floor by the wall 0.4–0.9. It shows the bookcases and books, the
  doors, the lace, the stove, the table and chairs.
- [x] 2. The levels (`REFL_FILTER_FRAG`): six, roughness 0, 0.2 … 1 (α its square), the GGX lobe
  in 256 samples, each from the mip its share of the lobe spans (filtered importance sampling,
  no bias: with 64 samples and Křivánek's +1 every sample read a 16-texel level and the glow
  spread into a haze).
- [x] 3. The lookup (`refl_seen`): the floor's matt wax reads it where the reflected ray meets
  the room's box, from the probe, at roughness × 5, the ray turned toward the floor's normal
  as the wax roughens (Frostbite's dominant direction: without it the lobe round a grazing
  ray took the bake's floor under the horizon, an orange veil over the far floor). The door's
  reflection is a soft glow; in the corner by the window (task 130's camera) the glow over the
  near floor 2.5× (Cycles 3.3×, the old box 2.0×), the far shade 4.5× (5.9×, 3.3×). `--refl off`
  gives the box back. Open: the bake's floor reads lighter and more orange than the room's; the
  app's shade about twice Cycles' (task 122's indirect light, not this).
- [ ] 4. The brass, the gilt, the glaze, the window hardware, the table, chairs, board and
  pieces, the glass on the same lookup; the old box code and its patches removed.
- [ ] 5. Phones (its size, the A33), ngfx at parity, the bake's time; the decision and the
  architecture docs.

## Acceptance criteria

- [ ] One reflection lookup for every glossy material, no per-material sharpness patches
- [ ] Its panorama within Cycles' (region by region, as `build/notes/reflections/`)
- [ ] The floor's reflections of the doors and the windows read as the concepts' matt floor
- [ ] Bake time, memory and frame cost recorded, on the Mac and the A33
- [ ] `docs/decisions/rendering.md` records it replacing the cube map's rejection;
  `docs/architecture/rendering.md` describes it
