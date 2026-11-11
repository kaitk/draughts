# 070: ngfx against gfx, uncapped, on the Mac

Status: todo (on the `ngfx` branch)

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

- [ ] `--no-vsync` on both builds, checked to present uncapped
- [ ] Both builds' uncapped numbers, flat and 3D, windowed and full screen, recorded here
- [ ] ngfx's antialiasing modes measured against gfx's MSAA, uncapped
- [ ] Where ngfx is slower, what it is (CPU or GPU) and what to try, recorded here
