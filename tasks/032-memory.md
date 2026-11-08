# 032: Bring memory use down

Status: todo (last, once the other work has landed)

The app uses about 261 to 274 MB on the tablet (PSS, `scripts/lifecycle_memory.sh`), of
which about 206 to 215 MB is graphics. Not bad, but more than a draughts app should
need, and Goose usually packs data tightly. The user (2026-11-08) expects low-hanging
fruit. A holistic look, measuring before cutting.

## Work

- **Where it goes:** `dumpsys meminfo` by category (native heap, graphics/GL mtrack,
  code, stack, data stack), the Goose program's own arrays and their sizes, and the GPU
  side: every texture and buffer with its format and size (the photograph and its
  blurred copies per season, the text atlas at each baked size, settings' thumbnails,
  render targets and their sample counts, swapchain images), and what SDL_GPU and the
  Vulkan driver keep on top.
- **Candidates to check, not assumptions:** textures kept in RGBA8 or larger where a
  smaller format or a lower resolution would look the same on the tablet; blur copies
  that could be smaller (a blurred image needs few pixels); several seasons or sizes
  resident at once; mipmaps nothing samples; transfer buffers kept after upload; MSAA
  targets; the photograph loaded at more pixels than the screen shows; the 16 MB of data
  stack the photograph's load takes (`trim_memory`); the AI's transposition table and
  the worker's own engine; struct layout and padding in large arrays (Goose's field
  order, `i64` where `i32` or `u8` would do in per-square or per-entry tables).
- **Cut what is cheap and safe**, one change at a time, each with its before and after
  on the tablet and a look that it still renders the same.

## Acceptance criteria

- [ ] A table of where the memory goes, CPU and GPU, measured on the tablet
- [ ] Each change with its before and after (PSS and graphics), the look unchanged
- [ ] Idle CPU and lifecycle memory scripts run at the end, numbers recorded
