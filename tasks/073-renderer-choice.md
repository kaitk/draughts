# 073: One executable, the renderer chosen at run time

Status: in-progress (steps 1 and 2 done on main 2026-11-11; step 3 on main next; steps 4 to 6 on a branch of their own)

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

## What stands in the way

- **Two copies of the drawing.** The ngfx build lays `src/ngfx/` over `src/app/`: `host`,
  `render`, `draw`, `widgets`, `scene`, `draw3d`, `photo.c`, and `render3d` each exist
  twice, alike but for the GPU calls. Only the 3D shaders are generated from one source
  (`scripts/ngfx_3d_shaders.py`). Every rendering change is made twice, as task 071's
  were. Merged as it is, that cost moves onto main. (Step 2 split the drawers; the 2D
  shaders are still two copies, step 3.)
- **Linking both.** NoGraphicsAPI's CMake refuses a deployment target under macOS or iOS
  26, and its Metal backend calls Metal 4's classes directly; the gfx build runs on iOS
  16 (`scripts/ios.py`'s `MIN_IOS`). On Windows ngfx imports `vulkan-1.dll` directly, which
  is no loss: gfx draws only through Vulkan there too (Direct3D 12 rejected for FXC's 5 s
  at each launch, `docs/decisions/README.md`), so a PC without a Vulkan driver can't run
  Draughts either way; only Windows' own missing-DLL dialog stands in for the app's
  message (the user, 2026-11-11). The fallback matters there for GPUs with Vulkan but
  not ngfx's newer needs, `VK_EXT_descriptor_heap` above all.
- **The hand-off.** The ngfx host opens gfx's window `WINDOW_ONLY` (patch 0008) and
  aborts if `ngfx::open` fails. Falling back needs gfx to make its GPU device afterwards,
  in the window it already opened.

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
   - **Order.** ngfx is tried before gfx makes any device: gfx opens the window
     `WINDOW_ONLY`, `ngfx::open` runs, and only if it returns false does gfx make its
     device in that window. Nothing of ngfx's (its device, instance, or surface) is left
     open when gfx takes over, or Vulkan on Windows may refuse gfx a second swapchain on
     the same window.
   - **A device that passes but breaks.** The Vulkan extensions ngfx needs are new
     (2025 to 2026), and their drivers will have bugs that no check sees. `auto` writes a
     marker beside the settings before making ngfx's device and clears it after the
     first frame is shown; a start that finds the marker still there picks gfx and says
     so. `--renderer ngfx` clears it, for trying again after a driver update. A failure
     after the first frame (device lost) is not caught this way; record it if it shows.
   - **No setting in the UI.** The flag is for testing and bug reports; players get
     `auto`.
6. **Checked**: the Mac and the iPhone pick ngfx; an iOS 16 to 25 device or an Intel Mac
   gfx; Windows on the RTX 4090 ngfx and with `--renderer gfx` gfx; the tablet, the
   Pixel 7a, and the A33 gfx; the shots, `--rest`, and `--bench` of each as task 065's.

## Where it stands (2026-11-11)

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
- **Next, on main**: step 3, the 2D shaders generated from the GLSL (2026-11-12).
- **Then, on its own branch** (steps 4 to 6): both renderers in one executable. The
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
- [ ] The 2D shaders generated from gfx's GLSL, the hand ports gone, ngfx's shots as
      before
- [ ] One executable per platform holding both renderers, starting on Apple systems
      without Metal 4
- [ ] `--renderer auto|gfx|ngfx`, `auto` picking ngfx where it runs and gfx elsewhere,
      and gfx after a start that didn't reach its first frame on ngfx
- [ ] Checked on the Mac, the iPhone, Windows, and an Android device, recorded here
- [x] The `ngfx` branch retired
- [ ] The decision and the architecture docs updated
