# 065: The NoGraphicsAPI renderer through goose-ngfx

Status: in-progress (on the `ngfx` branch; steps 1 to 6 on Windows, 2026-11-11)

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
- **The footprint** is ngfx's texture heap, one 512 MB block made at open: at 256 MB the
  flat game's footprint fell from 741 to 556 MB. It becomes a heap that grows as
  textures need it (ngfx).

## Later, not in this task

- **Choosing at run time.** Both renderers in one executable, ngfx where the device has
  it (Metal 4; Vulkan 1.4 with `VK_EXT_descriptor_heap`), else gfx. They can't both
  link their own SDL as they do now: Goose's release builds gfx with its SDL, and ngfx
  builds its own. Fixable, since the app already builds gfx from patched sources and
  ngfx is ours: ngfx's CMake takes the SDL the app links instead of its submodule's, the
  app opens the window, probes the device, and hands the window to the renderer it
  picked.
- **Presenting on Linux**: a Vulkan surface from SDL (`SDL_Vulkan_CreateSurface`) in
  ngfx's layer where NoGraphicsAPI makes none, the rest as on Windows.
- ngfx on iPad and iPhone; the Steam builds (task 064).

## Acceptance criteria

- [ ] goose-ngfx at Goose v2026.4, released, its tests and samples passing on the Mac
      and the PC
- [ ] `scripts/ngfx.py` builds Draughts on ngfx on the Mac and Windows, on the `ngfx`
      branch, with the gfx build unchanged
- [ ] Every screen, the flat board, and the 3D board drawn by ngfx, compared against the
      gfx build at the same flags
- [ ] Nothing drawn while idle; shaders built ahead, no Slang at run time
- [ ] Frame time against the gfx build on the Mac and the PC, recorded here
- [ ] What ngfx gained recorded in its own docs, and gaps in Goose in
      `docs/goose-findings.md` (ngfx's or this repo's, by whose they are)
