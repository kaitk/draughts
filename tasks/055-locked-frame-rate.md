# 055: Frames locked to the display

Status: in-progress

While something moves, every frame should be on screen for exactly one refresh; the user
wants both boards locked to the display's rate on every device. Counted by the
compositor (`scripts/device_perf.sh`: SurfaceFlinger's timestats over the bench's
presented frames, between its `presenting` and `presented` lines), as the app's own
clock can't tell how long a frame stayed on screen: from it the bench said the tablet's
flat board had a 1% low of 70 fps, where the compositor counts none dropped. A dropped frame is one
that wasn't ready for a refresh, so the one before it stayed on screen for two or more.

## Measured, 2026-11-10

The release built from 1aaf406 (on the tablet, from the tree that became it), counted
by `scripts/device_perf.sh`, which now prints the build it measured.

Tablet, 90 Hz:

| Board | Frames counted | Dropped frames | FPS (avg / 1% low) |
| --- | --- | --- | --- |
| Flat | 988 to 991, four runs | 0 | 90 / 90 |
| 3D | 993 | 172 (17%), each on screen for two refreshes | 77 / 45 |

Pixel 7a, 60 Hz:

| Board | Frames counted | Dropped frames | FPS (avg / 1% low) |
| --- | --- | --- | --- |
| Flat | 995 | 0 | 60 / 60 |
| 3D | 995 | 1 | 60 / 60 |

Galaxy A33, 90 Hz:

| Board | Frames counted | Dropped frames | FPS (avg / 1% low) |
| --- | --- | --- | --- |
| Flat | 990 | 0 | 90 / 90 |
| 3D | 993 | 500, every other frame (23 ms of GPU work) | 60 / 45 |

iPhone 13 mini, 60 Hz, the development build from 2919b45 (no app source changed since
1aaf406), counted by Instruments' Animation Hitches (`displayed-surfaces-interval`)
between the bench's console lines, stamped on the Mac:

| Board | Frames counted | Dropped frames | FPS (avg / 1% low) |
| --- | --- | --- | --- |
| Flat | 979 | 4 | 60 / 60 |
| 3D | 985 | 1 | 60 / 60 |

The iPhone's flat board's dropped frames (two runs, 4 and 5): Instruments' own hitch
table counts none of them, the render server takes its usual 2 ms around each, and the
app's loop hands over every frame on time (a temporary log of any gap over 25 ms printed
nothing). They come in bursts about 1.05 to 1.08 s apart (19.67, 20.75, 21.83 s; 29.31,
30.36, 31.42 s), a beat between two clocks: the present's timing against the display's
refresh, in SDL's Metal path or the way goose_gfx uses it, not the drawing. Next: when
each frame is presented against the refresh. The iPhone can't run `poc/pace.goose` with
the free team: a new bundle id needs a profile it won't make.

What was ruled out on the way, with `poc/pace.goose` (the screen cleared every frame
through the same goose_gfx and SDL): the pacing itself dropped none of 1815 frames, nor
with a full-screen shader keeping the GPU 76% busy at its top clock, nor with three 16 KB
buffer uploads a frame as the app does. The flat board's loop does 1.0 ms of CPU work a
frame (1.4 at P99, 1.8 at most); the rest of the frame is `frame()` waiting for a
swapchain image.

A trap for the next measurement: the bench's first phase waits for the GPU after every
frame, so its frames miss refreshes by design. A count that overlaps it (an earlier one
here started on a timer) shows dropped frames on the flat board that never happen in play.

## The 3D board

Its frame takes 10.6 ms of GPU work waited (P99 12.7) against 11.1 ms, so it drops
one whenever a frame runs long; task 042 holds the candidates for cutting it. The Android GPU
governor lowers the clock toward a busy target, so the frame needs room to spare at the
clock the governor picks, not just at the top one.

## Acceptance criteria

- [x] The tablet's flat board drops no frame over 1000 presented ones
- [x] The same on the Pixel 7a
- [x] The same on the Galaxy A33
- [ ] The iPhone's flat board's 4 to 5 dropped of about 980 looked into
- [ ] The 3D board drops no frame on the tablet and the Pixel 7a (the Galaxy A33,
      the weakest tried, at least holding a steady rate)
- [ ] A screen transition counted the same way
