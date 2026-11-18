# Architecture

How the app works, as it is now. This file holds the stack, how the code is laid out, and
the rules every part of it keeps. [Draughts from above](https://kaitk.github.io/draughts/architecture/) tells the
whole app in plain words: the start-up, the loop, the packages, and the threads. The rest
is by area:

- [rules.md](rules.md): draughts variants and how the engine represents them
- [ai.md](ai.md): the computer player, its search, and how its levels play like a person
- [puzzles.md](puzzles.md): the puzzles, their file, goals, and checks
- [rendering.md](rendering.md): drawing, the UI layer, glass, fonts, and frame pacing
- [sound.md](sound.md): the sounds, the events that play them, and the Volume row

Each decision, with its date, its reason, and what it rejected, is in
[decisions](../decisions/README.md).

## Stack

| Concern | Choice |
| --- | --- |
| Language | [Goose](https://github.com/aardappel/goose), compiled to C (`goose -o game.c`, `goose --emit-runtime`) |
| Graphics, input, window | `gfx` from [goose_gfx](https://github.com/aardappel/goose_gfx): SDL3's GPU API, with GLSL compiled to SPIR-V, MSL, and HLSL at compile time |
| GPU backend | Vulkan on Android, Windows, and Linux, from the SPIR-V compiled with the program; Metal on macOS and iOS |
| Android build | NDK clang for `aarch64-linux-android29`; SDL shared (`libSDL3.so`) with SDL's stock SDLActivity Java and one small subclass of it (`DraughtsActivity`: development flags, the launch cover, closing the app, SDL's accelerometer kept off); APK built by `scripts/android.py` without Gradle ([development](../development.md)) |
| Desktop iteration | `goose game.goose` runs in the compiler's process (TinyCC), with no build step |
| UI | Our own immediate-mode layer in Goose ([rendering.md](rendering.md)); Nuklear (`ui`) for developer tools only |
| Text | TrueType fonts baked by `ui`'s font atlas |

Why Goose, the fallback, and why not goose-ngfx on Android:
[decisions](../decisions/README.md#the-stack).

## What the stack costs against bare C + sokol

- Game code is compiled C with no GC, and frame-loop code allocates nothing.
- goose_gfx makes no texture or target while drawing, but its `update_buffer` allocates
  and frees a small transfer buffer per buffer each drawn frame (three, about 35 KB:
  [GPU memory](rendering.md#gpu-memory)), copying through staging where NoGraphicsAPI
  writes mapped memory.
- Each call passes goose_gfx's checks, then SDL_GPU, then Vulkan: negligible at 10 to 20
  draws a frame.
- The binary carries SDL3, about 2 to 3 MB, against about 0.2 MB for sokol, and SDL owns
  the main loop and the Android lifecycle.
- There is no GLES fallback: devices without a working Vulkan driver can't run the app.

## Code layout

The code is packages with no graphics, each run headless by its tests, and an app that
feeds them the pointer and the time and draws what they leave.

**The program's code is under `src/`**, as the tests are under
`test/`: `src/` holds the packages and the app, one directory each, and the top level
keeps what isn't the program's Goose: `test/`, `strings/` (the text and its loader,
shared with the build scripts), `assets/`, `platform/` (each platform's files the build
takes: Android's manifest and activity, iOS's CMake project, the desktop icons),
`scripts/` (the builds), `tools/` (programs for development, `tools/perf/` for
measuring a device, `tools/assets/` for making assets), `docs/`, and the rest. Below,
`app/` means `src/app/`, and so on.

**The programs are `main/`'s two roots**, and nothing else is there:
`main/draughts.goose`, gfx alone, which Android and Linux ship, and
`main/draughts_ngfx.goose`, the same program holding goose-ngfx too, which macOS, iOS,
and Windows ship. Each declares the packages and picks its renderer's
`backend`; both call `run` in `app/app.goose`. Their `.build` sidecars list the
program's C, all of it in `native/`.

**The rule: only `app/` and the renderers, `gfx/` and `ngfx/`, import `gfx` or call
SDL or the platform**, the platform through the program's C in `native/`. The packages
hand them flat, fixed-size data and take back the pointer and the time; nothing else
(but `platform/` and the build scripts) knows what draws or what it runs on.
One package is drawing code outside these: `render3d/`, the 3D board's renderer, which
the app and `tools/board_shot.goose` (settings' board pictures) share. Its recording (`render3d_gpu`) imports
gfx, and only those two programs import it; no package of the game does. What the 3D board
is but drawing, its meshes, looks, light, and the plan of its bake, is `model3d/`, which
imports no gfx and is tested headless.

**Inside `app/`, the main loop sees two halves of what it runs on**: the
platform, `app/host` (the window, the frame's end and clock, the screen's size and
focus, the pointer, keys and typed text, the screenshot, and the program's C for the
safe area, the wake timer, storage, locales, and Android's launch, back, and close), and
the renderer, `app/render`, which holds every drawer (`draw`, `draw3d`, `scene`,
`widgets`) and, through the renderer's package, every GPU handle. `main` calls these two and nothing of gfx. Each frame it
hands `render::frame` one `render::Frame` of the app's own values: the board as
`board::build_frame_pieces` left it, where it goes, the pieces over the UI, the UI's quads, the 3D
board's view and place, the blur, and the transition's hole; the frame's pass begins and
ends there. The glyphs, the badges, and the season's photograph reach the renderer as
pixels: `text::bake` and `badges::atlas` return R8 bytes, `background.c` decodes into
pixels that the renderer's own C (`photo.c`) uploads, the embedded ASTC blocks with no
copy, and `resize.c` takes the pixels the renderer reads back for a Mac window's cover.
Each drawer is what it draws, renderer-free, and records through a backend it is handed
(`be`): the few calls every drawer makes on it (`be.flush()`, `be.target(...)`) and a
recorder per drawer on its fields (`be.draw`, `be.scene`, `be.widgets`, `be.r3d` for the
3D board, `be.host` for the window). gfx's backend is `gpu::Gfx` (`src/gfx/gpu.goose`)
over `draw_gpu`, `scene_gpu`, `widgets_gpu`, `render3d_gpu`, and `host_gpu`; `photo.c`
uploads the photograph. The drawers are generic over the backend's type, so each call
resolves at compile time to one renderer's recorder. `gfx/` is a package the roots
declare as `gpu`, as `ngfx/` is `gpu_ngfx`: a package can't take the name of goose_gfx's
`gfx` or goose-ngfx's `ngfx`. The one seam is `backend`
([rendering](rendering.md#two-renderers)): `render.goose` and `host.goose` run their
drawers in `backend::with`, and `backend::open` opens the window. The gfx build's root
(`src/main/draughts.goose`) takes `src/gfx/backend.goose`, gfx's alone;
`src/main/draughts_ngfx.goose`, a second root over the same program (`src/app/app.goose`),
adds goose-ngfx's backend (`gpu_ngfx::Ngfx`, `src/ngfx/`'s `_ngfx` recorders,
`photo_ngfx.c`, and `nx`, which gives goose-ngfx's calls gfx's handle types) and its own
`backend.goose`, whose `open` chooses: `--renderer gfx`, `ngfx`, or `auto`, each
platform's first choice; for ngfx a windowless check (`renderer.c`), then ngfx in a
hidden window of gfx's, gfx alone if that fails, and a marker that sends the next start
to gfx if ngfx never presented a frame on this GPU, driver, and app. ngfx's shaders are
gfx's GLSL written as Slang at each build (`scripts/ngfx_2d_shaders.py`,
`ngfx_3d_shaders.py`), so each has one source; `src/ngfx/shaders/` holds only what they
include, ngfx's own antialiasing and mip passes, and SMAA's wrapper. The scripts of
macOS, iOS, and Windows build that root by default, and the gfx root with `--gfx-only`.

The targets this keeps open, each replacing or adding to `app/` and the renderers alone:

- **The 3D board** ([rendering](rendering.md#board-and-pieces)): drawn by `render3d/` from `app/`; what the board needs
  of it, the camera and its fit into the layout, a tap turned into a square by a ray
  through the perspective, and each frame's instances, stays plain math in `board/`
  (`view3d`), tested headless.
- **Other platforms on SDL:** iOS (UIKit, SDL_GPU on Metal; `platform/ios/` and
  `scripts/ios.py`, [development](../development.md#run-on-ios)), and desktop Windows and Linux (SDL_GPU on
  Vulkan, on Linux in a Wayland window, or X11's without Wayland; built by
  `scripts/windows.py` and `scripts/linux.py`, which builds SDL itself): a build script and shims beside the Android ones (storage, locales, the
  launch cover, closing). On iOS the program's C calls SDL directly as on Android
  (`src/native/platform.h`), `draughts_platform` tells the app where it runs, home has no
  way out (`home::closable`), and nothing is drawn while the app hasn't focus: iOS ends
  an app that uses the GPU in the background, and SDL doesn't block the loop there.
- **A second renderer**, the NoGraphicsAPI version through goose-ngfx on desktop and
  Apple devices that support it ([product](../product.md)): its recorders in `src/ngfx/`,
  a second root beside the gfx build's, the packages and the drawers shared.
- **Chess** ([product](../product.md)): new rules and board packages beside these,
  reusing `gui/`, `shell/`'s screens, and `app/` as they are.

| Directory | What it holds |
| --- | --- |
| `src/rules/` | The rules as pure functions over values: variants as data, positions, legal moves, playing a move, FEN, the square at a column and row, the draws, and a game's record (where it began and the position before each move) ([rules.md](rules.md)) |
| `src/ai/` | The computer player over `rules`: a search sliced into steps, its levels and skill, a played move judged, and the ratings ([ai.md](ai.md)) |
| `src/puzzles/` | The puzzles as plain text read into a fixed table, and the exact search that says whether a move solves one ([puzzles.md](puzzles.md)) |
| `strings/` | The user-facing text by key, from `strings/<lang>.txt` |
| `src/gui/` | The UI layer ([rendering.md](rendering.md#ui-layer)): rect cuts and `stack`, widgets with their press state, text laid out from glyph tables the app bakes; every call appends quads to one fixed array |
| `src/board/` | The board on screen: the position, the legal moves, and the game's record (`rules::Record`); where the board goes and which square a point is on; taps and drags; a move's animation and the sound events it reports (`sound_event`); and each frame's draw lists (pieces, the squares' marks, a wrong move's flash); the 3D board's camera, its fit on screen, picking through its perspective, and its instances (`view3d`); the panels and where they and the board go on every screen with a board (`panel::layout`, round the 3D board `panel::corners_in`, each a `Layout` with its mode: landscape, corners, portrait, or compact) |
| `src/game/` | The game screen: its panels declared (`panel::game`, with what its clocks show, `game::clocks`), the clocks, the computer's turn (asking for a move and playing the answer), the celebration, the moves as played with their marks and their panel (`notes.goose`), and the pieces it puts over the UI |
| `src/shell/` | The screens and which one shows: home and a new game's setup with the board of the game it starts, the game, settings with their preview board, the puzzles to pick from and the puzzle playing ([puzzles.md](puzzles.md#the-screen)); the pieces the screen showing puts over the UI (`Frame.ui_pieces`, which the app draws); who's playing over home and a player's sheet; the players, their settings files, their saved games, and their games played with the results screen |
| `src/model3d/` | The 3D board but its drawing, with no graphics: the meshes, the themes as data (`looks`), the photograph's light as spherical harmonics, the plain fade's ambient, and the plan of a theme's bake in steps |
| `src/render3d/` | The 3D board's renderer, shared by the app and `tools/board_shot.goose`: its shaders, the meshes and surfaces on the GPU, the surfaces' bake, the photograph's blur, the shadow map, and the multisampled pass ([rendering.md](rendering.md#board-and-pieces)) |
| `src/sound/` | The sounds ([sound.md](sound.md)): the recorded hits decoded from IMA ADPCM, the rest synthesized, made into goose_gfx's mixer only while the volume is above zero, and played by one call; the events that play them are the board's (`board/sound_event.goose`) |
| `src/badges/` | The players' animal badges: their SVGs from `assets/badges/` baked at startup into a distance-field atlas |
| `src/app/` | The app: the main loop, the platform (`host`), the renderer (`render`) and its drawers of the board, the pieces, the UI's quads, the season's photograph and its blurs, and the 3D board, the font atlas, the themes, the computer's worker thread, the development flags, and the bench |
| `src/gfx/` | gfx's backend (`gpu::Gfx`): the drawers' recorders through gfx (`draw_gpu`, `scene_gpu`, `widgets_gpu`), the window's GPU half (`host_gpu`), and the gfx build's `backend` |
| `src/ngfx/` | goose-ngfx's backend (`gpu_ngfx::Ngfx`): its recorders, `nx`, its hand-written shaders, and the `backend` that chooses a renderer at start |
| `src/native/` | The program's C: the storage folder, locales, the safe area and the display, the clock's wake timer, the launch and closing, the JPEG decoder and the photograph's upload to each renderer, and the renderer check |
| `src/main/` | The two programs' roots and their sidecars |
| `tools/` | Programs for development: perft, the computer's benchmark and matches, a terminal game against it, and the puzzles' checks; device measurements in `tools/perf/` and asset makers in `tools/assets/` |

`ai`, `board`, and `puzzles` build on `rules`, `board` also on `gui`'s pointer
(`board::touch`) and on `model3d`'s measures of the 3D board (`mesh::FIELD`.., which
`view3d` picks through); `game` on `board`, `gui`, `strings`, and `ai`'s lookout
(`game::watch`); `shell` on `game` and `ai`; `render3d` on `model3d` and nothing of the
game's; the app on all of them. What crosses to the renderer (`render::Frame`) is flat
and fixed-size, laid out as the shaders read it: `board::Piece`, `board::Marks`, the
flash, `board::Layout`, `gui::Quad`, and `theme::Theme`; to the 3D board,
`view3d::Scene` and `view3d::View`'s matrix.

### A frame

`run` (`src/app/app.goose`) is one loop on every platform
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
   (`shell::build_frame_pieces`) fills its draw lists, and `render::frame` draws the frame: first what
   can't run inside the screen's pass (the UI's quads copied or kept, the 3D board's
   image when its scene changed, the pieces' buffers), then the pass: the photograph and
   the squares, the pieces, the UI's quads, then the pieces over the UI; on the 3D board
   the photograph and its image in place of the squares and pieces. Otherwise nothing is
   drawn, and the next frame waits for input. `host::frame` presents it.
6. While a clock runs, a timer is set for when the time it shows changes.

The development flags are `src/app/dev.goose`: those that set up the shell at launch
(`dev::setup`), and those that act while the loop runs (`--tap`, `--go`, `--win`,
`--hold`, `--bench`, `--rest`, `--frames`), which the loop calls at fixed points of a
frame; with none of them given, its calls do nothing. `--bench` draws each frame through
`bench::frame` (`src/app/bench.goose`) in place of `render::frame`, so the drawing holds
no measuring.

Android's back (the gesture or the button) and Escape on the Mac go back a screen, as
the screen's own back or home control does (`shell::back`): a setup to home's menu, the
game, settings, and the puzzles to pick from where their tile goes, a puzzle to the
puzzles. On home's menu, which has no way back, back puts the app in the background with the
activity kept (`draughts_leave`, `DraughtsActivity.leaveApp`, `moveTaskToBack`), and
Escape ends the loop. Back reaches the program as SDL's "AC Back" key: up to Android 12
through SDL's key handling, from Android 13 through an `OnBackInvokedCallback` in
`DraughtsActivity` (the manifest sets `enableOnBackInvokedCallback`, as Android 16
requires) ([why](../decisions/README.md#the-apps-lifecycle)).

The loop ends on Escape on home's menu or when home's X sets `Frame.quit`. The game is
written; after home's X on Android the program calls `DraughtsActivity.closeApp()` over
JNI (`src/native/launch.c`), which finishes the activity with `finishAndRemoveTask()`, so
no card is left in recents. The next start is a fresh process that restores the game.

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
  embedded file, so looking one up allocates nothing. The keys and their constants are
  generated from `en.txt` in its order (`scripts/strings_keys.py` writes
  `strings/keys.goose`, and `scripts/test.sh` fails while it is stale), so a new string is
  a line in `en.txt` and the script run. English is the default and fills in
  any key a translation lacks. The language is the first of the system's preferred
  locales (`src/native/locale.c`) that has a file, else English. A language is a new file
  plus its code in `strings::LANGUAGES`; `test/strings/` fails on a key missing from any
  file.
- **Kept in the app's storage folder** (SDL's pref path, through `src/native/storage.c`), per
  player ([players](#players)): the settings as a small `key = value` file
  (`player-N.txt`, `src/shell/prefs.goose`), written whole and atomically after a change;
  and the game as it stands, `game-N.bin`, written when the app is paused or quits,
  since Android may kill a paused app, and before another player plays. The device's
  own keys are in `settings.txt`. All are read at start. Nothing is written while idle.
- **The saved game is one flat value** (`shell::Saved`): the screen, the variant, the
  position, the last move, the game's record (where it began and the undo history, a limited array),
  the clocks, and the computer's side, level, and skill, if it plays, with the game's
  number for its seeds, and whether anyone set the game up (home's Continue); written
  with Goose's `to_bytes` and an FNV-1a checksum, about 15 KB. While a game played from
  a replay shows, the game it set aside is the one written (`shell::Parked`). A file
  whose shape, checksum, or `VERSION` fails is ignored and the app starts afresh. The
  pause is seen as the window losing focus: SDL runs the loop once more after Android
  pauses the app.
- **Assets are embedded** in the binary (shaders by `embed_shader`, fonts and puzzles as
  data), so no code reads Android's asset manager.

## Players

Up to four players share one tablet, local only: no accounts, no network, no passwords. A player is a badge, an optional name of up to 12 characters, and
what a child makes their own; the rest belongs to the device.

| Kept | Per player | Per device |
| --- | --- | --- |
| Badge (one of six, each its own colour; one a player has isn't offered to another) and name | yes | |
| Look: theme (and photograph or plain), kings, board; move hints | yes | |
| A new game's setup: the opponent (a friend, or the computer's level), draughts, colour or turning, clock | yes | |
| The computer's skill per level and the games against it | yes | |
| The games played, the rating by draughts, and the moves panel's setting | yes | |
| Puzzle stars | yes | |
| The game in progress | yes | |
| The first start done (not built yet: only the flag) | yes | |
| Language, and which player is playing | | yes |

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
  the moves in PDN, and the best move from the position before each as the judge found
  it (`best=`, `-` for an only move or one not judged; older lines have none), for the
  replay. A game is written when it ends, and its line again once its last moves are
  judged (`src/shell/record.goose`). The player's file keeps `moves =
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

**At start**, when `settings.txt` has no `player` key, its keys become `player-1.txt`
with the fox and no name, `game.bin` becomes `game-1.bin`, and `settings.txt` is
rewritten with `language` and `player = 1` last, so a kill at any point loses nothing
(`test/shell/players`). A fresh install starts the same way and opens on its one
player's sheet, so the child picks a badge.
