# Decisions

Draughts' design decisions for contributors and agents: each dated, with its reason and
what was rejected. How the app works now is in [Architecture](../architecture/README.md).
A change that contradicts a decision records the new one here in the same change and
updates the architecture; a replaced decision shrinks to a line saying what replaced it,
its full text left to git history (`git log -S '<phrase>' -- docs/decisions`).

One file per area, as the architecture has:

- This file: the stack, the code's layout, the players, and the app's lifecycle
- [layout.md](layout.md): where the programs, their C, the renderers, the platforms, the
  build scripts, and the tools are
- [rules.md](rules.md): the variants, the engine's representation, and the draws
- [ai.md](ai.md): the computer player, its levels, the lookout, and the hint
- [puzzles.md](puzzles.md): the puzzles, their file, and their checks
- [rendering.md](rendering.md): drawing, the UI, the look, the 3D board, frames, memory
- [sound.md](sound.md): which sounds, how they are made and stored, and the Volume row

## The stack

- Goose (2026-11-07). The proof of concept ran on the Galaxy Tab A11+ through Vulkan with
  no change to the compiler or runtime, needing one goose_gfx patch, one SDL patch, one C
  shim, and a shared SDL build ([goose-findings](../goose-findings.md)). Fallback, not
  needed: C99 and sokol. What the stack costs against bare C and sokol is in
  [Architecture](../architecture/README.md#what-the-stack-costs-against-bare-c--sokol).
- Not NoGraphicsAPI on Android (2026-11-07): its Vulkan backend needs
  `VK_EXT_descriptor_heap` and mesh shaders, which mobile GPUs lack.
- Vulkan on Windows (2026-11-10): SDL's default, Direct3D 12, took 5 s at each launch for
  FXC to compile the HLSL; Vulkan takes SPIR-V compiled with the program.
- Direct3D 12 on a branch, not `main` (2026-11-18): it draws as Vulkan does only with a
  Goose built with a cute_spirv patch (storage buffers and HLSL keywords, task 010's
  subtask 03), and no build ships it. The `direct3d12` branch keeps that patch, the one
  for cute_framework, and how to build it; `main` takes the drawing changes that are
  portable anyway (the widgets draw each run from instance 0, as Direct3D 12 needs).
- goose_gfx from the user's fork (2026-11-12): the submodule follows `kaitk/goose_gfx`'s
  `main`, each change also a branch on upstream `main`. It replaces patches applied to
  upstream's `v1` at build time, which kept every change twice. The build takes only
  gfx's C from the submodule; the Goose side is the release's. Upstream's reused upload
  buffer came with it (the 3D board's CPU a frame 0.27 to 0.03 ms on the RTX 4090). SDL
  keeps its patches in `patches/SDL/`.
- SDL built by `scripts/linux.py` on Linux (2026-11-12, task 076), Wayland and X11 both,
  in place of the release's X11-only `libSDL3.a`: on Wayland the window is sharp at a
  fractional scale and gets 9 to 19% more frames uncapped than through XWayland, for
  about 15 MB on GNOME (libdecor loads GTK). The release still needs only libc and libm,
  glibc 2.35.
- NoGraphicsAPI on older Apple systems by weak links (2026-11-12, task 077): the fork's
  `below-26` branch links Metal 4 weakly, marks the backend available from 26 with
  `-Wunguarded-availability-new` an error, and `create_device` checks
  `@available(macOS 26, iOS 26, *)`, so one executable holds both renderers from iOS 16.
  Rejected: ngfx in a separately loaded framework (a second binary and its signing). A
  Simulator build leaves ngfx out, as its SDK has no Metal 4 types.

## The code's layout

- Packages with no graphics, each tested headless; only `app/` imports `gfx` or calls SDL
  or the platform (2026-11-08), so a second renderer or platform replaces `app/` alone.
  Since 2026-11-18 that is `app/`, the renderers' `gfx/` and `ngfx/`, and the C in
  `native/` ([layout](layout.md)).
  The program is under `src/`, the tests under `test/` (2026-11-09).
- `render3d/` is a package outside `app/` that no game package imports (2026-11-09). Its
  gfx-free half is `model3d/`, tested headless (2026-11-10).
- `poc/` is gone (2026-11-14): its proofs of concept had served, and the 3D prototype's
  last use, settings' board pictures, is `tools/board_shot.goose`, shooting each look with
  the app's renderer and `looks::of`; frame pacing's check is `tools/pace.goose`. The
  prototype stays in git's history.
- The main loop sees `app/host` and `app/render` (2026-11-10): `main` calls nothing of
  gfx, `render::frame` owns the pass, and C hands pixels to the renderer. C fills a
  `draughts_pixels` rather than calling back into Goose: an `export fn` called back
  during an `extern` call overwrites the caller's resizables
  ([goose-findings](../goose-findings.md)).
- Rejected at that seam: a wrapper over single gfx calls (gfx's and goose-ngfx's APIs
  differ too much), and a Clay-like layout engine.
- Each drawer is split into what it draws, renderer-free, and its recording, a `_gpu`
  file per renderer, with `gpu` naming each renderer's handle types (2026-11-11): before,
  `src/ngfx/` held whole copies of eight files that had drifted.
- Both renderers in one executable by facades over a copied tree (2026-11-12, task 073),
  replaced on 2026-11-14 by one seam, `backend::with`, over drawers generic in the
  backend, and a second root ([rendering](rendering.md#two-renderers)). Android stays
  gfx-only and its sources never name ngfx.
- The renderer is chosen at start (2026-11-12, task 073): `--renderer auto|gfx|ngfx`, no
  setting. `auto` takes each platform's measured first choice, not a GPU list: ngfx on
  Windows (26 to 41% less GPU time on the RTX 4090), the Mac, and iOS (2026-11-13, task
  085: about 5% under gfx on the M1 Pro and iPhone 13 mini, replacing gfx there); gfx on
  Linux (RADV ran ngfx 13% slower) and Android. It first checks what needs no window
  (Metal 4 and an Apple7 GPU; Vulkan 1.4 with NoGraphicsAPI's extensions), then opens
  ngfx in gfx's hidden window and falls back to gfx if it won't. A marker naming the GPU,
  driver, and app version stands until ngfx's first frame, after Firefox's
  DriverCrashGuard: a start that finds it takes gfx until one of them changes. Not
  caught: a device lost after the first frame. Rejected: handing one window from ngfx to
  gfx.
- The ngfx build's 2D shaders are written from gfx's GLSL at each build
  (`scripts/ngfx_2d_shaders.py`, beside the 3D one, over `ngfx_glsl.py`; 2026-11-12, task
  073), replacing about 1,000 lines of hand ports in Slang. Each 2D module has its own
  root laid out from the GLSL. Still by hand in `src/ngfx/shaders/`: `down`, `mip`, and
  `smaa`.

### The panels in the board package (2026-11-14)

The panels' layout (`src/board/panel.goose`) is part of the board package, beside
`board::Layout`: a puzzle, the lessons, a replay, and how to play lay out by it too, and
as a file of `game/` it reached back into `game` for the moves panel's row sizes. The row
sizes are now the panel's (`panel::MOVES_ROW`, `MOVES_PAD`, `LINE_HEAD`), and
`panel::game` takes `panel::Clocks` (made by `game::clocks`), so the board package builds
on nothing of the screens'. Rejected: a package of its own, which seventy-odd roots
declaring `game` would have to declare too; and `shell/`, which `game` can't import. The
landscape 3D layout's special cases stay: its rows invert the 3D board's fit (`panel::fit_view`),
which no closed rule gives, and the golden layouts must not move.

### The shell's frame and the panel's regions (2026-11-10)

- One screen table, `shell::KINDS`, and one `match`, in place of the dispatch in eight
  places; the shell's frame leaves a `shell::Frame` the app only reads.
- `shell::still` runs the leaving screen's frame in a transition so `shell::blend` fades
  everything it declares: about 28 µs a frame for 0.25 s.
- The panel's regions (`Out`, `Play`) come from pure functions of `panel::Layout`.
  Rejected: filling them into the `Layout` each frame, which would make the shell measure
  words and read the clocks.
- `panel::game` is split by layout, with one declaring sequence, so the quads keep one
  order.
- `gui::stack` serves home's menu and settings' column only; cuts elsewhere (the stack
  moved a printed position in its last decimals).

## Players

Up to four players share one device, local only: no accounts, network, or passwords
(2026-11-09). A player is a badge, an optional name, their game in progress, and the
computer's skill against them (or `ai::adapt` would follow neither child); the language
is the device's. One file per player, so a change rewrites only that one.

## The app's lifecycle

- Back on home's menu puts the app in the background with the activity kept
  (`moveTaskToBack`). Rejected: SDL's `SDL_SendAndroidBackButton`, which finished the
  activity on Android 17.
- Back from Android 13 comes through an `OnBackInvokedCallback`, the manifest opting in,
  as Android 16 requires for an app targeting it; no SDL patch.
- Home's X calls `finishAndRemoveTask()` over JNI. Rejected: `finish()`, which leaves a
  card of home in recents.
