# 075: Linux build and release

Status: in-progress (built and run in WSL 2026-11-12; the Linux machine's checks and the
release left)

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

## Acceptance criteria

- [x] `scripts/linux.py` builds the app with the fork's gfx, and `--run` runs it.
- [x] The program's C calls SDL directly on Linux; the settings are saved.
- [x] `--release` makes the tarball, needing glibc 2.35, built in Ubuntu 22.04.
- [x] The tests pass on Linux.
- [ ] On Bazzite: clone, fetch the Goose Linux release (Run on Linux), build in the
      `ubuntu:22.04` distrobox (Desktop releases), and run the build on the host with its
      GPU. Record the GPU, driver, and session (KDE or GNOME, Wayland).
- [ ] Both boards played with the mouse in a real window, every screen visited; the 3D
      board's crash in WSLg either gone on the GPU or found and fixed. `--board 3d`
      headless and windowed; each `--aa` way.
- [ ] Wayland and X11: SDL picks Wayland where there is one; also run with
      `SDL_VIDEO_DRIVER=x11` (XWayland). Resizing, maximizing, `--size full`, a display
      scale of 125% or 150% (`draughts_display`'s scale and the layout), and the window
      closed by its X (the desktop asks before quitting, e4c15b9).
- [ ] The icon: gfx names the app "Goose" (`SDL_HINT_APP_NAME`), and Wayland matches a
      window to its `.desktop` file by app id, so the window and taskbar likely show a
      generic icon. Set `SDL_HINT_APP_ID` (or `SDL_SetAppMetadata`) to
      `io.github.kaitk.draughts` before gfx opens the window (`display.c` beside
      `draughts_choose_gpu`), name the tarball's file `io.github.kaitk.draughts.desktop`
      with `StartupWMClass` to match, and for X11 a window icon (`SDL_SetWindowIcon`).
      Check where the tarball's `.desktop` and icon go to show in the menu
      (`~/.local/share/applications`, `~/.local/share/icons/hicolor/256x256/apps`): say so
      in the release notes, or ship an install line.
- [ ] **The idle loop** (the fork's draw-on-demand and its wait, `docs/architecture/rendering.md`,
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
- [ ] The locale: `LANG=et_EE.UTF-8` opens in Estonian (`locale.c`), English otherwise.
- [ ] A saved game resumes after quitting; `--reset-skill` and the rest of the flags as on
      the Mac.
- [ ] Frame times: `--bench` on both boards, capped and `--no-vsync`, against Windows'
      numbers on the PC where they compare.
- [ ] NoGraphicsAPI on Linux (task 065, "Presenting on Linux"): whether the driver has
      `VK_EXT_descriptor_heap` (`vulkaninfo | grep descriptor_heap`; RADV or NVIDIA's,
      whichever the Bazzite PC has), then a Vulkan surface from SDL
      (`SDL_Vulkan_CreateSurface`) in goose-ngfx's layer, and the ngfx build
      (`scripts/ngfx.py`) run and compared with gfx as task 074 did on Windows.
- [ ] The release: the tarball built in the distrobox, extracted into a fresh folder and run
      on the host; uploaded to the GitHub draft `v0.2.0` (the Mac's zip and Windows' are
      its others) with a Linux paragraph and its SHA-256 in the notes, asked of the user
      first. Linux needs Vulkan (Mesa or NVIDIA's driver) and glibc 2.35.
- [ ] Any Linux-only finding in Goose, goose_gfx, or SDL recorded in `docs/goose-findings.md`.
