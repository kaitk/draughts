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
- **Compressed textures** (the user, 2026-11-08): for images loaded from files (the
  season photographs, settings' thumbnails), not render targets or the blurred copies
  drawn into them. ASTC is the candidate: Android's baseline for Vulkan devices has ETC2
  and ASTC LDR, Apple silicon has ASTC, so the tablet, phones, and the Mac all sample it;
  4×4 blocks are 1 byte a pixel against RGBA8's 4, 6×6 about 0.44. Encode offline
  (`astcenc`, Apache 2.0) into the APK, which also skips decoding at load (the 16 MB
  data stack spike). Check `SDL_GPUTextureSupportsFormat` at startup and fall back to
  decoding to RGBA8 where it's missing (an Intel Mac, a desktop GPU with only BC), so
  nothing stops working. Worth it only if the measured table shows these textures are a
  real part of the total; compare the look on the tablet at 4×4 and 6×6.
- **The blur, against the alternatives** (the user, 2026-11-08: measure them and take
  the best, as Carmack or Sweeney would). Now (`docs/architecture/rendering.md`): the
  photograph scaled to 512 × 512 and blurred once per season on the GPU (two Gaussian
  passes, 1 MB), and that blurred again into 256 × 256 for the glass (0.25 MB); the
  sharp 2048 × 2048 RGBA (16 MB) stays resident behind home. Measure against: smaller
  copies (a blur of sigma 5.6 at 512 keeps its look at 256 or 128 with bilinear
  sampling, a quarter or a sixteenth of the memory); a dual-filter (Kawase) down and up
  chain, the usual mobile blur; sampling a mip of the photograph instead of a copy;
  copies blurred offline and shipped compressed, with no GPU pass at all; and for the
  sharp image, sizing it to the screen's long side and ASTC. For each: memory, the time
  a season change takes on the tablet, and whether the look holds side by side at the
  tablet's and a phone's size. Keep the one that wins on memory without a visible
  change, and record the numbers.
- **Every screen size:** whatever is cut must keep working on every tablet and phone
  (task 030's sizes: phones from 720 × 1280 to 1080 × 2400, tablets up to 2560 × 1600
  and 2880 × 1920). Size what follows the screen (render targets, the photograph and its
  blurred copies, the text atlas) from the screen it runs on, not the Galaxy tablet's
  1920 × 1200, and measure memory at the smallest and largest of those sizes too (the
  user, 2026-11-08: don't waste memory, but it must work everywhere).
- **Cut what is cheap and safe**, one change at a time, each with its before and after
  on the tablet and a look that it still renders the same.

## Acceptance criteria

- [ ] A table of where the memory goes, CPU and GPU, measured on the tablet
- [ ] Each change with its before and after (PSS and graphics), the look unchanged
- [ ] Memory measured at the smallest and largest screen sizes, everything still drawn right
- [ ] Idle CPU and lifecycle memory scripts run at the end, numbers recorded
