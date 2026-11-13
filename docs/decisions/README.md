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

SDL built by `scripts/linux.py` on Linux (2026-11-12), from the submodule with
`patches/SDL` applied, Wayland and X11 both required, in place of the Goose release's
`libSDL3.a`, which has X11 only. On GNOME's Wayland the window is then Wayland's: sharp at
a fractional scale where XWayland's is scaled up, matched to its `.desktop` file by its
app id, 9 to 19% more frames uncapped than through XWayland, and the frames' 1% lows
higher still; ngfx presents into it as well (task 076). It costs about 15 MB of memory on
GNOME, where libdecor's plugin loads GTK for the title bar, and the build needs CMake and
the headers, so the first one runs in the `draughts-jammy` box. The release still needs
only libc and libm, glibc 2.35, the oldest the Goose compiler runs on. Rejected: XWayland
with the release's SDL (0.2.0, task 075), and only X11 for ngfx.

NoGraphicsAPI on Apple's older systems by weak links (2026-11-12, task 077). The app runs
from iOS 16, and Metal 4, which NoGraphicsAPI's Metal backend is written on, exists from
macOS and iOS 26. The fork's `below-26` branch builds the backend for an older deployment
target: Metal 4's symbols are linked weakly (an iOS 16 link has 12 weak imports of them
and no strong one), the whole backend is marked available from 26 with
`-Wunguarded-availability-new` an error in it, so the compiler proves nothing reaches
Metal 4 but through a device, and `create_device` asks `@available(macOS 26, iOS 26, *)`
first and returns `Error::unsupported` before it. One executable then holds both
renderers on Apple too, and starts gfx where ngfx can't run (task 073). It is Apple's own
pattern for a newer API. Rejected: ngfx in a library the app opens only on 26 (an
embedded framework on iOS, signed and loaded by name), which adds a second binary, its
signing, and a `dlopen` boundary for the same result. The Simulator's SDK declares no
Metal 4 types, so a Simulator build leaves ngfx out.

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

Both renderers in one executable by facades in the ngfx overlay (2026-11-12, task 073,
replacing the build option above on desktop and iOS). Goose has no function pointers,
vtables, or conditional compilation, so the choice is an `if` at a seam, and Android stays
gfx-only (NoGraphicsAPI doesn't build there), so nothing in the shared sources names
ngfx's code. `scripts/ngfx.py`'s tree gives each twin three parts: gfx's recorder under a
name of its own (`draw_gfx`: `src/app/draw_gpu.goose` copied with its namespace line
rewritten, as a recorder never names its own namespace), goose-ngfx's (`draw_ngfx`, in
`src/ngfx/`), and in their place a facade of the twin's name that calls one or the other
as `nx::ngfx_on` says, set once at start; `render3d_gpu` and `photo_gpu.h` alike, the C
twin by `#define`d names. The drawers, `render3d.goose` included, are unchanged, and the
gfx-only build is as before. The drawers hold one handle type, gfx's: a handle is an id
into the chosen renderer's tables, both renderers' handles an id alone, and `nx` gives
goose-ngfx's calls gfx's types. gfx's 3D recorder names `render3d.goose`'s items as
`render3d::` so it compiles in either namespace. Rejected: the recorders renamed apart in
the repo with a facade per twin in every build, a forwarding one for Android's beside a
dispatching one, twice the facades for no gain; and the dispatch written into the
drawers' 52 call sites with a stub of goose-ngfx's C API linked on Android, which puts
ngfx's code and blobs in the APK.

The renderer chosen at start (2026-11-12, task 073): `--renderer auto|gfx|ngfx`, `auto`
the default and the only one players see (no setting). `auto` takes each platform's first
choice as measured, not a list of GPUs: ngfx on Windows (26 to 41% less GPU time a frame
on the RTX 4090, task 074), gfx on the Mac and iOS (ngfx's MSAA frame 2% over gfx's on the
M1 Pro, task 077) and on Linux (RADV ran ngfx 13% slower, task 076, to be measured again
with MSAA); Android is gfx-only. Where it is ngfx, `auto` first asks what needs no window
or device (macOS or iOS 26 and an Apple7 GPU with Metal 4; Vulkan's 1.4 loader and a
1.4 GPU with NoGraphicsAPI's three required extensions, `src/ngfx/app/renderer.c`), so a system
without them opens no window for ngfx at all. Then gfx's window opens hidden and
`WINDOW_ONLY`, ngfx opens in it, and if it won't, both close and gfx starts as alone, so
no window is handed from one renderer to the other. A marker beside the settings, naming
the GPU, its driver (the OS version on Apple), and the app's version and commit, stands
from before ngfx's device to its first frame presented, after Firefox's DriverCrashGuard:
a start that finds it takes gfx until one of the three changes, and `--renderer ngfx`
clears it. The choice and its reason are printed at start. Not caught: a device lost
after the first frame. Rejected: one window handed from ngfx to gfx, which needs gfx's
device made late and a second swapchain on a surface ngfx had.

`auto` takes ngfx first on the Mac and iOS too (2026-11-13, task 085), replacing gfx
there above: with NoGraphicsAPI's Metal root hint gone, ngfx's 3D frame is about 5% under
gfx's on the M1 Pro (2.89 to 2.94 ms of GPU against 3.05 to 3.12, full screen) and the
iPhone 13 mini (8.62 to 8.68 against 9.00 to 9.07), and the flat board waits 2.0 ms
against 2.1 to 2.2 headless on the Mac. Linux stays gfx.

The ngfx build's 2D shaders are written from gfx's GLSL at each build, as the 3D board's
already were (2026-11-12, task 073): `scripts/ngfx_2d_shaders.py` beside
`ngfx_3d_shaders.py`, both over one translation (`ngfx_glsl.py`) that keeps each stage's
GLSL as written in a namespace, its blocks, buffers, and samplers statics filled from the
root, and negates y for NoGraphicsAPI's clip space. A 2D module's root is its own, laid
out from the GLSL and written at the top of the file: the storage buffers' addresses,
the textures' and their sampler's heap indices padded to 16 bytes, then the uniform
blocks' fields, the vertex stage's first; the recorders fill it in that order. The one
hand-written part is the UI's `first`, the run's first quad: gfx draws from a first
instance, which `gl_InstanceIndex` counts and `SV_InstanceID` doesn't. Before,
`src/ngfx/shaders/` held hand ports of seven 2D shaders (about 1,000 lines), and a change
to the GLSL, as task 063's to the UI's, was made again in Slang. The GLSL stays the
source, as gfx is what ships everywhere. Rejected: the 3D board's one shared root, each
uniform block a pointer into frame memory, for the 2D modules: each draw would copy its
uniforms and then its root into frame memory, where one root holds both. Still by hand in
`src/ngfx/shaders/`: what ngfx alone has (`down` for its 2× pass in place of MSAA, and `mip`) and `smaa`, which includes SMAA's own HLSL as gfx's `smaa.goose` wraps it in GLSL.

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
