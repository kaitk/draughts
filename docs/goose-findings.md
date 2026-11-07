# Goose findings

Gaps found in Goose, goose_gfx, and the SDL it pins, while building for Android, with what
we do about each here and what could go upstream. Newest first.

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
