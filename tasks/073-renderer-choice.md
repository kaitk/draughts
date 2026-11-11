# 073: One executable, the renderer chosen at run time

Status: todo

Task 065 drew all of Draughts through goose-ngfx on its own branch, `ngfx`, as a
build-time choice; tasks 070 and 071 brought it to gfx's frame time and memory on the Mac
and the iPhone. ngfx gains the user nothing measurable today (task 065, 070, 071), and the
branch is rebased by hand onto main (34 commits on 2026-11-11). This task brings it into
main as a renderer the app picks when it starts: ngfx where the device has it, gfx
everywhere else and on Android, and a flag to force either (the user, 2026-11-11).

## What stands in the way

- **Two copies of the drawing.** The ngfx build lays `src/ngfx/` over `src/app/`: `host`,
  `render`, `draw`, `widgets`, `scene`, `draw3d`, `photo.c`, and `render3d` each exist
  twice, alike but for the GPU calls. Only the 3D shaders are generated from one source
  (`scripts/ngfx_3d_shaders.py`). Every rendering change is made twice, as task 071's
  were. Merged as it is, that cost moves onto main.
- **Linking both.** NoGraphicsAPI's CMake refuses a deployment target under macOS or iOS
  26, and its Metal backend calls Metal 4's classes directly; the gfx build runs on iOS
  16 (`scripts/ios.py`'s `MIN_IOS`). On Windows ngfx imports `vulkan-1.dll`, which a PC
  without a Vulkan driver lacks, and Windows then refuses to start the program at all.
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

1. **One copy of the drawing.** Split each twin into what to draw (layout, quads,
   instances, uniforms, the passes' order: one module, renderer-free, as `model3d` is
   for the 3D board) and recording it (a small module per renderer). Both builds stay
   as they are on screen, compared against shots before (flat identical, 3D within
   task 065's margins).
2. **ngfx in main as a build option.** `scripts/ngfx.py` and `src/ngfx/` on main; the
   `ngfx` branch retired. The gfx build is unchanged and still what ships.
3. **Both in one executable.** Draughts' one SDL for both (as task 065 left it); ngfx's
   code loaded only where it can run: Metal 4 behind `@available` with weak links, or
   ngfx in a library the app opens only on macOS and iOS 26 (and on Windows, only once
   `vulkan-1.dll` loads: a delay-loaded import, or Vulkan's functions fetched at run
   time). Which of the two, decided here and recorded in `docs/decisions/`.
4. **Choosing.** `--renderer auto|gfx|ngfx` (`auto` the default): `auto` tries ngfx and
   falls back to gfx in the same window; `ngfx` fails loudly where it can't run; Android
   is always gfx. The choice and why printed at start, for bug reports.
5. **Checked**: the Mac and the iPhone pick ngfx; an iOS 16 to 25 device or an Intel Mac
   gfx; Windows on the RTX 4090 ngfx and with `--renderer gfx` gfx; the tablet, the
   Pixel 7a, and the A33 gfx; the shots, `--rest`, and `--bench` of each as task 065's.

## Acceptance criteria

- [ ] The drawing in one copy, both renderers' shots as before
- [ ] One executable per platform holding both renderers, starting on systems without
      Metal 4 or Vulkan
- [ ] `--renderer auto|gfx|ngfx`, `auto` picking ngfx where it runs and gfx elsewhere
- [ ] Checked on the Mac, the iPhone, Windows, and an Android device, recorded here
- [ ] The decision and the architecture docs updated; the `ngfx` branch retired
