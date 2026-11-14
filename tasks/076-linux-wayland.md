# 076: Wayland on Linux, for gfx and ngfx

Status: in-progress (built, run, and measured on the Bazzite PC 2026-11-12; the pull
requests, the user's, left)

The Goose release's `libSDL3.a` has no Wayland (`docs/goose-findings.md`), so the app ran
through XWayland, a fractional scale upscaled by the compositor. Wayland is what the
desktops with ngfx's GPUs run, so it is the main path, X11 kept for X11 sessions.

## What was built (2026-11-12)

- `scripts/linux.py` builds the submodule's SDL with Wayland and X11 (`patches/SDL/`
  applied); SDL loads both at run time, so the executable still links only libc and libm.
- NoGraphicsAPI `linux-presentation` (`d41f3aa`, on upstream `ffd9f2a`): one commit for
  the pull request; `DeviceDesc::window_system` (Wayland or Xlib),
  `set_drawable_extent` for a Wayland swapchain, `max_surface_formats` 256 (RADV lists 72
  for a Wayland surface). Its tests: 29 pass, 8 skip as before.
- goose_gfx `window-only-linux` (`6b709d3`, on `window-only`): `native_window()`,
  `native_display()`, and `native_kind()` from SDL's current driver.
- goose-ngfx `ngfx::open(window, w, h, flags, display, kind)`, the last two defaulting to
  0 for every other platform (the user chose one call over an `open_linux`, 2026-11-12).
- Draughts: `scripts/ngfx.py` builds on Linux in the `goose` box (its shader compiler
  built rather than `goose run`, for SELinux); `host_gpu.goose` passes gfx's display and
  kind.
- On Wayland at 125% and 150% the buffer is the window times the scale, sharp, on both
  renderers. libdecor's title bar loads GTK on GNOME: 17 MB more PSS than XWayland.
- The release tarball (from `c4cecb0`, SHA-256
  `b5cfe2ecbeb87ff0ee681124bc1ba085603d622c40d0e40f52257347f7f64b3e`) replaced the
  XWayland one on the draft `Draughts 0.2.0`; played by the user on Wayland and XWayland,
  the gamepad included.
- The glibc floor stays 2.35: the Goose compiler itself needs it, so an older floor would
  need the C made on a newer system and compiled in the older one, as `android.py` does.

## Numbers (Bazzite 44, GNOME 50, RX 6800 on RADV, 1920 × 1080 at 60 Hz)

At rest (`--rest 25`) on Wayland: 0.01 to 0.02% CPU on both renderers, nothing drawn;
0.05% (gfx) and 0.08% (ngfx) with a clock running.

`--bench 1000` full screen, uncapped, presented fps (avg / 1% low), medians of three:

| run | gfx Wayland | gfx XWayland | ngfx Wayland |
| --- | --- | --- | --- |
| flat | 8,238 / 5,602 | 6,940 / 4,465 | 7,700 / 5,017 |
| 3D off | 4,354 / 2,487 | 3,950 / 1,770 | 4,007 / 3,757 |
| 3D msaa (gfx's default) | 3,599 / 2,557 | 3,308 / 1,324 | – |
| 3D smaa (ngfx's default) | 3,482 / 2,934 | 3,183 / 1,369 | 3,123 / 2,791 |

Both hold 60 capped. The release SDL's spiky 1% lows (task 075's 158) were its own, not
XWayland's. On RADV ngfx presents 7 to 13% fewer frames than gfx, unlike the RTX 4090
(task 074); a GPU trace (`RADV_THREAD_TRACE` or RGP) would say why. ngfx's flat capped
waited time counts the wait for the window's image.

Nothing here grabs a Wayland window non-interactively: the screenshot portal waits on a
permission dialog and stalls every SDL program's Wayland start until
`systemctl --user restart xdg-desktop-portal`.

## Acceptance criteria

- [x] `scripts/linux.py` builds SDL with Wayland and X11; the release still asks for
      glibc 2.35 and links only libc and libm.
- [x] On GNOME 50 the gfx build opens a Wayland window, sharp at 125% and 150%;
      `SDL_VIDEO_DRIVER=x11` still runs it through XWayland.
- [x] The rest and bench numbers of task 075 again on Wayland, against XWayland's.
- [x] ngfx presents on Wayland and on X11 on the RX 6800, compared with gfx.
- [ ] The fork branches offered upstream one at a time (pushed, findings updated; the pull
      requests are the user's: `linux-presentation` to `sebbbi/NoGraphicsAPI`,
      `window-only-linux` to `aardappel/goose_gfx` after `window-only`).
- [x] The glibc floor checked: 2.35 kept, with the reason.
