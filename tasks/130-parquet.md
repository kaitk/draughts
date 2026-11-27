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
- [ ] 1. The grain out of the reflection: its share of the wax film's normal (a quarter
  today) down to 10–25% of it. Less urgent under a matt wax; look before tuning.
- [ ] 2b. The grain, later: fainter and finer, more tone between blocks.
- [ ] 3. The joints: soft shoulders that catch light, not dark lines.
- [ ] 4. The blocks' tilt and cup; wear only if it still shows.

## Acceptance criteria

- [ ] Each stage shown to the user and kept or dropped
- [ ] The app's floor and Cycles' agree under the same light and camera
- [ ] `docs/architecture/rendering.md` and `docs/decisions/rendering.md` say what the floor
  is once `--light physical` becomes the app's
