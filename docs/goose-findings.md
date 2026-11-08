# Goose findings

Gaps found in Goose, goose_gfx, and the SDL it pins, while building for Android, with what
we do about each here and what could go upstream. Newest first.

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
the Pixel 7a 150 px in portrait, 32 more than its camera, and 74 px in landscape). SDL
3.4.16 (`fa2c02b`).

- Here: `patches/SDL/0002-safe-area-without-system-gestures.patch` leaves
  `systemGestures` out and takes only the bottom of `mandatorySystemGestures` (the
  gesture bar); the cutout, the bars while shown, and `tappableElement` still count.
  `scripts/android.py` compiles SDL's Java from the patched copy, as it does its C. The
  side strips' part checked on the Pixel 7a; the top strip's waits for it (task 030).
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
`SENSOR_DELAY_GAME` whenever the app is resumed, whether or not the program opens a
sensor or joystick. SDL uses it for an accelerometer joystick and to notice display
rotation. With the idle board drawing nothing, it is what remains: 1.9% of a core on
the Java main thread and 50 wakeups a second, plus the sensor's power. SDL 3.4.16
(`fa2c02b`).

- Here: not yet; task 011 plans a patch to SDL's Java in `patches/SDL/`.
- Upstream: for the user only, as with the other SDL entries.

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
