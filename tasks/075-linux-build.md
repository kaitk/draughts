# 075: Linux build and release

Status: in-progress (built, released, and played on the Bazzite PC 2026-11-12; the
hands-on checks below, the gamepad at rest, and ngfx left)

Draughts for desktop Linux (x64): `scripts/linux.py` beside `windows.py`, a tarball on the
GitHub release beside the Mac and Windows zips, checked on the Bazzite PC (Fedora-based,
immutable, distrobox at hand). Also the way to task 064's Linux depot. How to build and
run is in `docs/development.md` (Run on Linux, Desktop releases).

## What was settled (2026-11-12)

- The program's C calls SDL directly on Linux (`src/app/platform.h`): the Mac's `dlsym`
  lookups found nothing in an executable that exports no SDL symbols.
- The release is built in an Ubuntu 22.04 distrobox with Clang 20 (gcc 11 has no
  `#embed`) and asks for glibc 2.35; built on a newer system it asks for what Fedora
  refuses. The Goose compiler itself needs 2.35 (task 010/01). `CC` reaches Goose as
  `GOOSE_CC`.
- The app id is `io.github.kaitk.draughts` (`SDL_APP_ID`, set beside
  `draughts_choose_gpu`); the tarball holds the executable, its `.desktop` file, a 256 px
  icon, and `install.sh` for `~/.local`.
- TinyCC can't run under SELinux, so `test/run_tests.py --build` (89 pass).
- At rest (`--rest 25`) 0.01% of a core on every screen, 0.05% with a clock running;
  the numbers are in `docs/architecture/rendering.md`'s table.
- The tarball is on the draft `Draughts 0.2.0` (task 010/01 replaced it with the Wayland
  build).

Numbers on the Bazzite PC (RX 6800, RADV, 1920 × 1080 at 60 Hz) are in task 010/01.

## Acceptance criteria

- [x] `scripts/linux.py` builds the app with the fork's gfx, and `--run` runs it.
- [x] The program's C calls SDL directly on Linux; the settings are saved.
- [x] `--release` makes the tarball, needing glibc 2.35, built in Ubuntu 22.04.
- [x] The tests pass on Linux.
- [x] On Bazzite: cloned, built in the distrobox, run on the host with its GPU.
- [ ] Both boards played with the mouse in a real window, every screen visited; the 3D
      board's crash in WSLg's llvmpipe found (it doesn't happen on the GPU). `--board 3d`
      headless and windowed; each `--aa` way.
- [x] Wayland and X11, resizing, fullscreen, display scales, and closing by the X
      (task 010/01).
- [x] The icon and app id.
- [x] The idle loop measured and recorded in rendering.md's table.
- [ ] **A gamepad at rest:** Linux takes gfx's generic path, as Windows does (no
      `SYSTEM_GAMEPADS` system wake there): measure the idle CPU with a pad connected and
      untouched, and that a press wakes the loop at once, with Steam running and not. If
      the poll costs, propose udev/evdev's fd in the wait to the fork.
- [ ] Keyboard and gamepad focus (task 072) on Linux: arrows, Enter, Escape, A and B.
- [x] The locale: `LANG=et_EE.UTF-8` opens in Estonian.
- [ ] A saved game resumes after quitting; `--reset-skill` and the rest of the flags as on
      the Mac.
- [x] Frame times on both boards, capped and `--no-vsync` (task 010/01).
- [x] ngfx on Linux (task 010/01).
- [x] The release uploaded to the draft with its Linux paragraph and SHA-256.
- [x] Linux-only findings recorded in `docs/goose-findings.md`.
