# 085: Why ngfx's 3D frame waits a whole refresh

Status: done

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

- [x] The Mac: ngfx against gfx in the waited phases and in GPU time a frame, the wait
      found and explained
- [x] The barrier's state in the build and its cost measured
- [x] A fix or a proposal for goose-ngfx (`docs/goose-findings.md`)
- [x] The iPhone checked against it

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
  other barriers (all dropped: 15.5 ms), memoryless storage, a 16 × 16 tile. The Metal 4
  MSAA path is our own: `kaitk/NoGraphicsAPI`'s `msaa` branch (b29bd71, merged into its
  `ngfx`), which sets the textures' sample count and `MTLTextureType2DMultisample`, the
  pipelines' `rasterSampleCount`, memoryless transient attachments made from the device
  outside the heaps and the residency sets, untracked hazards, and the resolve through
  `MTLStoreActionMultisampleResolve` on a shared, reused `MTL4RenderPassDescriptor`.
  Start there: the cause is likely in that branch, not in NoGraphicsAPI or the driver;
  not established without GPU counters.
- A forced 32 × 32 tile on the MSAA pass, an experiment in a scratch copy of that branch,
  faulted the GPU (three restarts, "MMU interrupt", signature 674, not goose-ngfx task
  008's hang, signature 544): never force a tile size there, and don't drop the barriers.
  The pass barrier's default stays as it is.

A fallback: SMAA as ngfx's anti-aliasing on Apple, which the slowdown doesn't touch.

## The cause: NoGraphicsAPI's root alignment hint shades every sample

Found 2026-11-13, on the M1 Pro. The slowdown is not in the `msaa` branch, the pass
barrier, or the driver's scheduling: ngfx's 4× pass runs its fragment shaders once per
sample. Upstream NoGraphicsAPI's `GPU_ROOT` on Metal loads the root through
`gpu_root_aligned_storage`, which emits `__builtin_assume((ptr & 15) == 0)` on the
constant root pointer (upstream ae017a2, 5eb6fbc). Apple's compiler then shades a
multisampled pipeline per sample. Single-sample pipelines pay for it too, less.

How it was found, headless (`GOOSE_GFX_HEADLESS=1`, `--renderer ngfx --size 3600x2260`,
the 3D bench, waited P50), which shows the slowdown as full screen does:

- ngfx 4× MSAA 11.9 ms against `--aa off` 2.2, SMAA 3.1, gfx's 4× MSAA 2.0; 2× MSAA 7.2.
  No resolve, a fresh pass descriptor each pass, the viewport's flip: no change. An empty
  MSAA pass (draws skipped) 0.5 ms; the backdrop draw about 3.8 ms of it, the first lit
  mesh 5.7.
- Metal GPU counters (Instruments' `Metal GPU Counters` instrument, headless, the mean
  while busy times the frame): ALU 5.06 against `--aa off`'s 1.14 and gfx MSAA's 1.25;
  texture samples 240 against 46 and 55; GPU writes 27.6 GB/s against 6.5 and 6.0;
  buffer stores 5.1% against 0.3 and 0.07. Compiler spill events: ngfx's 4× pass 224
  bytes each frame, its 1× pass none, gfx 32 to 80.
- A standalone Metal program (classic and Metal 4 alike: one full-screen draw, 4×
  memoryless color and D16, resolved) costs the same at 4× as at 1×. The backdrop's own
  Slang-made Metal in it: 0.58 ms at 1×, 1.66 at 4×, with 4.2× the ALU work and 3.9× the
  texture samples, so per sample. Not the cause, each removed in turn: `[[position]]`,
  the frame block copied into the thread context, the texture fetch, the Metal language
  version, the depth state. The root loaded without the `__builtin_assume`: 0.41 to 0.65
  at 1×, 0.56 to 0.68 at 4×. `__builtin_assume_aligned` doesn't compile on a `constant`
  pointer.

The fix: `kaitk/NoGraphicsAPI`'s branch `metal-root-hint` (5083bb1, on upstream `main`)
drops the hint on Metal, keeps `GPU_ROOT`'s alignment argument for Vulkan, and says so in
`docs/slang.md`; merged into `ngfx` (e543e9e), goose-ngfx follows it (965152e).
NoGraphicsAPI's root and shader-ABI tests pass; its timestamp tests fail on this Mac with
or without it (5 to 9 of 39 a run, "unwritten or unordered timestamps"). goose-ngfx's 36
tests pass.

Headless, before against after, alternated, two runs each (waited P50, ms):

| Scene | Before | After |
| --- | --- | --- |
| 4× MSAA | 11.82, 11.84 | 2.08, 2.10 |
| `--aa off` | 2.24, 2.19 | 1.75, 1.76 |
| SMAA | 3.06, 3.03 | 2.57, 2.55 |
| gfx, 4× MSAA | 2.09, 2.12 | |

Full screen, GPU time a frame (`scripts/mac_gpu_time.py`, `--renderer ngfx`), alone and
beside another Metal process (a full-screen draw looping), alternated, two rounds:

| | Before | After |
| --- | --- | --- |
| Alone | 14.98, 14.69 ms | 4.57, 2.93 |
| Beside another GPU load | 14.59, 14.53 | 5.05, 2.88 |

The first round's 4.57 and 5.05 ran while the GPU moved between clock states (the
others held Maximum). Before the fix the pass was slow alone too here, with the desktop
in use: the 3 ms "alone" readings above weren't reproduced.

The forced 32 × 32 tile: NoGraphicsAPI has no tile size in its API, and nothing in it,
goose-ngfx, or Draughts sets `tileWidth` or `tileHeight`, so every pass gets the
driver's own. The fault came from a scratch copy that set the property directly; a
check belongs with a tile size, if one is ever added.

On the iPhone 13 mini (2026-11-13), a development build of HEAD holding both renderers,
the 3D bench (`--bench 300`) with Metal System Trace attached, the GPU's time over the
loop phase (agents/testing.md, "The iPhone"), alternated, ngfx first, two runs each:

| Renderer | GPU a frame | Waited with the shadow map P50 | Presented every |
| --- | --- | --- | --- |
| ngfx | 8.68, 8.62 ms | 9.23, 9.14 ms | 16.66 ms |
| gfx | 9.00, 9.07 | 9.41, 9.42 | 16.67 |

ngfx was 14.65 and 14.76 ms of GPU, waited 17.18 to 17.69 (task 084): the per-sample
shading explains all of it, and ngfx's frame is now about 4% under gfx's. Whether `auto`
should put ngfx first on iOS or the Mac is for task 073's comparison.
