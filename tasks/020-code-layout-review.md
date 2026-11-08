# 020: Review the code's layout as a whole

Status: in-progress (6, 8, and 1 made; 2 and 5 wait for task 007)

Once the MVP's flows work in their basic form (task 008, then 006 and 007), look at the
code as a whole: is it readable and neatly packaged, as a game's code would be, and does
it fit what comes next: more screens and flows (task 019), other screen sizes, a Mac
version, and perhaps a NoGraphicsAPI port (`docs/product.md`), reusing most of it. Not
before then: the flows should exist first, so the review is of real code (asked
2026-11-07).

## Work

- Read the packages (`rules/`, `board/`, `gui/`, `game/`, `shell/`, `strings/`) and
  `app/`, and note where game logic, layout, and drawing mix, where state hides in the
  app's main loop, and what a second renderer would have to rewrite.
- Propose changes with their reasons; no abstractions ahead of need, only what removes
  tangles or real duplication. Record the layout in `docs/architecture/`.

## Acceptance criteria

- [x] A written review with the changes proposed, agreed with the user
- [ ] The agreed changes made, tests passing, the app unchanged on the Mac and tablet

## Settled (2026-11-08)

Once tasks 021, 025, and the computer's wiring are in, review the code with subagents and
make the clear-cut fixes without waiting for agreement: tangles and real duplication
whose fix is obvious, no abstractions ahead of need. Anything larger or arguable goes in
the written review for the user to agree.

The review also reads the code as Goose: whether each part is written the way the
release's `docs/`, `samples/`, and `stdlib/` write it, and where writing it more
idiomatically would simplify it meaningfully. The user's other Goose projects,
`~/projects/goose/goose-http` and `~/projects/goose/plod`, are models to compare with.
Change only what gains clearly; finding nothing of real value is a fine answer.

## Done (2026-11-08)

Read every package, `app/`, `tools/`, and the tests against the release's docs, samples,
and stdlib and against goose-http and plod. The packages import no graphics, the rules
are pure, nothing allocates per frame, and the code reads as Goose's samples do; what
follows were the clear-cut fixes, one commit each. The layout as it now is:
`docs/architecture/README.md`, "Code layout".

- `5f7bcc2` `shell::shown` returns the board the screen shows; the app drew it in two
  branches, `shell::animating` in three.
- `acb905b` The settings and game paths are built from the storage folder, not by
  slicing 12 bytes off the settings path; a frame counter nothing read is gone.
- `41c1c08` `gui::take` and `gui::hold_if` replace five copies of "a press on the UI is
  the UI's" and three of "a widget that is off takes the press"; `choice`'s word form,
  unused, is gone.
- `4d61f1b` `rules::bit_at` is the square at a column and row; its formula was written in
  `make_variant`, `parse_square`, and `board::bit_at`. The app's `--tap` now parses with
  `rules::parse_square`.
- `6971893` `shell::restore` starts the saved game with `game::start` and puts back the
  board and clocks, rather than resetting the game's fields by hand.
- `d774d42` A piece over the UI is put centered in a rect; all seven callers worked the
  center out.
- `af882b8` Home and settings lay out at `g.scale`, which their helpers used, rather
  than working the scale out again from the screen size.
- `463d40f` The drawer's overlay buffer is sized by `panel::OVER`, not a second `4`.
- `b453fa7` The theme drawn and its colors live in the drawer beside the scene loaded for
  it; the main loop held them as two locals and passed them to each draw.
- `e51c0bb` `gui::text_width` lost its spacing, 0 at every call.
- `43a0d92` `board::hint`'s comment says it is kept for puzzles.

Checks: the tests pass through TinyCC and built, no expected output changed, and
`scripts/test.sh`'s perft and random-game sweeps agree after the `rules` change. Ten
`--frames 20` shots on the Mac (home, game, settings, each in 960 × 600 and 600 × 960
where they differ, both setups, `--clock 5+3 --tap c3 --tap d4`, and `--computer white`)
before and after: seven byte-identical; the computer's game and both settings differ
only by the computer's ring's pulse and the preview's flash, as two runs before any
change did. The APK builds (5624 KB). The tablet is not checked: it was locked.

## Agreed (2026-11-08)

The user took the recommendations: 6, 8, and 1 now; 2 and 5 at the start of the puzzle
screen (task 007), which would otherwise add a third panel layout to `board` and another
copy of each test helper; 3 maybe, later; 4, 7, and 9 left as they are.

Made the same day, one commit each:

- `7459320` (6) The app no longer puts `--hints` into `sh.prefs`; the flag sets the
  game's board only, so a settings tap writes the hints chosen there and applies them,
  as a tap ends `--theme` and `--lang` too.
