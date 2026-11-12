# 073: One executable, the renderer chosen at run time

Status: in-progress (steps 1 and 2 done on main 2026-11-11, step 3 on 2026-11-12; steps 4 to 6 on a branch of their own)

Task 065 drew all of Draughts through goose-ngfx on its own branch, `ngfx`, as a
build-time choice; tasks 070 and 071 brought it to gfx's frame time and memory on the Mac
and the iPhone. ngfx gains the user nothing measurable today (task 065, 070, 071), and the
branch is rebased by hand onto main (34 commits on 2026-11-11). This task brings it into
main as a renderer the app picks when it starts: ngfx where the device has it, gfx
everywhere else and on Android, and a flag to force either (the user, 2026-11-11).
Main takes it as far as a build-time choice with one copy of the drawing and its
shaders (steps 1 to 3); the run-time choice (steps 4 to 6) is built on a separate branch
and not merged to main yet (the user, 2026-11-11). Task 074 has since given Windows a
measured reason: on the RTX 4090 ngfx takes 26 to 41% less GPU time a frame and 54 to
74 MB less GPU memory, at the same CPU time, so `auto` on Windows is the case to get
right first (the user, 2026-11-12).
The reason is NoGraphicsAPI's, not the app's: Draughts as a real program on its API, to
show its author and to back the pull requests (`docs/goose-findings.md`); the app itself
needs neither renderer over the other (the user, 2026-11-12).

## What stands in the way

- **Two copies of the drawing.** The ngfx build lays `src/ngfx/` over `src/app/`: `host`,
  `render`, `draw`, `widgets`, `scene`, `draw3d`, `photo.c`, and `render3d` each exist
  twice, alike but for the GPU calls. Only the 3D shaders are generated from one source
  (`scripts/ngfx_3d_shaders.py`). Every rendering change is made twice, as task 071's
  were. Merged as it is, that cost moves onto main. (Step 2 split the drawers, and step
  3 writes the 2D shaders from the GLSL too.)
