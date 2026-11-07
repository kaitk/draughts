# 001: Goose on Android proof of concept

Status: done

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
- [x] It survives pause/resume and rotation without leaking or crashing: 20 cycles of
      home → resume and portrait ↔ landscape keep the same process with no errors and
      flat memory (below)
- [x] The same program runs on macOS in-process (`goose poc.goose`)
- [x] One script builds and installs the APK (`adb install`); the steps are in `docs/development.md`
- [x] Decision recorded in `docs/architecture/README.md`: Goose

## Closing (2026-11-07)

- Full screen: on Android the POC opens with `gfx::WINDOW_FULLSCREEN`, found through
  `ANDROID_ROOT`. The status bar's inset reports `visible=false`, and the app draws all
  1920×1200 pixels.
- Taps: the piece moves on `gfx::mouse_pressed` or `mouse_released` as well as
  `mouse_down`, so `adb shell input tap` moves it.
- Memory, `scripts/lifecycle_memory.sh 20`, each cycle home → resume then portrait →
  landscape:

  | | Graphics (KB) | Native heap (KB) | PSS (KB) |
  | --- | --- | --- | --- |
  | Before the SDL patch, cycle 0 | 112 216 | 26 252 | 155 664 |
  | Before the SDL patch, cycle 20 | 681 652 | 27 524 | 727 657 |
  | With it, cycle 0 | 111 952 | 26 232 | 176 188 |
  | With it, cycle 20 | 114 416 | 25 324 | 175 431 |

  Without the patch, graphics memory rose 28.4 MB on every resume (rotation alone stayed
  flat): SDL_GPU leaked the old Vulkan swapchain when it recreated the surface
  (`docs/goose-findings.md`). With the patch it stays at 112 to 114 MB, apart from one
  66 MB rise at cycles 4 and 5 that the driver gave back. Same pid, no errors in logcat.
