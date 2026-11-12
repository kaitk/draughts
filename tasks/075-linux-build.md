# 075: Linux build and release

Status: in-progress (built and run in WSL, then on the Bazzite PC with the release's
tarball, 2026-11-12; the hands-on checks, the gamepad, and ngfx left)

Draughts for desktop Linux (x64): `scripts/linux.py` beside `windows.py`, a tarball on the
GitHub release beside the Mac and Windows zips, and the checks only a Linux machine with
a GPU can make: the Bazzite PC (Fedora-based, immutable, distrobox at hand). Also the way
to task 064's Linux depot, and to NoGraphicsAPI presenting on Linux (task 065).

## Done on the Windows PC, in WSL (2026-11-12)

WSL's Ubuntu 26.04 (WSLg, Mesa's llvmpipe for Vulkan, no GPU) and an Ubuntu 22.04 chroot
inside it.

- `scripts/linux.py` builds as `windows.py` does: the Goose release
  `goose-v2026.4-linux-x64` copied to `build/linux/goose/`, its `libgoose_gfx.a` rebuilt
  from the fork's sources, the release's `libSDL3.a` linked statically. 26 s from clean.
- **SDL called directly on Linux** (`src/app/platform.h`): with the Mac's `dlsym` lookups
  the executable found nothing, as it exports no SDL symbols, so the storage folder came
  back empty (nothing saved) and the wake timer, locales, safe area, and display scale were
  silently missing. Now `~/.local/share/kaitk/draughts/` gets `settings.txt` and
  `player-1.txt`.
