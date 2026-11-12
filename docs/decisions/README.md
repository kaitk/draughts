# Decisions

This folder records Draughts' design decisions for contributors and agents: each one
dated, with its reason and what was rejected, and the measurements behind it. How the app
works as it is now is in [Architecture](../architecture/README.md). A change that
contradicts a decision here records the new one in the same change and updates the
architecture to match; a decision that replaces an earlier one says so, and both stay.

One file per area, as the architecture has:

- This file: the stack, the code's layout, the players, and the app's lifecycle
- [rules.md](rules.md): the variants, the engine's representation, and the draws
- [ai.md](ai.md): the computer player, its levels, the lookout, and the hint, with the
  self-play behind each change
- [puzzles.md](puzzles.md): the puzzles, their file, and their checks
- [rendering.md](rendering.md): drawing, the UI layer, the look, the 3D board, frames,
  memory, and the measurements behind them

## The stack

Goose (2026-11-07). The proof of concept ran on the Galaxy Tab A11+ through Vulkan with
no change to the Goose compiler or runtime. It needed one goose_gfx patch, one SDL patch
(a swapchain leak on resume), one C shim, and a shared SDL build, all listed in
[goose-findings](../goose-findings.md).

Fallback: C99 and sokol (sokol_app, sokol_gfx, sokol_audio, sokol-shdc; NativeActivity
on GLES3), if SDL_GPU's Vulkan path turned out unreliable on the tablet, with the same
structure and rules (2026-11-07). Not needed so far.

Rejected for now: NoGraphicsAPI through goose-ngfx on Android (2026-11-07). Its Vulkan
backend needs `VK_EXT_descriptor_heap` and mesh shaders, which mobile GPUs lack. Its
utility math adds AVX2 only for the x86-64 slice and uses NEON on arm64; whether its
utility libraries need AVX2 on x86 Windows is still open. It is a later, separate desktop
and Apple version ([product](../product.md)); its ideas are used inside SDL_GPU now
([rendering](rendering.md)).

