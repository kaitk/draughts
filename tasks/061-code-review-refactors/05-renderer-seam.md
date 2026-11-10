# 05: Stage 4, the renderer seam

Status: done (2026-11-10)

Stage 3 (`04-layout.md`) first. What the app shows doesn't change. This is the seam
that task 060 (shared blocks for chess) and a later goose-ngfx renderer build on. It is
worth having even without either.

## First: review stage 3's departures

Stage 3 (`04-layout.md`, "Outcome") left five places where it didn't do what its file
asked. The user wants each one reviewed before this stage starts. For each, read the
code and decide whether the choice holds or an alternative is better. Ask the user
before changing an expected output or what the app shows. Record each verdict here.

1. **`shell::still` still runs the screen's frame.** The file said it declared the
   screen left only to learn where the board goes; in fact `shell::blend` fades those
   quads out, so the screen left is drawn. The transition's frame time wasn't measured
   for that reason; the shell's frame was timed headless instead. The alternatives: a
   cheaper still declaration (the layout plus only what shows faded), or dropping the
   fade-out, which changes what the app shows.
2. **The rects that change with the game aren't in `panel::Layout`.** The layout holds
   what doesn't change (the bar's tiles' room, `stacked`, what each side has taken); the
   clocks, the eye, the hint, and undo move come per frame from `way_out` and the three
   `*_play` functions, as `Out` and `Play`. The alternative: fill them into the layout
   each frame before `game()`, which needs the game's state and the faces where the
   shell builds the layout.
3. **`game()` was split by layout, not by declaring.** One function per mode works out
   the regions; one declaring sequence serves all three, with `turn_words` choosing the
   words' look by mode. The alternative: a declaring function per mode as well, repeating
   the clocks, the piece, and the controls three times.
4. **`gui::stack` is used in fewer places than listed.** Home's menu and settings'
   landscape column use it. Settings' side-by-side groups keep their cuts (the stack
   changed a printed position in its last decimals), one group at a time keeps them (a
   cut clamps a glass taller than its room), and the rows, the cards, and the picker's
   grid don't use it. The alternatives: re-bless the outputs the stack moves by a last
   bit, or give the stack a cut's clamp.
5. **`settings::layout` writes `s.name_w` and `s.slim`.** It is pure but for those two,
   which the rows read through `s`. The alternative: return them in the `Page` and pass
   them down to `rows_at`, `group_width`, `group_height`, and the tiles.

### Verdicts

Read at `665257c`, 2026-11-10.

1. **Holds.** `declare` puts the screen left's quads at `first..middle` and `blend`
   fades and drifts them out under the screen come to: everything `still` declares
   shows. A cheaper declaration would leave out only what is already invisible, which is
   nothing, and dropping the fade changes what the app shows. The cost is about 28 µs a
   frame for the 0.25 s of a transition.
2. **Holds.** `Out` and `Play` are the per-frame regions, worked out by pure functions
   from the `Layout` and what shows (`Shows`, `Words`); the `Layout` holds what doesn't
   change with the game. Filling them into the `Layout` would make the shell, which
   builds it, measure the panel's words and read the clocks, the countdown, and a draw:
   the game's state crossing back into the layout for no gain.
3. **Holds.** The modes differ in where things go, not in what is declared or in what
   order. One declaring sequence keeps one order of quads for all three; a declaring
   function per mode would repeat the clocks, the piece, and the controls three times.
4. **Holds.** Re-blessing would change expected outputs, which this task keeps
   byte-identical, for a last-bit difference no one sees; a cut's clamp would make the
   stack a second cut API. The rows' heights are known only once their tiles wrap, the
   cards share `card_size` and `card_at`, and the picker is a grid: a stack adds nothing
   there.
