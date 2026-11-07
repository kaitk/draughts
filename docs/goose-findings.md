# Goose findings

Gaps found in Goose and goose_gfx while building for Android, with what we do about each
here and what could go upstream. Newest first.

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
