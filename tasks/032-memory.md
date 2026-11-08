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

## Measured (2026-11-08)

Step one: measured, nothing cut. On the Galaxy tablet (1920 × 1200, UI scale 1.5), the
build of `27b2c23`; the Pixel 7a wasn't attached, so phone numbers below are worked out,
not measured. `/proc/<pid>/smaps` is closed (the APK isn't debuggable), so the GPU side
comes from a temporary build that logged SDL's `vkAllocateMemory`, its binds, and the
swapchain (an SDL patch and an `app/` copy, neither kept), and `dumpsys gpu --gpumem`.

### `dumpsys meminfo`, fresh launch (PSS, MB)

| | Home | Game | Settings | Puzzle 21 | After 3 lifecycle cycles |
| --- | --- | --- | --- | --- | --- |
| Native heap | 41.0 | 41.6 | 42.0 | 41.0 | 27.3 |
| GL mtrack (Vulkan memory) | 100.7 | 100.6 | 160.3 | 100.6 | |
| EGL mtrack (swapchain) | 59.7 | 59.7 | 32.2 | 59.7 | |
| Graphics | 160.3 | 160.3 | 192.5 | 160.3 | 208.6 to 211.1 |
| Code (.so, .apk, .jar, .oat) | 9.6 | 9.6 | 9.6 | 9.4 | |
| Dalvik, stack, other, unknown | 4.9 | 4.9 | 4.9 | 4.9 | |
| **Total PSS** | **216.3** | **216.9** | **249.5** | **216.1** | **252 to 255** |

`dumpsys gpu --gpumem` gives the process 197.2 MB at home and 258.3 MB in settings. Settings
opened at launch draws frames for a while, and that is enough to need a second 64 MiB
block (below). The lifecycle's 211 MB is the same two blocks plus the swapchain.

### Where the graphics memory goes

The Mali-G615 has one memory type (device-local and host-visible), so everything shares
SDL's allocator: a resource up to 2 MiB goes into 16 MiB blocks, and a larger one gets a
block **rounded up to 64 MiB** (`LARGE_ALLOCATION_INCREMENT` in `SDL_gpu_vulkan.c`). It
then also takes later large resources into the free space. Transfer buffers are
dedicated allocations of their exact size.

| What | Size, format | Bytes (Mali) | Lifetime |
| --- | --- | --- | --- |
| Swapchain | 6 × 1920 × 1200 RGBA8 (driver's `minImageCount` is 6; SDL asks for 2) | 6 × 9.7 MiB = 58 MiB | resident, EGL mtrack |
| gfx's screen | 1920 × 1200 RGBA8 | 9.6 MiB | resident; a second one while cycled or resized |
| gfx's screen depth | 1920 × 1200 D32F, never used by a 2D app | 9.5 MiB | as the screen |
| Sharp photograph | 2048² RGBA8, 1 mip | 16.3 MiB | resident, current season |
| Text atlas | 1024 × 2048 RGBA8 (1846 rows used), 6 faces × 376 glyphs | 8.1 MiB | resident |
| Blurred copy, glass copy | 512² and 256² RGBA8 | 1.0 + 0.26 MiB | resident |
| Blur intermediates | 512² ×2 (one a texture), 256² | 2.3 MiB | released after the blur |
| Thumbnails | 160 × 392 RGBA8 | 0.5 MiB | resident |
| Storage buffers | quads 32 KB, pieces 3 KB, overlay 256 B | 35 KB | resident |
| Upload transfers | photo 16 MiB, blur source 1 MiB, atlas 8 MiB, thumbs 0.25 MiB | | freed after the next completed submit; the atlas's and thumbs' stay until a frame is drawn |
| Per-frame transfers | 32 KB + 3 KB + 256 B | | `vkAllocateMemory` and `vkFreeMemory` each, every drawn frame |

No MSAA, no mips, one season and one atlas resident. Live `VkDeviceMemory` at home after
launch: one 64 MiB block (screen, depth, sharp, atlas: 45.6 MB, plus a second screen and depth
from a resize at launch), one 16 MiB small block, and the atlas's unfreed 8 MiB transfer:
88.3 MiB of GL mtrack's 98.3. The other **10 MiB is the driver** (pipelines, pools). Once
the screen is cycled (frames drawn while the last is still on the GPU) or recreated
(rotation), a **second 64 MiB block** comes for about 20 MB of screen and depth. After
lifecycle cycles: 2 × 64 + 16 MiB + driver + swapchain = the 211 MB.

### CPU side

- Native heap: 23 MB before `gfx::open` (ART and the JNI, as the POC's 25), +6 MB opening
  Vulkan, +6 MB loading the scene (pipelines; stb's 16 MB decode is freed), +1.7 baking
  text, +1.6 thumbnails: 39 MB malloc'd. After lifecycle cycles it settles at 27 MB.
- Data stacks: the photograph's 16 MiB `px` and the atlas's 8 MiB copy are transient and
  trimmed (anonymous RSS 75 → 58 MB after the scene's `trim_memory`, 69 → 61 after the
  bake). The load's peak is about 33 MB above rest (data stack + stb's decode).
- Goose packs structs (`ai::Entry` is 15 bytes), so no padding. The computer's worker has a
  transposition table of 2^18 × 15 B = 3.75 MiB and 64 plies × 25.7 KB = 1.6 MiB, committed only
  once the computer first plays. The main thread's state is under 1 MB: `Shell` 237 KB,
  `Gui` 115 KB (glyph tables 81 KB), the puzzle's `Play` 111 KB.

### Idle CPU per thread (60 s, untouched)

| Thread | Home | Game |
| --- | --- | --- |
| `SDLActivity` (the Java main thread) | 1.12 s, 3128 wakeups | 1.30 s, 3126 wakeups |
| `SDLThread` (the program) | 0.02 s, 62 | 0.03 s, 62 |
| Process | 1.15 s | 1.34 s |

The idle cost and its rise sit in the Java main thread, waking 52 times a second: SDL's
`SDLSurface` keeps the accelerometer registered at `SENSOR_DELAY_GAME` (20 ms) while
resumed (`dumpsys sensorservice`: our process's only sensor connection), for its rotation
check and accelerometer-as-joystick. The program thread wakes once a second as designed.

### Candidates, ranked (tablet; smallest phone 720 × 1280, largest tablet 2880 × 1920)

1. **SDL's 64 MiB rounding** (an SDL patch: allocate large resources at their size or a few
   MiB): steady state after any animation or rotation from 2 × 64 MiB to the ~45 to 66 MB
   used, **~60 MB** (fresh home ~18); at 720 × 1280 ~40, at 2880 × 1920 ~60. Low risk, a
   constant; small effort. A note for the user, SDL being upstream.
2. **The screen not cycled and no depth target** (a gfx patch: create the depth target
   lazily, and clear the screen without cycling; the app begins its pass without depth):
   9.5 MiB depth always, and with no cycled pair the second 64 MiB block goes even
   without 1, **~10 to 64 MB**; 3.5 / 21 MiB depth at the small and large sizes. Low risk
   (the GPU waits on the last frame's blit instead of taking new memory); small effort.
3. **The text atlas as R8, cut to its used rows, and the title and clock faces baked with
   only their glyphs**: 8 MiB to about 0.6 to 1.8, **~6.5 to 7.5 MB**, and the 8 MiB
   transfer and 10 MB bake buffers with it; 4 → 0.2 at 720 × 1280, **32 → 1.5 MiB at
   2880 × 1920** (scale 2.4; 16 MiB at scale 2.0, the Pixel's 1.97). Low risk; medium
   effort (app-only: R8 upload, `.r` in the shader, v rescaled, a glyph set per face).
4. **The sharp photograph as ASTC, sized by the screen and density**: 16 → 4 MiB (4×4)
   or 1.8 (6×6), **~12 to 14 MB**, and the 33 MB load spike and 16 MiB transfer gone;
   phones at 1536 px 9 → 2.25. Medium risk (the look, the RGBA8 fallback, gfx has no
   compressed formats, so a gfx patch); high effort. Sizing alone saves nothing on the
   tablet (2048 against a 1920 long side), ~7 MB on a phone.
5. **Drawing straight into the swapchain** (a gfx patch dropping the screen copy): 9.6 MiB
   and its cycled copy; high effort. The swapchain's 6 images (58 MiB; 21 at 720 × 1280,
   127 at 2880 × 1920) are the driver's minimum and can't be cut from the app.
6. **The computer's tables**: 2^17 entries and 128 moves a ply would save ~3 MB in the
   worker, only once it plays; strength and time to check with `tools/aibench.goose`. Low.
7. **Blur copies smaller, Kawase, a mip, offline**: 1.25 MiB resident inside a 16 MiB
   block, so nothing measurable; not worth it. Thumbnails as ASTC: 0.4 MB, not worth it.
8. Nothing to cut: MSAA (none), unused mips (none), several seasons or sizes (one of
   each), struct padding (packed), the data-stack spike (already trimmed).

Not memory, but seen: every drawn frame allocates and frees three `VkDeviceMemory`
transfers (`update_buffer`); a persistent upload buffer in gfx would end that. Idle CPU:
keep `SDLSurface` from registering the accelerometer (`DraughtsActivity` overriding
`createSDLSurface` with a surface whose `enableSensor` does nothing, or an SDL patch), about
1.1 to 1.3 s a minute, nearly all of it; check that turning the screen still relays out.

With 1 to 3 the tablet's graphics would go from ~211 to ~135 MB and PSS from ~260 to
~185 MB.

## Cuts

### Cut 1: the screen without a depth target or cycling (2026-11-08)

`patches/goose_gfx/0003-screen-without-depth-or-cycling.patch`: gfx makes the screen's
depth target only when `screen_depth()` is first called, and `begin_pass` no longer
cycles the screen when it clears it; the app begins its pass with no depth target. Why
cycling was there: it lets SDL give a cleared target fresh memory while an earlier frame
still reads it, so the GPU need not wait. For the screen that is the last frame's blit,
nearly always in flight, so cycling kept a second copy for good. Without it SDL's barrier
orders the clear after that blit on the GPU; the CPU never waits, and the frame times
below show no stall.

Galaxy tablet, landscape, rotation locked, `pm clear` before each build's run; before is
`d3c2714`'s APK, after the same with the cut. Home and the game 8 s after a fresh
launch; "after moves" after five moves and take-backs (c3-d4) in the game; "after a
rotation" after those and a turn to portrait and back; then home and another turn.

| PSS / graphics (GL + EGL mtrack), MB | Before | After |
| --- | --- | --- |
| Home, fresh | 215.4 / 156.6 (98.3 + 58.3) | 215.2 / 156.5 (98.2 + 58.3) |
| Game, fresh | 212.6 / 156.6 (98.3 + 58.3) | 212.3 / 156.5 (98.2 + 58.3) |
| Game after moves | 180.9 / 123.8 (92.3 + 31.5) | 181.0 / 123.7 (92.2 + 31.5) |
| Game after a rotation | 324.9 / 267.3 (220.3 + 46.9) | 200.9 / 143.3 (91.9 + 51.4) |
| Home after another rotation | 265.3 / 207.5 (156.1 + 51.4) | 196.0 / 138.9 (91.9 + 46.9) |
| `dumpsys gpu --gpumem`, the last two | 282.9, 218.8 MiB | 154.5, 154.5 MiB |

Fresh, nothing changes: the depth target sat inside the first 64 MiB block, which is
taken whole either way. The cut is in the second block: before, a rotation remade the
screen and its depth (19 MiB) beside their cycled copies and the old pair, and SDL took
a second 64 MiB block (and a short peak above it); after, the screen, the photograph,
and the atlas (34 MiB) and a remade screen fit in the first. GL mtrack stays at 92 MB
through rotations, the steady state ~69 MB lower, PSS ~265 → ~196 MB. Either change
alone might have kept this tablet in one block; both leave room.

Frame times, SurfaceFlinger's `--timestats` present-to-present of the app's layer at
90 Hz, over 15 moves and 15 take-backs, two runs a build (gaps of 350 ms and more, the
app idle between taps, left out):

| | Frames | 10 to 11 ms | 21 to 22 ms | 32 to 33 ms |
| --- | --- | --- | --- | --- |
| Before | 948 | 902 (95.1%) | 38 | 8 |
| After | 946 | 908 (96.0%) | 28 | 10 |

The same within run-to-run noise, no frames dropped. The look: the same Mac shots
(home, the game, a transition held at 0.5, settings, puzzle 21, landscape and portrait)
are byte-identical apart from settings' preview flash (25 pixels), and the tablet's shots
of home and the game in landscape and portrait after rotations are byte-identical. The
Mac runs the built-in gfx, so it shows only the app's side of the change.

### Cut 2: large resources in memory of their own size (2026-11-08)

`patches/SDL/0003-large-allocations-at-their-size.patch`: SDL_GPU's Vulkan allocator
gives a resource over 2 MiB its own `VkDeviceMemory` of exactly its memory requirements'
size instead of a block rounded up to 64 MiB, and keeps such allocations (transfer
buffers' too) out of the free list, so nothing else lands in one and it is freed at a
submit soon after its resource is released. Small resources keep the shared 16 MiB
blocks. How it works and what to watch for 3D: `docs/architecture/rendering.md`, GPU
memory.

Galaxy tablet, landscape, rotation locked, `pm clear` before each launch; before is
`c26c9e3` (cut 1), after the same with the patch, both built in one worktree. Home 8 s
after a fresh launch; the game 8 s after its own launch (`--screen game`); after five
moves and take-backs (b4-c5); after a turn to portrait and back; home after another
turn; then settings, a season (Winter), back home and into the game.

| PSS / graphics (GL + EGL mtrack), MB | Before | After |
| --- | --- | --- |
| Home, fresh | 220.0 / 160.3 (100.6 + 59.7) | 189.1 / 129.5 (69.8 + 59.7) |
| Game, fresh | 219.7 / 160.3 (100.6 + 59.7) | 189.4 / 129.5 (69.8 + 59.7) |
| Game after moves | 187.5 / 126.7 (94.4 + 32.2) | 157.2 / 95.9 (63.6 + 32.2) |
| Game after a rotation | 207.9 / 146.7 (94.1 + 52.6) | 177.5 / 115.9 (63.3 + 52.6) |
| Home after another rotation | 208.0 / 146.7 (94.1 + 52.6) | 177.0 / 115.9 (63.3 + 52.6) |
| Settings | 173.1 / 112.6 (94.3 + 18.3) | 142.6 / 81.8 (63.5 + 18.3) |
| Settings after a season change | 163.0 / 112.6 (94.3 + 18.3) | 132.5 / 81.8 (63.5 + 18.3) |
| The game, from home after settings | 163.0 / 112.6 (94.3 + 18.3) | 132.6 / 81.8 (63.5 + 18.3) |
| `dumpsys gpu --gpumem`: home fresh, after moves, after a rotation, after the season | 188.0, 182.0, 154.5, 154.7 MiB | 157.9, 151.9, 124.4, 124.6 MiB |

GL mtrack is about 31 MB lower at every point, PSS 30 to 31 MB: the 64 MiB block's
unused ~30 MiB. What is left is the resources' sum (screen 9.6 MiB, photograph 16.3,
atlas 8.1; fresh, also the atlas's 8 MiB transfer until a frame is drawn), the 16 MiB
small block, and about 10 MB of the driver's. EGL mtrack (the swapchain) moves with the
screen shown, the same in both. Native heap is the same (it drops 10 MB in both once a
season loads, the decode's buffers). Worked out, not measured: at 2880 × 1920 (screen
21.1 MiB, atlas 32, photograph 16.3) two 64 MiB blocks become ~70 MiB, ~58 MiB saved; at
720 × 1280 (screen 3.5, atlas 4) one block becomes ~24 MiB, ~40 saved.

When large allocations happen, from a temporary build logging SDL's `vkAllocateMemory`
and `vkFreeMemory` (not kept): at launch the screen (10.06 MB), the photograph (17.04 MB)
and its 16 MiB transfer, the blur source's 1 MiB transfer, the atlas (8.52 MB) and its
8 MiB transfer, and one 16 MiB small block; on a season change the new photograph and
its transfer, then the old photograph freed; on a rotation the new screen, then the old
one freed. A move or take-back allocates only the three per-frame transfers (32 KB, 3 KB,
256 B), as before the patch. Opening settings allocates nothing large.

Frame times, SurfaceFlinger's `--timestats` present-to-present at 90 Hz over 15 moves and
15 take-backs, two runs a build (gaps of 350 ms and more left out):

| | Frames | 10 to 11 ms | 21 to 22 ms | 32 to 33 ms |
| --- | --- | --- | --- | --- |
| Before | 956 | 883 (92.4%) | 65 | 8 |
| After | 957 | 884 (92.4%) | 59 | 14 |

The same within run-to-run noise, no frames dropped. A season change's longest frame
gap, four seasons a build: before 58 to 78 ms, after 66 to 78 ms (the histogram's 4 ms
buckets), the same. A rotation recreates the layer, so timestats doesn't see it; it
allocates one screen and frees one. The look: the tablet's shots of the game and home
after rotations, and the game in winter after the season change, are byte-identical
before and after. The Mac uses Metal, untouched.

Alternatives weighed (the user, 2026-11-08, asked whether rounding to 4 or 8 MiB would
do as well):

- **Rounded to 4 or 8 MiB:** the same allocation count (one per large resource), but
  half a step wasted per resource on average: on the tablet 44 or 56 MiB for the 34 MiB
  of resources, at 2880 × 1920 about 80 or 88 for 70. It would pay only if a freed
  block were kept and taken by a later resource of nearly its size, and that doesn't
  happen here: SDL makes the new screen on a rotation and the new photograph on a
  season change before it releases the old (the log above), and the empty block is
  freed at the next submit. Keeping freed blocks for reuse means a block's rest stays
  free for others, and a large block kept alive by a small tenant is the 64 MiB
  blocks' trouble. Rejected.
- **A smaller fixed block (16 or 32 MiB) shared as upstream does:** less waste than 64,
  but a resource larger than the block still needs its own, the largest tablet's atlas
  (32 MiB) and a 3D MSAA target among them, and shared blocks stay alive while any tenant
  lives. Rejected for exact.
- **`VkMemoryDedicatedAllocateInfo`:** SDL has no `VK_KHR_dedicated_allocation`
  plumbing (no `vkGet*MemoryRequirements2`); an exact plain allocation already gives
  the memory back, and the extension would only let some drivers place it better.
  Not worth the patch's size.
- **A 3D board** (task 015: MSAA 4× target, depth, a shadow map, albedo, normal, and
  roughness atlases with mips) adds perhaps a dozen large resources made at load or a
  resize: a dozen allocations, far from Vulkan's guaranteed 4096, and exact sizing
  keeps their cost at their bytes. What would hurt is a large resource made or cycled
  per frame, with or without the patch.

Risks in the patch: each large resource is one `vkAllocateMemory` (a handful here);
on failure the allocator returns as before and SDL tries the next memory type, but a
large resource can no longer slip into a block's spare room, so memory pressure shows
a little sooner than with an oversized block already held. An SDL upgrade that changes
`VULKAN_INTERNAL_BindResourceMemory` stops the patch applying and fails the build,
loudly.

### Cut 3: the text atlas in one byte a texel, the rows used, and two faces' glyphs (2026-11-08)

`app/text.goose`: the title (64 dp) and the figures (36 dp) are baked with only the
characters they draw (`shell::face_chars`: the app's name in every language file, read at
the bake; the clock's `0123456789:`; and '?', the fallback), the other four faces with
every glyph as before. The texture is R8, the alpha moved to the front of the buffer
`ui::atlas_pixels` returns (in place, no second copy), and only the rows down to the
lowest glyph and one empty row are uploaded, v remapped from whole rows; the UI shader
reads `.r`. No gfx patch: gfx has `R8`, and `ui`'s bake stays RGBA32 since the Mac's
built-in `ui` couldn't take one ([findings](../docs/goose-findings.md)).
`test/shell/faces` checks both sets against every language's name and every clock time
to 100 minutes.

The texture, 1024 wide, from debug prints of the bake on the Mac at each scale:

| Screen (scale) | Before: RGBA, power of two (rows used) | After: R8, rows used |
| --- | --- | --- |
| 720 × 1280 at low density (0.9) | 1024 rows, 4 MiB (709) | 261 rows, 0.25 MiB |
| The Galaxy tablet, or 720 × 1280 at xhdpi (1.5) | 2048, 8 MiB (1846) | 630, 0.62 MiB |
| The Pixel 7a (1.97) | 4096, 16 MiB (3082) | 1023, 1.0 MiB |
| 2880 × 1920 (2.4) | 8192, 32 MiB (4573) | 1482, 1.45 MiB |

On the tablet the two faces' glyph sets took the rows used from 1846 to 630, R8 is a
factor of four, and dropping the power of two up to another two. Under 2 MiB at every size, the
atlas now sits in SDL's shared 16 MiB block, and its transfer buffer shrinks with it. The
bake's transients shrink in proportion (Nuklear's alpha and RGBA images and `ui`'s copy
at the next power of two of the smaller atlas, 4 MiB each on the tablet against 8, and
the program's copy likewise), worked out, not measured.

Galaxy tablet, landscape, rotation locked, `pm clear` before each launch; before is
`ea1faef` (cuts 1 and 2), after the same with the cut. Home 8 s after a fresh launch; a
game (Russian, 5+3, `--screen game`) 8 s after its own launch; that game after a turn to
portrait and back.

| PSS / graphics (GL + EGL mtrack), MB | Before | After |
| --- | --- | --- |
| Home, fresh | 189.0 / 129.5 (69.8 + 59.7) | 173.4 / 113.6 (53.9 + 59.7) |
| Game, fresh | 189.5 / 129.5 (69.8 + 59.7) | 173.3 / 113.6 (53.9 + 59.7) |
| Game after a rotation | 175.7 / 114.0 (61.3 + 52.6) | 166.7 / 105.5 (52.9 + 52.6) |
| `dumpsys gpu --gpumem`: home, game, after a rotation | 157.9, 157.9, 122.5 MiB | 142.4, 142.4, 114.3 MiB |

After a rotation GL mtrack is 8.4 MB lower, the atlas's 8 MiB less its 0.6 now in the
small block. Fresh it is 15.9 MB lower: the atlas's 8 MiB transfer buffer, which lived
until the next drawn frame, is 0.6 MiB too. Native heap is the same (43.4 to 44.1 MB
before, 43.5 to 43.6 after): Nuklear's bake buffers are freed before the measurement
either way. Worked out at the other sizes: 3.8 MiB saved at 720 × 1280 at low density,
15 at the Pixel 7a, 30.5 at 2880 × 1920, each twice that at a fresh launch.

The look: the Mac's shots of home, a clocked game, settings, puzzle 21, and the friend
setup, in English and Estonian, landscape and portrait, and the Pixel 7a's scale in
landscape (home in both languages, a clocked game, the puzzle), are byte-identical to
`ea1faef`'s apart from settings' preview flash, whose box is the one two runs of
`ea1faef` differ in. The tablet's home, clocked game, and the game after a rotation are
byte-identical before and after.

### Cut 4: SDL's accelerometer off (task 011, 2026-11-08)

Not memory: the idle CPU found above, and the rise from 1.25 to 1.5 s a minute listed under
"Also seen". `DraughtsActivity` gives SDL a surface whose `enableSensor` ignores the
accelerometer ([findings](../docs/goose-findings.md)); no SDL patch. Per thread, 60 s
untouched, before `9530afe`, after the same with the change:

| CPU in 60 s (voluntary switches) | Home before | Home after | Game before | Game after |
| --- | --- | --- | --- | --- |
| `SDLActivity` (the Java main thread) | 1.14 s (3123) | 0.00 s (0) | 1.25 s (3132) | 0.00 s (0) |
| `SDLThread` (the program) | 0.03 s (62) | 0.03 s (63) | 0.03 s (62) | 0.02 s (63) |
| Process | 1.19 s | 0.05 s | 1.29 s | 0.06 s |

The game's extra 0.1 s a minute before was the same thread, so the rise was the sensor's
callbacks costing more there, not the computer's worker or the launch cover. Rotation,
the sensor check, and the 300 s run are in task 011's file.

### The scripts after cuts 1 to 4 (2026-11-08)

Galaxy tablet, the build of cut 4, `pm clear`, a fresh launch to home in landscape.

- `scripts/idle_cpu.sh 60`: the program's thread 0.03 s, the process 0.06 s, 60 voluntary
  switches (at the start: 0.03, 1.26 s, 60). Over 300 s: 0.14 s and 0.14 s, 299.
- `scripts/lifecycle_memory.sh 20`: the same process throughout, no errors in logcat.
  Before the first cycle PSS 177 MB, native heap 43.5, graphics 117.7; over the cycles
  PSS 162 to 166 MB, native heap 37.4 to 37.6, graphics 106.3 to 110.4 (at the start:
  PSS 259 to 264, native heap 27, graphics 211 to 215). Graphics rose in two steps of
  2 MB (after cycles 3 and 9) and was flat between them, as the start's 4 MB spread; the
  native heap crept 0.2 MB over 20 cycles. PSS is about 96 MB lower, graphics about 104;
  the native heap, though, sits about 10 MB above the start's 27, not yet looked into.

### Cut 5: the season photographs as ASTC (2026-11-08)

The sharp photograph is uploaded as ASTC in 6 × 6 blocks (2048², 1.87 MB) where gfx and
the GPU take it, with nothing decoded; elsewhere the JPEG is decoded to RGBA8 as before.
`patches/goose_gfx/0004-compressed-textures.patch` gives gfx BC and ASTC formats and
`gs_gfx_format_supported` ([findings](../docs/goose-findings.md)); `app/background.c`
calls gfx's C API to make the texture from the embedded bytes, so nothing goes through
the data stack on either path (the `trim_memory()` calls after loads are gone). The
512 px blur source and settings' thumbnails are now shrunk from the sharp texture on the
GPU (`scene.goose`'s `SHRINK_FRAG`, a 4 × 4 box from 2 × 2 bilinear taps) rather than on
the CPU. How it works, what ships, and the APK: `docs/architecture/rendering.md`, "Scene
and glass".

**What ships and what is generated.** The `.astc` files are made from the lossless PNG
masters with astcenc 5.7.0 (`design/backgrounds/README.md`; installed from ARM's release
zip into `build/`, as `docs/development.md` says: Homebrew has no formula), and like the
JPEGs stay local in `design/backgrounds/masters/`, out of git, embedded with
`__has_embed`: a checkout without them decodes the JPEGs everywhere. The Android build embeds
only the ASTC files (no JPEGs, no stb_image: `#ifndef __ANDROID__` in `background.c`), which
took the APK from 13.69 MB (13,690,076 bytes) to 11.41 MB (11,412,700); a GPU without ASTC
would show the page color. The Mac keeps the JPEG path.

**Which path each platform takes.** Android: gfx is built from patched sources, so the
ASTC path (the tablet's shots differ from the JPEG's as the Mac's ASTC ones do). The Mac:
`goose build` links the release's prebuilt `pkg/gfx/lib/libgoose_gfx.a` (and `goose run`
the binary's built-in gfx), which lack the patch, so a weak stand-in in `background.c`
answers that ASTC isn't supported and the JPEG is decoded, as on an Intel Mac or a
BC-only GPU. For the comparison below the Mac got the ASTC path from a copy of the
release whose `libgoose_gfx.a` was compiled from goose_gfx's `src/gfx` with patch 0004
(`docs/development.md`); Metal sampled it.

**4 × 4 against 6 × 6.** Against the PNG master (astcenc `-thorough`, `-esw rgb1`): JPEG
q85 37.5 to 41.5 dB, 6 × 6 40.0 to 45.1, 4 × 4 45.6 to 50.0, so both are nearer the
master than what shipped. Mac shots (1920 × 1200 and a Pixel 7a's 900 × 2000 at 540 dp,
home in all four seasons, a game, settings) against the JPEG build's: home 45 to 50 dB
for either block size, the blurred game 61 to 63 dB, settings' thumbnails alike. Crops
enlarged 3× of the sharp photograph behind home (summer's birch, tree line and rocks,
autumn's and winter's edges, the phone's) show no difference between the JPEG, 6 × 6,
and 4 × 4; the blur hides any. **6 × 6 kept**: it looks the same at 1.87 MB against
4 MB. The build with this change on the built-in gfx (the JPEG path) matches the old
build at 72 to 82 dB, the GPU shrink standing in for the CPU's box.

**Density** (the Work item above): not done, and not worth it now. As ASTC the sharp
image is 1.87 MB and sits in SDL's shared 16 MiB block; a dense phone's 1024 to 1536 px
copy would save at most 1 MB there, and needs a second encoding per size or a choice at
load. It stays 2048 everywhere; larger tablets' 1.25 to 1.41× stretch is left as is.

**Two waits for the GPU and the embedded pages.** A first build used 6.9 MB *more*
graphics at home (GL mtrack 53.9 → 60.7 MB): the thumbnails made the four seasons'
textures in a row, each freed only after the GPU finished, so they spilled out of the
shared 16 MiB block into another, which a later resident resource kept. A
`gfx::flush()` after each thumbnail took GL at home to 36.4; one between releasing the
old scene and loading the new took GL after the season changes from 57.3 to 40.9, for a
season change one frame longer (11 → 22 ms; it was 54 to 66). And the thumbnails read
all four embedded images, whose clean pages from the APK stayed resident and counted in
PSS (`.apk mmap` 9.2 MB against 4.1 before); `madvise(MADV_DONTNEED)` after each upload
or decode leaves 2.0, PSS at home 160.1 → 152.6.

Galaxy tablet, landscape, rotation locked, `pm clear` before each launch; before is main
`bde1841`'s APK, after the same with the cut, built in one worktree. Home 8 s after a
fresh launch; a game (Russian, `--screen game`) 8 s after its own launch; settings
(`--screen settings`) through four season changes (winter, spring, summer, autumn tiles).
Peak RSS is `/proc/<pid>/status`'s `VmHWM`, the load's peak included.

| PSS / graphics (GL + EGL mtrack), MB | Before | After |
| --- | --- | --- |
| Home, fresh | 173.0 / 113.6 (53.9 + 59.7) | 152.6 / 96.2 (36.5 + 59.7) |
| Game, fresh | 173.0 / 113.6 (53.9 + 59.7) | 152.4 / 96.1 (36.4 + 59.7) |
| Settings after four season changes | 154.9 / 105.2 (73.0 + 32.2) | 118.6 / 73.3 (41.0 + 32.2) |
| Native heap: home, game, after the seasons | 43.8, 43.6, 33.7 | 42.8, 42.7, 31.5 |
| `dumpsys gpu --gpumem`: home, game, after the seasons | 142.4, 142.4, 161.0 MiB | 125.4, 125.3, 129.8 MiB |
| Peak RSS: home, game, after the seasons | 258.8, 259.1, 283.4 | 213.2, 210.1, 214.0 |
| A season change's longest frame (90 Hz, four changes) | 66, 58, 58, 54 ms | 22, 22, 22, 22 ms |

GL mtrack is 17.4 MB lower fresh, the RGBA8 photograph's 16.3 MiB less the ASTC's place
in the shared block; after the season changes 32 MB lower, the second shared block
gone too (before, a season change's new scene beside the old one opened it). Peak RSS is
46 MB lower fresh and 69 lower through the season changes: no 16 MiB decode and data
stack. Native heap is about 1 MB lower fresh. The APK is 13.4 MB against 6.0 (deflated,
as a store would send it, 11.3 against 4.1): the ASTC files add 7.5 MB to `libmain.so`,
which is stored uncompressed, and compress by only 3 to 5%. The look: the tablet's home
in landscape and portrait and the game differ from before by 46 to 47 dB and 61 dB, as
on the Mac, and crops of the photograph show no difference; the final build's tablet
shots are byte-identical to the one before the `madvise`. The Mac's own build, which
decodes the JPEG, shows settings within 2% of the JPEG-path build's but for the
preview's flash.
