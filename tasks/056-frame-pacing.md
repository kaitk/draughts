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

## The iPhone, 2026-11-10

The development build from 37f350b, the flat board, `--bench 1000`.

- **Instruments' Metal System Trace changes the pacing on the iPhone:** under it the loop
  presented every 8.33 ms, 120 a second on the 60 Hz panel (`ca-client-present-request`
  1000 in 8.3 s; the bench's own clock: avg 120.0 / 1% low 104.2 fps), and its display
  tables hold only the first half second. Under Animation Hitches the same build runs at
  60. So the iPhone's pacing is read with Animation Hitches only.
- Animation Hitches, four runs: 0, 1, 1, 2 frames dropped of 982 to 984
  (`scripts/ios_perf.py`; the bench's own clock avg 60.0 / 1% low 58.0 to 58.4 fps). The
  app's surfaces go direct to display, 33 ms from the CPU to the display.
- **Each drop is a frame rendered in time and never shown.** Around every one (run 0 at
  7.78 s and 17.38 s; run 1 at 28.10 s; run 2 at 0.78, 2.51, 15.21, 18.36, 25.66 s) the
  app's GPU work completes every 16.7 ms without a gap (`metal-command-buffer-completed`),
  yet `display-surface-swap` skips one of the three surfaces: the swap before and after it
  were generated 15.5 to 16.8 ms before their swap and queued 14.6 to 15.9 ms before it,
  as every frame is. At 7.78 s the skipped frame was done at 7.7798 s, about 0.4 ms past
  the latch for its refresh (its swap would have been 7.7944, queued by about 7.7794);
  the next frame, done at 7.7964, caught the refresh after, and replaced it. So the
  frames finish close to the latch, and the app's phase against it drifts: a frame that
  runs a little long misses by a fraction of a millisecond and is dropped, not delayed.
  The app's frame starts when `nextDrawable` returns a surface, which is tied to the
  display's swaps, so the phase is set by the frame's own CPU and GPU time.
- The way to hold it off: finish each frame further from the latch, by starting it at a
  chosen point after the vsync (a display link) or presenting at a chosen time
  (`presentDrawable:atTime:`); both are changes to SDL's Metal path or goose_gfx.

## The Galaxy A33, 2026-11-10

The release built from 37f350b, `--bench 1000` in the usual scene, traced with Perfetto
(SurfaceFlinger and the app's atrace: `gfx`, `view`, `sched`, `freq`, at 90 Hz). The
app's SurfaceView carries no frame tokens, so SurfaceFlinger's frame timeline leaves it
out; a frame's latch is the drop of the layer's `BufferTX` counter, read with Perfetto's
trace processor.

- **The flat board:** 2 of 1000 frames latched a refresh late, both from the app's side.
  The loop is paced by the buffers, not the vsync: `dequeueBuffer` (3.3 ms on average,
  up to 14.7) and `queueBuffer`, whose BLAST queue waits (`waitForever`) while the
  compositor holds the swapchain's other buffers, so the app hands its buffers over at
  uneven times (8.5, 13.9, 6.1, 3.8, 3.6 ms apart around the one at 24.7 s). One came
  just after SurfaceFlinger's wake-up, so that refresh had nothing new; the next two
  came 3.6 ms apart, and the app then waited 13.2 ms in `queueBuffer` for a buffer
  back. The iPhone's pattern on Android: the frame's place against the latch drifts
  with the loop's own timing. The bench's own clock: waited P50 18.3 / P99 19.0 ms,
  presented avg 89.6 / 1% low 79.0 fps.
- **The 3D board, moving (the bench's loop phase):** 60 frames a second, but on the 90 Hz
  display they alternate two refreshes and one (22.2 and 11.1 ms: 424 and 404 of 829
  latched), an uneven 60. The app is GPU-bound: its thread sleeps in `queueBuffer` 13.8
  ms of each 16.7 ms frame (`waitForever`, waiting for a buffer back), running 2.2 s of
  the 14. The waited phases before it ran at 47 to 52 frames a second.
- So on the A33 the 3D board can't be locked to 90 Hz, and 60 frames on a 90 Hz display
  is judder, not even motion: evenly paced it would be 45 at 90 Hz, or 60 with the
  display switched to 60 Hz while the 3D board moves (`ANativeWindow_setFrameRate`), the
  choice being the user's. The 3D pass's cost is task 059's.

## Vsync pacing, tried and set aside (2026-11-10)

A goose_gfx patch to `frame()` on iOS and Android: after a frame that drew is presented,
wait for the display's next vsync before the next frame begins (iOS a `CADisplayLink`
on the main run loop, made through the Objective-C runtime and paused while idle;
Android `AChoreographer_postFrameCallback64` on the loop thread's own `ALooper`).
First waiting for the vsync after the present, then (so a present that blocks past the
vsync loses no refresh) the vsync after the frame began, waiting only if it hadn't come.
Frames late of about 980 (the iPhone, Animation Hitches) or 1000 (the A33, Perfetto):

| | Without | Vsync after the present | Vsync after the frame began |
| --- | --- | --- | --- |
| iPhone, flat, four runs | 0, 1, 1, 2 | 4, 2, 3, 2 | 6, 4, 1, 2 |
| iPhone, 3D | 1 | 1 | |
| A33, flat | 2 | 6 | 3 |

On the A33 the first version lost a refresh whenever `QueuePresentKHR` blocked past the
vsync waiting for a buffer back (12.6 ms at one late frame); the second made the frames
reach SurfaceFlinger 9.7 ms before their latch instead of 4.5, but no fewer were late.
The 3D board's loop stayed at 60 frames a second, `queueBuffer` still 14 ms of each:
the swapchain's buffers pace it, not the frame's start. So the start of a frame isn't
what decides the drops here; the patch was removed. What's left for the flat boards is
a few frames in a thousand; for the A33's 3D board, the display at 60 Hz while it moves.

## The display at 60 Hz while the 3D board moves (2026-11-10)

On Android the app asks for 60 Hz on its surface (`ANativeWindow_setFrameRate`, from
`src/app/display.c`) while the 3D board draws, on a device whose 3D board can't keep up
with a faster display: the gaps between frames that drew a ready, shown board are timed
at the display's own rate, and if 60 of them average over 1.25 refreshes on a display over
60 Hz, it asks from then on whenever the 3D board draws, and for the display's own rate
(0) at rest and on the flat board. A device that holds its rate is left alone (the user
chose that over a fixed 60, which would cap faster devices). `RTLD_DEFAULT` doesn't find
the function from the app's library (its own linker namespace); `dlopen("libandroid.so")`
does.

- **The Galaxy A33 ignores it.** The release built from 8a22ba0 with the change:
  SurfaceFlinger holds the layer's vote (`frameRate: 60.00 Hz` on the 3D bench, 0.00 at
  rest and on the flat bench; timestats' "SetFrameRate vote for this layer"), but the
  display stays at 90. Its motion smoothness is "High", which Samsung's
  `RefreshRateModeManager` runs as `REFRESH_RATE_MODE_ALWAYS`: the display manager's
  policy is 90 to 90 for both the primary and the app-request ranges (`dumpsys
  SurfaceFlinger`, `dumpsys display`), so no surface's or window's vote moves it; only the
  user's Standard setting puts it at 60 (its history, 2026-11-09). Perfetto over the
  moving board's 1000 frames: 59.0 a second, latch gaps 10 to 14 ms 481, 20 to 24 ms 519,
  as before (404 and 424 of 829). `scripts/device_perf.sh`: the flat board 990 frames at
  90 Hz, avg 90.0 / 1% low 90, none dropped; the 3D board 995 at 90 Hz, avg 57.6 / 1% low
  45 fps, 558 dropped (the two-and-one alternation). The script missed the 3D board's
  rate (a layer's `displayRefreshRate` line comes before its name) and is fixed.
- **The Galaxy Tab A11+** (its policy 60 to 90 Hz, so it follows a vote), the release with
  the change: the flat board 989 frames at 90 Hz, avg 90.0 / 1% low 90, none dropped. Its
  3D board at first came out at 60 Hz, 994 frames, none dropped (avg 60.0, waited P50
  14.2 ms): the first 60 frames timed were the bench's waited phase, slower than the loop.
  With the bench's two waited phases left out of the timing, it keeps 90: 995 frames,
  avg 77.7 / 1% low 45 fps, 158 dropped (15.9%), as before the change (17%); its frames
  average about 1.15 refreshes, under the 1.25. The user chose to keep it at 90 rather
  than an even 60.
- **The Pixel 7a** runs its display at 60 Hz (Smooth Display off, the policy 0 to 60), so
  the app asks it for nothing; not measured.
- So on a fixed-90 Samsung the even choices left are 45 frames a second, every second
  refresh, chosen by the app, or the user's Standard setting.

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

0. **Done (2026-11-10, above): the display at 60 Hz while the 3D board moves, on Android.** The
   A33's moving 3D board shows 60 frames a second on its 90 Hz display as two refreshes
   and one in turn; asking for 60 (`ANativeWindow_setFrameRate` on the game's surface,
   from the app's own C, or `Surface.setFrameRate` from `DraughtsActivity`) while the
   board moves, and the display's own rate again at rest, should show each frame for one
   refresh. Check it on the A33 with Perfetto (`agents/testing.md`, "Frame pacing"): the
   latch gaps all one refresh at 60 Hz; then the tablet and the Pixel 7a, whose 3D boards
   run near their rate, so that it doesn't cost them frames they now hold.
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

- [x] The iPhone's drops explained, with a measurement that shows the cause
- [ ] The flat board drops no frame over 1000 on the iPhone
- [ ] The Pixel's 3D drop checked over a longer run