What the stack costs against bare C and sokol was checked against goose_gfx's source on
2026-11-07; the list is in [Architecture](../architecture/README.md#what-the-stack-costs-against-bare-c--sokol).

Vulkan on Windows (2026-11-10). SDL would pick Direct3D 12 there, whose HLSL its
compiler FXC took 5 s to compile at each launch; Vulkan takes the SPIR-V compiled with the
program, as on Android. Rejected: Direct3D 12, SDL's default.

goose_gfx from the user's fork (2026-11-12). The `third_party/goose_gfx` submodule follows
`kaitk/goose_gfx`'s `main`: upstream `main` with every change Draughts needs merged in, each
also a branch of its own on upstream `main` to offer upstream one at a time. It replaces
patches in `patches/goose_gfx/` applied to upstream's `v1` at build time, which kept every
change twice, as a patch here and as the fork's branch. The build takes only gfx's C from
the submodule; the Goose side is still the release's, whose externs `main`'s C keeps. It
also brought upstream's commits past `v1`, among them one upload buffer reused in place of
a transfer buffer per update, which cut the 3D board's CPU a frame from 0.27 to 0.03 ms
on the RTX 4090 (task 074). SDL keeps its patches in `patches/SDL/`.

## The code's layout

Packages with no graphics, each run headless by its tests, and an app that feeds them the
pointer and the time and draws what they leave (2026-11-08).

Only `app/` imports `gfx` or calls SDL or the platform (2026-11-08), so the packages can
be tested headless and a second renderer or platform replaces `app/` alone.

The program's code is under `src/` (2026-11-09), as the tests are under `test/`; the top
level keeps what isn't the program's Goose.

`render3d/`, the 3D board's renderer, is a package outside `app/` that the app and the 3D
prototype (`poc/3d/`) share (2026-11-09). It imports gfx, and no package of the game
imports it.

The main loop sees two halves of what it runs on, `app/host` and `app/render`
(2026-11-10). Before, `main` called gfx's platform half and its drawing half directly, the
screen's pass began in the drawers and ended in `main`, gfx handles lived in the app's
state, and `background.c` and `resize.c` called goose_gfx's C texture functions. Now
`main` calls nothing of gfx, `render::frame` owns the pass, and C hands pixels to the
renderer. This is the seam a second renderer (goose-ngfx) and a second game build on.

- The C decoder can't hand pixels to Goose by a callback (2026-11-10): an `export fn`
  called back from C during an `extern` call overwrites the caller's resizables
  ([goose-findings](../goose-findings.md)), and C can't return a slice. So
  `background.c` fills a `draughts_pixels` pointing into the embedded ASTC blocks or the
  decoded JPEG, and the renderer's own C, `photo.c`, uploads them and gives them back,
  adding no copy.
- The 3D board's gfx-free half, its meshes, looks, harmonics, fade, and the bake's plan,
  moved to `model3d/` (2026-11-10), so it is tested headless.
- Left alone at the seam (2026-11-10): `view3d`'s matrix, column-major for SDL_GPU's clip
  space, which a later renderer converts on its own side; the GLSL; and `render3d`'s
  internals beyond the split. Rejected: a wrapper over single gfx calls, as gfx's and
  goose-ngfx's APIs differ too much for one; and a Clay-like layout engine, as
  `gui::stack` covers what it would give here.

goose-ngfx is a build option on main, its drawing one copy with gfx's (2026-11-11).
Each drawer is split into what it draws, renderer-free (`scene`, `draw`, `widgets`,
`draw3d`, `render`, `host`, `render3d`, `photo.c`), and its recording, a `_gpu` file per
renderer, with `gpu` naming each renderer's handle types; `scripts/ngfx.py` lays
`src/ngfx/`'s recorders over gfx's. Before, `src/ngfx/` held whole copies of eight files,
alike but for the GPU calls: each rendering change was made twice, and the copies had
drifted (the ngfx host lacked the keys' focus). The rejection above of a wrapper over
single gfx calls stands: a recorder records whole passes in its renderer's own terms,
and `gpu` holds only the types and the few calls that read the same in both (release, a
target, a pass's begin and end, the wait). `render3d_gpu` is a second file in namespace
`render3d`, so the 3D board's callers didn't change. Both renderers in one executable,
chosen at run time, waits on a branch of its own.

### The shell's frame and the panel's regions (2026-11-10)

- One screen table, `shell::KINDS`, and one `match` choosing each screen's code, in
  place of the same dispatch written in eight places. The game's and a puzzle's frames
  return an event, and the shell's frame leaves a `shell::Frame` the app only reads, in
  place of flags one package set and another cleared.
- `shell::still` runs the screen left's frame in a transition, for `shell::blend` fades
  and drifts out everything it declares. A cheaper declaration would leave out only what
  is already invisible, which is nothing; dropping the fade-out would change what the app
  shows. It costs about 28 µs a frame for the 0.25 s of a transition.
- The panel's per-frame regions, `Out` and `Play`, are worked out by pure functions from
  the `panel::Layout` and what shows; the `Layout` holds what doesn't change with the
  game. Rejected: filling them into the `Layout` each frame, which would make the shell,
  which builds it, measure the panel's words and read the clocks, the countdown, and a
  draw.
- `panel::game` is split by layout, not by declaring: one function per shape works out
  the regions, and one declaring sequence serves every mode, so the quads keep one order.
  Rejected: a declaring function per mode, repeating the clocks, the piece, and the
  controls three times.
- `gui::stack` serves home's menu and settings' landscape column only. Settings'
  side-by-side groups keep their cuts (the stack moved a printed position in its last
  decimals), one group at a time keeps them (a cut clamps a glass taller than its room),
  and the rows, the cards, and the picker's grid don't use it. Rejected: re-blessing the
  expected outputs for a last-bit difference no one sees, and a cut's clamp in the stack,
  which would make it a second cut API.
- `settings::Fit` (the names' width and the slim tiles) is part of the `settings::Page`
  and passed down to the rows and tiles; `settings::layout` changes nothing. It replaced
  two layout results written into the player's `Settings` and read back through it, a
  side channel.

## Players

Up to four players share one tablet, local only: no accounts, no network, no passwords
(2026-11-09). A player is a badge, an optional name, and what a child makes their own;
the rest belongs to the device. The game in progress is the player's, so continue means
"my game" and switching to a sibling never replaces a game against the computer; the
computer's skill is the player's, or `ai::adapt` would follow neither child; the language
is the device's, as a parent sets it once.

One file per player (2026-11-09), so a change rewrites only that player's and no section
parser is needed. Rejected: sections in one file.

## The app's lifecycle

Back on home's menu leaves the app as the system's back does, putting it in the
background with the activity kept (`moveTaskToBack`). Rejected: SDL's own way,
`SDL_SendAndroidBackButton` and the activity's `onBackPressed`, which finished the
activity on Android 17 instead, taking the card out of recents as home's X does.

Back from Android 13 comes through an `OnBackInvokedCallback`, the manifest opting into
back callbacks, as Android 16 does for an app targeting it, where the key is no longer
dispatched. SDL's sample manifest opts out instead, which Android calls temporary. No SDL
patch is needed.

Home's X finishes the activity with `finishAndRemoveTask()`, over JNI before the program
returns. Rejected: plain `finish()`, what SDL does when the program returns, which leaves
a card with a picture of home in recents, as if the app still ran.
