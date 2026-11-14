# 055: Frames locked to the display

Status: in-progress

While something moves, every frame should be on screen for exactly one refresh: both
boards locked to the display's rate on every device. Counted by the compositor
(`scripts/device_perf.sh`: SurfaceFlinger's timestats over the bench's presented frames;
`scripts/ios_perf.py` with Instruments' Animation Hitches on the iPhone), as the app's own
clock can't tell how long a frame stayed on screen. A dropped frame is one that wasn't
ready for a refresh.

Trap: the bench's first phase waits for the GPU after every frame, so its frames miss
refreshes by design; a count must not overlap it.

## Measured, 2026-11-10 (release from 1aaf406)

| Device | Flat: dropped of ~990 | 3D: dropped of ~990 |
| --- | --- | --- |
| Tablet, 90 Hz | 0 | 172 (17%), 77 / 45 fps; none of 994 after task 059 |
| Pixel 7a, 60 Hz | 0 | 1 |
| Galaxy A33, 90 Hz | 0 | every other frame (23 ms of GPU work), a steady 60 |
| iPhone 13 mini, 60 Hz | 0 to 5 (pacing: task 056) | 1 |

The flat board's loop does 1.0 ms of CPU work a frame; `tools/pace.goose` ruled out the
pacing itself (no drop in 1815 frames, also with a busy GPU and the app's uploads).

The 3D board needs room to spare at the clock the Android GPU governor picks, not just at
the top one; task 042 holds the candidates for cutting its cost.

## Acceptance criteria

- [x] The tablet's flat board drops no frame over 1000 presented ones
- [x] The same on the Pixel 7a
- [x] The same on the Galaxy A33
- [ ] The 3D board drops no frame on the tablet and the Pixel 7a (the A33 at least a
      steady rate): the tablet done; the Pixel 1 of 995 (task 056's longer run to check)
- [ ] A screen transition counted the same way
