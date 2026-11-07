# 001: Goose on Android proof of concept

Status: in-progress

Prove that a Goose program using `gfx` runs on the Galaxy tablet: Goose → C → NDK clang
(arm64) → APK, with SDL3 + SDL_GPU (Vulkan) and the `goose_gfx` native layer. If it can't
be made to work in reasonable time, switch to the C99 + sokol fallback in
`docs/architecture/README.md`.

## Result (2026-11-07)

It works. `poc/poc.goose` (a shader-drawn piece that follows touch, and Tenor Sans text
with õäöüšž) runs on the Galaxy Tab A11+ (SM-X230, Android 16, Mali-G615 MC2, Vulkan 1.3)
and in-process on the Mac (Metal). `scripts/android.py poc/poc.goose --run` builds,
installs, and starts it. How the build works is in `docs/development.md`.

What it took beyond Goose and goose_gfx as released:

- No changes to the Goose compiler or runtime: `goose -o` and `--emit-runtime` C compiled
  with NDK clang for `aarch64-linux-android29` unchanged.
- SDL3 is built shared, not static as goose_gfx's CMake builds it, because SDL's stock
  Java glue loads `libSDL3.so` by name (`android/CMakeLists.txt`). No Java of our own.
- One goose_gfx patch (`patches/goose_gfx/0001-no-clip-distance.patch`): SDL_GPU requires
  Vulkan's `shaderClipDistance` by default, which the Mali-G615 lacks, so device creation
  failed with "No supported SDL_GPU backend found!". The patch creates the device with
  `SDL_PROP_GPU_DEVICE_CREATE_FEATURE_CLIP_DISTANCE_BOOLEAN` false.
- One C shim, `android/stdio_to_logcat.c`: Android discards stdout and stderr, where
  Goose's `print`, `abort`, and runtime errors go, so it forwards them to logcat (tag
  `goose`).
- The HUD must not call `ui::input_from_gfx`: that turns on SDL text input, which opens
  Android's on-screen keyboard. An empty `ui::input_begin`/`ui::input_end` pair ends the
  frame instead.

APK: 2.8 MB (`libSDL3.so` 1.9 MB and `libmain.so` 0.9 MB stripped, SDL's dex 43 KB).

Each item is in `docs/goose-findings.md`, with what to propose upstream.

## Acceptance criteria

- [x] `goose -o` and `--emit-runtime` C compiles with NDK clang for `aarch64-linux-android`;
      runtime patches (if any) are listed in `docs/goose-findings.md` (none needed)
- [x] SDL3 and goose_gfx's C build with the NDK; the Goose `main` is entered as `SDL_main`
- [x] On the tablet: a cleared screen, one shader-drawn shape, touch moves it, one line of
      TrueType text including "õäöüšž"
- [ ] It survives pause/resume and rotation without leaking or crashing. Home → resume
      and portrait ↔ landscape keep the same process with no errors (checked over adb).
      Leaks over many cycles are not measured yet
- [x] The same program runs on macOS in-process (`goose poc.goose`)
- [x] One script builds and installs the APK (`adb install`); the steps are in `docs/development.md`
- [x] Decision recorded in `docs/architecture/README.md`: Goose

## Left for the next session

- The window sits under the status bar: the top 45 px of the app are covered. Make it
  full screen (immersive) on Android, through SDL's fullscreen window or a hint.
- `adb shell input tap` doesn't move the piece: a quick tap presses and releases within
  one frame, so `gfx::mouse_down` never sees it. The board must act on
  `gfx::mouse_pressed`/`mouse_released` or on events. Drags work.
- Measure memory over 20 pause/resume and rotation cycles (`adb shell dumpsys meminfo
  com.kaitk.kabe`), then close this task.