- `982656b` (8) `draw::SHARED_BLOCK` holds the quad's corners, `box`, `tint`, and
  `over` with its `acc`, for the board's, the pieces', and the UI's shaders.
- `cbedc28` (1) `Shell.over` (a `game::Overlay`) holds the pieces over the UI; the game
  screen, home, and settings each clear and fill the list they are handed, home takes
  the board's size rather than the game, and settings no longer threads the game
  through its six functions. The game tests hold the list as a global.

Checks: the tests pass through TinyCC and built, no expected output changed. Sixteen
`--frames` shots on the Mac (home, settings, both setups, the game, `--clock 5+3 --tap c3
--tap d4`, `--computer white`, and a Russian win's celebration, each in 960 × 600 and
600 × 960) before and after each of 8 and 1: ten byte-identical; the computer's game,
settings, and the celebration differ only where the ring pulses, the preview flashes,
and the winner pops in and the sparks drift, as two runs before any change did. The
tablet is not checked.

## Review: left for the user

Each with its reason and rough cost; none is needed for the MVP.

1. **The pieces over the UI belong to the frame, not the game.** `Game.overlay` is filled
   by home and settings too, so `settings` threads the whole `game::Game` through six
   functions only to put two kings on its tiles, and home takes the game for its
   wordmark's piece. Hold the overlay in `Shell` and hand the screens the list. About
   1 h: `game`, `home`, `settings`, `shell`, the app, and four tests that read
   `sh.game.overlay`. Done: `cbedc28`.
2. **The game screen's layout lives in `board`.** `board::layout` places the game's two
   panels (`SIDE`, `TOP`, `BOTTOM`) and `board::Layout` carries them as `left` and
   `right`, while `game/panel.goose` is what fills them. Move `layout` and the panel
   rects to `game`, leaving `board::layout_at` for the board alone. About 1.5 h; five
   test files call `board::layout`. Worth it before task 019's further screens or other
   screen sizes, not before.
3. **Themes as a package.** `app/theme.goose` has no graphics, but because it is in
   `app/`, `settings` numbers the seasons by hand (`SEASON_KINDS = [1, 2, 3, 0]`) and
   the app holds `theme_for`. A `theme/` package would let settings name them and pick
   the season's theme itself. About 1 h; every root that imports `shell` declares one
   more package (four tests).
4. **The levels are numbered twice.** `game::EASY..HARD` and `ai::EASY..HARD` must
   agree (the shell passes the one to `ai::adapt` as the other). Using `ai`'s makes
   `game` import `ai` for three constants, where now the app's worker is the only bridge
   between them. 20 min either way; leaving it is defensible.
5. **A helper package for the UI tests.** Five tests define the same `square` (a square
   name to a point), three the same `name`, two the same `marked`, and six a pointer
   `frame` of their own. A `test/drive/` package would hold them; `check` can't, since the rules
   tests would then have to declare `board` and `gui`. About 1 h, some 60 lines.
6. **`--hints` leaks into the settings file.** The app puts the flag's value into
   `sh.prefs`, so a settings tap during such a run writes it, where the flag should
   override the run only. A dev flag; 15 min, but it changes behavior, so asked.
   Done: `7459320`.
7. **Home measures its setup twice.** `home::content_height` repeats the sizes `choose`
   cuts; settings already lays out and measures with one function (`rows` with
   `declare`). Arguable for one screen; about 45 min.
8. **Shared shader helpers.** `box`, `tint`, `over`, and the quad corners are written
   twice each across the three shaders. A block like `THEME_BLOCK` would hold them, pixel
   for pixel the same. 20 min; a second renderer ports them anyway. Done: `982656b`.
9. **Enums for screens and asks: not proposed.** Goose's C-like enums would make the
   screens and each screen's asks exhaustive in `match`, but the integer constants are
   the samples' way for UI state (`29_ui_todo.goose`), index arrays, go into shaders,
   and the screen is saved in `game.bin`. About 2 h for little gain.

What a second renderer rewrites: `app/draw.goose`, `app/widgets.goose`, and
`app/scene.goose` (about 900 lines, two-thirds of them GLSL), the texture upload in
`app/text.goose`, the loop's `gfx` calls and input in `app/draughts.goose` (about 30
lines), and `app/wake.c`'s SDL timer. It keeps every package, `theme.goose`, and
`think.goose`, and reads the same flat lists. What is left in the main loop is I/O and
GPU work (saving on pause, the settings file, the language, when the photograph loads,
the thumbnails, the clock's wake, development taps), no game logic.
