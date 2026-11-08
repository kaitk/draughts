# Architecture

The decisions the code follows, and why. This file holds the stack, how the code is laid
out, and the rules every part of it keeps. The rest is by area:

- [rules.md](rules.md): draughts variants and how the engine represents them
- [ai.md](ai.md): the computer player, its search, and how its levels play like a person
- [puzzles.md](puzzles.md): the puzzles, their file, goals, and checks
- [rendering.md](rendering.md): drawing, the UI layer, glass, fonts, and frame pacing

## Stack

| Concern | Choice |
| --- | --- |
| Language | [Goose](https://github.com/aardappel/goose), compiled to C (`goose -o game.c`, `goose --emit-runtime`) |
| Graphics, input, window | `gfx` from [goose_gfx](https://github.com/aardappel/goose_gfx): SDL3's GPU API, with GLSL compiled to SPIR-V, MSL, and HLSL at compile time |
| GPU backend | Vulkan on Android; Metal on macOS; D3D12 or Vulkan on Windows |
| Android build | NDK clang for `aarch64-linux-android29`; SDL shared (`libSDL3.so`) with SDL's stock SDLActivity Java and one small subclass of it (`DraughtsActivity`: development flags, the launch cover, closing the app); APK built by `scripts/android.py` without Gradle ([development](../development.md)) |
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

## Code layout

The code is packages with no graphics, each run headless by its tests, and an app that
feeds them the pointer and the time and draws what they leave (2026-11-08).

**The rule: only `app/` imports `gfx` or calls SDL or the platform** (2026-11-08). The
packages hand it flat, fixed-size data and take back the pointer and the time; nothing
outside `app/` (and `android/`, the build scripts) knows what draws or what it runs on.
The targets this keeps open, each replacing or adding to `app/` alone:

- **The 3D board** (task 015, a prototype soon): drawn in `app/`; what the board needs
  of it, the camera's tilt eased into the layout and a tap turned into a square by a ray
  onto the board's plane, stays plain math in `board/`, tested headless.
- **Other platforms on SDL:** iOS (UIKit, SDL_GPU on Metal), and desktop Windows and
  Linux (SDL_GPU on D3D12 or Vulkan): a build script and shims beside the Android ones
  (storage, locales, the launch cover, closing; iOS hides home's X).
- **A second renderer**, the NoGraphicsAPI version through goose-ngfx on desktop and
  Apple devices that support it ([product](../product.md)): `app/`'s drawing rewritten
  against it, the packages unchanged.
- **Chess** ([product](../product.md)): new rules and board packages beside these,
  reusing `gui/`, `shell/`'s screens, and `app/` as they are.

| Directory | What it holds |
| --- | --- |
| `rules/` | The rules as pure functions over values: variants as data, positions, legal moves, playing a move, FEN, and the square at a column and row ([rules.md](rules.md)) |
| `ai/` | The computer player over `rules`: a search sliced into steps, and its levels and skill ([ai.md](ai.md)) |
| `puzzles/` | The puzzles as plain text read into a fixed table, and the exact search that says whether a move solves one ([puzzles.md](puzzles.md)) |
| `strings/` | The user-facing text by key, from `strings/<lang>.txt` |
| `gui/` | The UI layer ([rendering.md](rendering.md#ui-layer)): rect cuts, widgets with their press state, text laid out from glyph tables the app bakes; every call appends quads to one fixed array |
| `board/` | The board on screen: the position, the legal moves, and the undo history; where the board goes and which square a point is on; taps and drags; a move's animation; and each frame's draw lists (pieces, the squares' marks, a wrong move's flash) |
| `game/` | The game screen: its panels and where they and the board go (`panel::layout`), the clocks, the computer's turn (asking for a move and playing the answer), the celebration, and the pieces it puts over the UI |
| `shell/` | The screens and which one shows: home and a new game's setup with the board of the game it starts, the game, settings with their preview board, the puzzles to pick from and the puzzle playing ([puzzles.md](puzzles.md#the-screen)); the pieces the screen showing puts over the UI (`Shell.over`, which the app draws); the settings file and the saved game |
| `app/` | The program: the main loop, the GPU drawing of the board, the pieces, and the UI's quads, the season's photograph and its blurs, the font atlas, the themes, the computer's worker thread, and its C (storage folder, locales, the clock's wake timer, the JPEG decoder) |
| `tools/` | Programs for development: perft, the computer's benchmark and matches, a terminal game against it, and the puzzles' checks |

`ai`, `board`, and `puzzles` build on `rules`; `game` on `board`, `gui`, and `strings`; `shell` on
`game` and `ai`; the app on all of them. What crosses to the renderer is flat and
fixed-size, laid out as the shaders read it: `board::Piece`, `board::Marks`, the flash,
`board::Layout`, `gui::Quad`, and `theme::Theme`.

### A frame

`app/draughts.goose` runs one loop on every platform
([rendering.md](rendering.md#frames-and-battery)):

1. The window: when it loses focus the game is written (Android may kill a paused app),
   and on Android the clocks pause; a new season's photograph loads two frames after its
   tile was tapped; the text is baked again if the scale changed.
2. `gui::begin` takes the pointer and the time, and `shell::frame` declares the screen
   showing. Its widgets append quads and its pieces over the UI go into the shell's
   list; a press that lands on the UI is the UI's, and only otherwise does the game
   screen hand the pointer to `board`. The screen reports what it asks for (another
   screen, a new game) and whether anything on it changed.
3. `think::frame` hands the computer's worker the game's ask, and the game its answer.
4. After a change in settings: the file is written, the language switched, and a new
   season's photograph scheduled.
5. If anything changed or still moves (`shell::animating`), the board the screen shows
   (`shell::shown`) fills its draw lists, and the frame is drawn: the photograph and the
   squares in one pass, the pieces, the UI's quads, then the pieces over the UI.
   Otherwise nothing is drawn, and the next frame waits for input.
6. While a clock runs, a timer is set for when the time it shows changes.

Android's back (the gesture or the button) and Escape on the Mac go back a screen, as
the screen's own back or home control does (`shell::back`): a setup to home's menu, the
game, settings, and the puzzles to pick from where their tile goes, a puzzle to the
puzzles. On home's menu, which has no way back, back leaves the app as the system's back
does, putting it in the background with the activity kept (`draughts_leave`,
`DraughtsActivity.leaveApp`, `moveTaskToBack`), and Escape ends the loop. Back reaches the program as SDL's
"AC Back" key: up to Android 12 through SDL's own key handling, from Android 13 through
an `OnBackInvokedCallback` in `DraughtsActivity` that hands it to SDL, the manifest
opting into back callbacks (`enableOnBackInvokedCallback`), as Android 16 does for an app
targeting it, where the key is no longer dispatched.

The loop ends on Escape on home's menu or when home's X asks the shell to stop
(`Shell.quit`). The game is then written as at any loop's end; after home's X, on Android the program
calls `DraughtsActivity.closeApp()` over JNI (`app/launch.c`), which finishes the
activity with `finishAndRemoveTask()`, so no card is left in recents, before the
program returns. SDL then finds the activity finishing and leaves it; the next start
is a fresh process that restores the game. On the Mac the window closes as the program
returns.

## Rules every part keeps

- **No allocation in the frame loop.** Goose gives this through its data stacks. Per-frame
  arrays live in the frame's scope. Long-lived tables, such as the transposition table,
  are sized once at startup (the computer's worker, when it starts). Goose's typed
  queues, which carry the computer's ask and answer, allocate in the runtime: once a
  turn, never per frame.
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
- **The saved game is one flat value** (`shell::Saved`): the screen, the variant, the
  position, where the game began, the last move, the undo history (a limited array),
  the clocks, and the computer's side, level, and skill, if it plays, with the game's
  number for its seeds; written with Goose's `to_bytes` and an FNV-1a checksum after
  it, about 15 KB. `from_bytes` verifies the image's shape and the checksum its bytes; a
  file that fails either, or has another `VERSION`, is ignored and the app starts
  afresh. The pause is seen as the window losing focus: SDL runs the loop once more
  after Android pauses the app before it blocks.
- **Assets are embedded** in the binary (shaders by `embed_shader`, fonts and puzzles as
  data), so no code reads Android's asset manager.
