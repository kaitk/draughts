# 057: The iPhone at rest

Status: todo

At rest the app should cost next to nothing, as on Android (0.04 to 0.3% of a core,
`docs/architecture/rendering.md`, "Frames and battery"). On the iPhone 13 mini it costs
16% of a core on either board (2026-11-10, the development build from 1c25f33, measured
with `--rest 25` through `scripts/ios_perf.py`): its loop passes once a second and draws
nothing, as it should, yet its threads stay busy.

## What was found

Over 25 s at rest on the flat board, from `--rest`'s list of the threads' CPU time
(none of them named):

| Thread | CPU in 25 s | Of a core |
| --- | --- | --- |
| The first, the main thread, which runs the loop | 2.21 s | 8.8% |
| Three others | 0.53 to 0.63 s each | about 2.4% each |

goose_gfx's `frame()` waits for events in `SDL_WaitEventTimeout` after a frame that drew
nothing (`patches/goose_gfx/0002-draw-on-demand.patch`). UIKit's video driver has no
`WaitEventTimeout`, so SDL falls back to polling: `SDL_PumpEvents` (which runs the run
loop for 2 µs) and a 1 ms sleep, a thousand times a second
(`SDL_events.c`, `SDL_WaitEventTimeoutNS`, `EVENT_POLL_INTERVAL_NS`). The other threads'
share is likely woken by the same pumping; to be checked once it stops.

## Direction

On iOS, wait in the run loop itself: `CFRunLoopRunInMode(kCFRunLoopDefaultMode, timeout,
true)` returns when a source fires (a touch, a system event), and then `SDL_PumpEvents`
reads what came. The app's own timer (`wake.c`'s `draughts_wake_in`, the clock's next
change and the computer's move) must then wake the run loop too (`CFRunLoopWakeUp` on the
main loop). A goose_gfx patch for the iOS build, with a findings entry
(`docs/goose-findings.md`); SDL itself gets only a note for the user (AGENTS.md).

## Acceptance criteria

- [ ] The iPhone at rest under 1% of a core on both boards (`--rest 25`)
- [ ] A touch, a running clock, and the computer's move still wake it at once
- [ ] The other threads' share checked after the change
