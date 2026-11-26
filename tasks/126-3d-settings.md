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
