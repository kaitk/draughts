# 065: The NoGraphicsAPI renderer through goose-ngfx

Status: in-progress (on the `ngfx` branch; steps 1 to 7 on Windows and the Mac, and the
iPhone, 2026-11-11; memory next)

Draw Draughts through goose-ngfx (github.com/kaitk/goose-ngfx, NoGraphicsAPI over Metal 4
and Vulkan 1.4) on devices that have it: Apple silicon Macs, later iPads and iPhones, and
Windows and Linux GPUs with `VK_EXT_descriptor_heap`. In the end it is the main renderer
wherever it's supported, chosen at run time, with gfx (SDL_GPU) as the fallback and on
Android ([decisions](../docs/decisions/README.md), `docs/product.md` item 6). This task is
the prototype: a build-time choice on its own branch, `ngfx`, until it draws everything
the gfx build draws. Draughts is ngfx's first real user, so ngfx changes as Draughts
needs it to, in its own repository, with a new ngfx release when this branch needs one.

Task 061's stage 4 made the seam this builds on: `main` calls only `app/host` (the
platform) and `app/render` (one `render::frame` a frame, which owns the pass), the C
decoders hand over pixels, and `model3d` holds the 3D board's gfx-free half. Everything
outside `src/app/` and `src/render3d/` stays as it is.

## What there is to port

Counted at `56ad433`:

- **The platform**: `app/host` wraps gfx's window, frame, time, screen size, focus,
  pointer, events, keys, typed text, and screenshot. ngfx keeps gfx's platform half under
  much the same names.
- **The drawing**: `app/render`, `draw` (the flat board, 616 lines), `draw3d` (454),
  `widgets` (the UI's three pipelines and the text atlas, 802), `scene` (the photograph,
  its blur, and the thumbnails, 222), `text`, and `render3d` (the 3D board: a shadow
  map, a 4× multisampled forward pass resolved, mips, and the theme's bake in steps,
  1,055). 26 pipelines.
- **The shaders**: 27 GLSL programs embedded in Goose strings (17 in
  `render3d/shaders.goose`), rewritten in Slang. Vertex pulling from storage buffers is
  already how they read their data, so most become a root struct and pointers.
- **The C**: `photo.c` uploads the photograph through goose_gfx's C texture calls, and
  `resize.c` reads back a cover. Both need ngfx's equivalents.
- **gfx's patches** (`patches/goose_gfx/`), each a behavior ngfx must have or not need:
  0002 draw on demand (the app draws only when something changed,
  `docs/architecture/rendering.md`), 0003 a screen without depth or cycling, 0004
  compressed textures (ASTC 6 × 6), 0005 an MSAA resolve without a store, and 0006 ending
  on a lost device.

## What ngfx lacks for this

Read from goose-ngfx v0.2.0 (`fc7c60d`) on 2026-11-11:

- **The Goose version.** ngfx pins Goose `46356c2`, from before v2026.0. Draughts uses
  the v2026.4 release. ngfx moves to v2026.4 (or a newer release both use), with what
  breaks fixed there.
