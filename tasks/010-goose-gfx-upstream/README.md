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
2026-11-18: rebase before sending). A branch under another goes after it.

1. `no-clip-distance`: device made with clip distances off, which Mali GPUs lack
   (13 lines).
2. `no-vsync-immediate`: `NO_VSYNC` asks for immediate before mailbox (4 lines).
3. `screen-without-depth`: the screen's depth made on first `screen_depth()`, the screen
   not cycled on clear.
4. `msaa-resolve-without-store` (on 3): resolve without storing the samples, multisampled
   depth not stored.
5. `compressed-textures`: BC and ASTC formats, block-aware sizes,
   `format_supported`.
6. `draw-on-demand`: no present for a frame that drew nothing, then wait for an event;
   to make opt-in first.
7. `end-on-device-lost` (on 6): quit once on a lost device instead of spinning.
8. `ios-run-loop-wait` (on 6): the idle wait in the iOS run loop, not a 1 ms poll.
9. `gamepad-wake` (on 8): pads read in `frame()` and the wait, `SYSTEM_GAMEPADS`.
10. `window-only` (on 8): `WINDOW_ONLY`, the window without a device; an issue first,
    as it adds the most API.
11. `window-only-linux` (on 10): the Wayland or X11 handles (subtask 01).
12. Not yet a branch: `gfx::safe_area()`, beside upstream's `display_scale()` (#7).

## Acceptance criteria

- [ ] Each of the above sent, or dropped with the reason here
- [ ] `ui::input_from_gfx` starts SDL text input only while a text field has focus
- [ ] Possibly `load_texture` from memory and JPEG (`docs/goose-findings.md`); we don't
      need it, so only if upstream wants it
- [ ] Possibly an Android path in goose_gfx's CMake (shared SDL), if upstream wants it
- [ ] After each lands: the fork's `main` and the submodule follow upstream, the Goose
      release bumped when it ships the API (`docs/development.md`), and
      `docs/goose-findings.md` updated
