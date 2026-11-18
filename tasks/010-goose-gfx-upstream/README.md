# 010: Propose our goose_gfx and SDL changes upstream

Status: todo (goose_gfx first; SDL after)

Each workaround in `docs/goose-findings.md` that belongs in goose_gfx or SDL goes
upstream, so the fork and `patches/SDL/` shrink to nothing. The user sends every pull
request; a session prepares each as a small, tested branch and description.

## Subtasks

- `01-linux-wayland.md`: Wayland for gfx and ngfx, built and measured; its fork branches
  offered upstream one at a time (task 076 until 2026-11-16)
- `02-sdl.md`: what to send SDL, in the user's own words

## goose_gfx, in the order to send them

Branches of `kaitk/goose_gfx`, each on upstream `main` (two commits behind it on
2026-11-18: rebase before sending). A branch on another goes after it. The
prepared descriptions are local, in `build/notes/gfx-prs/`.

1. `no-clip-distance`: device made with clip distances off, which Mali GPUs lack
   (13 lines).
2. `no-vsync-immediate`: `NO_VSYNC` asks for immediate before mailbox (4 lines).
3. `screen-without-depth`: the screen's depth made on first `screen_depth()`, the screen
   not cycled on clear.
4. `msaa-resolve-without-store` (on 3): resolve without storing the samples, multisampled
   depth not stored.
5. `compressed-textures`: BC and ASTC formats, block-aware sizes,
   `format_supported`.
6. `draw-on-demand`: `WAIT_WHEN_IDLE`, opt-in: no present for a frame that drew nothing,
   then wait for an event. Draughts passes the flag once its submodule follows.
7. `end-on-device-lost` (on 6): quit once on a lost device instead of spinning; Vulkan's
   loss only, Direct3D 12's removal perhaps added first.
8. `window-only` (on 6 once restacked): `WINDOW_ONLY`, the window without a device; an
   issue first, as it adds the most API. Then `window-only-linux` (subtask 01).
9. Not yet a branch: `gfx::safe_area()`, beside upstream's `display_scale()` (#7), for
   the MacBook notch in full screen as well as phones.

Held in the fork (2026-11-18), since upstream gfx targets the desktop (its tested
platforms are Windows, Linux, and macOS):

- `ios-run-loop-wait`: iOS is outside upstream's platforms, and the fix belongs in SDL
  (`02-sdl.md`).
- `gamepad-wake`: split first. Reading the pads in `frame()` and the wait goes upstream
  on 6; `SYSTEM_GAMEPADS` (Apple and Android, Objective-C through the runtime) stays.

## Acceptance criteria

- [ ] Each of the above sent, or dropped with the reason here
- [ ] `ui::input_from_gfx` starts SDL text input only while a text field has focus
- [ ] Possibly `load_texture` from memory and JPEG (`docs/goose-findings.md`); we don't
      need it, so only if upstream wants it
- [ ] Possibly an Android path in goose_gfx's CMake (shared SDL), if upstream wants it
- [ ] After each lands: the fork's `main` and the submodule follow upstream, the Goose
      release bumped when it ships the API (`docs/development.md`), and
      `docs/goose-findings.md` updated
