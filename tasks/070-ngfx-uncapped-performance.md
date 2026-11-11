# 070: ngfx against gfx, uncapped, on the Mac

Status: done (on the `ngfx` branch, 2026-11-11)

Task 065 brought ngfx's memory to gfx's. Its performance has only been measured paced by
the display, where both builds present 118 to 120 fps of 120 on the M1 Pro and 60 of 60
on the iPhone, and where ngfx's `--bench` waited time now includes waiting for a free
drawable (`agents/testing.md`). This measures what each renderer costs a frame with
nothing pacing it.

## What to do

1. **`--no-vsync`**, a development flag (`src/app/flags.goose`), which the gfx build's
   host passes to `gfx::open` as `gfx::NO_VSYNC` and the ngfx build's to `ngfx::open` as
   ngfx's `NO_VSYNC` (gfx itself is opened `WINDOW_ONLY` there, so its flag means
   nothing). ngfx's `NO_VSYNC` turns the layer's display sync off; check that gfx's does
   the same through SDL_GPU on Metal (immediate presents), or say what it does instead.
2. **The runs**, both builds, `--bench 300`, a 1280 × 800 window and full screen
   (`--size full`), the flat and 3D game (Russian, wood, the start), three runs each,
   the medians recorded: presented fps, waited P50 / P99, and the CPU a frame. On the 3D
   board, ngfx's `--aa` modes (`off`, `fxaa`, `smaa`, `ssaa`) against gfx's 4× MSAA:
   task 065 deferred measuring them until after the memory work.
3. **The GPU's own time**, where the builds can say it: ngfx prints each frame's GPU
   time under `GOOSE_NGFX_BENCH=1`; gfx has no such timestamps, so its GPU time is the
   uncapped waited time.
4. **Read the numbers**: where ngfx is slower, find whether it is the CPU (recording,
   the per-pass barrier on Metal, `docs/design.md` in goose-ngfx) or the GPU, and record
   what to try. Windowed, presents go through the compositor, so the fps is how fast the
   app submits; full screen is closer to what reaches the display.

Measure once the Mac is cool and nothing else draws; the M1 Pro's clocks move with load,
so compare medians of runs, not single runs. Windows interrupt the user: run them in one
batch (memory: Mac shots in one batch).

## Acceptance criteria

- [x] `--no-vsync` on both builds, checked to present uncapped
- [x] Both builds' uncapped numbers, flat and 3D, windowed and full screen, recorded here
- [x] ngfx's antialiasing modes measured against gfx's MSAA, uncapped
- [x] Where ngfx is slower, what it is (CPU or GPU) and what to try, recorded here

## Progress

### 2026-11-11: the runs on the M1 Pro

macOS 26.3.1, on mains power, the window on the built-in display (120 Hz); goose-ngfx
v0.5.0 (`e952736`). `--bench 300 --no-vsync`, Russian, wood, the start; the window
1280 × 800 points (2560 × 1600 pixels) and `--size full` (3600 × 2260). ngfx runs with
`GOOSE_NGFX_BENCH=1`, its default `--aa smaa` unless named.

- **`--no-vsync`** (`src/app/flags.goose`): the gfx build opens with `gfx::NO_VSYNC`, the
  ngfx build `ngfx::open` with ngfx's `NO_VSYNC`. Both turn the `CAMetalLayer`'s
  `displaySyncEnabled` off: SDL_GPU on Metal has no mailbox, so gfx's flag falls back to
  `SDL_GPU_PRESENTMODE_IMMEDIATE`, which sets it (`SDL_gpu_metal.m`), and ngfx sets it
  itself. Checked uncapped: the flat bench in the window went from 117 to 168 fps on gfx
  and 119 to 215 on ngfx.

**The app's own numbers**, medians of three runs, interleaved build by build: presented
fps (avg / 1% low), waited P50 / P99 in ms (each frame waited for: the CPU's fill, the
submit, and the GPU), and the CPU a frame to the submit:

| run | gfx | ngfx |
|---|---|---|
| flat, window | 226 / 63 fps, 3.00 / 6.16, cpu 0.23 | 230 / 78 fps, 3.18 / 15.5, cpu 0.24 |
| flat, full | 241 / 63 fps, 3.18 / 6.42, cpu 0.11 | 227 / 81 fps, 3.79 / 14.8, cpu 0.10 |
| 3D, window | 268 / 61 fps, 2.80 / 6.53, cpu 0.10 | 251 / 61 fps, 2.74 / 6.75, cpu 0.15 |
| 3D, full | 242 / 61 fps, 3.56 / 7.11, cpu 0.11 | 224 / 68 fps, 3.88 / 6.48, cpu 0.15 |

