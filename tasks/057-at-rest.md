# 057: At rest on every platform

Status: done

At rest the app should draw nothing and sleep until input or its own timer: about one
wakeup a second and well under 1% of a core, as on Android (0.04 to 0.3%,
`scripts/idle_cpu.sh`). One behaviour everywhere: `frame()` presents only what was drawn,
then blocks in the platform's real event wait, woken by input or `draughts_wake_in`
(`docs/architecture/rendering.md`, "Frames and battery").

## What was found (2026-11-10)

- **iOS**: 16% of a core on either board (the development build from 1c25f33, `--rest 25`
  through `scripts/ios_perf.py`): the main thread 8.8%, three others about 2.4% each,
  though the loop passed once a second and drew nothing. UIKit's SDL has no
  `WaitEventTimeout`, so `SDL_WaitEventTimeout` polled: the run loop for 2 µs and a 1 ms
  sleep, a thousand times a second ([findings](../docs/goose-findings.md)).
- **Mac**: 8.2% at rest at home, the loop passing 120 times a second: the Mac built with
  the release's own gfx, which presents every frame; patch 0002 was applied only in the
  Android and iOS builds.
- **Windows**: `scripts/windows.py` already builds the patched gfx, so 0002 applies, and
  SDL's Windows driver waits in `MsgWaitForMultipleObjects` and wakes on a push
  (`WIN_SendWakeupEvent`). `--rest` couldn't have built there: `memory.c` took
  `getrusage`, which Windows lacks.

## What was done

- `patches/goose_gfx/0007-wait-in-the-ios-run-loop.patch`: on iOS the idle wait runs
  the main run loop (`CFRunLoopRunInMode`) until a source fires or the timeout; an event
  pushed from another thread signals a run loop source of gfx's own through an event
  watch, which ends the wait.
- `scripts/mac.py`: the Mac's build, goose_gfx's patched sources compiled into a copy of
  the release (`build/mac/goose/`), as `windows.py` does; the docs build the Mac app with
  it. `wake.c` takes SDL's timer on the Mac too, through dlsym. With the patched gfx the
  Mac samples the photographs as ASTC.
- `--frames` runs push an event each frame (`draughts_wake_now`), so they count frames,
  not waits: the computer's reply in `--frames 5000` takes 2.4 s.
- `memory.c`: `--rest`'s CPU time and footprint on Windows (`GetProcessTimes`, private
  bytes), not yet compiled there.

At rest over 25 s (`--rest 25`):

| Where | Process CPU | `frame()` returns, draws | Footprint |
| --- | --- | --- | --- |
| iPhone 13 mini, home | 0.09% | 26, none | 216 MB |
| iPhone 13 mini, flat board, a game | 0.08% | 26, none | 59 MB |
| iPhone 13 mini, 3D board, a game | 0.08% | 26, none | 204 MB |
| iPhone 13 mini, a clock running | 0.52% | 51, 26 | 217 MB |
| Mac, home, release gfx (before) | 8.2% | 2989, none | 414 MB |
| Mac, home, patched gfx | 0.03% | 27, none | 321 MB |
| Mac, a clock running | 0.17% | 51, 26 | 338 MB |

The iPhone's other threads, 2.4% each before, now spend next to nothing.

## Acceptance criteria

- [x] The iPhone at rest under 1% of a core on both boards (`--rest 25`)
- [x] A running clock and the computer's move still wake it (the clock: a draw each
      second; the computer's reply on the Mac in a `--frames` run)
- [x] A touch on the iPhone wakes it at once (by hand; the user, 2026-11-10)
- [x] The other threads' share checked after the change
- [x] The Mac at rest under 1%
- [x] Windows: `python scripts/windows.py src/app/draughts.goose --run -- --rest 25`
      builds, and at rest is under 1%; the numbers here and in the rendering doc (works,
      the user, 2026-11-10; numbers not recorded)
