# 128: The light in the window niche

Status: in-progress (built behind `--niche-light`, for the user to judge)

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

- [x] The cause found with numbers from the tracer (the path-traced reference is ground
      truth), not theories
- [x] Fixed, behind a light tuner flag defaulting off if it changes the look, with shots
      before and after and against Cycles at the casement view (`--plan-eye 4.2,6.15,1.3
      --plan-at 4.75,7.6,1.55 --fov 50`) and a close one (`--plan-eye 4.3,6.8,2.2 --plan-at
      4.5,7.4,2.42 --fov 22`)
- [x] The room's other points against the tracer (task 122's `tuner` and props modes) the
      same or better
- [x] `volumes`' 0.3 m slack in `baked_light` decided on measurement
- [x] Results on `build/notes/niche-light/index.html`; the numbers recorded here
- [ ] The user's look at the shots; then `--niche-light` on by default under
      `--light physical`, or not

## The cause (2026-11-27)

Scratch `pts` modes `niche` (300 points the two views see: the tracer, the atlas, and the
tracer's own light at the probes the lookup mixes), `wprobes`, `nsrc`, `ncells`, `meter`.

- Not the probes' placement: the tracer's light at the probes the lookup reads, mixed as
  the lookup mixes them, gives the niche's faces 1.0 to 1.5 of the truth and the wall 1.0.
  The probes' values are short, by sources the bake lacks.
- The sun the inner casement's members stop on the room's side of the inner pane was
  dropped (`sun_patches` scales the ray by what passes): at the niche's probes 0.013 to
  0.015 of 0.06 to 0.17, nothing in the bake.
- The casement's front had no cells: 0.006 to 0.015 more; the niche's own cells (sill,
  reveals, head) were half the tracer's (head 0.48, sill 0.76) for the same reason.
- The row 0.15 m before the wall stands 3 cm in front of the lace; the wall, the shutters'
  fronts and the frames in the niche's mouth face the lace's back. Toward the wall: tracer
  0.026, bake 0.0098, the lace 0.014 against 0.
- The probes under a sill (z 0.75 m) and over a head are inside the wall and took the
  room's row: the bottom rail read 0.0094 against 0.0426.
- `baked_light`'s `d < -0.3` is in world units (30.48 a metre): 1 cm, as commented. Kept.

## The fix (`--niche-light on`, `room_light::niche_light`)

`member_sun` (the members' stopped sun as patches by face, half and band, and into the
bounces), `casement_cell` (the inner casement's front, 2 × 5 cells a window), `lace_on_wall`
(the lace's back in the light the row before the wall settles toward it),
`niche_above_below` (walled probes under a sill or over a head copy the niche's), and the
camera's meter without the casement's cells. Tried and dropped: the space between the panes
seen from the niche as a source (no change at the faces).

Off: the atlas and the shots byte-identical to before. On, against the tracer:

| Measure | Before | After |
|---|---|---|
| Bottom rail | 0.0094 | 0.0262 (tracer 0.0426) |
| Niche head, 0.2 m in | 0.0221 | 0.0303 (0.0510) |
| Window wall beside the niche | 0.0079 | 0.0419 (0.0255) |
| Sill, 0.2 m in | 0.0685 | 0.0896 (0.0959) |
| Transom face | 0.0424 | 0.0431 (0.0448) |
| 132 niche points (geo mean, error factor) | 0.52, 2.22 | 0.74, 1.64 |
| 168 wall points round it | 0.53, 2.13 | 0.98, 1.48 |
| Frames' sides in the niche | 0.54 | 0.75 |
| Frames' room faces in the niche | 0.53 | 0.68 |
| Faces in the niche's mouth toward the room | 0.17 | 0.51 |
| Probes 0.15 m / 2 m / 6 m before the wall | 0.54 / 0.70 / 0.80 | 0.61 / 0.76 / 0.83 |
| Task 122's 22 props points | 0.51, 2.04 | 0.55, 1.93 |

(task 127's "inner sash stile" point lands on the pane, not wood.) The camera's meter rises
with the room: EV 2.54 → 2.41, the picture 0.13 EV darker overall. The bake 176 to 183 ms →
200 to 211 ms on the Mac; nothing per frame.

Left: the frames' room faces deep in the niche at 0.68 (one probe row 0.15 m in; a probe
volume over the niche's air would hold it); single wall points up to 2× behind the folded
lace (the bake's lace is flat, task 124); the probes' light toward the glass is L1 only.
