# 056: Even frame pacing

Status: in-progress

A frame that is drawn in time can still be dropped: the one before it stays on screen for
two refreshes because the frame came to the display at the wrong moment, not because it
took too long. Task 055 found such drops where the frame's work fits with room to spare,
and this task finds where they come from and stops them. Follows task 055, whose
measurement (`scripts/device_perf.sh`, and Instruments on the iPhone) it uses.

## What was seen, 2026-11-10

The release built from 1aaf406 (the iPhone's development build from 2919b45, the same
app code), 1000 presented frames of the bench (`--bench 1000`):

- **iPhone 13 mini, 60 Hz, the flat board:** 0 to 5 frames dropped of about 980 over five
  runs (4, 5, 3, 0, 0), though its GPU work is small. Instruments' own hitch table counts none of them,
  the render server takes its usual 2 ms around each, and the app's loop hands over
  every frame on time (a temporary log of any gap over 25 ms printed nothing). The drops
  come in bursts about 1.05 to 1.08 s apart (19.67, 20.75, 21.83 s; 29.31, 30.36,
  31.42 s): a beat between two clocks, the present's timing against the display's
  refresh, in SDL's Metal path or the way goose_gfx uses it.
- **iPhone, the 3D board:** 1 of 985.
- **Pixel 7a, the 3D board:** 1 of 995, with 3 ms to spare in each 16.7 ms frame.
- The tablet's and the Galaxy A33's flat boards dropped none; their 3D boards drop
  because the frame is too long (task 055, task 042).

## The Mac, 2026-11-10

MacBook Pro M1 Pro, the built-in display at 120 Hz, a 1280 × 800 pt window (2560 × 1600
px), built with `scripts/mac.py` from 646f168. One batch: `xcrun xctrace record --template
'Metal System Trace' --launch -- build/draughts --board 3d --screen game --theme wood
--variant russian --bench 1000`, and a transition (`--board flat --go settings`, 6 s).
Exported with `xctrace export`; the presented times are `ca-client-presented-handler`'s
requested time (the Mac's trace has no `display-vsyncs-interval` or
`display-surface-swap` rows), joined to `ca-client-present-request`,
`metal-command-buffer-completed`, `metal-gpu-intervals`, and
`ca-client-buffer-wait-interval` (the app's wait for a drawable). A frame is late when
the gap to the one before is over one refresh.

| Bench phase (1000 frames each) | Late | Refreshes missed | App GPU a frame | WindowServer GPU a frame |
| --- | --- | --- | --- | --- |
| 0, 3D + shadow map, each waited | 29 | 36 | 5.9 ms | 2.7 ms |
| 1, the pass alone, each waited | 101 | 109 | 5.6 ms | 3.1 ms |
| 2, 3D + shadow map as the loop draws it (the moving board) | 5 | 9 | 6.2 ms | 3.7 ms |
| 3, pulsing rings | 4 | 10 | 5.8 ms | 2.3 ms |

The waited phases drop by design (task 055). The transition dropped 3 frames of 362: two
at the launch, and one at 4.07 s that the present made late (the GPU done 5.1 ms into
its refresh, the drawable a whole refresh late).

- **The moving board's late frames are the GPU's.** The loop commits a frame about 0.8 ms
  after a refresh, once SDL has its drawable, and the whole command buffer runs only when
  that drawable's surface is free, which is the refresh after: Metal holds back a command
  buffer that writes a drawable, and goose_gfx records the frame and the blit into the
  drawable in one. The frame then has about 7.5 ms before the next one, and its GPU work is
  6.2 ms: the 3D pass's fragments 4.1 ms (4× MSAA at 2560 × 1600, the lit shader), the
  screen's pass 1.3 ms, the shadow map 0.15, the blit 0.14. The late ones finish 7.6 to
  8.3 ms into the refresh. WindowServer composites on the same GPU, 3.7 ms a frame.
- **A stall every 5.00 s.** WindowServer drew nothing for 47 to 56 ms at 5.47, 10.46, …,
  35.47 s from the recording's start, in every phase, the app waiting for a drawable the
  whole time (5 or 6 refreshes missed). Its period and its phase follow the recording, so
  it is most likely Instruments' own; not yet checked without it.
- **Tried and set aside:** submitting the frame before the wait for the drawable, the blit
  alone in a second command buffer (a patch to goose_gfx's `gfx_present`). The frame's
  work ran at once (done 3 to 4 ms into the refresh), but the blit still waited for a
  free surface and the frame after it for that blit (SDL keeps 2 frames in flight), and
  the moving board's late frames went from 5 to 20 of 1000: most waited two refreshes for
  a drawable. The window has 3 surfaces and WindowServer holds two of them.
- The app's own clock, the same build without Instruments: presented avg 120.0 / 1% low
  96.4 fps, waited P50 4.2 / P99 6.89 ms.

So on the Mac the drops are the 3D pass's GPU cost against a 120 Hz refresh, the
fixable part. The iPhone's beat (above) is not seen here: its GPU work is small.

## Directions

First on the desktops, going to a device only if nothing shows there (the user,
2026-11-10): Windows with PresentMon (the user tunes there), and the Mac with `xcrun xctrace
record --template 'Metal System Trace' --launch -- build/draughts …` on a moving 3D board's
`--bench` run and a screen transition, in one batch, exported with `xctrace export`: the
frames past one refresh, and whether CPU, GPU, or the present made them late. The Metal
HUD (`MTL_HUD_ENABLED=1`) for a look by eye.

Windows, 2026-11-10 (`scripts/windows_perf.py`, RTX 4090, 2560 × 1440 at 165 Hz, full
screen): of about 970 bench frames per board, none dropped and none held past a refresh,
on both boards, each flipped straight to the screen (Independent Flip), 6 ms from present
to display. A moving board and a transition are still to record there.

1. **When each frame is presented.** On the iPhone, the trace's Metal tables
   (`metal-command-buffer-completed`, `display-surface-swap`) against the display's
   vsyncs (`display-vsyncs-interval`), and the app's own time stamps at acquire and
   commit; does the beat line up with the drawable's wait or with the commit?
2. **How SDL presents on Metal:** `presentDrawable` with no time, the layer's
   `maximumDrawableCount` and `displaySyncEnabled`, frames in flight. A present at a
   chosen time (`presentDrawable:atTime:`, or a display link) may hold the beat off; that
   would be a patch to SDL, so a note for the user first (AGENTS.md).
3. **The Pixel's single drop:** whether it repeats over a longer run, and where it falls.

After the Mac, the phones; most profiling on the Galaxy A33, the slowest, which shows best
what to cut (2026-11-10). The Windows build looks separately for drawing that keeps most of
the look for less work.

The iPhone can't run `poc/pace.goose` with the free team (a new bundle id needs a
profile it won't make); the app with a temporary flag that draws almost nothing is the
way to rule its drawing out there.

## Acceptance criteria

- [ ] The iPhone's drops explained, with a measurement that shows the cause
- [ ] The flat board drops no frame over 1000 on the iPhone
- [ ] The Pixel's 3D drop checked over a longer run