- **Shaders built ahead.** `ngfx::slang` compiles Slang when the program runs, which
  needs Slang's library in the shipped app and costs time at every launch: the reason
  Direct3D 12 was rejected on Windows (FXC's 5 s). A blob (`native/ngfx_blob.h`) is plain
  bytes, so a build step can compile each module to a blob and embed it.
- **Draw on demand.** An idle app waits for an event and draws nothing. `ngfx::frame`
  has to be able to wait as patch 0002 makes gfx's, and `wake.c`'s wake has to reach it.
- **MSAA** for the 3D board's forward pass and its resolve.
- **Compressed textures**: ASTC on Apple silicon. Desktop GPUs have only BC, where the
  JPEG fallback serves, as on an Intel Mac today.
- **From C**: a texture made from pixels, and one read back, for `photo.c` and
  `resize.c`.
- **Linux can't present** yet (NoGraphicsAPI has no swapchain there); **no iOS build**.
  Both are later than this task.

## Steps, in order

Each step ends with the app built and run on the Mac and on the Windows PC, and what it
shows compared with the gfx build at the same flags (`--frames` screenshots). They are
close, not byte-identical: Slang and SDL_GPU's shader compilers round differently.

1. **ngfx at v2026.4.** Bring goose-ngfx to the Goose release Draughts uses; its tests
   and samples pass on the Mac (Metal 4) and the PC (Vulkan, RTX 4090). Release it.
2. **A window.** `scripts/ngfx.py`, for the Mac and Windows, builds the app with ngfx
   twins of `host` and `render` in place of the gfx ones (a copy of `src/app/` with the
   twins laid over it, as patches are, or a second root file; decided here). It opens,
   clears to the page color, and back and Escape work. The gfx build is unchanged.
3. **The photograph.** The season's JPEG decoded and uploaded through ngfx, sharp and
   blurred behind home.
4. **The UI.** `widgets`' three pipelines and the text atlas: home and settings drawn
   whole, taps working.
5. **The flat board.** `draw`: a game played to its end on the flat board, the
   transitions between screens, and the thumbnails.
6. **The 3D board.** `render3d` and `draw3d`: the shadow map, MSAA, the bake, every
   theme.
7. **At rest and shipped.** No frame drawn while idle, the shaders built ahead and
   embedded, ASTC on the Mac, and one executable that needs no Slang or Vulkan SDK.
   Frame time measured against the gfx build on the Mac and the PC (`--bench`), recorded
   here.

## Progress

### 2026-11-11, on Windows (RTX 4090, Vulkan)

- **goose-ngfx** (pushed to `main`, no release yet): the pin moved to v2026.4, where its
  36 tests and samples passed unchanged; `WINDOW_ON_DEMAND`, gfx's patch 0002 as a flag
  (a frame that drew nothing into the screen isn't presented, and the next `frame()`
  waits for an event up to a second); and goose_gfx `main`'s platform additions since
  `v1` (`737d91a`: fullscreen and maximize, pixel density and display scale, system
  cursors, gamepads), 38 tests passing. goose_gfx `v1`, which Goose v2026.4 blesses, is
  the commit ngfx's platform half was copied from, so nothing else drifted.
- **The build** (step 2, decided): `scripts/ngfx.py` copies the program into
  `build/ngfx/tree/` and lays `src/ngfx/` over it: `app/` (`host`, `render`, `scene`,
  `draw`, `widgets`, `photo.c`, a stand-in `draw3d`) and a stand-in `render3d`. The root
  file gets ngfx's import and the sidecar ngfx's C headers there; `src/app/` is
  untouched. The package is a checkout (`NGFX`, else `../goose/goose-ngfx`).
- **Shaders built ahead**: `src/ngfx/shaders/*.slang`, compiled by
  `tools/ngfx_shaders.goose.in` (run under `goose run` with the package) into ngfx's
  blobs, which the app embeds. The gfx GLSL carries over almost as written: Slang takes
  it with type aliases (`vec2`..., `bvec3`), `mix` and `fract` as macros, GLSL's `mod`
  and two-argument `atan` defined, arrays as `{ }` lists, and uniforms as statics set
  from the root (`common.slang`). Clip space is y down there.
- **Steps 3 to 5**: the photograph, its blurs and thumbnails, the UI and its kept layer,
  and the flat board, compared headless at 1280 × 800 against the gfx build: home, the
  game, settings, taps, a capture, stone, birch's settings, sunset on the plain fade,
  home on the plain fade, a puzzle, a win, a transition held at half, portrait 800 ×
  1280, and the lookout. Every one within 1 of 255 a channel, but the must-capture pulse
  (up to 7 on 89 pixels) and settings' preview flash (up to 4 on 125), which move with
  time and differ between two gfx runs too. The 3D board shows the shell's still mark.
- **At rest** (`--rest 15`, the flat game): gfx 0.0% CPU, 17 loops, 0 frames drawn;
  ngfx 0.1%, 16 loops, 0 drawn. The footprint is 741 MB on ngfx against 256 MB on gfx:
  to look into.
- **Bench** (`--bench 300`, the flat game at 2560 × 1440, a 165 Hz display): gfx CPU
  0.155 ms a frame, waited P50 5.36 / P99 8.36 ms, presented 166.0 fps (1% low 112.1),
  photograph 20.3 ms; ngfx CPU 0.0125 ms, waited P50 5.91 / P99 7.71 ms, presented 165.4
  fps (1% low 111.9), photograph 17.4 ms.
- **No MSAA in NoGraphicsAPI** (no sample count on its textures, no resolve): the 3D
  board's 4× MSAA needs another way. The prototype draws it at twice the size and shrinks
  it; MSAA itself would be a change to NoGraphicsAPI (sebbbi/NoGraphicsAPI) and ngfx.
- **Step 6, the 3D board**: `src/ngfx/render3d/render3d.goose` is gfx's with the GPU calls
  changed and its logic kept. Its 14 shader modules are not written by hand:
  `scripts/ngfx_3d_shaders.py` writes them into `build/ngfx/shaders/` at every build from
  `render3d/shaders.goose`'s GLSL, so the two builds keep one source. Each stage's body
  stays as written, in a namespace. Its inputs, outputs, blocks, buffers, and samplers
  become statics filled from one root (`r3d.slang`), the vertices are pulled from the mesh's
  buffer, and the position's y is negated, which leaves the picture as gfx draws it. Two
  hand modules fill what ngfx lacks. `mip.slang` draws the baked surfaces' mips as passes,
  since ngfx's `generate_mips` takes no sRGB. `down.slang` shrinks the pass drawn at
  twice the size, in place of the MSAA resolve. Compared at 1280 × 800 against the gfx
  build in 16 cases: the four themes, summer's second look, spring's carved one, the plain
  fade, home, settings, a held transition, a capture with its pulsing rings, the lookout,
  a win, a puzzle, and portrait. The mean difference is 0.6 to 2.4 of 255. The rest is
  along edges (2 × 2 supersampling against 4× MSAA, up to 79 on a few dozen pixels on
  the carved frame) and in the wood's fine grain: anisotropy is NoGraphicsAPI's fixed 4×
  against gfx's 8×, which also leaves the field about 1 to 2 of 255 lighter. The
  photograph's backdrop is 2 of 255 lighter on ngfx, the plain fade's identical: to
  look into. Preparing takes 40 steps as on gfx, the longest 29 ms (gfx 18 ms) once the
  driver has the pipelines cached; the first launch ever took 687 ms on the bake's.
- **3D at rest** (`--rest 15`, the 3D game): gfx 0.0% CPU, 17 loops, 0 drawn, 397 MB;
  ngfx 0.4%, 17 loops, 0 drawn, 815 MB.
- **3D bench** (`--bench 300`, 2560 × 1440, 165 Hz): gfx CPU 0.259 ms, waited P50 5.10 /
  P99 6.43 ms, 166.1 fps (1% low 108.9); ngfx CPU 0.029 ms, waited P50 5.64 / P99 8.58
  ms, 165.8 fps (1% low 113.0). Both wait on the display; the pass at twice the size
  costs the RTX 4090 nothing visible here.
- **The footprint** was ngfx's texture heap, one 512 MB block made at open. ngfx now
  grows texture memory in 64 MB chunks, as it does buffers (`042de64`, a test with it,
  39 passing). At rest (`--rest 15`): the flat game 293 MB on ngfx against 255 on gfx
  (741 before), the 3D game 494 MB against 397 (815 before). Most of the 3D board's
  remaining gap is likely the pass at twice the size.

### 2026-11-11, later, on Windows

- **goose-ngfx v0.3.0** released (github.com/kaitk/goose-ngfx/releases/tag/v0.3.0): the
  v2026.4 pin, `WINDOW_ON_DEMAND`, gfx `737d91a`'s platform calls, and growing texture
  memory, in its README, API, design, and development docs, and release notes in
  v0.2.0's form that say the Mac is untested since the pin moved. Its externs are
  declared as `extern fn ... = "sym"` now, which took the build's 99 deprecation warnings
  to none. All 40 checks passed in the compiler with clang-cl, built (`--aot`), and with
  MSVC; the tag fetched from GitHub built and ran.
- **The findings** (`docs/goose-findings.md`): ngfx has no MSAA (NoGraphicsAPI's gap);
  ngfx's `generate_mips` takes no sRGB; `pad` and `block` are keywords everywhere (a
  Goose request: documented keywords, so not a bug). The `'\\'` literal parses on
  v2026.4: what failed was the Bash tool, which collapses `\\` to `\` in text it
  writes (`agents/goose.md`); `tools/ngfx_shaders.goose.in` now uses the literals.
- **The photograph behind the 3D board** is the same on both builds. The 512 px blur, the
  copy it is blurred from, and the glass copy, saved from each build, are byte for byte
  identical, and the settled 3D view's smooth backdrop differs by 0.00 to 0.07 of 255 on
  average in every theme, both backgrounds, and with `--keep off`. The 2 of 255 came from
  shots taken before ngfx's board had faded in: a headless run draws about 3,500 frames
  a second, so `--frames 80` is 23 ms, and ngfx's board, whose preparing is slower,
  appears later in wall time than gfx's (still fading at 3,000 frames). 3D shots are
  compared at `--frames 20000` now (`agents/testing.md`).
- **In a window** (a script posting mouse messages to it, `agents/testing.md`), both
  builds: a game on the 3D board played to its win by clicking squares, with the board
  turning between turns and start over after; the four themes, both boards, and both
  backgrounds switched in settings; home, back, and continue with their transitions
  caught half-way; the window resized to 1600 × 900, 800 × 1000, 1000 × 600, 640 × 400,
  and dragged through 30 sizes. The grabs match gfx's as the headless shots do; neither
  build printed anything, no misuse.
- **One executable** (step 7): the ngfx build imports only `vulkan-1.dll` beyond Windows'
  own DLLs, and holds no slangc, Vulkan SDK, or NoGraphicsAPI path (`ngfx::slang` isn't
  linked in). Run with a bare environment (PATH only `C:\Windows\System32;C:\Windows`,
  no `VULKAN_SDK`, no `NGFX_*`) it draws, and loads System32's Vulkan loader, which the
  GPU driver installs, NVIDIA's driver, and the implicit layers other programs
  registered (RivaTuner, OBS); nothing of Slang's or the SDK's. Nothing to fix.
- **Antialiasing**: `--aa off|fxaa|smaa|ssaa` (the ngfx build only, read in
  `src/ngfx/app/render.goose`) picks how the 3D pass is antialiased, `render3d::AA` the
  default, now SMAA. SMAA 1x is SMAA's reference shader (`third_party/smaa/`, MIT,
  unchanged) through its porting macros in `src/ngfx/shaders/smaa.slang`: luma edges,
  the HIGH preset, three passes over the pass drawn at 1x. FXAA is FXAA 3.11's quality
  algorithm, its preset 39's twelve steps, written in `src/ngfx/shaders/fxaa.slang`.
  `ssaa` is the 2 × 2 supersampling before. Against gfx's 4× MSAA at 1280 × 800, the
  3D game settled, edges taken as the pixels where the pass without antialiasing
  differs from gfx by more than 8, grown by a pixel (mean difference of 255 there, and
  elsewhere):

  | `--aa` | wood: edges / rest | spring carved | winter stone | GPU busy P50 / P99, the whole frame | the pass's targets at 2560 × 1440 | footprint at rest |
  |---|---|---|---|---|---|---|
  | gfx 4× MSAA | 0 / 0 | 0 / 0 | 0 / 0 | 2.02 / 4.87 ms | 88 MB (4× color and depth) | 526 MB |
  | off | 4.58 / 0.07 | 5.87 / 0.07 | 5.95 / 0.06 | 1.90 / 5.13 ms | 7 MB (depth) | 563 MB |
  | fxaa | 4.40 / 0.36 | 5.29 / 0.45 | 5.73 / 0.26 | 2.13 / 4.98 ms | 22 MB | 561 MB |
  | smaa | 3.74 / 0.12 | 4.62 / 0.18 | 4.79 / 0.10 | 2.25 / 5.29 ms | 44 MB | 563 MB |
  | ssaa | 3.63 / 0.94 | 4.12 / 0.91 | 4.89 / 0.52 | 2.65 / 5.38 ms | 88 MB | 619 MB |

  GPU busy is PresentMon's, `scripts/windows_perf.py` full screen at 2560 × 1440 on the
  165 Hz display, 1,000 bench frames (`EXE` and `FLAGS` there measure the ngfx build);
  every build presented all its frames at 165 fps. The footprint is the private bytes
  after `--rest 25`; ngfx's texture memory grows in 64 MB chunks, so the 1x modes'
  differences vanish in them. The ngfx build's footprint is about 37 MB above gfx's in
  every mode, `off` included, so it is ngfx's own memory, not the pass's: what of it is
  unmeasured (below). SMAA is the default: its edges are as close to the MSAA as
  supersampling's, while the surfaces stay as gfx draws them (supersampling filters the
  wood's grain and the carvings' relief again, 0.5 to 0.9 of 255 over the whole board,
  and outlines the carvings darker), at half supersampling's added GPU time and half its
  memory. FXAA blurs the surfaces more and dots the one-pixel highlight along the stone
  frame's rim, a pattern FXAA makes on thin lines. Within SMAA, the ULTRA preset came out
  further from the MSAA than HIGH in all three looks (its lower threshold smooths surface
  detail: wood 3.85 / 0.16), and color edges tied with luma (3.72 / 0.12), so HIGH and
  luma stay. With SMAA every 3D case compared settled is within 0.10 to 0.25 of 255 on
  average (home, settings, portrait, a held transition, a win, the capture's pulse, the
  plain fade), against 0.6 to 2.4 with supersampling; the flat board is still within 1.

### 2026-11-11, on the Mac (M1 Pro, macOS 26.3.1, Metal 4)

- **goose-ngfx v0.3.0 on Metal 4**: its 40 checks pass, in the compiler with Apple clang
  and built (`--aot`), with nothing changed; its README and the v0.3.0 release notes say
  so now.
- **The build on Metal**: `scripts/ngfx.py` builds on the Mac as on Windows (`NGFX` set to
  the checkout, `NGFX_SLANGC` to slangc 2026.18.3). Every Slang module compiled to a
  metallib on the first try: the 3D board's written from GLSL, SMAA's reference shader
  through its porting macros, and FXAA. Headless shots against the Mac's gfx build
  (`scripts/mac.py`) at 1280 × 800, every case at `--frames 20000` (the Mac's headless
  loop is as fast as the PC's, and at 400 frames gfx's 3D board on home is still fading
  in): the flat game, stone, a puzzle, a win, portrait, and the lookout within 1 of 255;
  home, settings, birch's settings, a held transition, sunset and home on the plain fade
  identical (0, once the photograph is ASTC on both, below). The 3D board with SMAA,
  mean difference against gfx's 4× MSAA: wood 0.25, stone 0.32, birch 0.41, sunset 0.25,
  summer's second look 0.25, spring's carved 0.39, the plain fade 0.26, home 0.24,
  settings 0.14, a held transition 0.34, the capture's rings 0.27, the lookout 0.32, a
  win 0.81 (its confetti moves), portrait 0.36; the rest along the board's edges and in
  the wood's grain, as on the PC. `--aa` each way, mean difference (pixels over 32) for
  wood, spring's carved, and stone: off 0.23 (1,462), 0.29 (1,930), 0.32 (1,992); fxaa
  0.52 (1,149), 0.67 (1,626), 0.48 (1,504); smaa 0.25 (674), 0.39 (922), 0.32 (964); ssaa
  0.89 (1,269), 0.95 (3,592), 0.57 (1,390). SMAA halves the edge pixels far from the MSAA
  and leaves the surfaces; FXAA and supersampling blur them, as on the PC.
- **ASTC**: NoGraphicsAPI knew ASTC only in 4 × 4 blocks. The user forked it
  (github.com/kaitk/NoGraphicsAPI): `astc-6x6` adds ASTC 6 × 6 (both backends, its block
  size, its tests), the fork's `ngfx` branch is the pinned upstream commit with it, and
  goose-ngfx follows that branch (`b614c80`). goose-ngfx takes compressed textures now:
  `BC3`, `BC7`, `ASTC_4x4`, `ASTC_6x6` (gfx's numbers), `SAMPLED` only, uploaded in
  whole blocks, with `format_supported` (`4af28ec`, a test of its own, 42 checks
  passing). `src/ngfx/app/photo.c` uploads the embedded ASTC where it's supported, as
  gfx's does, and `scripts/ngfx.py` copies the ASTC masters into its tree, which it
  didn't: the photograph was the JPEG there before.
- **The Mac's numbers** (a 1280 × 800 window, 2560 × 1600 pixels, the 120 Hz display;
  the photograph ASTC on both). `--rest 15`: every build 0.03 to 0.05% CPU, 16 loops, 0
  frames drawn (two ngfx runs 0.2% and 0.8%, a late wake from launch); the footprint
  is the gap: the flat game 115 MB on gfx against 309 MB on ngfx, the 3D game 355 MB
  against 614 MB (ngfx `off` 544, `fxaa` 544, `smaa` 614, `ssaa` 645). On Windows the
  gap was 37 MB; here it's about 200 MB before the 3D board (below). `--bench 300`, two
  runs each, waited P50 with the shadow map: gfx 5.49 / 5.54 ms; ngfx `off` 4.16 / 4.25,
  `fxaa` 4.89 / 4.95, `smaa` 5.52 / 5.20, `ssaa` 5.39 / 6.00; flat, gfx 4.52 against
  ngfx 4.71. Every build presented about 118 to 120 fps of 120, the 1% lows 60 to 101
  and noisy run to run. The CPU a frame is 0.08 to 0.32 ms on both. On the M1 Pro
  supersampling costs about 1.8 ms over `off` against SMAA's 1.0 to 1.3, so SMAA stays
  the default; the antialiasing modes are measured again after the memory work, not
  before.
- **Upstream NoGraphicsAPI moved** (`ffd9f2a`, "Improve Metal 4 presentation and texture
  resource handling"): roots now need a 16-byte stride, which ngfx's two shaders fail
  (`static_assert` in `shader.slang`), and so would Draughts' roots. `astc-6x6` rebases
  onto it cleanly; moving ngfx's pin there is a step of its own (below).

- **Where ngfx's memory goes, on the Mac** (`footprint` at rest, the flat game in a
  window): gfx 116 MB, of it 41 MB graphics (32 MB IOSurface, the window's drawables, and
  9 MB IOAccelerator); ngfx 309 MB, of it 220 MB graphics (132 MB of owned unmapped
  heaps, 88 MB IOAccelerator) and the same 32 MB of drawables. A Goose program that only
  opens ngfx and clears three frames already holds 160 MB, 138 MB of it graphics, at
  64 × 64 as at 2560 × 1600: ngfx's fixed pools, before Draughts draws anything. They are
  ngfx's sizes (`native/ngfx_gpu.hpp`): two frames' 16 MB of frame memory, the 32 MB
  upload queue, and the first 64 MB buffer and texture chunks, each heap committed whole
  on Metal, where Windows' private bytes didn't count it all (37 MB there). The rest is
  Draughts' own textures in further chunks, and the screen: an offscreen color texture
  and a depth texture and a spare of each for the frame in flight (16 MB apiece at
  2560 × 1600), copied into the drawable at the frame's end, where gfx draws into the
  drawable itself without depth (patch 0003). NoGraphicsAPI leaves sizing to the program:
  its examples make fixed heaps (256 MB of textures, 1 to 16 MB of data), and its
  utility upload queue defaults to 64 MB. So the change is ngfx's: pools sized from use,
  starting small (frame memory of a few hundred KB, an upload queue of a few MB, chunks
  of 8 MB doubling up to 64), the screen drawn into the drawable, and depth only for a
  program that asks for it. Draughts' per-frame data is a few KB.
- **SDL** (the user's call, 2026-11-11): ngfx drops SDL entirely. It takes the native
  window from the program (a `CAMetalLayer` on Apple's systems, an `HWND` on Windows,
  later a Vulkan surface on Linux) and keeps only drawing; the window, input, time, and
  events are the program's. Draughts keeps one SDL, the one its gfx build links, for both
  renderers, which is also what choosing the renderer at run time needs. The objc
  warnings on every ngfx `goose run` on the Mac ("Class SDL3Window is implemented in
  both" the compiler and ngfx's JIT library) are two SDLs in one process today.
- **goose-ngfx v0.4.0** (`9f7a0a3`, tagged and pushed; the GitHub release's notes wait for
  the user, whose permission it needs): no SDL, memory sized from use, compressed
  textures, NoGraphicsAPI from the fork. Its samples take gfx from the user's fork,
  `kaitk/goose_gfx`, branch `ngfx` (`v1` with this repository's patches 0001 to 0008, one
  commit each), fetched from git and passing; 34 checks in the compiler and with `--aot`
  on the Mac. Windows is still to run at v0.4.0 (gfx's `HWND`).
- **What still separates ngfx's memory from gfx's** (the flat game at rest, 52 MB, from
  `footprint`): the GPU heaps +19 MB (the spare screen 16, chunk slack about 3); the
  Metal driver's own memory (IOAccelerator) +20 MB, 29 against 9, not yet broken down:
  likely the 4 MB upload queue, the buffer chunk's 8 MB held whole, and NoGraphicsAPI's
  descriptor heaps (8,192 texture slots) and residency sets; malloc's large blocks +9 MB,
  not yet broken down. The drawables are the same 32 MB. Drawing into the drawable and
  dropping the spare take the heaps to about 13 MB under gfx's, which keeps a screen copy
  too; the driver's and malloc's 29 MB decide whether ngfx ends below gfx.
- **Next**, in this order: iOS and iPadOS; the memory follow-ups below; upstream
  NoGraphicsAPI's `ffd9f2a` (roots of a 16-byte stride) in the fork and ngfx.
- **goose_gfx pull-request branches** in `kaitk/goose_gfx`, patches 0001 to 0008 rebased
  onto upstream `main` (`737d91a`, six commits past `v1`: fullscreen, gamepads, cursors,
  the upload buffer reused, the externs' new form), one branch each: `no-clip-distance`,
  `draw-on-demand`, `screen-without-depth`, and `compressed-textures` on `main`;
  `msaa-resolve-without-store` on `screen-without-depth`; `end-on-device-lost` and
  `ios-run-loop-wait` on `draw-on-demand`; `window-only` on `ios-run-loop-wait`. All
  eight together are `upstream-series`. Two conflicts were resolved: the compressed
  upload's tight rows against `main`'s reused upload buffer, and `WINDOW_ONLY` beside the
  gamepads and cursors. `compressed-textures` gained its Goose side (the formats and
  `format_supported` in `gfx.goose`), which the patch here never had, so goose_gfx's
  `test/api_check.py` passes on every branch. ngfx's cube and ui_todo ran against
  `upstream-series` as against the fork's `ngfx` branch (`v1` with the patches), which
  ngfx's samples still take.

- **ngfx without SDL** (goose-ngfx `no-sdl`, `b38a5b6`): its platform half and SDL are
  gone. `ngfx::open(window, w, h, flags)` takes a native window's handle (0 headless),
  `present(force)` ends each frame and says whether it showed one, and `resize` follows
  the window; PNG loading and saving use stb_image. The window, input, events, time, and
  the idle wait are gfx's, opened `WINDOW_ONLY`: `patches/goose_gfx/0008-window-only.patch`
  here (the user chose it over ngfx's platform on the program's SDL, or a host of the
  program's own on SDL), and the branch `ngfx` of a local goose_gfx clone, `v1` with
  patches 0001 to 0008 one commit each, for ngfx's samples, which take gfx from it until
  the user's fork (`kaitk/goose_gfx`) has it. `src/ngfx/app/host.goose` is gfx's host
  with `WINDOW_ONLY`, ngfx opened in its window, and `frame()` presenting through ngfx
  before gfx's `frame()`; `scripts/ngfx.py` builds with the patched gfx, as `mac.py`
  does. The objc runtime's warnings of every SDL class twice are gone from built
  programs. ngfx's 34 checks pass (the four that tested the copied platform half
  removed); the cube presents in a window at the display's rate.
- **ngfx's memory sized from use** (`331821f`): frame memory from 256 KB per frame in
  flight, doubling when a frame outgrows it; 8 MB chunks, a buffer or texture over half
  of one in memory of exactly its size (as `patches/SDL/0003` does for SDL_GPU); a 4 MB
  upload queue that larger uploads pass through in parts; the screen's depth only when
  asked for. A program that opens ngfx and clears three frames: 160 MB before, 40 MB
  after. Exact-size texture heaps round to the device's texture heap alignment, which
  NoGraphicsAPI's allocator counts in (a 2048 × 2048 texture failed without it; a test
  has a 6.6 MB one now).
- **Draughts on the reworked ngfx, on the Mac**: every flat case identical to the gfx
  build (0 difference; a held transition 1 at most), the 3D cases differing only inside
  the board (SMAA against MSAA, mean 0.14 to 0.31, the win's confetti 0.69). At rest in
  a window: the flat game 167 MB (309 before, gfx 115), the 3D game 419 MB (614 before,
  gfx 355), 0.05% and 0.14% CPU, nothing drawn. `--bench 300` on the 3D board presented
  120.2 fps of 120, waited P50 5.85 ms.
- **Fewer copies** (the user's question, 2026-11-11), checked against the code: the
  screen is an offscreen texture and a spare, copied into the drawable each frame, about
  48 MB of the 52 MB still between the flat game's builds at 2560 × 1600. Drawing into
  the drawable directly saves the screen and its copy (32 MB there); it needs the
  screenshot read from elsewhere and the app redrawing when `needs_present()` asks
  instead of ngfx presenting the old screen again. Dropping the spare (16 MB), as gfx's
  patch 0003 dropped gfx's cycling, is ngfx's alone. The upload staging is 4 MB now, and
  the photograph's and the UI's kept layers are the app's design on both builds, not
  copies ngfx adds. Both screen changes are below, as follow-ups.

### 2026-11-11, on the iPhone 13 mini (A15, iOS 26)

- **goose-ngfx for iOS** (branch `ios`, `fe0b1e5` and `080ea34`, not released yet): its
  CMake compiles the layer's two shaders for the SDK it builds for (`iphoneos` for iOS
  and iPadOS, whose Metal loads no macOS metallib); `NGFX_METAL_SDK=iphoneos` makes
  `ngfx::slang_file` on a Mac write blobs for iOS; on the device `ngfx::slang` fails at
  once, saying to compile ahead, as iOS runs no subprocess. NoGraphicsAPI built for iOS
  26 as it was. The device only; the simulator untried.
- **Draughts on it**: `scripts/ios.py --device --ngfx` builds `scripts/ngfx.py`'s tree in
  `build/ngfx/ios/tree/` with iOS blobs, and `ios/CMakeLists.txt` adds goose-ngfx's
  CMake when `GOOSE_NGFX` is set; iOS 26 minimum for that build. `goose.h`, which ngfx's
  C includes, is the one the compiler wrote for ngfx's Mac build (`ios.py`'s
  `goose_h`): Goose writes it only for the native parts it builds itself
  (`docs/goose-findings.md`). The build installs under the gfx build's bundle id, in its
  place, keeping the app's data: a new id of the paid team was refused at launch while
  the phone was offline ("Unable to verify app"), and the comparison reinstalls the
  signed gfx build kept in `build/ios/gfx-signed/`. Online, a new id would likely verify;
  untried since.
- **On the iPhone**: home, the flat and 3D games, rotation, and settings all work
  (checked by the user); gfx's `WINDOW_ONLY` window, UIKit's Metal view, the safe area,
  and the run-loop wait needed nothing new. The first build presented a locked 30 fps:
  ngfx left NoGraphicsAPI's swapchain at two drawables, and on the A15 `nextDrawable`
  then waited for every other refresh. Three, as SDL_GPU has, give 60.
- **Numbers** (`scripts/ios_perf.py`, Russian, wood, the start, 1000 frames; the gfx
  build's from the README's table, as Instruments wouldn't attach to it this session):
  flat, 982 frames on the display at 60 Hz, 2 dropped, waited P50 7.48 / P99 7.74 ms; 3D
  with the shadow map, 983 frames, 2 dropped, waited P50 9.9 / P99 11.2 ms (the app's own
  count, run alone: 9.7 / 10.45); both a locked 60 like gfx's. At rest (`--rest 25`): 0
  frames drawn, 0.13% CPU, footprint flat 98 MB against gfx's 59, 3D 298 MB against
  gfx's 204. The memory gap is the Mac's (below, "Later"), smaller at the phone's
  1080 × 2338.
- **iPadOS**: no iPad at hand. Its layouts are the app's, the same on both renderers and
  checked headless on the Mac in task 050, so nothing was rerun; ngfx on an M-series iPad
  is untried.

### Left for the Mac

- **goose-ngfx v0.3.0 on Metal 4**: its tests and samples at the v2026.4 pin, which have
  run only on Vulkan since the pin moved, with `WINDOW_ON_DEMAND`, the platform calls,
  and the growing texture memory; then the release notes' Mac line.
- **The build on Metal**: `scripts/ngfx.py` on the Mac, every Slang module (the 3D
  board's written from GLSL, and SMAA's and FXAA's, untried in MSL) compiled to
  metallibs, and the shots of every screen against the Mac's gfx build, 3D settled at
  `--frames 20000`, with `--aa` each way.
- **ASTC**: the season's photographs as ASTC 6 × 6 on Apple silicon (gfx's patch 0004),
  which ngfx's textures don't take yet.
- **The Mac's numbers**: `--bench` and `--rest` of both builds, flat and 3D, and the
  antialiasing modes' GPU time on the M1 Pro, where supersampling's four times the
  shading should cost more than on the RTX 4090.
- **The iPad and iPhone**: NoGraphicsAPI builds for iOS and iPadOS 26 (A14 or M1 and
  newer, `docs/building.md` in its tree), and takes a `CAMetalLayer` there; ngfx has no
  iOS build yet. Draughts' iOS build (`ios/`) links gfx's SDL.

### Questions from higher up

- **Why ngfx holds more memory.** The sizes are ngfx's own (`native/ngfx_gpu.hpp`), not
  NoGraphicsAPI's, which leaves allocation to the application: two frames in flight of
  16 MB CPU-visible frame memory, a 32 MB upload queue, buffers and textures in 64 MB
  chunks (a texture over half a chunk alone), 8,192 texture and 1,024 sampler
  descriptors, and the screen as an offscreen RGBA8 texture and depth per frame in
  flight, copied to the swapchain. Which of these the 37 MB is, and whether a program
  this size should size them itself (`ngfx::open` taking them, or chunks that start
  small), is to measure, Mac first, where memory is unified. NoGraphicsAPI's own
  examples are the reference for how it is meant to be used.
- **Why ngfx has SDL.** NoGraphicsAPI takes a native window (`HWND`, or a `CAMetalLayer`
  on macOS and iOS) and needs no SDL; ngfx copied gfx's platform half (window, input,
  time, gamepads, cursors) over SDL3 and builds its own SDL. That is what keeps the two
  renderers from one executable (below). The options: ngfx takes a window from the
  program and drops its platform half, so Draughts keeps one SDL for both renderers; or
  ngfx links the SDL the program links.
- **SMAA in the gfx build** too, in place of 4× MSAA, if the tablet's and the Mac's
  numbers favour it: half the targets' memory here, the look within 0.1 to 0.25 of 255.

## Pull requests to open (the user, later)

Not opened yet; the user opens them (2026-11-11):

- `aardappel/goose_gfx`, from `kaitk/goose_gfx`: `no-clip-distance`, `draw-on-demand`,
  `screen-without-depth`, `compressed-textures` (each on upstream `main`);
  `msaa-resolve-without-store` (after `screen-without-depth`); `end-on-device-lost` and
  `ios-run-loop-wait` (after `draw-on-demand`); `window-only` (after `ios-run-loop-wait`).
  Once merged, Draughts drops the patch and ngfx's samples go back to Goose's gfx.
- `sebbbi/NoGraphicsAPI`, from `kaitk/NoGraphicsAPI`: `astc-6x6` (`03a36c3`, on upstream
  `main`).

## Later, not in this task

- **ngfx's driver and CPU memory**: break down the IOAccelerator's 29 MB and malloc's
  large blocks (Instruments' Metal resource list, or counting what ngfx and NoGraphicsAPI
  make), then size what is ngfx's: buffer chunks of 2 to 4 MB, an upload queue that
  shrinks when idle, descriptor heaps sized from use.
- **The screen straight into the drawable**, in ngfx: no offscreen screen and no copy
  (32 MB at 2560 × 1600), the screenshot from a texture of the program's or a read of
  the drawable, and the app redrawing when gfx's `needs_present()` asks. Then no spare
  screen per frame in flight (16 MB), as gfx's patch 0003 did for gfx.

- **Choosing at run time.** Both renderers in one executable, ngfx where the device has
  it (Metal 4; Vulkan 1.4 with `VK_EXT_descriptor_heap`), else gfx. They can't both
  link their own SDL as they do now: Goose's release builds gfx with its SDL, and ngfx
  builds its own. Fixable, since the app already builds gfx from patched sources and
  ngfx is ours: ngfx's CMake takes the SDL the app links instead of its submodule's, the
  app opens the window, probes the device, and hands the window to the renderer it
  picked.
- **Presenting on Linux**: a Vulkan surface from SDL (`SDL_Vulkan_CreateSurface`) in
  ngfx's layer where NoGraphicsAPI makes none, the rest as on Windows.
- **SMAA's targets**: its edges and weights could share memory with other per-frame
  targets, or the edges pass write a stencil that the weights pass tests, as SMAA's
  reference does, if the Mac's numbers ask for it.
- **ngfx on an iPad**, and goose-ngfx's `ios` branch released (v0.4.1) once it has run
  there or the user decides it's enough; the simulator, if Metal 4 runs there.
- **Displays over 60 Hz** (the user, 2026-11-11): ProMotion iPhones need
  `CADisableMinimumFrameDurationOnPhone` in the Info.plist, or iOS holds third-party apps
  to 60, and `ios_perf.py` reads `HZ = 60` where it should read the display's rate. The
  same for both renderers; no 120 Hz iPhone here.
- **The memory on iOS**: ngfx holds 39 MB (flat) and 94 MB (3D) more than gfx at rest on
  the iPhone; the follow-ups above are where it goes.
- The Steam builds (task 064).

## Acceptance criteria

- [x] goose-ngfx at Goose v2026.4 and released (v0.3.0, 2026-11-11), its tests and
      samples passing on the PC
- [ ] The same tests and samples passing on the Mac (Metal 4)
- [x] `scripts/ngfx.py` builds Draughts on ngfx on Windows, on the `ngfx` branch, with the
      gfx build unchanged
- [ ] The same on the Mac
- [x] Every screen, the flat board, and the 3D board drawn by ngfx, compared against the
      gfx build at the same flags, on the PC
- [ ] The same on the Mac
- [x] Nothing drawn while idle; shaders built ahead, no Slang or Vulkan SDK at run time,
      on the PC
- [ ] The same on the Mac, with ASTC
- [x] Frame time against the gfx build on the PC, recorded here
- [ ] The same on the Mac
- [x] What ngfx gained recorded in its own docs, and gaps in Goose in
      `docs/goose-findings.md` (ngfx's or this repo's, by whose they are)
