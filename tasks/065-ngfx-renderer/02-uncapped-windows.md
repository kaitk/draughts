# 02: ngfx against gfx, uncapped, on Windows

Status: in-progress (the runs done 2026-11-12; where ngfx's lower GPU time comes from,
still open)

Task 070 measured both renderers uncapped on the Mac. This does the same on the Windows
PC (RTX 4090), full screen, every antialiasing way, with memory: whether ngfx earns being
the default (`--renderer auto`, task 065/01), and whether the gap is ngfx's or a fault in gfx.

## What it took to measure uncapped

- `--no-vsync` now presents immediately on both: NoGraphicsAPI's `DeviceDesc` gained
  `vsync` (`kaitk/NoGraphicsAPI` `e50736d`, `vsync-option` for a pull request), and gfx
  asks for immediate before mailbox (`kaitk/goose_gfx`'s `no-vsync-immediate`).
- Uncapped, NVIDIA flips ngfx's swapchain only while its window is in front, so
  `tools/perf/windows_perf.py` brings the window to the front once it shows. With vsync both
  flip alike, so the app as run is unaffected.
- `tools/perf/windows_perf.py` prints the bench's peak private bytes and the 3D CPU a frame,
  and takes `SIZE=WxH` for a window.

## The runs (2026-11-12)

RTX 4090 (driver 617.42), 2560 × 1440 at 165 Hz, `FLAGS="--no-vsync --aa <way>"`, the
game, `--bench 1000`, three rounds interleaved, medians. gfx from `kaitk/goose_gfx` `main`
(`d9645b2`); ngfx at goose-ngfx `1cda46e`.

| run | fps (avg / 1% low) | CPU ms | GPU busy P50 / P99 ms |
| --- | --- | --- | --- |
| gfx flat | 2,422 / 1,781 | 0.020 | 0.39 / 0.52 |
| ngfx flat | 4,386 / 2,445 | 0.030 | 0.23 / 0.33 |
| gfx 3D msaa (its default) | 1,976 / 1,434 | 0.030 | 0.50 / 0.56 |
| gfx 3D smaa | 1,902 / 1,522 | 0.038 | 0.51 / 0.58 |
| ngfx 3D off | 2,746 / 2,385 | 0.021 | 0.34 / 0.41 |
| ngfx 3D smaa (its default) | 2,660 / 2,289 | 0.031 | 0.36 / 0.42 |

ngfx's frame takes 26 to 29% less GPU time on the 3D board and 41% less flat. Most of the
first runs' gap (ngfx 3.6 times gfx's frames) was gfx making a transfer buffer per
`update_buffer`, fixed upstream by `1fd45b8` (gfx's 3D CPU 0.27 → 0.03 ms).

Memory at rest, full screen: dedicated GPU gfx 194.5 / 322.8 MB (flat / 3D) against ngfx
140.6 / 249.0, so ngfx holds 54 to 74 MB less here, where on the Mac it held more
(task 071). The pictures match (1 pixel of 3,686,400 over 32 of 255).

GPU busy depends on the clocks: at 165 Hz the 4090 idles low (1.89 ms gfx, 2.49 ngfx a 3D
frame), so comparing GPU time needs fixed clocks (`nvidia-smi -lgc`, admin) or a trace.

## Left

- A GPU trace of one 3D frame of each (Nsight Graphics), and the same with clocks fixed:
  likely gfx's screen kept as a texture and copied, and SDL_GPU's barriers.
- The same runs on a laptop or integrated GPU, where the gap would show at 60 Hz.

## Acceptance criteria

- [x] `--no-vsync` uncapped on both builds full screen on Windows
- [x] Both builds' uncapped numbers, flat and 3D, every antialiasing way, recorded here
- [x] Memory of each, GPU and process, recorded here
- [x] The gap checked: the same picture, and what in gfx caused most of it (fixed)
- [x] Both presenting straight to the screen in every run of the table
- [ ] Where ngfx's lower GPU time comes from, from a trace