ngfx's 3D antialiasing, the same way (gfx's 4× MSAA in the table above):

| `--aa` | window | full |
|---|---|---|
| off | 213 fps, 2.87 / 5.26 | 228 fps, 2.96 / 6.98 |
| fxaa | 213 fps, 2.66 / 7.07 | 227 fps, 3.78 / 6.34 |
| smaa | 251 fps, 2.74 / 6.75 | 224 fps, 3.88 / 6.48 |
| ssaa | 204 fps, 3.86 / 8.23 | 137 fps, 7.36 / 9.20 |

- **The presented rate is noise**: one config moves 180 to 300 fps run to run, and no
  build's uncapped rate is set by its GPU. Instruments' Metal System Trace (below) shows
  the app's GPU busy 45 to 70% of the loop phase's time and the main thread waiting for
  a drawable 1.2 to 3 ms a frame, at times 10 to 75 ms: with the display sync off, the
  three drawables still come back only as fast as the window server lets them go, in a
  window and full screen alike. Uncapped, both builds present 220 to 290 fps.
- **ngfx's flat waited P99** (15 ms against 6) is the wait for a free drawable inside
  the waited frame, as with the display sync on (`agents/testing.md`).
- **The CPU**: 0.10 to 0.24 ms a frame on both. ngfx's 3D frame takes 0.15 against 0.10;
  nothing here is CPU-bound.

**The GPU's own time**, from Metal System Trace (`xctrace`), the union of the app's GPU
intervals in ms a frame, by the bench's phases: frames waited for, and the loop's frames
(the same work, frame to frame). Full screen, three traces each, all at the GPU's
Maximum performance state:

| full screen, 3D | waited | the loop's frames | overlap in the loop |
|---|---|---|---|
| gfx, 4× MSAA | 3.17 / 3.35 / 3.33 | 3.03 / 3.07 / 3.05 | × 1.27 to 1.33 |
| ngfx, SMAA | 3.47 / 3.47 / 3.52 | 3.50 / 3.41 / 3.47 | × 1.06 to 1.07 |
| ngfx, off | 2.56 / 2.73 / 2.69 | 2.65 / 2.57 / 2.54 | × 1.05 |
| ngfx, SSAA (one trace) | 7.08 | 7.10 | × 1.04 |

"Overlap" is the GPU work summed over every channel and encoder, divided by the time
any of it ran: gfx's encoders run alongside each other (its blits, the MSAA resolve, the
next pass's vertex work), ngfx's hardly. In the window the GPU moves between its Medium
and Maximum states, so single traces there compare less: 3D gfx 2.88 ms, ngfx 3.44; flat
2.30 against 2.19 at the same mix of states (Minimum and Medium), which is the same.

- ngfx's GPU stamps (`GOOSE_NGFX_BENCH=1`) span from a frame's first command to its last,
  across both of its submissions, so they include the wait for the drawable between them
  and read 1.2 to 17 ms frame to frame. They agree with the trace only for SSAA (7.6 ms
  full screen); the trace is the measure here.

**Reading them.**

- **The 3D board: ngfx's GPU, and it is SMAA.** Full screen, ngfx with SMAA takes 0.42 ms
  more of the GPU a frame than gfx (3.47 against 3.05, +14%); with no antialiasing it
  takes 0.47 ms less (2.58). SMAA's three passes cost about 0.9 ms at 3600 × 2260; FXAA
  (waited 3.78 full screen) costs about what SMAA does; SSAA 4.5 ms more than off, 2.7
  times the frame. The CPU isn't it.
- **The flat board**: the same GPU time on both where their clocks match.
- **The per-pass barrier on Metal** (goose-ngfx `docs/design.md`, task 008 there) is not
  it: with it left out (a local switch in `native/ngfx_draw.cpp`, reverted), interleaved,
  two traces each, the loop's frames read 3.42 / 3.48 ms with it and 3.39 / 3.42 without
  (SMAA, full), 2.48 / 2.62 and 2.47 / 2.54 (off), the overlap × 1.05 either way. No hang
  in those 12 runs, which says nothing at task 008's rate (5 in 123), so the barrier
  stays.

**What to try**, none of it needed at 60 or 120 Hz, where both builds present every
frame with the GPU two-thirds idle:

- SMAA's edges pass writing a stencil that the weights pass tests, as SMAA's reference
  does (task 065, "Later"): the weights pass is the costly one, and most pixels have no
  edge.
- Why ngfx's encoders overlap less than gfx's (× 1.05 against 1.3), not measured yet:
  not the per-pass barrier (above). Instruments' dependency view of one frame of each
  would show what each pass waits on, if the 3D board ever has to go faster.
- ngfx's bench stamps per submission, so its GPU time leaves out the drawable's wait.
