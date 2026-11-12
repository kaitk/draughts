# 074: ngfx against gfx, uncapped, on Windows

Status: in-progress (the runs done 2026-11-12; where ngfx's lower GPU time comes from, still open)

Task 070 measured both renderers uncapped on the Mac. This does the same on the Windows
PC (RTX 4090), full screen, every antialiasing way of each, with memory: whether ngfx
earns being the default (`--renderer auto`, task 073) by costing less, and whether the
gap is ngfx's or a fault in gfx.

## What it took to measure uncapped

- **ngfx's `NO_VSYNC` did nothing on Vulkan.** NoGraphicsAPI fixed FIFO, and ngfx only
  turned a Metal layer's display sync off: `--no-vsync` presented 165 fps of 165.
  NoGraphicsAPI's `DeviceDesc` gained `vsync` (`kaitk/NoGraphicsAPI` `ngfx` `e50736d`, and
  `vsync-option` on upstream `main` for a pull request): false presents immediately, else
  by mailbox, else FIFO. goose-ngfx `f6ffae3` passes `NO_VSYNC` to it.
- **gfx's `NO_VSYNC` was held to the refresh full screen.** It asked for mailbox first,
  which NVIDIA's Vulkan driver holds to 165 Hz full screen (747 fps in a window). It asks
  for immediate first now (`kaitk/goose_gfx`'s `no-vsync-immediate`, in its `main`).
- `scripts/windows_perf.py` prints the bench's most private bytes (the process's peak
  commit) and the 3D bench's CPU a frame.

## The runs

Windows 11, RTX 4090 (driver 617.42), 2560 × 1440 at 165 Hz, mains power.
`scripts/windows_perf.py 1000` with `FLAGS="--no-vsync --aa <way>"`: `--size full`, the
game (Russian, wood, the start), `--bench 1000`, PresentMon recording the presents.
Three rounds, configurations interleaved, medians; the rest (`--rest 25`) from the
first round. gfx built from `kaitk/goose_gfx` `main` (`d9645b2`); ngfx at goose-ngfx
`f6ffae3`, NoGraphicsAPI `e50736d`, its 3D way SMAA by default.

Presented fps (avg / 1% low, the app's own clock), waited frame P50 / P99 in ms (fill,
submit, and GPU, each frame waited for), the CPU a frame to the submit, and PresentMon's
GPU busy a frame (P50 / P99):

| run | fps | waited | cpu | GPU busy |
|---|---|---|---|---|
| gfx flat | 2,372 / 1,674 | 0.40 / 0.92 | 0.021 | 0.39 / 0.59 |
| ngfx flat | 5,326 / 2,894 | 0.21 / 1.38 | 0.033 | 0.14 / 0.49 |
| gfx 3D off | 2,117 / 1,190 | 0.33 / 0.75 | 0.033 | 0.46 / 0.70 |
| gfx 3D msaa (its default) | 1,909 / 1,302 | 0.37 / 0.47 | 0.037 | 0.50 / 0.61 |
| gfx 3D smaa | 1,825 / 1,227 | 0.37 / 0.49 | 0.045 | 0.51 / 0.64 |
| ngfx 3D off | 2,723 / 1,925 | 0.18 / 0.52 | 0.022 | 0.19 / 0.56 |
| ngfx 3D fxaa | 2,710 / 1,882 | 0.27 / 0.71 | 0.024 | 0.22 / 0.57 |
| ngfx 3D smaa (its default) | 2,644 / 1,913 | 0.24 / 0.52 | 0.031 | 0.23 / 0.58 |
| ngfx 3D ssaa | 2,612 / 1,755 | 0.36 / 0.97 | 0.024 | 0.35 / 0.69 |

The three runs of each agree within 3% (gfx 3D msaa 1,911 / 1,901 / 1,909 fps; ngfx 3D
smaa 2,607 / 2,663 / 2,644).

