# 128: The light in the window niche

Status: in-progress

Under `--light physical` the window frame's wood and the window's metal inside the niche (the
deep window recess) are lit far darker than Cycles lights them: the faces of the frame inside
the frame "do not get the light Cycles gives them" (the user, comparing the tuner against
Cycles in `build/notes/box-window/hardware.html`). Task 127's box window shows the same, so it
is the niche's baked light, not the window's geometry.

Task 127's session measured it with a scratch copy of the CPU path tracer
(`build/scratch/pts/pts.goose`, `frames` mode: the baked atlas as `ROOM_FRAG`'s `baked_light`
reads it against the tracer at the real surface, luminance over pi). Window B, atlas against
tracer:

| Face | Atlas | Tracer |
|---|---|---|
| Bottom rail | 0.0094 | 0.0426 |
| Niche head, middle, 0.2 m in | 0.022 | 0.051 |
| Window wall face beside the niche | 0.0078 | 0.0255 |
| Reveal behind the shutter | 0.089 | 0.168 |
| Sill | 0.068 | 0.096 |
| Inner sash stile, 1.5 m | 0.070 | 0.317 |
| Transom face | 0.042 | 0.045 |

The frame's stiles were about right. Also found: `baked_light`'s `if (d < -0.3) continue;`
(`PROBE_VOLUMES`) takes a volume's light in full up to 0.3 m outside it, against its
comment's "a centimetre's slack"; decide it on measurement.

Not this task: the warmer, more saturated cast over the whole view against Cycles (the sun's
colour and the grade, task 122); note it if measured.

## Acceptance criteria

- [ ] The cause found with numbers from the tracer (the path-traced reference is ground
      truth), not theories
- [ ] Fixed, behind a light tuner flag defaulting off if it changes the look, with shots
      before and after and against Cycles at the casement view (`--plan-eye 4.2,6.15,1.3
      --plan-at 4.75,7.6,1.55 --fov 50`) and a close one (`--plan-eye 4.3,6.8,2.2 --plan-at
      4.5,7.4,2.42 --fov 22`)
- [ ] The room's other points against the tracer (task 122's `tuner` and props modes) the
      same or better
- [ ] `volumes`' 0.3 m slack in `baked_light` decided on measurement
- [ ] Results on `build/notes/niche-light/index.html`; the numbers recorded here
