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
  (phones from 720 × 1280 to 1080 × 2400, tablets up to 2560 × 1600 and 2880 × 1920,
  the sizes task 030 laid out for). Size what follows the screen (render targets, the photograph and its
  blurred copies, the text atlas) from the screen it runs on, not the Galaxy tablet's
  1920 × 1200, and measure memory at the smallest and largest of those sizes too (the
  user, 2026-11-08: don't waste memory, but it must work everywhere).
- **Density, not only pixels** (the user, 2026-11-08): a phone's long side can exceed the
  tablet's (the Pixel 7a's 2400 against 1920, the photograph shown about 1.17× up), but
  at about twice the tablet's pixel density a smaller sharp image (1024 to 1536) may look
  the same. Size it from the screen's density as well as its size, and compare side by
  side on the Pixel 7a. On a 20:9 screen more than half the square is cropped away, but
  turning the screen shows another slice, so the square stays unless a rotation reloads.
  The blurred copies need neither: a blur has no fine detail, so its size can stay fixed
  (or shrink, above) at every density and resolution. The GPU can't render into ASTC, so
  a compressed blur means blurring offline and shipping it, or keeping the GPU blur small.
- **Cut what is cheap and safe**, one change at a time, each with its before and after
  on the tablet and a look that it still renders the same.

## Starting numbers (from task 030, 2026-11-08)

- **The tablet**, everything up to `d7dbccc`: 20 lifecycle cycles of home, resume, and
  rotation, PSS 273 MB at the start, then 259 to 264 MB, native heap 27 MB, graphics 211
  to 215 MB; idle at home in landscape, 60 s, the program thread 0.03 s, the process
  1.26 s, 60 voluntary switches.
- **The Pixel 7a** (1080 × 2400, the density floor on), 5 s after arriving, portrait:
  home PSS 291 MB, graphics 252 (180 GL, 73 EGL); the game (International) 292 MB,
  graphics 252. A cold start's home, before the floor: 289 MB, graphics 244.
- **Larger screens, on the Mac only** (no such device): the sharp photograph is
  cover-cropped by the long side from its 2048 px texture, so stretched long side /
  2048: 2560 px 1.25×, 2880 px 1.41×, 2208 px 1.08×, 2048 px 1.0×. Mac footprint 6 s in:
  2560 × 1600 215 MB on home and in a game, 1920 × 1200 160 and 159 MB; the 55 MB is
  graphics (100 MB against 65, the screen-sized buffers). The Mac's allocator and driver
  differ, so this shows only that the cost grows with the pixels; a device's PSS at
  2560 × 1600 is not measured.

## Also seen, for the same pass

- Idle CPU of the whole process rose from 1.25 s a minute (task 025) to about 1.5 s
  (task 007, game and puzzles alike) while the program's thread stayed at 0.02 s: find
  which thread (the computer's worker, SDL, the launch cover) and why.
- The first puzzle opened after launch had a 31 ms frame gap in its opening (task 007).

## Acceptance criteria

- [ ] A table of where the memory goes, CPU and GPU, measured on the tablet
- [ ] Each change with its before and after (PSS and graphics), the look unchanged
- [ ] Memory measured at the smallest and largest screen sizes, everything still drawn right
- [ ] Idle CPU and lifecycle memory scripts run at the end, numbers recorded