5. **Changed.** Two layout results in the player's `Settings`, written by `layout` and
   read through `s` by the rows, were the side channel stage 2 removed elsewhere.
   `settings::Fit` (the names' width and the slim tiles) is now in the `Page`, and
   `rows_at`, `group_width`, `group_height`, `lay`, the tiles, and the switch take it;
   `layout` changes nothing. Every expected output is byte-identical.

## The seam

The game packages are already clean. The flat structs that cross to the renderer are
laid out as the shaders read them:

- `gui::Quad`
- `board::Piece` and `board::Marks`
- `board::Layout`
- `theme::Theme`
- `view3d::Scene`

The app has no seam:

- gfx is both the platform layer (window, input, time, focus) and the renderer, and
  `main` calls both halves directly.
- `draw::frame` and `draw3d::frame` begin the screen pass (`draw.goose:523`), while
  `main` ends it (`draughts.goose:400`) and flushes it (`:406`).
- The draw sequence at `draughts.goose:383–400` is the real renderer, spread over five
  calls.
- gfx handles live in the app's state: `draw::Drawer`, `scene::Scene`,
  `text::Text.texture`, and `Widgets`, plus `w.atlas = t.texture` and
  `w.thumbs = scene::thumbs(…)`.
- `background.c` (48, 151–159) and `resize.c` (80, 94) call goose_gfx's C texture
  functions directly.

## Steps

1. **`app/host.goose`** (about half a day). Every platform call moves out of `main`:
   - open the window;
   - `frame`, `frame_count`, `time`, `screen_size`, `focused`;
   - the pointer and the events;
   - the keys and text input;
   - the screenshot.

   It wraps gfx as it is now. `wake.c`'s and `display.c`'s SDL calls stay as they are,
   since they work under any renderer.
2. **`app/render.goose`** (about a day). It holds every Drawer (`draw`, `draw3d`,
   `widgets`, `scene`, `text`'s texture) and has:
   - `render::new(kind, plain)` and `reload`;
   - `upload_text`, `upload_badges`, and `thumbs`;
   - `render::frame(FrameData)`, which owns the pass's begin and end;
   - `drop_3d` and `release`;
   - the lost device, which shows today as `frame()` returning false (goose_gfx patch
     0006).

   `FrameData` holds plain values, passed by reference:
   - the shown board's pieces, marks, and flash;
   - the `Layout` and the pieces over the UI;
   - the quads slice and the theme;
   - the 3D scene and its matrix;
   - blur, hole, tall, place, and fade;
   - now and the size.

   After this, `main` calls no gfx drawing function.
3. **Pixels from C** (about a day):
   - `background.c` returns pixels and their format, and the renderer uploads them.
   - `resize.c` takes pixels instead of reading a gfx texture back.
   - Text and badges hand over R8 bytes; `text.goose` already builds them.
   - **Watch the season photograph's load**, 80 to 95 ms on the tablet today. It must not
     gain a copy. It is timed with the task's end measurement (`README.md`).
4. **Split `render3d`** (about half a day). Its gfx-free half moves to its own file or
   package:
   - `mesh`
   - `looks`
   - `harmonics`
   - the theme bake's planning

   The half that calls gfx keeps the rest.
5. **Docs.** Record the seam in `docs/architecture/README.md` ("Code layout", "A
   frame") and in `rendering.md`.

Leave alone:

- `view3d`'s matrix, which is column-major for SDL_GPU's clip space; a later renderer
  converts it on its own side;
- the GLSL;
- `render3d`'s internals beyond the split.

## Acceptance criteria

- [x] `main` calls `host` and `render` only, no gfx directly
- [x] One `render::frame(FrameData)` owns the pass; no gfx handle outside `render` and
      its Drawers
- [x] The C decoders return pixels; `draughts_photo` declared once
- [x] `render3d`'s gfx-free half separate
- [x] Every expected output byte-identical; shots on the Mac match before and after
- [x] The task's end check (`README.md`): the photograph's load and one flat bench on the
      Mac (below), and the Android release smoke-tested by hand on the Pixel 7a
      (2026-11-11, below); the rest of the measurement dropped (the user, 2026-11-11)

## Outcome

One commit per step; after each, the tests passed with every expected output
byte-identical (`plan.out` is new).

- **`app/host`** holds every platform call: the window, `frame`, the clock, the screen's
  size and focus, the pointer and typed text (`host::input`), back, the keyboard, the
  screenshot, and the program's C for the platform (the externs that were in `main`).
- **`app/render`** holds the drawers (`draw`, `draw3d`, `widgets`, `text`'s state) and
  owns the screen's pass. `render::Frame` carries the board by reference and the pieces
  over the UI and the quads as slices (a Goose struct may hold both), the rest as values.
  `draw::frame` became `draw::upload` (the buffers, before the pass) and `draw::board`;
  `draw::photo` no longer begins the pass. The GPU sees the same commands in the same
  order. `dev` takes the renderer and waits through `render::wait`.
- **Pixels from C.** An `export fn` called back from C during an `extern` call overwrites
  the caller's resizables (`docs/goose-findings.md`), so the decoder can't hand pixels to
  Goose by a callback, and C can't return a slice. Instead `background.c` fills a
  `draughts_pixels` (`photo.h`) pointing into the embedded ASTC blocks, or the decoded
  JPEG, and the renderer's own C, `photo.c`, uploads them and gives them back: no copy
  added. `resize.c` takes pixels the renderer reads back (`draw::cover_with`), only where
  `draughts_resize_covers` says a cover shows (the Mac); elsewhere the 3D board's cover
  is no longer drawn at all. `text::bake` returns its R8 bytes, `badges::atlas` builds the
  badges', and `widgets` uploads both. `draughts_photo` is still declared once, in
  `render3d`.
- **`model3d`** (`src/model3d/`): `mesh`, `looks`, the harmonics, the fade and its
  ambient, sRGB to linear and back, the light's turn, and the bake's plan
  (`model3d::step`, `frame_rows`, the extents), which `render3d::theme_step` now follows.
  `test/model3d/plan.goose` checks the plan and the harmonics headless.
- **Shots**, a headless copy of `665257c` against each step (agents/testing.md): home,
  settings, both in portrait, a game with taps, a clocked game, the computer's setup, a
  puzzle reached through its transition, home to settings held at half, a capture, the
  3D game in both orientations, home and settings on the 3D board, and the 3D game in
  stone, sunset, and birch. All byte-identical but settings' preview flash and the
  must-capture pulse, which differ in the same boxes between two runs of the old build.
  The Android build compiles. The resize cover wasn't checked by dragging a window.
- **Measured on the Mac** (M-series, `--bench 300`, Russian, wood, 2560 × 1600): the
  photograph's load (the ASTC upload, shrunk, blurred, waited for; `--bench` prints it
  now) 7.4 and 7.7 ms for `6bf54c8` with the same timer, 7.5 ms after; on the 3D board 4.0
  ms before. The flat bench after: CPU 0.12 ms a frame, waited P50 3.91 / P99 6.1 ms,
  presented 119.9 fps, 1% low 91.2. The other bench runs printed no summary (a piece was
  picked up during one), and the idle CPU, the 3D bench, and the A33 were not run
  (2026-11-10); the user dropped them on 2026-11-11, the app having been checked by hand.
- **Smoke-tested on Android** (2026-11-11, the release APK of `ffffb8c` on the Pixel 7a):
  the launch lifts straight from the splash, a season's photograph and blur load, the 3D
  board fades in and back to flat leaves nothing stale, a name types with Backspace and
  Return, back goes back a screen and on home puts the app in the background, a game
  returns as it was with its clocks paused while away, and home's X ends the activity
  and its card in recents, the next start a fresh process. All worked. Seen there and
  fixed in `f2d3f11`, though older than 061: the sheet's head showed the name one
  character behind while it was typed.
