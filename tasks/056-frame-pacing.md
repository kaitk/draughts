# 056: Even frame pacing

Status: in-progress

A frame drawn in time can still be dropped when it reaches the display at the wrong
moment. Task 055 found such drops where the frame's work fits; this task finds where they
come from and stops them, measured as task 055 does (`agents/testing.md`, "Frame pacing").

## What is known (2026-11-10)

- **iPhone 13 mini, flat board:** 0 to 2 of ~983 dropped (Animation Hitches only:
  Instruments' Metal System Trace makes the loop run at 120 on the 60 Hz panel). Each
  drop is a frame rendered in time and never shown: it finished about 0.4 ms past the
  latch and the next frame replaced it. The frame starts when `nextDrawable` returns, so
  its phase against the latch drifts with its own CPU and GPU time. The fix would finish
  each frame further from the latch (a display link or `presentDrawable:atTime:`), a
  change to SDL's Metal path or goose_gfx; for SDL a note for the user first (AGENTS.md).
- **Mac, 120 Hz, 3D board:** 5 of 1000 late, from the GPU: the frame's 6.2 ms of GPU work
  (4.1 ms the 3D pass at 4× MSAA) against the ~7.5 ms left once Metal releases the
  drawable. A 47 to 56 ms stall every 5.00 s follows the recording, most likely
  Instruments' own (not checked without it). Splitting the blit into its own command
  buffer made it worse (5 to 20 late).
- **Galaxy A33:** flat board 2 of 1000 late, the same drift on Android (the loop is paced
  by `dequeueBuffer`/`queueBuffer`). The 3D board is GPU-bound at 60 frames a second,
  shown as two refreshes and one in turn on the 90 Hz display. The app asks for 60 Hz on
  its surface while a slow 3D board moves (`src/app/display.c`), but the A33's "High"
  motion smoothness fixes the display at 90, so only the user's Standard setting gives
  even motion there. The tablet keeps 90 (the user chose that over an even 60).
- **Windows** (RTX 4090, 165 Hz): none dropped of ~970 on either board.
- **Set aside:** waiting for the next vsync before each frame on iOS and Android
  (`CADisplayLink`, `AChoreographer`) dropped as many or more; the swapchain's buffers
  pace the loop, not the frame's start.

## Left

1. On the iPhone, the Metal tables against `display-vsyncs-interval` and the app's own
   stamps at acquire and commit; then whether a present at a chosen time holds the drift
   off (a patch to SDL, so a note first). The free team can't run `tools/pace.goose`; a
   temporary flag that draws almost nothing rules the drawing out instead.
2. The Pixel's single 3D drop over a longer run.
3. A moving board and a transition recorded on Windows.

## Acceptance criteria

- [x] The iPhone's drops explained, with a measurement that shows the cause
- [ ] The flat board drops no frame over 1000 on the iPhone
- [ ] The Pixel's 3D drop checked over a longer run
