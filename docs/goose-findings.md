# Goose findings

Gaps found in Goose, goose_gfx, the SDL it pins, NoGraphicsAPI, and goose-ngfx: what we do
here and what to propose upstream. Newest first within each section. Versions are Goose
v2026.4, goose_gfx `6cfa3de` (the release's `v1`), SDL 3.4.16 (`fa2c02b`) unless an entry
says otherwise. goose-ngfx is the user's, so its gaps are fixed there when Draughts needs
them.

Draughts builds gfx from `kaitk/goose_gfx`'s `main` (the submodule): upstream `main` with
every change below merged in, each also a branch of its own on upstream `main`, offered
upstream one at a time (`upstream-series` is all of them; task 065 lists which stack on
which). NoGraphicsAPI changes are branches of `kaitk/NoGraphicsAPI`, merged into its
`ngfx`, which goose-ngfx follows, each a pull request to `sebbbi/NoGraphicsAPI`. None of
these pull requests is opened yet; the user opens them.

SDL entries are for the user only: SDL's `CLAUDE.md` asks that no AI-written code or text
go into its reports or pull requests, so any report is the user's own. Check first whether
a newer SDL fixes it. SDL `main` still had every entry below on 2026-11-18 (release
3.4.20); task 010's `02-sdl.md` lists what to send.

## Goose

### Direct3D 12: storage buffers read as structured buffers SDL doesn't bind

Draughts draws through Vulkan on Windows, so this shows only with `SDL_GPU_DRIVER=direct3d12`.
There every shader that reads a storage buffer in its vertex stage draws nothing or
collapses: the flat board's pieces, every widget and all text, and the 3D board's 40 pieces
drawn as one in a corner. Shaders without one draw as on Vulkan. Goose's HLSL declares an
SSBO as `StructuredBuffer<float4>`, while SDL 3.4.16's Direct3D 12 backend makes storage
buffer views raw (`R32_TYPELESS`, `D3D12_BUFFER_SRV_FLAG_RAW`, stride 0), as for a
`ByteAddressBuffer`, which is what SPIRV-Cross emits. The cause fits every screen but isn't
proven; the debug layer printed nothing (Radeon 680M, 2026-11-18). Goose v2026.4.

- Here: nothing; Windows draws through Vulkan.
- Upstream: emit `ByteAddressBuffer` and `Load4` for SSBOs, as SPIRV-Cross does.

### Direct3D 12: HLSL keywords are kept as GLSL names

`embed_shader` writes GLSL identifiers into the HLSL unchanged, so one that is an HLSL
keyword compiles to SPIR-V and MSL but fails FXC at run time on Windows: `float line` in
`shaders::cracks` stops the app with `error X3000: syntax error: unexpected token 'line'`
(2026-11-18; found first 2026-11-10). Goose v2026.4.

- Here: nothing; Windows draws through Vulkan.
- Upstream: rename identifiers that are HLSL keywords (`line`, `point`, `triangle`,
  `sample`, `linear`, `precise`, `shared`, `matrix`, `vector`, ...) when writing the HLSL,
  as SPIRV-Cross does, or reject them when compiling the shader.

### `embed_shader` drops `mediump`, so no shader runs in fp16

Goose's GLSL compiler (`shaderc.c`, SPIR-V from cute_spirv) parses `mediump` and drops it:
no `RelaxedPrecision` decoration, where glslang gives the same source twelve. `precision
mediump float;` and `float16_t`/`f16vec3` are errors. `RelaxedPrecision` needs no device
feature, and Mali runs fp16 at twice fp32's rate in half the registers.

- Here: nothing; task 081's fp16 step waits for it. The Mac's Metal path may keep `float`,
  so check fp16's rounding on an Android device.
- Upstream: `mediump`/`lowp` decorate the variable and the operations computed into it
  `RelaxedPrecision`, as glslang does for Vulkan; `precision` statements set the default.

### The Linux release's SDL has no Wayland

The release's `libSDL3.a` has X11 and offscreen video only, so on a Wayland desktop every
Goose program runs through XWayland: a fractional scale is upscaled by the compositor, and
the window is matched to its `.desktop` file by `WM_CLASS`.

- Here: `scripts/linux.py` builds the submodule's SDL with Wayland and X11 both required
  (task 076); the executable still needs only libc and libm.
- Upstream: build the release's SDL with `SDL_WAYLAND=ON` (libdecor loaded dynamically);
  SDL loads `libwayland-client` at run time, so X11-only systems still run.

### TinyCC's run in memory fails under SELinux

`goose run` (and `test/run_tests.py`'s default) fails on Fedora's and Bazzite's enforcing
SELinux: libtcc's `mprotect` is refused.

- Here: `test/run_tests.py --build` on Fedora-based machines.
- Upstream: libtcc built `--with-selinux`, which maps the code twice from a temporary file.

### No way to write `goose.h` for a build of one's own

`goose -o --emit-runtime` gives a program's C and the runtime's, but no `goose.h`
(`gs_rref`, `gs_bld_append`), which a package's C taking a `u8[>..]&` includes;
`--header` lacks `gs_bld_append`. goose-ngfx's C needs it on iOS.

- Here: `scripts/ios.py`'s `goose_h` takes the one written for goose-ngfx's Mac build under
  `~/.goose/build/pkg/local/`, so `scripts/ngfx.py` must have run first.
- Upstream: `goose --emit-header goose.h`, beside `--emit-runtime`.

### `pad` and `block` are keywords everywhere

Both are reserved throughout (by the spec), though each means something in one place, and
both are common names in graphics code. `block` as a name also gives a second, confusing
error.

- Here: other names (`pad0`, `pad1`); `agents/goose.md` lists both.
- Upstream: make them contextual, as `inline` and `checkfree` are: `pad` only in a struct
  body, `block` only before `{`.

### `embed_shader`'s GLSL lacks conversions, and its Metal translation an inout swizzle

cute_spirv refuses `float(bool)` and `bvec2(vec2)` and has no `textureLodOffset` or
`textureGather`. A swizzle passed as `inout` (`f(v.xy)`) compiles, but its MSL fails at
`gfx::pipeline` on the Mac ("non-const lvalue reference ... cannot bind to a temporary").

- Here: `tools/smaa_glsl.py` writes `src/render3d/smaa.glsl` from the unchanged
  `SMAA.hlsl` with those spots rewritten; `src/render3d/smaa.goose` maps SMAA's sampling
  macros onto `textureLod`.
- Upstream: the two conversions and two functions in cute_spirv; an inout swizzle copied
  through a temporary in the MSL.

### An `export fn` called back from C inside an `extern` call overwrites the caller's data stack

```goose
extern fn decode() -> bool;                      // C: calls take_pixels(...), returns 1
export fn take_pixels(px: const u8[:]) {
    var tmp: u8[>..] = [];
    for i in 10 { tmp.push((i + 100) as u8); }
}
fn main() {
    var keep: u8[>..] = [];
    keep.push(7);
    decode();
    print(keep[0]);                              // prints 100, not 7
}
```

The export's wrapper seems to start from the data stacks' base rather than their tops.

- Here: no callbacks into Goose; the background's decoder (`src/app/background.c`) hands
  the photograph to the renderer's C (`src/app/photo.c`).
- Upstream: a re-entrant export continues from the stacks' tops, or the spec forbids it.

### No way to ask which platform the program runs on

- Here: `draughts_platform` in `src/app/launch.c`, from `__ANDROID__` and
  `TARGET_OS_IPHONE`.
- Upstream: possibly an `os` function naming the platform.

## goose_gfx

### Headless has no GPU device on macOS since upstream #8

Upstream `main` (`7ff752f`, #8) opens headless video with SDL's offscreen driver first, and
SDL_GPU's Metal backend takes only a driver that makes Metal views, which offscreen
doesn't. On the Mac every `GOOSE_GFX_HEADLESS=1` run fails with "no GPU device", and
Goose's suite skips its gfx tests rather than failing them (2026-11-18).

- Here: `kaitk/goose_gfx`'s `headless-apple` leaves the default driver (Cocoa) on Apple's
  systems; until it is in the fork's `main`, `SDL_VIDEO_DRIVER=cocoa` does the same.
- Upstream: the same (task 010).

### FXC compiles every shader again at each launch on Direct3D 12

goose_gfx turns Goose's HLSL into DXBC with FXC when `gfx::pipeline` is called, on the
main thread, keeping nothing: about 4 s on a black window at every launch on a Radeon
680M laptop, 5 s on a desktop (2026-11-18, 2026-11-10). Vulkan takes SPIR-V compiled at
build time.

- Here: nothing; Windows draws through Vulkan. A DXBC cache on disk made a later launch
  0.6 s (`patches/goose_gfx/0007-dxbc-cache.patch` at `fc7ae44`).
- Upstream: the cache in goose_gfx; or Goose embedding DXBC or DXIL beside the HLSL.

### No gamepad in the release

The release's `gfx.goose` declares no gamepad functions, though upstream `main` has them
since `d623f66` and the fork's `main` brings them.

- Here: `src/app/keys.goose` declares them itself, with weak stand-ins in
  `src/app/gfx_fork.c` for a plain `goose build`.
- At rest: SDL reads open pads every 1 ms, and on the Mac its HIDAPI thread took 5% of a
  core with a PS5 pad. The fork's `gamepad-wake` turns `SDL_HINT_AUTO_UPDATE_JOYSTICKS`
  off, reads the pads in `frame()` and every 16 ms of the idle wait, waking only on a
  press or a stick moved a quarter (about 0.5% of a core on Windows); `SYSTEM_GAMEPADS`
  turns HIDAPI off on Apple's systems and Android so the system's events wake the wait.
  The Mac's, the tablet's and iOS's numbers are to measure.
- Upstream: `gamepad-wake` (on `ios-run-loop-wait`, on `draw-on-demand`), with
  `SYSTEM_GAMEPADS` opt-in; `gamepad_*` in the next release's `gfx.goose`.

### NO_VSYNC capped full screen on Windows

gfx's `NO_VSYNC` asked for mailbox before immediate, and full screen on NVIDIA's Vulkan
mailbox is held to the refresh (165 fps against 747 immediate). ngfx's `NO_VSYNC` did
nothing on Vulkan, which NoGraphicsAPI fixes to FIFO.

- Here and upstream: `kaitk/goose_gfx`'s `no-vsync-immediate` asks for immediate first;
  NoGraphicsAPI's `DeviceDesc::vsync` (immediate, else mailbox, else FIFO), set by
  `ngfx::open`'s `NO_VSYNC` (task 074).

### No window without its GPU device

`gfx::open` makes an SDL_GPU device and claims the window, so another renderer can't draw
into gfx's window and keep its input, events, and idle wait.

- Here: `kaitk/goose_gfx`'s `window-only`: flag `WINDOW_ONLY` (64), the window and no
  device; `gs_gfx_native_window()` (a `CAMetalLayer`, `HWND`, or `ANativeWindow`); on
  Linux (`window-only-linux`) the `wl_surface` or X11 window with
  `gs_gfx_native_display()` and `gs_gfx_native_kind()` (`NATIVE_WAYLAND` 1, `NATIVE_X11`
  2); `gs_gfx_presented(shown)`, so a frame that showed nothing makes the next `frame()`
  wait; and `gs_gfx_needs_present()`. The Goose side is the program's own externs.
- Upstream: the flag and calls in `gfx.goose`. It is also how a program would choose its
  renderer at run time.

### A lost device makes `frame()` spin, submitting work that never runs

Once the device is lost every wait and submit fails at once; with draw on demand a program
ran about 12,000 frames a second on the A33 until the driver's records filled the heap.

- Here: `kaitk/goose_gfx`'s `end-on-device-lost`: `gfx_sdl_fail` notes `DEVICE_LOST`,
  prints it once, and sets quit; the app saves the game and closes, and the next start
  restores it.
- Upstream: the same, or a `gfx::lost()` to rebuild resources on a new device.

### No pipeline cache, and pipelines made only on first use

gfx makes a pipeline when first bound in a pass, and SDL_GPU's Vulkan backend has no
`VkPipelineCache`, so each launch compiles every pipeline on the frame that first uses it
(most of the Pixel 7a's 0.71 s cold 3D bake). gfx's tables aren't thread-safe either.

- Here: `render3d::warm` binds each pipeline alone in a pass on 4 × 4 targets, a step a
  frame, with a still mark in the board's place (`draw3d::prepare`).
- Upstream: `gfx::prepare(pipeline, formats...)`; for SDL (the user decides) a pipeline
  cache saved to disk, Metal's binary archives.

### No compressed texture formats

gfx maps no BC or ASTC format, counts bytes per texel rather than per block, uploads with
`pixels_per_row` set to the width, and can't ask whether the GPU samples a format. A 2048²
photograph is 16 MiB as RGBA8 against 1.8 MiB as ASTC 6 × 6.

- Here: `kaitk/goose_gfx`'s `compressed-textures`: `BC1`, `BC3`, `BC7`, `ASTC_4x4` to
  `ASTC_8x8` (21 to 27, sampled only), whole-block byte counts, tight uploads, and
  `gs_gfx_format_supported(format, usage)`. The program calls gfx's C API itself
  (`src/app/background.c`), with a weak stand-in answering no, so a plain `goose build`
  decodes the JPEG instead.
- Upstream: the formats and `format_supported` in `gfx.goose`, block-aware byte counts and
  `texel_size`; perhaps loading `.astc` or `.ktx2` from bytes.

### `ui`'s font atlas is RGBA32 only, its height a power of two

A program uploading the atlas itself gets four bytes a texel where one would do, and up to
twice the rows the glyphs use (8 MiB on the tablet).

- Here: `src/app/text.goose` moves the alpha to the front in place and uploads only the
  used rows as R8.
- Upstream: a format choice on `bake` (`NK_FONT_ATLAS_ALPHA8`) and the used height beside
  `atlas_size`.

### An MSAA pass stores its samples and depth, and cycles them

`begin_pass` stores `RESOLVE_AND_STORE` color and `STORE` depth and cycles what it clears:
on a tiler a 4× target at 1920 × 1200 writes about 74 MB a frame.

- Here: `kaitk/goose_gfx`'s `msaa-resolve-without-store`: `RESOLVE` color, `DONT_CARE`
  multisampled depth, no cycling on clear; single-sampled depth keeps `STORE` for shadow
  maps.
- Upstream: those defaults, or store ops and `cycle` in `PassDesc`. Note for SDL (the
  user's call): its Vulkan backend never uses transient memory for a target, so the 4×
  target still costs its bytes.

### The screen always has a depth target, and is cycled every frame

The window-sized depth target exists whether or not `screen_depth()` is called, and
clearing the screen cycles it, keeping extra window-sized copies (graphics memory on the
tablet 207.5 MB, 138.9 without).

- Here: `kaitk/goose_gfx`'s `screen-without-depth` makes the depth on the first
  `screen_depth()` and clears the screen without cycling; the app begins with
  `gfx::begin_pass(gfx::screen(), gfx::Texture { 0 }, clear)`.
- Upstream: both, or a flag in `gfx::open` and a `cycle` field in `PassDesc`.

### No safe area and no display scale

- Here: `src/app/display.c` reads `SDL_GetWindowSafeArea` and `SDL_GetWindowDisplayScale`
  each frame (through `dlsym` on the Mac), since the program's Goose compiles against the
  release's `gfx.goose`.
- Upstream: `gfx::safe_area() -> float4` (insets in pixels) and `gfx::display_scale() ->
  f32`, and a safe-area change counted as a resize.

### `load_texture` reads only PNG and BMP, and only from a file

- Here: the program decodes its JPEGs with stb_image in its own C and uploads through
  gfx's C API (or a compressed copy, above).
- Upstream: possibly `load_texture_from_memory(bytes, flags)` and JPEG through stb_image.

### `frame()` presents every frame, so an idle program redraws at the display rate

- Here: `kaitk/goose_gfx`'s `draw-on-demand`: `frame()` presents only when something used
  the GPU or the window needs it, and after a frame that drew nothing waits for an event
  (up to 1 s). After Android recreates the surface it retries the present for up to 8
  frames. It needs the Android busy-wait workaround and, on iOS, `ios-run-loop-wait`
  (below). The Mac at rest: 8.2% of a core before, 0.03% after.
- Upstream: the same, opt-in (`gfx::set_wait_when_idle(true)` or an `open` flag); skipping
  the present of an empty frame could be the default.

### SDL_GPU requires `shaderClipDistance`, which Mali GPUs lack

- Here: `kaitk/goose_gfx`'s `no-clip-distance` creates the device with the feature off.
- Upstream: the same everywhere; nothing in gfx's API uses clip distances.

### `ui::input_from_gfx` opens the on-screen keyboard on Android

- Here: a HUD calls `ui::input_begin` and `ui::input_end` with no input.
- Upstream: start text input only while a field has focus (`ui::wants_keyboard`).

### SDL is static, but SDL's Android Java loads `libSDL3.so`

- Here: `android/CMakeLists.txt` builds SDL shared and compiles gfx's sources itself.
- Upstream: possibly an Android path in gfx's CMake.

## NoGraphicsAPI and goose-ngfx

### Metal's root alignment hint shades every sample of an MSAA pass

`GPU_ROOT`'s `__builtin_assume((ptr & 15) == 0)` on Metal makes Apple's compiler run a
multisampled pipeline's fragment shader per sample (ngfx's 4× pass 11.8 ms against gfx's
2.1 on an M1 Pro; single-sample pipelines about 20% slower). Task 085 has a repro.

- Here and upstream: `metal-root-hint` drops the hint on Metal. `__builtin_assume_aligned`
  doesn't compile on a `constant` pointer.

### No presenting on Linux

The Vulkan backend presented on Win32 only, refused a Wayland surface's undefined
`currentExtent`, and held 64 surface formats where RADV lists 72.

- Here and upstream: `linux-presentation`: `DeviceDesc::display` and `window_system`
  (`wayland` default, `xlib`), `set_drawable_extent`, 256 formats; goose-ngfx's
  `ngfx::open(window, w, h, flags, display, kind)` takes gfx's three (task 076).

### MSAA (ASTC 6 × 6 and vsync likewise)

NoGraphicsAPI had no sample count or resolve. The fork's `msaa` adds `sample_count`,
`TextureUsage::transient`, and `ColorAttachment::resolve_view`; goose-ngfx has
`TextureDesc.samples`, `TRANSIENT`, and `PassDesc.resolve`, and the ngfx build draws MSAA
by default ([decisions](decisions/rendering.md)), SMAA a choice. Upstream once tested on
Vulkan (task 077). `astc-6x6` and `vsync-option` are the fork's other pull requests.

### `generate_mips` takes no sRGB texture

It writes levels through storage views, which sRGB formats can't be.

- Here: `src/ngfx/shaders/mip.slang` draws each level as a pass (`render3d::mip_chain`).
- Upstream, in goose-ngfx (`docs/design.md`, "Open"): an sRGB view over a UNORM storage
  texture, or levels drawn as passes for such formats.

## SDL

Each has a patch in `patches/SDL/` or an app-side workaround.

### `SDL_WaitEventTimeout` busy-waits on Android

Every pass of the wait pushes a new poll sentinel, whose wakeup ends the wait at once: a
1 s wait used a whole core.

- Here: gfx sets `SDL_HINT_POLL_SENTINEL` to `"0"` on Android before video init.
- Upstream: no sentinel pushed, or no wakeup sent for it, inside the wait loop.

### `SDL_WaitEventTimeout` polls every millisecond on iOS

UIKit has no `WaitEventTimeout` or `SendWakeupEvent`, so the wait polls with a 1 ms sleep
(16% of a core at rest on the iPhone 13 mini).

- Here: `kaitk/goose_gfx`'s `ios-run-loop-wait` runs the main run loop for the timeout;
  an event pushed from another thread signals a run loop source of gfx's own (0.08% at
  rest).
- Upstream: a UIKit `WaitEventTimeout` and `SendWakeupEvent`, as Cocoa has.

### SDL_GPU's Vulkan backend leaks a swapchain on every Android resume

- Here: `0001-destroy-swapchain-on-surface-recreate.patch` destroys the old swapchain before
  the old surface (it leaked 28.4 MB a resume).

### The Android safe area includes the system gestures' strips

- Here: `DraughtsActivity`'s `SDLSurface` subclass runs SDL's `onApplyWindowInsets`, then
  sends its own insets: `systemGestures` left out, `tappableElement` and
  `mandatorySystemGestures` only at the sides and bottom (a patch until 2026-11-18).
- Upstream: possibly a hint choosing which insets make the safe area.

### SDL_GPU's Vulkan allocator rounds large resources up to 64 MiB blocks

- Here: `0003-large-allocations-at-their-size.patch` gives a resource over 2 MiB its own
  allocation of its exact size, kept out of the free list (tablet graphics memory 94.4 →
  63.6 MB). Rounding to 4 or 8 MiB was rejected (`docs/architecture/rendering.md`).
- Upstream: a threshold over which allocations are dedicated, as VMA has.

### A size change while in the background leaves the window black on return

Recreating the swapchain queries the lost surface, fails, and never asks for a new one.

- Here: `0004-recreate-a-lost-surface-on-resize.patch` marks surface and swapchain for
  recreating and returns `TRY_AGAIN`.

### SDL_GPU refuses the iOS simulator's Metal device

- Here: `0005-metal-on-the-ios-simulator.patch` skips the family check under
  `TARGET_OS_SIMULATOR`.

### A rotation on iOS stretches the picture

- Here: `0006-metal-contents-unstretched-while-rotating.patch` sets the layer's gravity to
  `kCAGravityCenter` during the transition.

### A non-square texture's last mip is blitted at zero size

`VULKAN_GenerateMipmaps` doesn't clamp each axis to 1, and the A33's Mali-G68 loses the
device on the zero-extent blit.

- Here: `render3d::baked` asks for mips down to the shorter side's 1 pixel.
- Upstream: `SDL_max(1, ... >> level)` per axis.

### Launch flashes black between Android's splash and the first frame

- Here: `DraughtsActivity` holds the splash and a navy cover until the program reports its
  first presented frame over JNI (`src/app/launch.c`); the theme sets a navy navigation
  bar.

### The Java side keeps the accelerometer on at 50 Hz

- Here: `DraughtsActivity`'s `SDLSurface` subclass ignores `TYPE_ACCELEROMETER` in
  `enableSensor`; SDL's display orientation then stays at the launch's, which nothing
  reads.
- Upstream: register it only while a sensor or the accelerometer joystick is open.

## Settled

Android's stdout and stderr go to logcat through `android/stdio_to_logcat.c`, the usual
shim, with nothing to propose.
