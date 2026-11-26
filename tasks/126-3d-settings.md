# 126: 3D settings as data: presets, layers, and the stored overrides

Status: todo (designed 2026-11-26, `build/notes/3d-settings/`)

Every rendering choice the app makes, and those the room and later tasks add, held in one
structure: one field per category (frames, resolution, antialiasing, shadows, surfaces,
and the room's light, occlusion, reflections, window light, HDR, depth of field,
atmosphere, outside), each with a few named levels, and above them `lighting`, never
shown to players, `baked` today. Presets per tier (phone, tablet, desktop) are data; layers
resolve in the order preset, platform, detected, player, dev flag. A field whose content is
absent (the room, an add-on on some platforms only) or whose lighting isn't in force
doesn't apply. `render3d::apply` is the one place that turns fields into switches. Refines
the tiers of 2026-11-20 (a per-tier table in one place), adds no menu.

The user's answers (2026-11-26): the names as proposed (`lighting = baked`, `3d.` keys in
`settings.txt`); the device class fixed at startup; an unknown Android device measured
once, hidden, at first start to pick phone or tablet quality (the result stored, measured
again after an update that changes the scene); when frames are missed, after 2× MSAA the
room gives up its effects first (the mirror to the box, then the window's light, then the
occlusion, then the atmosphere) and the resolution last.

## Acceptance criteria

- [ ] `settings3d` (no graphics): the fields, their names and levels, `NEEDS`, `Layer`,
      `resolve`, `preset`, `parse` and `write`; tests in `test/settings3d/` for the layers'
      order, the room absent, a dependency (depth of field without HDR), unknown keys and
      values, and a round trip of the file
- [ ] The presets' table holds today's values: the app's frames, shots and pipelines are
      byte-identical before and after on the Mac (gfx and ngfx), at a phone's, the
      tablet's and a desktop's sizes (`scripts/test.sh`)
- [ ] `render3d::apply` replaces the tier lines in `app::follow_screen` and the light
      tuner's start; the tuner's `--tier`, `--phone-tier`, `--aa`, `--gtao`, `--hdr`,
      `--planar-size`, `--scene-*`, `--phone-leaves` map onto `--3d` and `--3d-preset`
- [ ] The device class chosen at startup from the platform and the display, no longer
      following the window's size each frame; only the resolution follows the window; a battery found per platform for `frames = on_mains`
- [ ] The content bits at startup: `ROOM` off in a build without the room; the room's
      fields then make no pipelines or targets (memory at rest unchanged on the A33 and
      the tablet, task 071's way)
- [ ] The slow-device step-down (2× MSAA) moved into the detected layer, unchanged in
      behaviour; a player override wins over it
- [ ] `3d.` keys in `settings.txt`, only the player's layer, with `3d.version`; an older
      file without them reads as before
- [ ] The About card lists the resolved fields, marking those detection lowered
- [ ] A decision in `docs/decisions/rendering.md` (the structure, the startup class,
      replacing the per-frame `!phone` switches); `docs/architecture/rendering.md`'s tier
      mentions point to the presets' table
- [ ] The first-start measurement on Android and the step-down's order, tested on the
      A33 and the tablet

## Later: ray-traced sun shadows on the highest tier (the user, 2026-11-26)

A `shadows` level `traced` on the highest desktops (RDNA2 and up, NVIDIA RTX, Apple M3 and
up), under `lighting = baked`, for the near occluders only. The sun reaches the room only
through the windows, and a point that can't see a window's opening is already known shaded
(the window's light map and the niches' outlines), so the rays need only what stands
between a lit point and the glass: the table, the chairs, the board and its pieces, the
shell's edges by the windows. That's a few hundred thousand static triangles, built once,
plus the pieces, which move rarely. The casements and the lace stay in the window's light
map, exact already; the maple, far outside, keeps its shadow map: its shadow is wide and
soft, and keeping it there avoids refitting its moving, alpha-cut leaves each frame. The gain
is the props' and the pieces' shadows: contact-sharp, softening with distance at the sun's
real disc, no map resolution. First: ray queries and acceleration structures in goose-ngfx,
through our fork of NoGraphicsAPI: a lean, minimal "trace some rays here" call only, as its
author proposes, tested on NVIDIA and RDNA2 (Linux); the Mac's Metal path written too (Metal's intersection
queries run on every Apple GPU, in hardware from M3), kept to "compiles and runs" on the M1; then a
measure against today's shadow maps. gfx (SDL GPU) has no ray tracing and none is planned
there: on gfx the level isn't offered, or, the occluders being few, a ray walk in the
shader over a small fixed tree of their triangles, measured before it's offered.

## ngfx as the renderer of the high tier (the user, 2026-11-26)

Ray tracing comes to ngfx only: a first use that shows why it exists. MSAA may be dropped from
ngfx altogether (NoGraphicsAPI's author doesn't want it upstream, and SMAA measured better
in the room's complex scene): first measured on the iPhone, where ngfx ships and MSAA is
nearly free on a tiled GPU while SMAA is a full-screen pass. A decision against the parity
rule between gfx and ngfx, to record when done.