**gfx before upstream's upload buffer** (goose_gfx `v1` with this repository's patches,
as shipped until `6a75d05`), the same way: flat 1,514 fps, cpu 0.160 ms; 3D off 736 fps,
cpu 0.276; msaa 736, 0.268; smaa 751, 0.289. Every `gfx::update_buffer` made, mapped, and
released a transfer buffer of its own, with a copy pass each (four a 3D frame); upstream's
`1fd45b8` (goose_gfx #5) reuses one upload buffer. That alone took gfx's 3D frame from
0.27 to 0.03 ms of CPU and from 736 to 1,909 fps: the first runs' gap (ngfx 3.6 times
gfx's frames) was mostly this.

### Memory

At rest in the game after 12 s, full screen (PowerShell's GPU process counters and the
process's private bytes), and the bench's most private bytes (peak commit):

| | dedicated GPU | shared GPU | private | bench peak private |
|---|---|---|---|---|
| gfx flat | 194.5 MB | 43.1 | 260.2 | 296 |
| ngfx flat | 140.6 MB | 40.1 | 184.7 | 119 |
| gfx 3D (msaa / smaa / off) | 322.8 / 324.8 / 322.8 MB | 45.4 | 398 to 403 | 705 / 748 / 577 |
| ngfx 3D (off / smaa / ssaa) | 249.0 / 249.0 / 250.8 MB | 40.4 | 304 to 306 | 258 / 337 / 373 |

The app's own `--rest 25` footprint (private bytes, after its idle trim): gfx flat 260,
3D 406 to 408 MB; ngfx flat 97, 3D 214 to 217. CPU at rest 0 to 0.18% on both, nothing
drawn. ngfx uses 54 MB less dedicated GPU memory flat and 74 MB less on the 3D board
here, where on the Mac it used more (task 065, 071).

### Sanity checks

- **The same picture.** The 3D game full screen with SMAA, grabbed from the screen
  (`PIL.ImageGrab`), gfx against ngfx: 1 pixel of 3,686,400 differs by more than 32 of
  255. ngfx draws the whole scene at 2560 × 1440.
- **The same CPU.** With the upload buffer, both record a frame in 0.02 to 0.045 ms; the
  remaining gap is not the CPU.
- **Presenting.** With vsync (as the app runs), both flip straight to the screen
  (Hardware: Independent Flip), show every frame at 165 Hz, and reach the display in
  about 6 ms. Uncapped, in the batch above Windows composed ngfx's window (Composed:
  Copy with GPU GDI), which leaves DWM's copy out of ngfx's GPU busy. Later the same
  builds, old and new, flipped straight to the screen (Hardware: Legacy Flip), so it was
  the desktop at the time, not NoGraphicsAPI's swapchain: neither its present-modes
  struct, a transfer usage as SDL's, nor two images in place of three changed it. The
  direct runs below are the fair GPU comparison.
- **GPU busy depends on the clocks.** At 165 Hz the 4090 idles low: 1.89 ms busy for gfx
  and 2.49 for ngfx a 3D frame, against 0.5 and 0.23 uncapped. Comparing GPU time needs
  fixed clocks (`nvidia-smi -lgc`, which needs admin) or a GPU trace.

### Both flipped straight to the screen

Uncapped, three interleaved rounds, ngfx on NoGraphicsAPI at upstream's `main`
(goose-ngfx `nographicsapi-main`; the build before gave the same rates). PresentMon's GPU
busy P50, presented fps, and present to display:

| run | gfx | ngfx |
|---|---|---|
| flat | 0.39 ms, 2,416 to 2,444 fps, 0.7 ms | 0.21 to 0.25 ms, 3,995 to 4,519 fps, 0.3 ms |
| 3D msaa (gfx) / smaa (ngfx) | 0.50 ms, 1,957 to 1,967 fps, 0.9 ms | 0.36 to 0.37 ms, 2,625 to 2,676 fps, 0.3 ms |
| 3D smaa both | 0.51 ms, 1,890 to 1,904 fps, 1.0 ms | as above |

ngfx's frame takes 27% less of the GPU on the 3D board (SMAA on both) and about 40% less
flat, and reaches the display 0.6 ms sooner (Legacy Flip against gfx's Independent Flip).

## Reading them

- **The CPU is not a reason for ngfx.** Both take about 0.03 ms a frame to record. The
  game's own frame work is as small; changing the game to use less of the CPU through
  ngfx gains nothing measurable on this PC.
- **The GPU is a modest reason.** Both flipped straight to the screen, ngfx's frame takes
  27% less GPU time on the 3D board and 40% less flat, and presents 1.4 and 1.8 times
  gfx's frames. Nothing at 165 Hz needs it on the 4090, which both leave almost idle; on
  a weaker GPU it would be headroom. A GPU trace of each (Nsight Graphics is installed)
  should show where gfx's extra 0.14 to 0.18 ms goes: likely its screen kept as a texture
  and copied to the window, which ngfx draws straight into, and SDL_GPU's barriers.
- **Memory is a reason.** ngfx holds 54 to 74 MB less GPU memory and 75 to 190 MB less
  private memory here. On the Mac it was the other way (task 071), so it is the platform's
  driver and NoGraphicsAPI's Vulkan backend, not ngfx in general.

## Next

- A GPU trace of one 3D frame of each (Nsight Graphics), and the same with clocks fixed.
- The same runs on a laptop or integrated GPU, where the GPU is the limit and the gap
  would show at 60 Hz.

## Acceptance criteria

- [x] `--no-vsync` uncapped on both builds full screen on Windows
- [x] Both builds' uncapped numbers, flat and 3D, every antialiasing way, recorded here
- [x] Memory of each, GPU and process, recorded here
- [x] The gap checked: the same picture, and what in gfx caused most of it (fixed)
- [ ] Where ngfx's lower GPU time comes from, from a trace