- **glibc:** built on Ubuntu 26.04 the executable asks for glibc 2.43 (gcc 15's libm:
  `sqrtf`, `acosf`, `fmodf`), which Fedora 43's 2.42 refuses. Built in Ubuntu 22.04 with
  Clang 20 from apt.llvm.org (22.04's gcc 11 has no `#embed`) it asks for 2.35, which the
  Goose release's `libSDL3.a` needs anyway (`hypotf`). `CC` reaches Goose as `GOOSE_CC`,
  by path, since Goose takes only the names clang, gcc, and cc.
- The release: `Draughts-0.2.0-linux-x64.tar.gz`, 12.3 MB (12,857,734 bytes), holding
  `Draughts/draughts` (16.0 MB stripped, 755), `draughts.desktop`, and `draughts.png`
  (`ios/icon-1024.png`); it links only libc and libm.
- Run from the extracted tarball: headless (`GOOSE_GFX_HEADLESS=1`) home and the 3D board
  drawn right; in a WSLg window the flat board played by the user with the mouse, the
  computer answering. The 3D board in the WSLg window crashed (llvmpipe through WSLg;
  headless it drew), not looked into.
- `test/run_tests.py` and `scripts/native.py` take the Linux Goose release on Linux: 89
  tests pass in WSL.
- Docs: `docs/development.md`'s Run on Linux and Desktop releases' Linux, with the
  distrobox recipe.

## On the Bazzite PC (2026-11-12)

Bazzite 44 (Fedora Silverblue based, glibc 2.43, GCC 16), GNOME 50 on Wayland, Ryzen 5
9600X, RX 6800 on RADV (Mesa 26.2.4), a 1920 × 1080 display at 60 Hz on HDMI. Built on the
host with GCC 16 (10 s) for development, and the release in the `draughts-jammy` distrobox
(Ubuntu 22.04, Clang 20): `GLIBC_2.35`.

- **Clone:** goose_gfx's own submodules are needed too (`git submodule update --init
  --recursive`), or gfx's sources miss `SDL3/SDL.h`; development.md says so now.
- **No Wayland:** the Goose release's `libSDL3.a` has X11 and offscreen video only, so on
  GNOME's Wayland the app runs through XWayland (`SDL_VIDEO_DRIVER=wayland`: "wayland not
  available"; findings). The windowed 3D and flat boards, with `--frames`' shots, draw
  right on the GPU: WSLg's 3D crash doesn't happen here.
- **The app id:** SDL's app id was the executable's name. `draughts_choose_gpu` now sets
  `SDL_APP_ID` to `io.github.kaitk.draughts` and `SDL_APP_NAME` to Draughts, over gfx's
  "Goose", on Linux: `xprop` reads `WM_CLASS "draughts", "io.github.kaitk.draughts"` and
  `WM_NAME "Draughts"`. The tarball holds `io.github.kaitk.draughts.desktop`
  (`StartupWMClass` the same; `desktop-file-validate` passes), the icon
  `io.github.kaitk.draughts.png` (256 px, `linux/`, from `windows/draughts.ico`), and
  `install.sh`, which copies the three to `~/.local` (`--remove` takes them away), tried
  with a throwaway `HOME`. No `_NET_WM_ICON`: GNOME takes the icon from the `.desktop` file.
- **Tests:** TinyCC can't run under SELinux (findings); `test/run_tests.py --build`
  passes all 89.
- **The tarball:** 12.0 MB (12,011,815 bytes), SHA-256
  `521f4a58539378498f55d278bb3443520b8ce3240120223c6069b0fc90093252`, the executable
  16.0 MB, needing only libc and libm. Extracted into a fresh folder and run on the host:
  the 3D game with a move played, and home in Estonian (`LANG=et_EE.UTF-8`) with the saved
  game offered.
- **At rest** (`--rest 25`, rendering.md's table): home, the flat board, and the 3D board
  full screen 0.01% of a core, 26 passes, nothing drawn; a running clock (Russian, `5+3`,
  c3-d4 played so Black's clock runs) 0.05%, 51 passes, 26 drawn. A plain `goose build`
  (the release's gfx) 0.65% at home, 1,502 passes. The footprint is now the PSS on Linux
  (`memory.c`): 65 MB at home, 68 flat, 72 on the 3D board, the GPU's memory outside it.
- **Benches**, full screen at 1920 × 1080 (XWayland), Russian, wood, the start,
  `--bench 1000`, three rounds interleaved, medians:

  | run | presented fps (avg / 1% low) | waited P50 / P99 ms | cpu ms |
  |---|---|---|---|
  | flat, `--no-vsync` | 2,932 / 158 | 0.21 / 0.56 | 0.008 |
  | 3D off, `--no-vsync` | 1,795 / 174 | 0.34 / 0.95 | 0.010 |
  | 3D msaa (the default), `--no-vsync` | 1,620 / 196 | 0.41 / 0.98 | 0.013 |
  | 3D smaa, `--no-vsync` | 1,654 / 225 | 0.42 / 0.94 | 0.017 |
  | flat, capped | 60.0 / 59.6 | 0.23 / 0.57 | 0.018 |
  | 3D, capped | 60.0 / 59.6 | 0.43 / 0.97 | 0.033 |

  The rounds agree within 10% (3D off 1,795 / 1,762 / 1,947). The 1% lows, about a tenth
  of the average, are occasional 4 to 7 ms frames uncapped, likely XWayland's; capped,
  none is late. The RX 6800 waits 0.34 to 0.42 ms for a 3D frame at 1080p against the
  4090's 0.33 to 0.40 at 1440p (task 074).

- **The release:** uploaded to the draft `Draughts 0.2.0` (untagged, beside the Windows
  zip; the Mac's zip still to come), with a Linux paragraph, `install.sh`, XWayland, and the
  SHA-256 in the notes (2026-11-12). Wayland is task 076, after 0.2.0 (the user, 2026-11-12).

## Acceptance criteria

- [x] `scripts/linux.py` builds the app with the fork's gfx, and `--run` runs it.
- [x] The program's C calls SDL directly on Linux; the settings are saved.
- [x] `--release` makes the tarball, needing glibc 2.35, built in Ubuntu 22.04.
- [x] The tests pass on Linux.
- [x] On Bazzite: clone, fetch the Goose Linux release (Run on Linux), build in the
      `ubuntu:22.04` distrobox (Desktop releases), and run the build on the host with its
      GPU. Record the GPU, driver, and session (KDE or GNOME, Wayland).
- [ ] Both boards played with the mouse in a real window, every screen visited; the 3D
      board's crash in WSLg either gone on the GPU or found and fixed. `--board 3d`
      headless and windowed; each `--aa` way.
- [ ] Wayland and X11: SDL picks Wayland where there is one; also run with
      `SDL_VIDEO_DRIVER=x11` (XWayland). Resizing, maximizing, `--size full`, Alt+Enter and F11 in and out of fullscreen, a display
      scale of 125% or 150% (`draughts_display`'s scale and the layout), and the window
      closed by its X (the desktop asks before quitting, e4c15b9).
- [x] The icon: gfx names the app "Goose" (`SDL_HINT_APP_NAME`), and Wayland matches a
      window to its `.desktop` file by app id, so the window and taskbar likely show a
      generic icon. Set `SDL_HINT_APP_ID` (or `SDL_SetAppMetadata`) to
      `io.github.kaitk.draughts` before gfx opens the window (`display.c` beside
      `draughts_choose_gpu`), name the tarball's file `io.github.kaitk.draughts.desktop`
      with `StartupWMClass` to match, and for X11 a window icon (`SDL_SetWindowIcon`).
      Check where the tarball's `.desktop` and icon go to show in the menu
      (`~/.local/share/applications`, `~/.local/share/icons/hicolor/256x256/apps`): say so
      in the release notes, or ship an install line.
- [x] **The idle loop** (the fork's draw-on-demand and its wait, `docs/architecture/rendering.md`,
      "Frames and battery"): at rest the app draws nothing and wakes about once a second.
      Measure process CPU over 25 s (`--rest 25`) at home, on the flat board, the 3D
      board, and with a clock running (it must still tick each second on time, `wake.c`);
      record them in rendering.md's table beside the Mac's and Windows'. Compare with a
      plain `goose build` (the release's gfx, presenting every frame).
- [ ] **A gamepad at rest:** Linux takes gfx's generic path, as Windows does (no
      `SYSTEM_GAMEPADS` system wake there): measure the idle CPU with a pad connected and
      untouched, and that a press wakes the loop at once. Steam Input on Bazzite may show
      the pad as a virtual one; try it with Steam running and not. If the poll costs, the
      way to propose to the fork is udev/evdev's fd in the wait.
- [ ] Keyboard and gamepad focus (task 072) on Linux: arrows, Enter, Escape, A and B.
- [x] The locale: `LANG=et_EE.UTF-8` opens in Estonian (`locale.c`), English otherwise.
- [ ] A saved game resumes after quitting; `--reset-skill` and the rest of the flags as on
      the Mac.
- [x] Frame times: `--bench` on both boards, capped and `--no-vsync`, against Windows'
      numbers on the PC where they compare.
- [ ] NoGraphicsAPI on Linux (task 065, "Presenting on Linux"): whether the driver has
      `VK_EXT_descriptor_heap` (`vulkaninfo | grep descriptor_heap`; RADV or NVIDIA's,
      whichever the Bazzite PC has), then a Vulkan surface from SDL
      (`SDL_Vulkan_CreateSurface`) in goose-ngfx's layer, and the ngfx build
      (`scripts/ngfx.py`) run and compared with gfx as task 074 did on Windows.
- [x] The release: the tarball built in the distrobox, extracted into a fresh folder and run
      on the host; uploaded to the GitHub draft `v0.2.0` (the Mac's zip and Windows' are
      its others) with a Linux paragraph and its SHA-256 in the notes, asked of the user
      first. Linux needs Vulkan (Mesa or NVIDIA's driver) and glibc 2.35.
- [x] Any Linux-only finding in Goose, goose_gfx, or SDL recorded in `docs/goose-findings.md`.
