# 122: The room's light rebuilt from physical inputs

Status: todo

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

To measure: `build/perf/light_tune-before122` is built (the tuner before this task's
changes); its times with `tools/perf/mac_room_bench.py --full` wait for a quiet machine.

## Acceptance criteria

- [ ] The CPU tracer in `tools/` (the room's triangles from `model3d`, physical inputs, a
      points mode and a picture mode), its numbers agreeing with Cycles' as in task 120
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
