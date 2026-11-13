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

## Found so far

On the M1 Pro (2026-11-13), the 3D bench full screen at 3600 × 2260:

- The wait is not a drawable, a fence, or the display: `--no-vsync` waits the same. It is
  the fragment stage of the board's 4× MSAA pass, 14.1 to 14.6 ms a frame against about
  3 when alone (task 077 had 3.08 ms). The vertex stage, the shadow pass, and the screen's
  pass are unchanged (0.14, 0.02, 0.48 ms).
- It slows only while other GPU work runs beside it: WindowServer composing the window, or
  any other Metal process. A 3 ms pass can fit between compositions, but once it overlaps
  one it takes 14 ms and keeps overlapping, so a run settles at about 15 ms or about 4.3 ms
  waited. gfx's MSAA pass and ngfx without MSAA don't slow:

| Scene, under another GPU load | ngfx waited P50 | gfx waited P50 |
| --- | --- | --- |
| 4× MSAA | 15.0 to 23.9 ms | 3.16 to 5.34 |
| 4× MSAA, `GOOSE_NGFX_PASS_BARRIER=1` | 17.4 to 20.1 | |
| 4× MSAA stored, not memoryless | 17.9 to 18.8 | |
| `--aa off` / SMAA | 4.2 / 3.43 | |

  GPU time a frame (Metal System Trace, Maximum state): ngfx 15.26 and 15.96 ms, gfx 3.00
  and 3.22. The iPhone's compositor runs each frame, which would explain its 14.7 ms: not
  yet checked there.
- Not the cause: the pass barrier (off in the build: only read from the environment), the
  other barriers (all dropped: 15.5 ms), memoryless storage, a 16 × 16 tile. The cause
  likely lies in NoGraphicsAPI's Metal 4 MSAA path (its `MTL4` pass or pipeline), which
  SDL_GPU's Metal 3 path doesn't share; not established without GPU counters.
- A forced 32 × 32 tile on the MSAA pass faulted the GPU (three restarts, "MMU interrupt",
  signature 674, not task 008's hang): never force a tile size there. Runs without any
  barrier are as unsafe.

A fallback: SMAA as ngfx's anti-aliasing on Apple, which the slowdown doesn't touch.
