# 121: SSAO only where the bake can't reach

Status: todo

Once the props take their occlusion from the per-vertex bake (task 120), the screen's
ambient occlusion (SSAO, or GTAO in the tuner) does again what the bake already does on
them, though `TABLE_FRAG` takes the darker of the two rather than both. The bake covers
any static prop with fine geometry, and better: the whole hemisphere, the same from every
view, no halos, nothing lost at the screen's edges. It can't cover what has no vertices to
hold it or moves: the floor and walls under the props (a few large quads), the pieces on
the board and the captured ones, the board itself when the table turns. Those keep their
analytic terms (`chair_hides`, `base_hides`, the discs' shadow, the board's foot) and
SSAO where those fall short.

The aim (2026-11-25): SSAO kept to the objects that still need it, never darkening what
the bake already darkens. Removing it entirely may not be possible, given the moving
pieces. Low-end Android GPUs keep it off whatever this finds: its gain there is small for
a full-screen pass.

## Acceptance criteria

- [ ] With task 120's light the default, each view shot with SSAO and without, and the
      difference mapped: where SSAO still adds something, per object
- [ ] SSAO applied only to those objects (or its pass dropped, if analytic or baked terms
      cover them), and no surface darkened by both the bake and SSAO
- [ ] The time saved in each view and size (`tools/perf/mac_room_bench.py --full`), in
      task 110
- [ ] A decision in `docs/decisions/rendering.md`, the occlusion's description in
      `docs/architecture/rendering.md`
