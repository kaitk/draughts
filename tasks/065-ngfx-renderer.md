# 065: The NoGraphicsAPI renderer through goose-ngfx

Status: todo (scoped 2026-11-11)

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

## Later, not in this task

- **Choosing at run time.** Both renderers in one executable, ngfx where the device has
  it (Metal 4; Vulkan 1.4 with `VK_EXT_descriptor_heap`), else gfx. They can't both
  link their own SDL as they do now: Goose's release builds gfx with its SDL, and ngfx
  builds its own. One SDL for both is the first problem of that task.
- ngfx on iPad and iPhone; presenting on Linux; the Steam builds (task 064).

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
