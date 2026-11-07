# Architecture

The decisions the code follows, and why. This file holds the stack and the rules every
part of the code keeps. The rest is by area:

- [rules.md](rules.md): draughts variants and how the engine represents them
- [ai.md](ai.md): the computer player, its search, and how its levels play like a person
- [rendering.md](rendering.md): drawing, the UI layer, glass, fonts, and frame pacing

## Stack

| Concern | Choice |
| --- | --- |
| Language | [Goose](https://github.com/aardappel/goose), compiled to C (`goose -o game.c`, `goose --emit-runtime`) |
| Graphics, input, window | `gfx` from [goose_gfx](https://github.com/aardappel/goose_gfx): SDL3's GPU API, with GLSL compiled to SPIR-V, MSL, and HLSL at compile time |
| GPU backend | Vulkan on Android; Metal on macOS; D3D12 or Vulkan on Windows |
| Android build | NDK clang for `aarch64-linux-android29`; SDL shared (`libSDL3.so`) with SDL's stock SDLActivity Java, no Java of our own; APK built by `scripts/android.py` without Gradle ([development](../development.md)) |
| Desktop iteration | `goose game.goose` runs in the compiler's process (TinyCC), with no build step |
| UI | Our own immediate-mode layer in Goose ([rendering.md](rendering.md)); Nuklear (`ui`) for developer tools only |
| Text | TrueType fonts baked by `ui`'s font atlas |

**Decided 2026-11-07 (task 001): Goose.** The proof of concept runs on the Galaxy Tab
A11+ through Vulkan with no change to the Goose compiler or runtime. It needed one
goose_gfx patch, one SDL patch (a swapchain leak on resume), one C shim, and a shared SDL
build, all listed in [goose-findings](../goose-findings.md).

**Fallback: C99 + sokol** (sokol_app, sokol_gfx, sokol_audio, sokol-shdc; NativeActivity
on GLES3), if SDL_GPU's Vulkan path turns out unreliable on the tablet. The structure and
rules below stay the same.

**Rejected for now: NoGraphicsAPI / goose-ngfx on Android.** Its Vulkan backend needs
`VK_EXT_descriptor_heap` and mesh shaders, which mobile GPUs lack, and its utility math
needs x86-64 with AVX2. It is a later, separate desktop and Apple version
([product](../product.md)). Its ideas are used inside SDL_GPU now
([rendering.md](rendering.md)).

## What the stack costs against bare C + sokol

Checked against goose_gfx's source on 2026-11-07:

- Game code is compiled C with no GC and no heap, and frame-loop code allocates nothing.
- goose_gfx uploads through one persistent staging ring that SDL recycles. Its `realloc`s
  run only when handle tables grow. Nothing is created or released while drawing.
- Each call passes through goose_gfx's handle and misuse checks, then SDL_GPU, then
  Vulkan. With 10 to 20 draws a frame, the cost is negligible.
- `update_buffer` copies through staging, where NoGraphicsAPI writes mapped memory
  directly. That's a few KB a frame.
- The binary carries SDL3, about 2 to 3 MB, against about 0.2 MB for sokol.
- SDL owns the main loop and the Android lifecycle.
- There is no GLES fallback: devices without a working Vulkan driver can't run the app.

## Rules every part keeps

- **No allocation in the frame loop.** Goose gives this through its data stacks. Per-frame
  arrays live in the frame's scope. Long-lived tables, such as the transposition table,
  are sized once at startup.
- **Draw only on change.** See [rendering.md](rendering.md#frames-and-battery).
- **Game state is a value.** A position is a few `u64`s plus side to move. Undo is a stack
  of positions; saving is writing the value.
- **Strings by key.** Every user-facing string comes from `strings/<lang>.txt`
  (`key = text` per line), built into the program with `embed_file`. Code names a string
  by its constant (`strings::HOME_CONTINUE`) and `strings::get` returns a view into the
  embedded file, so looking one up allocates nothing. English is the default and fills in
  any key a translation lacks; Estonian is `et.txt`. The language is the first of the
  system's preferred locales (SDL's, through `app/locale.c`) that has a file, else
  English. A language is a new file plus its code in `strings::LANGUAGES`;
  `test/strings/` fails on a key missing from any file. Kids who can't read get icons,
  and later voice clips keyed the same way.
- **Kept in the app's storage folder** (SDL's pref path, through `app/storage.c`): the
  settings as a small `key = value` file (`settings.txt`, `shell/settings.goose`),
  written whole and atomically after a change; and the game as it stands, `game.bin`,
  written when the app is paused or quits, since Android may kill a paused app. Both
  are read at start. Nothing is written while idle.
- **The saved game is one flat value** (`shell::Saved`): the screen, the position, where
  the game began, the last move, and the undo history (a limited array), written with
  Goose's `to_bytes` and an FNV-1a checksum after it, about 15 KB. `from_bytes` verifies
  the image's shape and the checksum its bytes; a file that fails either, or has
  another `VERSION`, is ignored and the app starts afresh. The pause is seen as the
  window losing focus: SDL runs the loop once more after Android pauses the app before
  it blocks.
- **Assets are embedded** in the binary (shaders by `embed_shader`, fonts and puzzles as
  data), so no code reads Android's asset manager.
