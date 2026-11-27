# 130: The parquet, procedural

Status: in-progress

The floor's herringbone stays ours and procedural (the user, 2026-11-27): no downloaded texture
ships. From the Poly Haven pick (`herringbone_parquet`, task 122's wood round) it borrows what
reads better: calmer, natural grain, a reflection that holds together, joints that catch the
light. Ours keeps its layout to the walls and each block's own colour, tilt and cup. Work goes
in stages, one look each, so the user can say whether it is better. ChatGPT's brief,
`~/Downloads/parquet_shader_reference_updated.pdf` (local), is a source of ideas, not a spec:
its micrometre pores, scratch curves and fibre lobe don't resolve at the room's distances.

Shots: `build/floor-matt/shots.sh TAG [flags]` in the `floor-matt` worktree (autumn,
`--light physical`; the concepts' framing, a view across the floor to the windows, a close one
looking down);
pages under `build/notes/floor-matt/`. The tuner's `--floor-finish X,Y,Z,W` sets the floor's
finish in place of `WOOD_FINISHES`' (the base's roughness X to Y, the coat's weight Z and
roughness W); under `--light physical` the floor's mirror takes the coat's.

## Stages

- [x] 0. How glossy. Today's full coat at 0.08, satin (1.0 at 0.22), soft (1.0 at 0.38) and
  matt (0.5 at 0.5) beside `style-01` and `library-autumn-02`. The user picked matt: a warm
  sheen where the sun falls, no image of the window, as the concepts. The floor's
  `WOOD_FINISHES` and the Cycles export's `tools/blender/woods/ours.json` take 0.5 at 0.5.
  With the shine gone the grain's dark, engraved-looking lines are the loudest thing left.
- [x] Size and the tuned floor (2026-11-27). The tuned floor (`--woods ... tuned`, task 122's way
  toward the Poly Haven parquet: 3.5 × 28 cm planks, tighter rings, its own stain range and
  plank warmth) is dropped; the floor is ours, 7 × 42 cm (`PLANK_W`, `PLANK_N`), the period's
  size (about 6–9 cm by 30–60 cm; not checked against a source). The pick (`--woods
  ours,ours,picks`, its textures in `build/wood-candidates/`; the tuner silently falls back to
  ours without them) stays only as a reference: fine worn grain, strong tone between blocks.
- [x] 2a. The grain, tried: 80% quarter-sawn (calm, straight), 95% (bamboo-like), fainter late
  wood (no change), a much wider stain range (dark and flat). The user keeps today's grain
  (45% quarter-sawn) for now; the later stages are shown with it and with its contrast softened
  (`--floor-range 0.022,0.080`, ours 0.0288–0.0734). Against the concepts the difference is the
  grain's contrast beside the blocks' own tones: theirs fine and faint, the blocks apart in tone.
- [x] 1. The grain in the reflection (2026-11-27): the wax film's share of the grain's relief
  (`--floor-film-grain`) swept 0.25, 0.12, 0.05, 0; under the matt wax hardly different, 0 the
  window's glow clean. 0.05 picked, the same cost as 0 (one multiply).
- [ ] 2b. The grain, later: fainter and finer, more tone between blocks.
- [x] 3. The joints (2026-11-27): each plank's edges rounded down into the joint (`--floor-joint
  WIDTH_MM,SLOPE,DARK`), the slope averaged over the pixel's footprint (`joint_slope`) and what it
  can't resolve widening the wax's lobe; the floor's mirror takes a quarter of it, as of the
  grain (the whole swung the reflected ray across the room and beaded the edges). Tried 2 mm and
  3 mm, slopes 0.5 and 0.8, the joint as dark or half; the user picked 2 mm at 0.5, half as
  dark, checked in motion. Open for the end: the dark joint still shows as a line inside the
  window's reflection; with it at 0 (the mirror kept across the joint too) the line went but
  that had issues of its own. Not yet in the Cycles export.
- [x] 4. The blocks' cup and tilt (2026-11-27, `--floor-shape CUP,TILT`): today's 0.012 and 0.01,
  nearly flat (0.004, 0.003, the brief's new floor), more tilt (0.025, the glow's edge stepping
  block to block), more cup (0.03, each plank shaded across its width). The user picked more
  cup, more natural: 0.03 and 0.01 under `--light physical`. Wear left as it is.
- The tuner's panel (Wainscot, with the floor ours under `--light physical`): the planks' cup and
  tilt, the joints' rounding, its slope and darkness, the grain in the wax; P prints them.

## Open for the end

- The dark joint as a line inside the window's reflection (stage 3).
- 2b, the grain.
- The Cycles export: the matt wax only; not the joints, cup and tilt.
- The floor shader's cost (the rounding's filter), measured at the task's end.

## Acceptance criteria

- [ ] Each stage shown to the user and kept or dropped
- [ ] The app's floor and Cycles' agree under the same light and camera
- [ ] `docs/architecture/rendering.md` and `docs/decisions/rendering.md` say what the floor
  is once `--light physical` becomes the app's