- **Linking both.** NoGraphicsAPI's CMake refuses a deployment target under macOS or iOS
  26, and its Metal backend calls Metal 4's classes directly; the gfx build runs on iOS
  16 (`scripts/ios.py`'s `MIN_IOS`). On Windows ngfx imports `vulkan-1.dll` directly, which
  is no loss: gfx draws only through Vulkan there too (Direct3D 12 rejected for FXC's 5 s
  at each launch, `docs/decisions/README.md`), so a PC without a Vulkan driver can't run
  Draughts either way; only Windows' own missing-DLL dialog stands in for the app's
  message (the user, 2026-11-11). The fallback matters there for GPUs with Vulkan but
  not ngfx's newer needs, `VK_EXT_descriptor_heap` above all.
- **The hand-off.** The ngfx host opens gfx's window `WINDOW_ONLY` (patch 0008) and
  aborts if `ngfx::open` fails. Falling back closes that window and lets gfx open its
  own (step 5), rather than gfx making its device late in ngfx's window.

## How a device is told apart

NoGraphicsAPI already checks what it needs when it makes its device, and fails with
`Error::unsupported` rather than crashing; `ngfx::open` returns false then. So detection
is trying ngfx and falling back, not a list of devices kept here:

- **Metal**: `MTLCreateSystemDefaultDevice()`, then `supportsFamily:MTLGPUFamilyApple7`
  (A14, M1 and later) and `supportsFamily:MTLGPUFamilyMetal4` (`NoGraphicsAPIMetal.mm`).
  The OS gates it too: Metal 4's API exists from macOS and iOS 26, so a build that also
  runs on older systems asks `@available(macOS 26, iOS 26, *)` before touching it, and
  links Metal 4's symbols weakly or loads ngfx's code only there (below).
- **Vulkan**: a 1.4 loader and device (`apiVersion`), the extensions
  `VK_EXT_descriptor_heap`, `VK_KHR_device_address_commands`,
  `VK_KHR_shader_untyped_pointers`, and `VK_EXT_mesh_shader`, swapchain maintenance 1
  with a surface, about 25 core features (16-bit storage, scalar layout, buffer device
  address, timeline semaphores, synchronization2, dynamic rendering, maintenance 4 and 5,
  the descriptor heap's, mesh shaders), CPU-visible device memory, and BC or ASTC
  (`NoGraphicsAPI.cpp`, the device candidate's check).

## Steps, in order

1. **ngfx in main as a build option** (first, the user, 2026-11-11: the refactor below
   touches `src/app/` all over, which other sessions change daily, so it is done on main
   in small commits rather than on a branch rebased by hand). Merge `ngfx` into main:
   `scripts/ngfx.py`, `src/ngfx/`, patch 0008, and its docs and tasks; the gfx build is
   unchanged and still what ships. Then the `ngfx` branch is retired (deleted locally and
   on origin once main is pushed, after asking).
2. **One copy of the drawing.** Split each twin into what to draw (layout, quads,
   instances, uniforms, the passes' order: one module, renderer-free, as `model3d` is
   for the 3D board) and recording it (a small module per renderer). Both builds stay
   as they are on screen, compared against shots before (flat identical, 3D within
   task 065's margins). One twin at a time, each its own commit.
3. **The 2D shaders in one copy.** The recorders stay one per renderer: they share no
   lines that are the same code (gfx binds buffers and uniforms, ngfx fills a root with
   heap indices and frame memory), and a layer over both would be the cleverness the code
   rules keep out. What is written twice is the shaders: `src/ngfx/shaders/`' `ui`,
   `board`, `pieces`, `blur`, `shrink`, `fade`, and `compose` are hand ports of the GLSL
   in `src/app/widgets_gpu.goose`, `draw_gpu.goose`, and `scene_gpu.goose` (about 1,000
   lines of shader each way; `ui` alone 618 against about 610), and a change to one, as
   task 063's to the UI's, has to be made again in the other. Write them from the GLSL at
   build time as the 3D board's are, `scripts/ngfx_3d_shaders.py` taking the 2D strings
   too (its root per module, the y flip, the GLSL names through `glsl.slang`), and delete
   the hand ports; what can't be generated cleanly (the quads pulled from frame memory by
   address, the three `ui_*` variants' defines) stays a small hand-written part beside the
   generated body, named as such. The GLSL stays the source, as gfx is what ships
   everywhere. Checked as step 2 was: ngfx's shots identical to before, or within task
   065's margins where the generated code differs, and `--bench` and the Pixel's UI
   cycles (task 063) not worse on gfx, which doesn't change.
4. **Both in one executable.** Draughts' one SDL for both (as task 065 left it); ngfx's
   code loaded only where it can run: Metal 4 behind `@available` with weak links, or
   ngfx in a library the app opens only on macOS and iOS 26. Which of the two, decided
   here and recorded in `docs/decisions/`. Windows links both as they are.
5. **Choosing.** `--renderer auto|gfx|ngfx` (`auto` the default): `auto` tries ngfx and
   falls back to gfx in the same window; `ngfx` fails loudly where it can't run; Android
   is always gfx. The choice and why printed at start, for bug reports.
   - **Order.** ngfx is tried first, in a hidden window of its own: gfx opens it
     `WINDOW_ONLY` and hidden, `ngfx::open` runs, and if it returns false everything is
     closed, the window too, and gfx starts as it does today, opening its own. No
     hand-off of one window between the two (the user, 2026-11-12): gfx needs no late
     device, and Vulkan never sees a second swapchain on a surface ngfx had; a window
     opened twice before anything shows costs nothing seen.
   - **A device that passes but breaks.** The Vulkan extensions ngfx needs are new
     (2025 to 2026), and their drivers will have bugs that no check sees. `auto` writes a
     marker beside the settings before making ngfx's device and clears it after the
     first frame is shown; a start that finds the marker still there picks gfx and says
     so. The marker names the GPU, its driver version, and the app's, as Firefox's DriverCrashGuard does, so a driver or app update tries ngfx again by itself; `--renderer ngfx` clears it too. A failure
     after the first frame (device lost) is not caught this way; record it if it shows.
   - **No setting in the UI.** The flag is for testing and bug reports; players get
     `auto`.
6. **Checked**: the Mac and the iPhone pick ngfx; an iOS 16 to 25 device or an Intel Mac
   gfx; Windows on the RTX 4090 ngfx and with `--renderer gfx` gfx; the tablet, the
   Pixel 7a, and the A33 gfx; the shots, `--rest`, and `--bench` of each as task 065's.

## Where it stands (2026-11-12)

- **Step 1 done.** `ngfx` merged into main (`088ca59`), after task 072's session
  committed its gui work; the merge took `16d44ab` (task 072's focus ring, made on
  `ngfx`) to main, where it wasn't, its `g.ring = false` carried into `src/gui/focus.goose`,
  where main had moved the focus's code. The 82 tests pass, and the merge's shots match
  the commit before it. Main pushed and `ngfx` deleted locally and on origin
  (2026-11-12), every commit of it in main by subject.
- **Step 2 done**, one commit a twin: `host` (`cf7a17f`), `scene` (`6fb5cec`), `draw`
  (`69b635d`), `widgets` (`23e3619`), `draw3d` (`2c4e972`), `render` (`19fe8fa`),
  `photo.c` (`4fc3d44`), `render3d` (`553a407`). Each drawer is now what it draws and a
  `_gpu` recorder per renderer, `gpu` naming each renderer's handles
  ([decisions](../docs/decisions/README.md#the-codes-layout)). `src/ngfx/` holds only
  recorders and shaders: `app/gpu`, `host_gpu`, `scene_gpu`, `draw_gpu`, `widgets_gpu`,
  `photo_gpu.h`, and `render3d/render3d_gpu`. Along the way the ngfx build gained what
  its copies had missed: the keys' focus in `host`, and gfx's wait on a theme's reload.
- **Checked** on the Mac, both builds, after each twin: 26 shots headless at 1280 × 800
  and `--frames 20000` (13 screens, flat and 3D: home, the game, taps, settings, stone,
  birch's settings, sunset and home on the plain fade, a puzzle, a win, a held
  transition, portrait 800 × 1280, the lookout), each build against its own shots taken
  at the merge. Flat: identical. 3D: within two runs' noise, a few pixels by at most 2
  of 255, none over 32 (gfx's portrait 3D differs by about 3,900 pixels between any two
  runs). After render3d also every `--aa` way of each build against the merge's build
  (none over 32), `--bench 60` alike (gfx waited P50 0.81 → 0.90 ms, ngfx 0.88 → 0.82,
  run-to-run spread), and the headless footprint at `--rest 4` the same (gfx 122.0 →
  122.2 MB, ngfx 139.3 → 139.3). poc/3d builds against the new render3d. Not run: the
  tablet, the iPhone, and Windows, as nothing on screen was meant to change; the iOS and
  Windows ngfx builds use the same overlay.
- **Step 3 done** (2026-11-12), one commit a module after the generator's core: the
  core split out of the 3D generator (`9b7de3d`, `scripts/ngfx_glsl.py`, its 3D output
  byte for byte the same), then `compose` (`d09cf74`), `fade` (`f59b933`), `blur`
  (`70243b2`), `shrink` (`8a198d9`), `board` (`cda0a91`), `pieces` (`4760c6b`), and the
  three UI variants (`40b9746`), each written by `scripts/ngfx_2d_shaders.py` and its
  hand port deleted, and `common.slang` trimmed to what `down` and `mip` use
  (`ef185cf`). The roots are laid out from the GLSL ([decisions](../docs/decisions/README.md#the-codes-layout));
  two recorders changed to match (the pieces' and the UI's `view` before `theme`, and
  compose's sampler). The only hand-written part is the UI's `first`, added to
  `SV_InstanceID`; the variants' defines come from `widgets_gpu`'s `BASE`, `ICONS`, and
  `FACES`, and the quads' address is the GLSL's storage buffer as a root pointer, both
  generated. `down`, `mip`, and `fxaa` were ngfx's own (gfx resolves MSAA, makes mips with
  SDL_GPU's blits, and has no FXAA); `smaa.slang` includes SMAA's own HLSL, as gfx's
  `smaa.goose` wraps it in GLSL, so neither is a port of the other. All four stay Slang.
- **Checked** on the Mac after each module, the ngfx build's 26 shots against a baseline
  taken at `a70b192`: flat identical every time; 3D within two runs' noise (pixels by at
  most 3 of 255, but the puzzle's 3D board, which sparkles along the pieces' and the
  board's edges from run to run: two baseline runs differ there by up to 40 at 2 pixels,
  the modules' runs by up to 67 at 9, all single pixels on the board). gfx's binary is byte for byte the
  baseline's, so its shots can't differ. Every `--aa` way of ngfx (off, fxaa, smaa,
  ssaa) on the 3D game against the baseline: none over 32. `--bench 60` headless, the
  game at 1280 × 800, five runs each, medians, ngfx baseline → step 3: flat waited P50
  0.64 → 0.47 ms, presented 4,460 → 4,380 fps; 3D waited P50 0.81 → 0.89 ms, presented
  1,336 → 1,339 fps (run-to-run spread: P50 0.39 to 0.82 ms in one build's flat runs).
  Footprint at `--rest 4` headless, the same: ngfx flat 53 → 53 MB, 3D 140 → 140 and 141;
  gfx (the same binary) 51 and 131 to 135. Built against goose-ngfx `82517d6` (its
  `origin/main`, for `ngfx::open`'s display and kind).
- **Windows ngfx, for the user**: `python scripts/ngfx.py src/app/draughts.goose`, then
  the 13 screens above (their flags in `agents/testing.md`), flat and 3D, headless
  (`GOOSE_GFX_HEADLESS=1`) at `--size 1280x800 ... --frames 20000`, against the same from a
  build of `a70b192` (`git archive` into a folder of its own, as `agents/testing.md`
  says), and the 3D game with each `--aa` way; flat identical and 3D none over 32 is the
  pass (`off`, `smaa`, and `ssaa`: FXAA has since gone, below). The generated shaders are the same text on every platform; what Windows adds is
  slangc's SPIR-V of them and the Vulkan driver.
- **FXAA removed** from the ngfx build (2026-11-12, the user: it looked ugly, not worth
  its speed over SMAA): `fxaa.slang`, its pipeline, and `--aa fxaa`, which now falls back
  to SMAA as any unknown name does; the A key goes SMAA, off, supersampling. `off`,
  `smaa`, and `ssaa` against the step's own shots: none over 3 of 255.
- **Next, on its own branch** (steps 4 to 6): both renderers in one executable. The
  recorders are the seam: each renderer's `_gpu` files compiled side by side (renamed
  apart, or `gpu` and the recorders behind one interface chosen at start), the drawers
  unchanged.
- Building ngfx: `NGFX=~/projects/goose/goose-ngfx` and
  `NGFX_SLANGC=~/projects/goose/slang/bin/slangc` in every shell, then
  `python3 scripts/ngfx.py src/app/draughts.goose` (`build/ngfx/draughts`); gfx is
  `scripts/mac.py src/app/draughts.goose`. Both need `third_party/goose_gfx` and its
  SDL and nuklear checked out (`git submodule update --init` there, then the same in
  `third_party/goose_gfx`).

## Acceptance criteria

- [x] ngfx on main as a build option, the gfx build unchanged
- [x] The drawing in one copy, both renderers' shots as before
- [x] The 2D shaders generated from gfx's GLSL, the hand ports gone, ngfx's shots as
      before
- [ ] One executable per platform holding both renderers, starting on Apple systems
      without Metal 4
- [ ] `--renderer auto|gfx|ngfx`, `auto` picking ngfx where it runs and gfx elsewhere,
      and gfx after a start that didn't reach its first frame on ngfx
- [ ] Checked on the Mac, the iPhone, Windows, and an Android device, recorded here
- [x] The `ngfx` branch retired
- [ ] The decision and the architecture docs updated

## Later

- Extra ngfx downloads on each GitHub release, beside the gfx ones and marked as for
  recent GPUs and drivers, until this task's one executable makes them unneeded
  (Windows first, for task 074's gain; Linux runs ngfx too, task 076). Not now (the
  user, 2026-11-12).
