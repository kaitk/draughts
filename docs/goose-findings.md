# Goose findings

Gaps found in Goose, goose_gfx, and the SDL it pins, while building for Android, with what
we do about each here and what could go upstream. Newest first.

## goose_gfx: `ui`'s font atlas is RGBA32 only, its height a power of two (2026-11-08)

`gs_ui_bake_font_atlas` always asks Nuklear for `NK_FONT_ATLAS_RGBA32` (white, the
coverage in alpha) and keeps a copy, which `atlas_pixels` copies out again; Nuklear rounds
the height up to a power of two. A program that uploads the image itself, as Draughts
does, gets four bytes a texel where one would do and up to twice the rows the glyphs use:
on the tablet 1024 × 2048 RGBA, 8 MiB, for 1846 rows of coverage, and three such buffers
(Nuklear's, `ui`'s copy, the program's) while baking.

- Here, no patch (the Mac's `goose` has its own `ui` built in): the app moves the alpha to
  the front of the buffer `atlas_pixels` returned, in place, and uploads only the rows
  the glyphs reach as an R8 texture, its v remapped from whole rows (`app/text.goose`).
- Upstream: a format choice on `bake` (`NK_FONT_ATLAS_ALPHA8`, which Nuklear has) and the
  used height beside `atlas_size`; `ui`'s own renderer would then need a coverage-only
  texture path.

## SDL: SDL_GPU's Vulkan allocator rounds large resources up to 64 MiB blocks (2026-11-08)

`VULKAN_INTERNAL_BindResourceMemory` puts a resource up to 2 MiB
(`SMALL_ALLOCATION_THRESHOLD`) in shared 16 MiB blocks, and gives a larger one a new
`VkDeviceMemory` rounded up to a multiple of 64 MiB (`LARGE_ALLOCATION_INCREMENT`), whose
free space later large resources share. A block is given back only once it is empty. On a
GPU with one memory type, as Mali's, a 2D app's few large resources take a whole block:
on the tablet (1920 × 1200) the screen, the photograph, and the text atlas are 34 MiB in a
64 MiB block, and the largest tablet's (2880 × 1920: screen 21 MiB, atlas 32) would need
two. SDL 3.4.16 (`fa2c02b`).

- Here: `patches/SDL/0003-large-allocations-at-their-size.patch` gives a resource over
  2 MiB its own `VkDeviceMemory` of exactly its memory requirements' size, as SDL already
  does for transfer buffers (`dedicated`), and keeps such allocations, transfer buffers'
  too, out of the free list, so nothing else is placed in one and it goes back to the
  driver at a submit soon after its resource is released. Small resources keep the
  shared 16 MiB blocks. SDL has no `VK_KHR_dedicated_allocation` plumbing, so the patch
  doesn't add `VkMemoryDedicatedAllocateInfo`. On the tablet GL mtrack after an animation
  went from 94.4 to 63.6 MB and stays there through rotations and season changes (PSS
  about 31 MB lower everywhere); frame times of moves and season changes unchanged (task
  032's file has the numbers). Large allocations happen only at load, on a season
  change, and on a resize. Rounding to 4 or 8 MiB instead was weighed and rejected
  (`docs/architecture/rendering.md`, GPU memory).
- Upstream: for the user only, as with the other SDL entries. Upstream's rounding suits
  a discrete GPU with many large resources; a threshold over which allocations are
  dedicated (as VMA does for resources over half a block) would serve both.

## goose_gfx: the screen always has a depth target, and is cycled every frame (2026-11-08)

`gfx_create_screen` makes a window-sized depth target (D32F where supported) beside the
RGBA8 screen, whether or not the program ever asks for `screen_depth()`, and remakes both
on every resize. `begin_pass` sets `cycle` on every color target it clears, the screen
included; since the last frame's blit nearly always still reads the screen when the next
frame clears it, SDL_GPU's Vulkan backend keeps a second (or third) window-sized copy
for good. On the tablet (Mali-G615, one memory type) SDL puts any resource over 2 MiB in
a block rounded up to 64 MiB; the screen, its depth, and their copies and remakes after
the first rotation needed a second such block: graphics 156.6 MB fresh, 207.5 MB after
a rotation. goose_gfx `6cfa3de`, Goose v2026.4.

- Here: `patches/goose_gfx/0003-screen-without-depth-or-cycling.patch` makes the screen's
  depth target the first time `screen_depth()` is called (so `begin_screen` still works;
  the POC uses it), and from then on with each resize; and clears the screen without
  cycling. Not cycling is safe: SDL's barrier orders the clear after the last frame's
  blit on the GPU, and the CPU never waits. The app begins its pass with
  `gfx::begin_pass(gfx::screen(), gfx::Texture { 0 }, clear)`. Graphics after an
  animation and a rotation: 207.5 → 138.9 MB, PSS 265 → 196 MB; frame times of a move at
  90 Hz unchanged (task 032's file has the numbers).
- Upstream: both in goose_gfx. Make the screen's depth lazily as here, or take a flag
  in `gfx::open`; and don't cycle the screen in `begin_pass` (a program-made target that
  is cleared each frame may still gain from cycling). A `cycle` field in `PassDesc`
  would let a program choose.

## goose_gfx: no safe area and no display scale (2026-11-08)

A phone's camera cutout and gesture bar take part of the window, and its density says
how large a pixel is; goose_gfx exposes neither, so a program can't keep its taps out
of the cutout or size them in millimetres. SDL has both: `SDL_GetWindowSafeArea` (on
Android from the window's insets: cutout, system bars and gestures) and
`SDL_GetWindowDisplayScale` (Android's density / 160, 2.625 on the Pixel 7a; on a Mac's
Retina screen 2.0, the pixel density 2 times a content scale of 1.0; a Mac window's safe
area is all of it). goose_gfx `6cfa3de`, Goose v2026.4.

- Here: no patch. A gfx patch can't add a function the program calls: the program's Goose
  is compiled against the release's own `pkg/gfx/gfx.goose` on both platforms, and a
  desktop run uses the gfx built into the goose binary (`agents/goose.md`). So the
  program's own C (`app/display.c`) finds the window with `SDL_GetWindows` once and reads
  both each frame, through `dlsym` on the Mac as `app/locale.c` does. A safe-area change
  wakes the loop with SDL's `SDL_EVENT_WINDOW_SAFE_AREA_CHANGED`, and the program, seeing
  new insets, draws again.
- Upstream: `gfx::safe_area() -> float4` (the insets in pixels: left, top, right,
  bottom, from `SDL_GetWindowSafeArea` scaled by the pixel density) and
  `gfx::display_scale() -> f32` (`SDL_GetWindowDisplayScale`), declared in
  `src/gfx/gfx_api.h` and `gfx.goose` as the other window queries are; and a safe-area
  change counted as a resize where `frame()` reports one. Small.

## SDL: the Android safe area includes the system gestures' strips (2026-11-08)

`SDLSurface.onApplyWindowInsets` makes the safe area from `systemBars | systemGestures |
mandatorySystemGestures | tappableElement | displayCutout`. With gesture navigation,
`systemGestures` holds the back gesture's strips down both sides, which Android's docs
say still pass taps to the window, so a portrait phone's safe area loses tens of dp of
its width for no tap's sake. With the bars hidden, `mandatorySystemGestures` still holds
the strip at the top a swipe pulls them down from, where taps reach the window too (on
the Pixel 7a 150 px in portrait, 32 more than its camera, and 74 px in landscape). On a
Samsung tablet (the Galaxy Tab A11+) that strip is reported as `tappableElement` too
(45 px), so it stays out of the safe area through that type as well. SDL 3.4.16
(`fa2c02b`).

- Here: `patches/SDL/0002-safe-area-without-system-gestures.patch` leaves
  `systemGestures` out, and takes `tappableElement` and `mandatorySystemGestures` only
  at the sides and the bottom: `max(systemBars | displayCutout, (tap.left, 0, tap.right,
  max(tap.bottom, gestures.bottom)))`. A status bar while shown counts through
  `systemBars`. `scripts/android.py` compiles SDL's Java from the patched copy, as it
  does its C. Checked on the Pixel 7a (0, 118, 0, 84 px in portrait, 118, 0, 0, 84 and
  0, 0, 118, 84 in landscape; a tap in the old top strip reaches the app, a swipe there
  still shows the bars) and on the Galaxy Tab A11+ (0, 0, 0, 72, nothing held at the top).
- Upstream: for the user only, as with the other SDL entries. Possibly a hint choosing
  which insets make the safe area.

## SDL: launch flashes black between Android's splash and the first frame (2026-11-08)

Android 12+ removes its splash at the activity window's first draw. SDLActivity's
window is a `SurfaceView`, whose hole shows what is behind it, black or the launcher,
until SDL presents its first frame, so the theme's `windowBackground` never shows there.
On the tablet the splash fades onto 150 to 260 ms of black before the app. SDLActivity
has no hook for "first frame presented", and the colour behind a `SurfaceView`
(`setResizeBackgroundColor`) is not public API. SDL 3.4.16 (`fa2c02b`).

- Here: `DraughtsActivity` covers the window with a view of the theme's navy and, on
  Android 12+, holds the splash with `getSplashScreen().setOnExitAnimationListener`. The
  program reports its first presented frame over JNI (`app/launch.c`, through
  `SDL_GetAndroidActivity`), and the activity removes both then. The theme also sets
  `windowDrawsSystemBarBackgrounds` with a navy `navigationBarColor`, or the navigation
  bar's area shows the launcher's taskbar during the hand-over. On the tablet the icon on
  navy now goes straight to the first frame.
- Upstream: for the user only, as with the other SDL entries. SDL could offer the hold
  itself, keeping the splash until the first `SDL_GPU` or EGL present.

## goose_gfx: `load_texture` reads only PNG and BMP, and only from a file (2026-11-07)

`gs_gfx_load_texture` picks `SDL_LoadBMP` for `.bmp` and `SDL_LoadPNG` for anything
else, from a path. There is no JPEG, and no way to load from bytes already in memory,
such as an `embed_file`. A photograph-like background is about 5 MB as PNG and 0.5 to
0.7 MB as JPEG. goose_gfx `6cfa3de`, Goose v2026.4.

- Here: no patch. The program decodes its JPEGs with stb_image in its own C (a
  `c_sources` entry in its sidecar) and uploads the pixels with `gfx::texture2d` and
  `update_texture`, which works with the built-in gfx on the Mac too
  ([rendering](architecture/rendering.md#scene-and-glass)).
- Upstream: possibly `load_texture_from_memory(bytes, flags)` and JPEG through
  stb_image, which goose_gfx's Nuklear demos already carry. Small and optional.

## SDL: the Java side keeps the accelerometer on at 50 Hz (2026-11-07)

`SDLSurface.handleResume` (and `SDLActivity` at start) registers the accelerometer at
`SENSOR_DELAY_GAME` (20 ms) whenever the app is resumed, whether or not the program opens a
sensor or joystick. SDL uses it for an accelerometer joystick and to notice display
rotation. With the idle board drawing nothing, it is what remains: on the tablet the Java
main thread woke 52 times a second for 1.1 to 1.3 s of CPU a minute, the program's thread
0.02 s, plus the sensor's power. SDL 3.4.16 (`fa2c02b`).

- Here (2026-11-08): no patch. SDL's Java has a hook: `DraughtsActivity` overrides
  `createSDLSurface` to return a subclass of `SDLSurface` whose `enableSensor` ignores
  `TYPE_ACCELEROMETER`, which covers both the start and every resume. Nothing in the app
  needs it: the program opens only video (and audio), no joystick, so the accelerometer
  joystick never exists; and the screen turns because Android rotates the activity
  (SDL requests `FULL_USER`) and the surface's new size reaches the program as a resize.
  What is lost is SDL's display orientation (`SDL_GetCurrentDisplayOrientation`,
  `SDL_EVENT_DISPLAY_ORIENTATION`), which then stays at the launch's; neither gfx nor the
  app reads it. On the tablet our process has no sensor connection while resumed
  (`dumpsys sensorservice`), the main thread does no work at idle, and the whole process
  takes 0.05 to 0.06 s a minute; portrait, landscape, and the flipped landscape still lay
  out right.
- Upstream: for the user only, as with the other SDL entries. Register the accelerometer
  only while a sensor or the accelerometer joystick is open, and learn the rotation from a
  `DisplayManager.DisplayListener` instead.

## SDL: `SDL_WaitEventTimeout` busy-waits on Android (2026-11-07)

On Android every pass of the wait loop in `SDL_WaitEventTimeoutNS` calls
`SDL_PumpEventsInternal(true)`, which takes the poll sentinel out of the queue and pushes
a new one. Pushing any event calls `SDL_SendWakeupEvent`, which on Android queues a
lifecycle WAKE event, and that WAKE ends `Android_PumpEvents(delay)` at once. So the loop
never blocks: on the tablet a 1 s wait used a whole core (1814 s of CPU in 30 minutes,
no voluntary context switches). SDL 3.4.16 (`fa2c02b`).

- Here: patch 0002 sets `SDL_HINT_POLL_SENTINEL` to `"0"` on Android before video init.
  With no sentinel nothing is pushed while waiting, and the wait blocks until an event or
  the timeout: one wakeup a second, 0.41 s of CPU in 30 minutes idle. gfx's
  `SDL_PollEvent` loop drains the queue the same way without the sentinel.
- Upstream: for the user only, under SDL's rule on AI-written reports (see the swapchain
  entry). The likely fix is in SDL: don't push a sentinel inside the wait loop, or don't
  send a wakeup for the sentinel. Check first whether a newer SDL fixes it.

## goose_gfx: `frame()` presents every frame, so an idle program redraws at the display rate (2026-11-07)

`gs_gfx_frame` presents the screen and polls events on every call, whether or not
anything was drawn since the last one. A program that draws only on change still
acquires a swapchain image and blits the screen each frame, and without the present's
vsync wait its loop would spin. There is no way to wait for an event instead. goose_gfx
`6cfa3de`, Goose v2026.4.

- Here: `patches/goose_gfx/0002-draw-on-demand.patch`. `frame()` presents only when
  something used the GPU since the last call or the window needs the screen again, and
  after a frame that drew nothing it waits for an event (up to 1 s) before reading
  events. On the tablet an idle program went from a present at every 90 Hz refresh to 5
  `frame()` returns and no presents in 5 seconds, and a tap still wakes it at once
  ([rendering](architecture/rendering.md#frames-and-battery)). The first version lost
  the picture on resume: the first present after Android recreates the surface gets no
  image, so the patch keeps trying for up to 8 frames. The wait also needs the next
  entry's workaround, or it spins on Android.
- Upstream: the same in `gs_gfx_frame`, but opt-in, since a program that polls input
  without drawing would otherwise block for up to a second: for example
  `gfx::set_wait_when_idle(true)`, or a window flag for `gfx::open`. A frame that drew
  nothing could skip the present by default, which only saves work.

## SDL: SDL_GPU's Vulkan backend leaks a swapchain on every Android resume (2026-11-07)

When Android brings the app back, SDL_GPU recreates the Vulkan surface
(`needsSurfaceRecreate` in `VULKAN_INTERNAL_AcquireSwapchainTexture`). It destroys the old
surface but not the old swapchain: `VULKAN_INTERNAL_RecreateSwapchain` frees only its
images' views, and `VULKAN_INTERNAL_CreateSwapchain` passes no `oldSwapchain` when the
surface is new, so nothing destroys it. On the tablet each home → resume leaked 28.4 MB
of graphics memory, three 1920×1200 images. Rotation doesn't recreate the surface and
didn't leak. SDL 3.4.16 (`fa2c02b`, goose_gfx's pin).

- Here: `patches/SDL/0001-destroy-swapchain-on-surface-recreate.patch` waits for the device
  and destroys the old swapchain before the old surface. `scripts/android.py` builds SDL
  from a patched copy. After it, 20 cycles hold graphics memory at 112 to 114 MB
  (task 001).
- Upstream: SDL's `CLAUDE.md` asks that no AI-generated code or text go into SDL bug
  reports or pull requests. So the report is the user's own, in their own words, if they
  send one. Check first whether a newer SDL already fixes it.

## Goose: no way to ask which platform the program runs on (2026-11-07)

The program needs to know it's on Android to open full screen (SDL then hides the system
bars) while keeping a resizable window on the Mac.

- Here: `env("ANDROID_ROOT", ...)` is true in every Android app process.
- Upstream: possibly an `os` function naming the platform, if more than one program needs it.

## goose_gfx: SDL_GPU requires `shaderClipDistance`, which Mali GPUs lack (2026-11-07)

`gs_gfx_open` calls `SDL_CreateGPUDevice`, which asks for SDL_GPU's default Vulkan features.
`shaderClipDistance` is among them, and the Galaxy Tab A11+'s Mali-G615 doesn't support it,
so `gfx::open` fails with "No supported SDL_GPU backend found!". Goose's GLSL never writes
`gl_ClipDistance`.

- Here: `patches/goose_gfx/0001-no-clip-distance.patch`, applied by `scripts/android.py`,
  creates the device with properties and the feature off.
- Upstream: the same change in goose_gfx, on every platform. Nothing in goose_gfx's API
  can use clip distances, so it costs nothing elsewhere.

## goose_gfx: `ui::input_from_gfx` opens the on-screen keyboard on Android (2026-11-07)

It turns on SDL text input every frame, for text fields. On Android that shows the
keyboard, even for a HUD with no fields.

- Here: a HUD calls `ui::input_begin` and `ui::input_end` with no input instead.
- Upstream: start text input only while a text field has focus (`ui::wants_keyboard`).

## goose_gfx: SDL is static, but SDL's Android Java loads `libSDL3.so` (2026-11-07)

goose_gfx's CMake forces a static SDL. SDLActivity loads `SDL3` and then `main` by name,
so a static SDL needs a Java subclass that overrides `getLibraries()`.

- Here: `android/CMakeLists.txt` builds SDL shared and compiles goose_gfx's sources itself.
- Upstream: possibly an Android path in goose_gfx's CMake, once more than one project
  builds for Android.

## Goose: stdout and stderr go nowhere on Android (2026-11-07)

`print`, `abort`, and runtime errors write to stdout and stderr, which Android discards.

- Here: `android/stdio_to_logcat.c` forwards both to logcat with the tag `goose`.
- Upstream: nothing needed; this is the usual Android shim.
