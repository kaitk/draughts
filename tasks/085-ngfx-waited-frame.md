# 085: Why ngfx's 3D frame waits a whole refresh

Status: in progress

On the iPhone 13 mini (task 084, 2026-11-13) the 3D bench's waited phases read 17.2 to
17.7 ms on ngfx against gfx's 9.2 to 9.4, right at the 60 Hz display's 16.7 ms, and the
GPU's own time a frame in the loop phase (Metal System Trace) was 14.7 ms against gfx's
8.9 to 10.5. Task 077 had ngfx's MSAA frame only 2% over gfx's on the M1 Pro, and
`agents/testing.md` says the 3D board's waited time isn't held up by the drawable. Find
out what ngfx waits for and why its GPU time is that much higher, on the Mac first.

## Questions

- Does the Mac show it: ngfx's 3D waited phases against gfx's, at a window's and full
  screen's sizes, with and without vsync (`--no-vsync`)? Does the waited time track the
  display's period (the Mac's 120 Hz against 60)?
- What the wait is: a drawable, the frame's own submissions, a fence on the frame before;
  where in ngfx's frame it falls (`GOOSE_NGFX_BENCH=1`'s stamps, Metal System Trace).
- Whether a different scene shows it: the flat board, the 3D board without MSAA (`--aa
  off`), without the shadow map, at a smaller size.
- The Metal pass barrier once placed against a driver hang (goose-ngfx task 008), behind
  `GOOSE_NGFX_PASS_BARRIER=1` and off by default since 1cda46e: that the build Draughts
  takes really runs without it, and the frame's time with it on and off.
- The iPhone's GPU time: whether what the Mac finds explains the 14.7 ms, checked on the
  iPhone last.

## Acceptance criteria

- [ ] The Mac: ngfx against gfx in the waited phases and in GPU time a frame, the wait
      found and explained
- [ ] The barrier's state in the build and its cost measured
- [ ] A fix or a proposal for goose-ngfx (`docs/goose-findings.md`), and the iPhone checked
      against it
