# 010: Propose our goose_gfx and SDL changes upstream

Status: in-progress (goose_gfx PRs open; SDL after)

Each workaround in `docs/goose-findings.md` that belongs in goose_gfx or SDL goes
upstream, so the fork and `patches/SDL/` shrink to nothing. The user sends every pull
request; a session prepares each as a small, tested branch and description.

## Subtasks

- `01-linux-wayland.md`: Wayland for gfx and ngfx, built and measured; its fork branches
  offered upstream one at a time (task 076 until 2026-11-16)
- `02-sdl.md`: what to send SDL, in the user's own words

## goose_gfx: where it stands (2026-11-18)

Branches of `kaitk/goose_gfx`, each on upstream `main` (`2ead633`), authored
`kait@kasak.ee`. Descriptions, prefilled links, the issue text and the Discord message are
local, in `build/notes/gfx-prs/` (its `README.md` lists them). A description is about gfx:
Draughts appears only where the change was tested (`agents/writing.md`).

Open upstream, with their `docs/stdlib.md` companions in Goose:

| goose_gfx | Branch | Goose docs |
|---|---|---|
| #10 | `no-clip-distance`: device made without clip distances, which Mali GPUs lack | none |
| #11 | `no-vsync-immediate`: `NO_VSYNC` asks for immediate before mailbox | none |
| #12 | `screen-without-depth`: the screen's depth made on first `screen_depth()`, the screen not cycled | #370 |
| #13 | `compressed-textures`: BC and ASTC formats, `format_supported`; a KTX2 loader offered as the next PR | #371 |
| #14 | `msaa-resolve-without-store` (on #12): MSAA resolved without storing samples | #372 |
| #15 | `draw-on-demand`: `WAIT_WHEN_IDLE`, opt-in | #373 |
| issue #16 | `window-only`, `window-only-linux`: the window without a device, for another renderer | |

Ready on the fork, to send after #15 settles (each says "Builds on #15"):
`end-on-device-lost` (Vulkan's loss only; Direct3D 12's removal perhaps added first) and
`gamepad-wake` (pads read in `frame()` and the wait). `window-only` and
`window-only-linux` wait for the answer on #16. Not yet a branch: `gfx::safe_area()`,
beside upstream's `display_scale()`, for the MacBook notch in full screen as well as
phones. Each new API needs its Goose `docs/stdlib.md` companion, as above.

Held in the fork, since upstream gfx targets the desktop (Windows, Linux, macOS):
`ios-run-loop-wait` (iOS isn't upstream's; the fix belongs in SDL, `02-sdl.md`) and
`system-gamepads` (`SYSTEM_GAMEPADS`: Apple and Android, Objective-C through the runtime).

`upstream-series-next` merges every branch, held ones included: what Draughts builds from
next. The fork's `main` (`15de5e0`, the submodule's pin) still has the older versions,
with draw on demand always on.

## Next

1. Run gfx's suite and showcase on a Mac once, for the macOS column of upstream's
   "Platforms tested" table (`docs/gfx.md`: macOS "not run"), and draft that PR.
2. Merge `upstream-series-next` into the fork's `main` (a merge, not a reset, so every
   commit the submodule has pinned stays reachable).
3. Move the submodule to it; Draughts opens with `WAIT_WHEN_IDLE` and `SYSTEM_GAMEPADS`
   to keep drawing on demand. Check on the Mac, then the tablet.

## Acceptance criteria

- [ ] Each branch above sent, or dropped with the reason here
- [ ] `ui::input_from_gfx` starts SDL text input only while a text field has focus
- [ ] Possibly `load_texture` from memory and JPEG (`docs/goose-findings.md`); we don't
      need it, so only if upstream wants it
- [ ] Possibly an Android path in goose_gfx's CMake (shared SDL), if upstream wants it
- [ ] After each lands: the fork's `main` and the submodule follow upstream, the Goose
      release bumped when it ships the API (`docs/development.md`), and
      `docs/goose-findings.md` updated
