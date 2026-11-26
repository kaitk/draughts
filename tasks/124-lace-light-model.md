# 124: One model of the lace's light

Status: todo

The lace curtains pass the sun and the sky through their pattern, and scatter some of it.
The renderer, the probe bake, the CPU tracer and the Cycles scene each model this their own
way (`room_light::lace_lets`, `LIGHT_FN`'s `lace_shadow`, a sheet passing 0.72 in Cycles),
with terms tuned by eye. Task 122 can't judge the lace's terms until all of them share one
model.

## Acceptance criteria

- [ ] One description of the lace (open part from its mask, the thread's transmission and
      scattering) used by the bake, the shaders, the CPU tracer and the Cycles scene
- [ ] The light under the lace in the tuner within a stated error of the reference
- [ ] The lace's hand-tuned terms kept, fitted or removed, as in task 122

## Progress

- 2026-11-26 (task 122): the CPU tracer's lace is Cycles' model (a sheet with 0.72 open,
  its thread throwing `LACE_SCATTER` of the light reaching either side on through it and as
  much back); the lace panels in the close view agree within 1.00 to 1.08. The bake and the
  shaders still take their own (`tasks/122-light-from-physical-inputs.md`, "The fourth step,
  the reference's fixes").
