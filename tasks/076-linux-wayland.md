# 076: Wayland on Linux, for gfx and ngfx

Status: todo (decided by the user 2026-11-12: 0.2.0 ships through XWayland, Wayland next)

The Goose release's `libSDL3.a` has no Wayland (`docs/goose-findings.md`), so on a
Wayland desktop the app runs through XWayland: a fractional display scale is upscaled by
the compositor, and ngfx's first Linux presenting (task 075, not yet built) takes an X11
window. Wayland is what the desktops that have ngfx's GPUs run, so it is the main path,
with X11 kept for X11 sessions.

1. **SDL of our own in `scripts/linux.py`:** the submodule's SDL built with Wayland and
   X11 (CMake, as `android.py` and `ios.py` build it, `patches/SDL/` applied), in place of
   the release's `libSDL3.a`. The `ubuntu:22.04` distrobox needs `libwayland-dev`,
   `libxkbcommon-dev`, `libdecor-0-dev`, `wayland-protocols`, and the X11 headers. SDL
   loads the Wayland and X11 libraries at run time, so the executable still needs only
   libc and libm, and runs where either is.
2. **gfx (`kaitk/goose_gfx`):** WINDOW_ONLY on Linux gives the window SDL made: on
   Wayland its `wl_display` and `wl_surface`, on X11 its `Display*` and window, and which
   (`native_display()`, `native_window()`, and a third for the kind); drop the
   `SDL_VIDEO_DRIVER=x11` hint of `window-only-x11`.
3. **NoGraphicsAPI (`kaitk/NoGraphicsAPI`):** `DeviceDesc` names the window system, and a
   Wayland surface is made beside the Xlib one (`xlib-surface`). On Wayland the surface's
   `currentExtent` is undefined (0xFFFFFFFF), so the swapchain takes the size the caller
   gives (ngfx's resize).
4. **goose-ngfx:** one Linux open taking the display, the window, and the kind, in place
   of `open_x11`.

## Acceptance criteria

- [ ] `scripts/linux.py` builds SDL with Wayland and X11; the release still asks for
      glibc 2.35 and links only libc and libm.
- [ ] On the Bazzite PC (GNOME 50) the gfx build opens a Wayland window (`WAYLAND_DEBUG=1`
      shows its `xdg_toplevel.set_app_id("io.github.kaitk.draughts")`), sharp at 125% and
      150%; `SDL_VIDEO_DRIVER=x11` still runs it through XWayland.
- [ ] The rest and bench numbers of task 075 again on Wayland, against XWayland's.
- [ ] ngfx presents on Wayland and on X11 on the RX 6800 (the build of task 075 first),
      compared with gfx as task 074 did on Windows.
- [ ] The fork branches offered upstream one at a time, as the others are; the finding
      updated.
