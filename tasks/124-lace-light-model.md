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
