# Architecture

How the app works, as it is now. This file holds the stack, how the code is laid out, and
the rules every part of it keeps. [Draughts from above](index.html) tells the
whole app in plain words: the start-up, the loop, the packages, and the threads. The rest
is by area:

- [rules.md](rules.md): draughts variants and how the engine represents them
- [ai.md](ai.md): the computer player, its search, and how its levels play like a person
- [puzzles.md](puzzles.md): the puzzles, their file, goals, and checks
- [rendering.md](rendering.md): drawing, the UI layer, glass, fonts, and frame pacing

Each decision, with its date, its reason, and what it rejected, is in
[decisions](../decisions/README.md).

## Stack

| Concern | Choice |
| --- | --- |
| Language | [Goose](https://github.com/aardappel/goose), compiled to C (`goose -o game.c`, `goose --emit-runtime`) |
| Graphics, input, window | `gfx` from [goose_gfx](https://github.com/aardappel/goose_gfx): SDL3's GPU API, with GLSL compiled to SPIR-V, MSL, and HLSL at compile time |
| GPU backend | Vulkan on Android and Windows; Metal on macOS and iOS. Windows takes the SPIR-V compiled with the program, as Android does |
| Android build | NDK clang for `aarch64-linux-android29`; SDL shared (`libSDL3.so`) with SDL's stock SDLActivity Java and one small subclass of it (`DraughtsActivity`: development flags, the launch cover, closing the app, SDL's accelerometer kept off); APK built by `scripts/android.py` without Gradle ([development](../development.md)) |
| Desktop iteration | `goose game.goose` runs in the compiler's process (TinyCC), with no build step |
| UI | Our own immediate-mode layer in Goose ([rendering.md](rendering.md)); Nuklear (`ui`) for developer tools only |
| Text | TrueType fonts baked by `ui`'s font atlas |

Why Goose, the fallback, and why not goose-ngfx on Android:
[decisions](../decisions/README.md#the-stack).

## What the stack costs against bare C + sokol

From goose_gfx's source:

- Game code is compiled C with no GC and no heap, and frame-loop code allocates nothing.
- goose_gfx's `realloc`s run only when handle tables grow, and no texture or target is
  made or released while drawing. Its `update_buffer` does allocate and free a small
  transfer buffer per buffer each drawn frame (three, about 35 KB:
  [GPU memory](rendering.md#gpu-memory)).
- Each call passes through goose_gfx's handle and misuse checks, then SDL_GPU, then
  Vulkan. With 10 to 20 draws a frame, the cost is negligible.
- `update_buffer` copies through staging, where NoGraphicsAPI writes mapped memory
  directly. That's a few KB a frame.
- The binary carries SDL3, about 2 to 3 MB, against about 0.2 MB for sokol.
- SDL owns the main loop and the Android lifecycle.
- There is no GLES fallback: devices without a working Vulkan driver can't run the app.

## Code layout

The code is packages with no graphics, each run headless by its tests, and an app that
feeds them the pointer and the time and draws what they leave.

**The program's code is under `src/`**, as the tests are under
`test/`: `src/` holds the packages and the app, one directory each, and the top level
keeps what isn't the program's Goose: `test/`, `tools/`, `strings/` (the text and its
loader, shared with the build scripts), `assets/`, `android/`, `scripts/`, `docs/`, and
the rest. Below, `app/` means `src/app/`, and so on.

**The rule: only `app/` imports `gfx` or calls SDL or the platform.** The
packages hand it flat, fixed-size data and take back the pointer and the time; nothing
outside `app/` (and `android/`, the build scripts) knows what draws or what it runs on.
One package is drawing code outside `app/`: `render3d/`, the 3D board's renderer, which
the app and the 3D prototype (`poc/3d/`) share. Its recording (`render3d_gpu`) imports
gfx, and only those two programs import it; no package of the game does. What the 3D board
is but drawing, its meshes, looks, light, and the plan of its bake, is `model3d/`, which
imports no gfx and is tested headless.

**Inside `app/`, the main loop sees two halves of what it runs on**: the
platform, `app/host` (the window, the frame's end and clock, the screen's size and
focus, the pointer, keys and typed text, the screenshot, and the program's C for the
safe area, the wake timer, storage, locales, and Android's launch, back, and close), and
the renderer, `app/render`, which holds every drawer (`draw`, `draw3d`, `scene`,
`widgets`) and every GPU handle. `main` calls these two and nothing of gfx. Each frame it
hands `render::frame` one `render::Frame` of the app's own values: the board as
`board::fill` left it, where it goes, the pieces over the UI, the UI's quads, the 3D
board's view and place, the blur, and the transition's hole; the frame's pass begins and
ends there. The glyphs, the badges, and the season's photograph reach the renderer as
pixels: `text::bake` and `badges::atlas` return R8 bytes, `background.c` decodes into
pixels that the renderer's own C (`photo.c`) uploads, the embedded ASTC blocks with no
copy, and `resize.c` takes the pixels the renderer reads back for a Mac window's cover.
Each drawer is what it draws, renderer-free, and its recording, a `_gpu` file per
renderer: `scene_gpu`, `draw_gpu`, `widgets_gpu`, `host_gpu` (opening the window,
presenting, the screenshot), `render3d_gpu` (a second file in namespace `render3d`), and
`photo_gpu.h` for `photo.c`; `gpu` names the renderer's handle types and the few calls
the drawers make themselves. gfx's are in `src/app/` and `src/render3d/`. goose-ngfx's
are in `src/ngfx/`, which `scripts/ngfx.py` lays over them, for a build that draws
through NoGraphicsAPI. Its shaders are gfx's GLSL written as Slang at each build
(`scripts/ngfx_2d_shaders.py` and `ngfx_3d_shaders.py`), so each shader has one source,
and compiled ahead; `src/ngfx/shaders/` holds in Slang only what they include, the
antialiasing and mip passes ngfx alone has, and SMAA's wrapper. The gfx build is what
ships.

The targets this keeps open, each replacing or adding to `app/` alone:

- **The 3D board** ([rendering](rendering.md#board-and-pieces)): drawn by `render3d/` from `app/`; what the board needs
  of it, the camera and its fit into the layout, a tap turned into a square by a ray
  through the perspective, and each frame's instances, stays plain math in `board/`
  (`view3d`), tested headless.
- **Other platforms on SDL:** iOS (UIKit, SDL_GPU on Metal; `ios/` and
  `scripts/ios.py`, [development](../development.md#run-on-ios)), and desktop Windows and Linux (SDL_GPU on
  Vulkan, on Linux in a Wayland window, or X11's without Wayland; built by
  `scripts/windows.py` and `scripts/linux.py`, which builds SDL itself): a build script and shims beside the Android ones (storage, locales, the
  launch cover, closing). On iOS the program's C calls SDL directly as on Android
  (`src/app/platform.h`), `draughts_platform` tells the app where it runs, home has no
  way out (`home::closable`), and nothing is drawn while the app hasn't focus: iOS ends
  an app that uses the GPU in the background, and SDL doesn't block the loop there.
- **A second renderer**, the NoGraphicsAPI version through goose-ngfx on desktop and
  Apple devices that support it ([product](../product.md)): its recorders in `src/ngfx/`,
  a build option today, the packages and the drawers unchanged.
- **Chess** ([product](../product.md)): new rules and board packages beside these,
  reusing `gui/`, `shell/`'s screens, and `app/` as they are.

| Directory | What it holds |
| --- | --- |
| `src/rules/` | The rules as pure functions over values: variants as data, positions, legal moves, playing a move, FEN, and the square at a column and row ([rules.md](rules.md)) |
| `src/ai/` | The computer player over `rules`: a search sliced into steps, its levels and skill, a played move judged, and the ratings ([ai.md](ai.md)) |
| `src/puzzles/` | The puzzles as plain text read into a fixed table, and the exact search that says whether a move solves one ([puzzles.md](puzzles.md)) |
| `strings/` | The user-facing text by key, from `strings/<lang>.txt` |
| `src/gui/` | The UI layer ([rendering.md](rendering.md#ui-layer)): rect cuts and `stack`, widgets with their press state, text laid out from glyph tables the app bakes; every call appends quads to one fixed array |
| `src/board/` | The board on screen: the position, the legal moves, and the undo history; where the board goes and which square a point is on; taps and drags; a move's animation; and each frame's draw lists (pieces, the squares' marks, a wrong move's flash); the 3D board's camera, its fit on screen, picking through its perspective, and its instances (`view3d`) |
| `src/game/` | The game screen: its panels and where they and the board go (`panel::layout`, round the 3D board `panel::corners_in`, each a `Layout` with its mode: landscape, corners, portrait, or compact), the clocks, the computer's turn (asking for a move and playing the answer), the celebration, the moves as played with their marks and their panel (`notes.goose`), and the pieces it puts over the UI |
| `src/shell/` | The screens and which one shows: home and a new game's setup with the board of the game it starts, the game, settings with their preview board, the puzzles to pick from and the puzzle playing ([puzzles.md](puzzles.md#the-screen)); the pieces the screen showing puts over the UI (`Frame.over`, which the app draws); who's playing over home and a player's sheet; the players, their settings files, their saved games, and their games played with the results screen |
| `src/model3d/` | The 3D board but its drawing, with no graphics: the meshes, the themes as data (`looks`), the photograph's light as spherical harmonics, the plain fade's ambient, and the plan of a theme's bake in steps |
| `src/render3d/` | The 3D board's renderer, shared by the app and `poc/3d/`: its shaders, the meshes and surfaces on the GPU, the surfaces' bake, the photograph's blur, the shadow map, and the multisampled pass ([rendering.md](rendering.md#board-and-pieces)) |
| `src/badges/` | The players' animal badges: their SVGs from `assets/badges/` baked at startup into a distance-field atlas |
| `src/app/` | The program: the main loop, the platform (`host`), the renderer (`render`) over the GPU drawing of the board, the pieces, and the UI's quads, the season's photograph and its blurs, the font atlas, the themes, the computer's worker thread, and its C (storage folder, locales, the clock's wake timer, the JPEG decoder and the photograph's upload) |
| `tools/` | Programs for development: perft, the computer's benchmark and matches, a terminal game against it, and the puzzles' checks |

`ai`, `board`, and `puzzles` build on `rules`, `board` also on `gui`'s pointer
(`board::touch`); `game` on `board`, `gui`, `strings`, and `ai`'s lookout
(`game::watch`); `shell` on `game` and `ai`; `render3d` on `model3d` and nothing of the
game's; the app on all of them. What crosses to the renderer (`render::Frame`) is flat
and fixed-size, laid out as the shaders read it: `board::Piece`, `board::Marks`, the
flash, `board::Layout`, `gui::Quad`, and `theme::Theme`; to the 3D board,
`view3d::Scene` and `view3d::View`'s matrix.

### A frame

`src/app/draughts.goose` runs one loop on every platform
([rendering.md](rendering.md#frames-and-battery)):

1. The window (`host`): when it loses focus the game is written (Android may kill a
   paused app), and on Android the clocks pause; a new season's photograph loads two
   frames after its tile was tapped; the text is baked again if the scale changed
   (`render::upload_text`).
2. The app tells the shell what only it knows, whether the 3D board is ready and shown,
   after asking it whether the 3D board is wanted, kept, or to be dropped
   (`shell::board3d`). `gui::begin` takes the pointer and the time, and `shell::frame`
   declares the screen showing. Its widgets append quads and its pieces over the UI go
   into the frame's list; a press that lands on the UI is the UI's, and only otherwise
   does the game screen hand the pointer to `board`. The game's and a puzzle's frames
   return an event (where to go, a game ended or started over, a puzzle solved), which
   the shell acts on; the settings are put where they act by one `shell::apply_prefs`,
   when they change or a game starts. The shell's frame leaves what the app needs in a
   `shell::Frame`, which the app reads and never writes: whether anything changed, where
   the board is and how the 3D board shows, the blur, the pieces over the UI, the
   keyboard, and whether to save the settings.
3. `think::frame` hands the computer's worker the game's ask, and the game its answer.
   It comes after the shell's frame, so a game the shell started over this frame is asked
   at the skill the shell gave it.
4. After a change in settings (`Frame.save`): the file is written, the language
   switched, and a new season's photograph scheduled.
5. If anything changed or still moves (`shell::animating`), the board the screen shows
   (`shell::fill`) fills its draw lists, and `render::frame` draws the frame: first what
   can't run inside the screen's pass (the UI's quads copied or kept, the 3D board's
   image when its scene changed, the pieces' buffers), then the pass: the photograph and
   the squares, the pieces, the UI's quads, then the pieces over the UI; on the 3D board
   the photograph and its image in place of the squares and pieces. Otherwise nothing is
   drawn, and the next frame waits for input. `host::frame` presents it.
6. While a clock runs, a timer is set for when the time it shows changes.

The development flags are `src/app/dev.goose`: those that set up the shell at launch
(`dev::setup`), and those that act while the loop runs (`--tap`, `--go`, `--win`,
`--hold`, `--bench`, `--rest`, `--frames`), which the loop calls at fixed points of a
frame; with none of them given, its calls do nothing.

Android's back (the gesture or the button) and Escape on the Mac go back a screen, as
the screen's own back or home control does (`shell::back`): a setup to home's menu, the
game, settings, and the puzzles to pick from where their tile goes, a puzzle to the
puzzles. On home's menu, which has no way back, back leaves the app as the system's back
does, putting it in the background with the activity kept (`draughts_leave`,
`DraughtsActivity.leaveApp`, `moveTaskToBack`), and Escape ends the loop. Back reaches
the program as SDL's
"AC Back" key: up to Android 12 through SDL's own key handling, from Android 13 through
an `OnBackInvokedCallback` in `DraughtsActivity` that hands it to SDL, the manifest
opting into back callbacks (`enableOnBackInvokedCallback`), as Android 16 does for an app
targeting it, where the key is no longer dispatched
([why not SDL's way](../decisions/README.md#the-apps-lifecycle)).

The loop ends on Escape on home's menu or when home's X asks the shell to stop
(`Frame.quit`). The game is then written as at any loop's end; after home's X, on Android the program
calls `DraughtsActivity.closeApp()` over JNI (`src/app/launch.c`), which finishes the
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
  of positions; saving is writing the value. The draw counts are folded over that stack
  when the position changes, so undo and a saved game bring them back with nothing more
  kept.
- **Strings by key.** Every user-facing string comes from `strings/<lang>.txt`
  (`key = text` per line), built into the program with `embed_file`. Code names a string
  by its constant (`strings::HOME_CONTINUE`) and `strings::get` returns a view into the
  embedded file, so looking one up allocates nothing. English is the default and fills in
  any key a translation lacks; Estonian is `et.txt`. The language is the first of the
  system's preferred locales (SDL's, through `src/app/locale.c`) that has a file, else
  English. A language is a new file plus its code in `strings::LANGUAGES`;
  `test/strings/` fails on a key missing from any file. Kids who can't read get icons,
  and later voice clips keyed the same way.
- **Kept in the app's storage folder** (SDL's pref path, through `src/app/storage.c`), per
  player ([players](#players)): the settings as a small `key = value` file
  (`player-N.txt`, `src/shell/prefs.goose`), written whole and atomically after a change;
  and the game as it stands, `game-N.bin`, written when the app is paused or quits,
  since Android may kill a paused app, and before another player plays. The device's
  own keys are in `settings.txt`. All are read at start. Nothing is written while idle.
- **The saved game is one flat value** (`shell::Saved`): the screen, the variant, the
  position, where the game began, the last move, the undo history (a limited array),
  the clocks, and the computer's side, level, and skill, if it plays, with the game's
  number for its seeds, and whether anyone set the game up (home's Continue); written with Goose's `to_bytes` and an FNV-1a checksum after
  it, about 15 KB. `from_bytes` verifies the image's shape and the checksum its bytes; a
  file that fails either, or has another `VERSION`, is ignored and the app starts
  afresh. The pause is seen as the window losing focus: SDL runs the loop once more
  after Android pauses the app before it blocks.
- **Assets are embedded** in the binary (shaders by `embed_shader`, fonts and puzzles as
  data), so no code reads Android's asset manager.

## Players

Up to four players share one tablet, local only: no accounts, no network, no passwords. A player is a badge, an optional name of up to 12 characters, and
what a child makes their own; the rest belongs to the device.

| Kept | Per player | Per device |
| --- | --- | --- |
| Badge (one of six, each its own colour; one a player has isn't offered to another) and name | yes | |
| Look: theme (and photograph or plain), kings, board; move hints | yes | |
| A new game's setup: draughts, level, colour, clock | yes | |
| The computer's skill per level and the games against it | yes | |
| The games played, the rating by draughts, and the moves panel's setting | yes | |
| Puzzle stars | yes | |
| The game in progress | yes | |
| The first start done (not built yet: only the flag) | yes | |
| Language, and which player is playing | | yes |

The game in progress is the player's so continue means "my game": switching to a
sibling never replaces a game against the computer. The computer's skill is the
player's, or `ai::adapt` would follow neither child. Language is the device's: the
parent sets it once.

**The files** (`src/shell/players.goose`; the shell's changes to the list in
`roster.goose`, the saved game in `saved.goose`), one per player rather than sections in one file,
so a change rewrites only that player's and no section parser is needed:

- `settings.txt`: the device's keys, `language` and `player = N`, the playing player's id.
- `player-N.txt`, N the id from 1 to 4: `picture = fox` (the badge's name), `name = Mia`
  if there is one, `first_start = done` once had, then the keys `src/shell/prefs.goose`
  writes. Players show in the order of their ids; a new player takes the lowest free id.
- `game-N.bin`: the player's saved game, as `shell::save` writes it.
- `history-N.txt`: the player's finished games, a line each, oldest first, at most 200
  (`src/shell/history.goose`): tab-separated `key=value` fields, the time, the draughts,
  the opponent (the computer's level and skill, or a friend), the player's side, the
  winner, the rating before and after, each side's accuracy, a digit a move for its mark,
  and the moves in PDN. A game is written when it ends, and its line again once its last
  moves are judged (`src/shell/record.goose`). The player's file keeps `moves =
  hidden|list|marks` and, per draughts with rated games, `rating.<draughts>` and
  `rated.<draughts>`.

Each is written whole and atomically. Starting a player again deletes their game and
their games played and clears their stars, the computer's skill, the games against it,
and the rating, keeping the badge,
the name, the look, and the setup. Removing deletes their game, then their settings, so
one killed halfway is left as one started again. The last player can't be removed;
removing the one playing makes the first left play.

In memory the shell holds the playing player's settings and, for every player, only the
id, badge, and name, in a fixed table of four read at start. Switching writes the
leaving player's settings and game and reads the other's: one small file and one game on
a tap, never while idle; the photograph loads two frames later as for a season's tile.

**Migration**, at start, when `settings.txt` has no `player` key: its keys become
`player-1.txt` with the fox and no name (the first start marked done), `game.bin` is
renamed `game-1.bin`, then `settings.txt` is rewritten with `language` and `player = 1`.
Until that last write the next start migrates again from the same keys, and each step
done again does the same, so a kill at any point loses nothing (`test/shell/players`).
A fresh install, with no `settings.txt`, starts the same way, and its first run opens on
its one player's sheet, so the child picks a badge; later starts never do.
