# 076: Wayland on Linux, for gfx and ngfx

Status: in-progress (built, run, and measured on the Bazzite PC 2026-11-12; the pull
requests, the user's, left)

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
   gives (ngfx's resize). The pull request to `sebbbi/NoGraphicsAPI` offers Linux
   presenting as one change: Wayland first, X11 the fallback where it stays cheap (the
   user, 2026-11-12), so `xlib-surface` grows into that branch rather than going alone.
4. **goose-ngfx:** one Linux open taking the display, the window, and the kind, in place
   of `open_x11`.

5. **The glibc floor:** 2.35 (Ubuntu 22.04) came from the release's `libSDL3.a`, which
   needs `hypotf@GLIBC_2.35`. With SDL built here, only the Goose runtime and the
   program's own C set it: build in an older container (Debian 11's 2.31, the Steam
   Runtime's sniper, for task 064) if the compiler there takes `#embed`.

The clones are in `../goose/` (goose-ngfx, goose_gfx, and NoGraphicsAPI inside
goose-ngfx). The ngfx toolchain is on the Bazzite PC: slangc 2026.18.3 in `~/slang/bin/`,
the Vulkan SDK 1.4.363 in `~/vulkansdk/1.4.363.0/` (`source
~/vulkansdk/1.4.363.0/setup-env.sh`, with `spirv-val`), and the `goose` distrobox (Fedora
43) has the X11 and Wayland headers and `libglvnd-devel` now.

## Done on the Bazzite PC (2026-11-12)

Bazzite 44, GNOME 50 on Wayland, Ryzen 5 9600X, RX 6800 on RADV (Mesa 26.2.4), 1920 × 1080
at 60 Hz, as in task 075. Each fork's branch was rewritten from the local `xlib-surface`
and `window-only-x11`, which were never pushed, and is pushed now:

- **NoGraphicsAPI** `linux-presentation` (`d41f3aa`, on upstream `main` `ffd9f2a`), one
  commit for the pull request: `DeviceDesc::window_system` (`wayland`, the default, or
  `xlib`) says what `window` and `display` are, and a Wayland or Xlib surface is made.
  Neither `wayland-client.h` nor `Xlib.h` is needed to build it: the WSI headers take a
  few declarations. `set_drawable_extent(device, extent)` gives a Wayland swapchain the
  window's size, as a Wayland surface's `currentExtent` is undefined; elsewhere it does
  nothing. `max_surface_formats` went from 64 to 256: RADV lists 72 for a Wayland surface
  (each format in each of its color spaces), and 64 refused the device ("Required Vulkan
  device, memory, or display capabilities are unavailable"). The README and docs no longer
  say Linux is headless. Its tests built Debug in the `goose` box and run on the host:
  29 pass, and the 8 that skip are queue-family tests RADV's queues don't fit, as before.
  The fork's `ngfx` (`98225fb`, the same change on its older base) and `main` (`21b5a8b`).
- **goose_gfx** `window-only-linux` (`6b709d3`, on `window-only`): on Linux
  `native_window()` is the `wl_surface` on Wayland or the X11 window's number,
  `native_display()` its `wl_display` or `Display*`, and `native_kind()` which
  (`NATIVE_WAYLAND` 1, `NATIVE_X11` 2), from SDL's current video driver; no video-driver
  hint, so SDL picks Wayland where there is one. Picked into `upstream-series`
  (`76d8b29`) and `ngfx` (`bc34f35`), `main` (`15de5e0`) merging `upstream-series`;
  `test/api_check.py` passes but on `ngfx`, whose ASTC and BC constants were missing in
  `gfx.goose` before this.
- **goose-ngfx** `de55ced`, then `ngfx::open(window, w, h, flags, display, kind)` in place
  of `open_x11` (the last two default to 0, so one call serves every platform; a separate
  `open_linux` first made every caller choose between two, the user chose this
  2026-11-12), with `NATIVE_WAYLAND` and `NATIVE_X11` as gfx's, the swapchain
  sized by `create_screen` on Wayland, and its four samples opening that way on Linux.
  Its tests built in the `goose` box (`run_tests.py --aot --cc clang`) and run on the
  host: all 26 pass, each test also under `GOOSE_NGFX_SYNC=full`, and `cube` and
  `ui_todo` present in a window on Wayland and on X11. Fedora's GCC names Goose's build
  folder `gcc-15.3.1-1)-...`, which breaks SDL's Wayland step in the gfx package (its
  findings), hence clang.
- **Draughts:** `scripts/linux.py` builds SDL (above); `scripts/ngfx.py` builds on Linux,
  in the `goose` box, building its shader compiler instead of `goose run`ning it (SELinux),
  and `host_gpu.goose` passes gfx's display and kind to `ngfx::open`.

**SDL with Wayland.** The submodule's SDL (3.4.16, the Goose release's version) built with
the Goose package's options and Wayland and X11 required, in the `draughts-jammy` box: 20
s with the app. Its objects are the release's `libSDL3.a`'s plus Wayland's, and the same
audio, IME, and input backends once the box has their headers (`development.md`). The
host's GCC builds then link it. The executable still links only libc, libm, and the
loader, glibc 2.35.

**On Wayland** (`WAYLAND_DEBUG=1`): `xdg_toplevel.set_app_id("io.github.kaitk.draughts")`
and `set_title("Draughts")`, libdecor's title bar on GNOME, Mesa's WSI presenting. At a
display scale of 125% the window opens 1280 × 800 logical with buffers of 1600 × 1000, and
after GNOME fits it to the screen 1536 × 795 with 1920 × 994; at 150% 1280 × 651 with
1920 × 977: the buffer is the window times the scale and the viewport maps it 1:1, so it
is sharp, for gfx and ngfx alike, and the layout takes the scale (`draughts.png` at 150%,
1920 × 977, the UI 1.5 times). Through XWayland the buffer stays 1280 × 800 and GNOME
scales it. `--size full` configures 1920 × 1080, and ngfx's buffers follow, the resize
from the window's first size included. (Set with `gdctl set -L -M HDMI-1 --primary
--scale 1.25`, not persistent, and back to 1.)

**At rest** (`--rest 25`), on Wayland:

| run | gfx CPU | ngfx CPU | passes, drawn | PSS (gfx) |
|---|---|---|---|---|
| home | 0.01% | 0.01% | 26, none | 82 MB |
| full screen, flat, a game | 0.01% | 0.02% | 26, none | 84 MB |
| full screen, 3D, a game | 0.02% | 0.02% | 26, none | 89 MB |
| a clock running (Russian, `5+3`, c3-d4) | 0.05% | 0.08% | 53, 27 | 90 MB |

As through XWayland (task 075: 0.01%, 0.01%, 0.01%, 0.05%), but 17 MB more PSS: on GNOME
libdecor's plugin loads GTK 3, Cairo, and Pango for the title bar.

**Benches**, full screen, Russian, wood, the start, `--bench 1000`, three rounds
interleaved, medians (the rounds within 3%, but gfx's 3D off on Wayland, 4,365 / 3,939 /
4,354). XWayland is `SDL_VIDEO_DRIVER=x11`, the same builds:

| run | gfx Wayland | gfx XWayland | ngfx Wayland | ngfx XWayland |
|---|---|---|---|---|
| flat | 8,238 / 5,602, 0.15 / 0.20 | 6,940 / 4,465, 0.16 / 0.22 | 7,700 / 5,017, 0.19 / 0.25 | 7,474 / 4,958, 0.15 / 0.43 |
| 3D off | 4,354 / 2,487, 0.21 / 0.32 | 3,950 / 1,770, 0.24 / 0.34 | 4,007 / 3,757, 0.22 / 0.31 | 3,856 / 2,257, 0.24 / 0.33 |
| 3D msaa (gfx's default) | 3,599 / 2,557, 0.26 / 0.38 | 3,308 / 1,324, 0.29 / 0.41 | – | – |
| 3D fxaa | – | – | 3,191 / 2,984, 0.29 / 0.40 | 3,080 / 2,283, 0.30 / 0.42 |
| 3D smaa (ngfx's default) | 3,482 / 2,934, 0.27 / 0.40 | 3,183 / 1,369, 0.30 / 0.42 | 3,123 / 2,791, 0.30 / 0.41 | 3,023 / 2,320, 0.31 / 0.43 |
| 3D ssaa | – | – | 1,664 / 1,582, 0.56 / 0.79 | 1,627 / 1,547, 0.57 / 0.81 |
| flat, capped | 60 / 58, 0.51 / 0.63 | | 60 / 58 | |
| 3D, capped | 60 / 58, 0.72 / 1.11 | | 60 / 58, 0.76 / 1.15 | |

Each cell: presented fps (avg / 1% low), waited P50 / P99 ms. The CPU a frame is 0.008 to
0.016 ms uncapped, 0.02 to 0.03 capped.

- **Wayland against XWayland:** gfx presents 9 to 19% more frames on Wayland, its 1% lows
  1.4 to 2.1 times as high; ngfx 3 to 4% more. Capped, both hold 60.
- **Against task 075's XWayland numbers** (flat 2,932 / 158, 3D off 1,795 / 174): those
  came with the Goose release's SDL. The 0.2.0 executable run again now through XWayland
  gives 2,674 and 3,071 flat with 1% lows of 140 to 172 (one run of three 6,978), and 1,602
  to 1,971 on the 3D board; the same app with the SDL built here gives 6,940 / 4,465
  through XWayland. The spiky frames were the release SDL's, not XWayland's; what in its
  build differs wasn't looked into.
- **ngfx against gfx on RADV:** unlike Windows' RTX 4090 (task 074, ngfx 1.35 to 1.8
  times gfx's frames), on the RX 6800 ngfx presents 7% fewer frames flat, 8% fewer on the
  3D board without antialiasing, 10% fewer with SMAA on both, and 13% fewer at each one's
  default (its SMAA against gfx's MSAA); its waited P50 is 0.01 to 0.04 ms longer. Its 1%
  lows are higher on the 3D board without antialiasing (3,757 against 2,487). Why RADV
  favors SDL_GPU's frame is open: a GPU trace (`RADV_THREAD_TRACE` or RGP) would say.
- ngfx's flat capped run shows a waited P50 of 16.6 ms and its CPU 16.1 ms, on X11 too: the
  flat frame takes the window's image first, so capped it counts the wait for the display.
  The frame rate is unaffected.

**ngfx's window, looked at:** through XWayland, `import -window Draughts` (ImageMagick)
showed the 3D game full and right. Nothing here grabs a Wayland window: the screenshot
portal's non-interactive call waited on a permission dialog, and while it waited every
SDL program's Wayland start stalled 50 s on the portal (`Settings.ReadOne` timing out),
until `systemctl --user restart xdg-desktop-portal`. On Wayland its presents are in the
protocol (`create_immed` buffers of the window's pixel size, an attach each frame), and
the samples' `cube` and `ui_todo` present 120 of 120 frames.

**The release:** `CC=clang-20 scripts/linux.py src/app/draughts.goose --release` in the
box: 12.0 MB (11,985,195 bytes), the executable 16.0 MB, linking only libc and libm,
`GLIBC_2.35`. Extracted into a fresh folder and run on the host: Wayland, the app id, the
3D game with c3-d4 played. Not uploaded (0.2.0 shipped its XWayland tarball).

**The glibc floor** stays 2.35. What asks for it is the build's own glibc (`hypotf@2.35`;
`pthread_*`, `dlopen`, and `__libc_start_main@2.34`; `stat@2.33`), all of which older
glibcs have under older versions, so a build against 2.31 would ask for 2.31. But the
Goose compiler itself needs 2.35 (on Debian 11: "version `GLIBC_2.34' not found"), so
nothing older can run the build: the floor would drop only by making the C with Goose on a
newer system and compiling it in the older one, as `android.py` and `ios.py` do. Debian 11
(2.31, the Steam Runtime's sniper too) is past its end of life: deb.debian.org's security
pool 404s its packages until the sources point at archive.debian.org; Clang 20 from
apt.llvm.org installs there. It has no libdecor, so GNOME's Wayland window would lose its
title bar. Tried in a throwaway `debian:11` distrobox, since removed.

## Acceptance criteria

- [x] `scripts/linux.py` builds SDL with Wayland and X11; the release still asks for
      glibc 2.35 and links only libc and libm.
- [x] On the Bazzite PC (GNOME 50) the gfx build opens a Wayland window (`WAYLAND_DEBUG=1`
      shows its `xdg_toplevel.set_app_id("io.github.kaitk.draughts")`), sharp at 125% and
      150%; `SDL_VIDEO_DRIVER=x11` still runs it through XWayland.
- [x] The rest and bench numbers of task 075 again on Wayland, against XWayland's.
- [x] ngfx presents on Wayland and on X11 on the RX 6800 (the build of task 075 first),
      compared with gfx as task 074 did on Windows.
- [ ] The fork branches offered upstream one at a time, as the others are, NoGraphicsAPI's
      as one pull request for Wayland with the X11 fallback; the finding updated. (The
      branches pushed and the findings updated, 2026-11-12; the pull requests are the
      user's: `linux-presentation` to `sebbbi/NoGraphicsAPI`, `window-only-linux` to
      `aardappel/goose_gfx` after `window-only`.)
- [x] The glibc floor checked: lowered below 2.35 if the build allows, or 2.35 kept with
      the reason.
