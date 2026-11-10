# 056: Even frame pacing

Status: todo

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

The iPhone can't run `poc/pace.goose` with the free team (a new bundle id needs a
profile it won't make); the app with a temporary flag that draws almost nothing is the
way to rule its drawing out there.

## Acceptance criteria

- [ ] The iPhone's drops explained, with a measurement that shows the cause
- [ ] The flat board drops no frame over 1000 on the iPhone
- [ ] The Pixel's 3D drop checked over a longer run
