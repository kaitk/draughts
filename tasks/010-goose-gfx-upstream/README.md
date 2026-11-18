# 010: Propose our goose_gfx and SDL changes upstream

Status: in-progress (goose_gfx PRs open; SDL after)

Each workaround in `docs/goose-findings.md` that belongs in goose_gfx or SDL goes
upstream, so the fork and `patches/SDL/` shrink to nothing. The user sends every pull
request; a session prepares each as a small, tested branch and description.

## Subtasks

- `01-linux-wayland.md`: Wayland for gfx and ngfx, built and measured; its fork branches
  offered upstream one at a time (task 076 until 2026-11-16)
- `02-sdl.md`: what to send SDL, in the user's own words
- `03-cute-spirv-direct3d12.md`: cute_spirv's HLSL storage buffers and keywords, fixed
  for cute_framework and then Goose; the first instance on Direct3D 12 still open

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
| #17 | `headless-apple`: headless on macOS keeps the default video driver | none |
| #18 | `macos-tested` (on #17): the macOS column, and two `test/window` fixes | none |
| #19 (draft) | `end-on-device-lost` (on #15): `frame()` ends on Vulkan's lost device | none |
| #20 (draft) | `gamepad-wake` (on #15): pads read in `frame()` and the wait | none |

#19 and #20 stay drafts until #15 settles. `window-only` and `window-only-linux` wait for the answer on #16. Not yet a branch: `gfx::safe_area()`,
beside upstream's `display_scale()`, for the MacBook notch in full screen as well as
phones. Each new API needs its Goose `docs/stdlib.md` companion, as above.

#17 and #18 (sent 2026-11-18), from gfx's suite, `test/window` and showcase on the Mac (2026-11-18,
M1 Pro, macOS 26, Goose `master` `745901f` built with upstream `main`'s gfx in `build/goose`,
gfx in `build/gfx-mac`, both local):

- `headless-apple` (12): since upstream #8 headless opens SDL's offscreen driver, which
  SDL_GPU's Metal backend refuses, so every headless program on macOS has no GPU device and
  Goose's suite skipped its 10 rendering gfx and ui tests and 4 gfx samples. Apple's
  systems keep Cocoa. `upstream-series-next` takes #8, so the fork's `main` needs it too.
- `macos-tested` (13, on 12): the macOS column filled in, and two `test/window` fixes:
  `run_window_test.py` linked no native showcase on any platform (Goose's runtime object,
  since Goose `d285793`), and the showcase's input check failed with no focus, which macOS
  doesn't give a window a terminal starts.

With both: Goose builds with gfx (no warnings from gfx) and without; the suite passes with
gfx at -O0, -O2, and TinyCC, and without it skipping them; `run_input_test.py` passes;
`run_window_test.py` passes in-process and with clang on Metal, screenshots identical.
Goose's own `completion bash, run` fails either way.

Held in the fork, since upstream gfx targets the desktop (Windows, Linux, macOS):
`ios-run-loop-wait` (iOS isn't upstream's; the fix belongs in SDL, `02-sdl.md`) and
`system-gamepads` (`SYSTEM_GAMEPADS`: Apple and Android, Objective-C through the runtime).

`upstream-series-next` merges every branch, held ones included. The fork's `main`
(`b8cd74b`, the submodule's pin since 2026-11-18) merges it into the old `main` (`15de5e0`,
whose tree it replaces, so every earlier pin stays reachable) and then `headless-apple`.
Draughts opens with `WAIT_WHEN_IDLE` and `SYSTEM_GAMEPADS`, as draw on demand is now
opt-in. At rest on the Mac (a game, flat, 25 s): gfx 0.017% of a core, ngfx 0.037%, the
loop 26 times, nothing drawn; headless shots and `scripts/test.sh` pass. On the Pixel 7a
(the `.dev` install; the main app there has another signature), 60 s at home: the program's
thread 0.12%, 60 wakeups, but the process 4.8%, nearly all of it AAudio's and SDL's audio
threads: the open sound device, which this didn't change. The iOS simulator (iPhone 13
mini, `ios-run-loop-wait`'s new version): 0.056%, the loop 26 times in 25 s, nothing drawn.
Not yet on the tablet, nor on an iOS device.

## Next

1. Check the move to `b8cd74b` on the tablet over USB (idle CPU, `install -r`).
2. `audio-pause`, once built: with sound on, SDL's audio thread mixes silence the whole
   session (the Pixel 7a at rest: 4.5% of a core, against 0.12% for the program's thread),
   as gfx's audio has no pause. A fork branch with `audio::pause(on)` and its Goose
   `docs/stdlib.md` companion; Draughts pauses a few seconds after the last sound and
   resumes on a press. Measure the resume's delay to the first sound on the Pixel and the
   A33, then offer it upstream.

## Acceptance criteria

- [ ] Each branch above sent, or dropped with the reason here
- [ ] `ui::input_from_gfx` starts SDL text input only while a text field has focus
- [ ] Possibly `load_texture` from memory and JPEG (`docs/goose-findings.md`); we don't
      need it, so only if upstream wants it
- [ ] Possibly an Android path in goose_gfx's CMake (shared SDL), if upstream wants it
- [ ] After each lands: the fork's `main` and the submodule follow upstream, the Goose
      release bumped when it ships the API (`docs/development.md`), and
      `docs/goose-findings.md` updated
