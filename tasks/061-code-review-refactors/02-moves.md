# 02: Stage 1, moves only

Status: done (2026-11-10)

Nothing here changes behaviour. After each item, `scripts/test.sh` passes with every
expected output byte-identical. Build the app after each item too, because the tests
don't compile its shaders.

## Leftovers and drift

- `docs/architecture/README.md`:
  - Its AVX2 note (about line 34) is out of date. NoGraphicsAPI adds AVX2 only for the
    x86-64 slice and uses NEON on arm64. What remains open is whether its utility
    libraries need AVX2 on x86 Windows.
  - The dependency line says `game` builds on board, gui, and strings, but it also uses
    `ai`'s lookout (`watch`).
- `src/shell/shell.goose`:
  - The comment at about 932 ("Whether anything is still moving…") sits above
    `waiting3d`, away from `animating`.
  - Line 182 is too long, and 222–223 wrap oddly.
- `settings::DRAUGHTS_ON` is all true, and `strings::PUZZLES_FOR_NOW` says there is
  "none now". Remove both if nothing still needs them; otherwise say in a comment why
  they stay.
- `game.goose:891` has the literal `"2/3"`; it becomes a string key or is built from
  numbers.
- `draughts_photo` is declared twice (`scene.goose:34`, `render3d.goose:32`). Declare it
  once.
- `board::ease` and `game::smooth` are the same smoothstep. Keep one.

## Files split

- **`shell.goose`:**
  - `Saved`, `checksum`, `save`, `restore`, `write_game`, and `read_game` (about 701–800)
    move to `shell/saved.goose`.
  - The roster operations `enter`, `switch_player`, `add_player`, `edit_player`,
    `start_again`, and `remove_player` (about 804–908) move beside `players.goose`.
  - `face_chars` (132) moves to `app/text.goose`, its only user.
- **`settings.goose`:** the data (`Settings`, `parse`, `write`, the key tables, about
  40–260) moves to `shell/prefs.goose`. The screen (about 306–947) stays.
- **`game.goose`:** the end cards (`cheer`, `celebrate`, `settle`, about 740–975) move to
  `game/ending.goose`.
- **`game::Overlay`** is used by every screen; it moves to `board`.
- **`game::touch`** (593) is board input shared by the game and the puzzle; it moves to
  `board`.

## Developer flags out of `main`

The code for `--tap`, `--go`, `--win`, `--hold`, `--bench`, `--rest`, and `--frames` is
about a third of the loop's lines in `src/app/draughts.goose`. Move it into
`app/dev.goose`, called before and after the frame, so that `main` reads like "A frame"
in `docs/architecture/README.md`. The flags' behaviour stays exactly as it is: the
shots and the bench output are the check.

## Shared constants

- **The phone threshold.** 600 dp is written about five times (`settings:354`,
  `picker:39`, `who:79` and `:243`, `panel:159`, and `panel::PHONE_DP`). Replace them
  with one `gui::phone(area, s)`, next to `gui::compact`.
- **Repeated paddings and fudge factors.** Name them:
  - the paddings 12 and 16 dp;
  - the panel insets {16, 20} and {20, 16};
  - the `0.94` board share, used 5 times in settings;
  - `72.0 * s` in the narrow-bar test (`panel.goose:248`, `:460`).
- **Widget ids** are numbered by hand per screen:
  - panel 110–115
  - game 200
  - home 300–360
  - settings 401, 460, 800+
  - who 500–540
  - picker 600–710, 1000+

  Put the ranges in one table in `gui`, so a collision is caught.
- **Action codes.** `BACK` is 1, 5, −2, or 2 depending on the screen. Give the shared
  actions one numbering.

## Acceptance criteria

- [x] Each item above done, or noted here with why not
- [x] Every expected output byte-identical; the app builds on the Mac
- [x] `main`'s loop holds no developer-flag code

## Outcome

One commit per item. After each, `scripts/test.sh` passed with every expected output
byte-identical, and the app built on the Mac. One test is new (`test/gui/ids`).

- **Leftovers.** `DRAUGHTS_ON` is gone. `PUZZLES_FOR_NOW` stays: English, which the
  engine plays but the setup doesn't offer, shows International's set with that note,
  and `test/shell/puzzle_set` checks it. `picker::note_of` says so. The "2/3" is built
  from the countdown's numbers. `draughts_photo` is declared once, in `render3d`.
  `board::ease` is the one smoothstep.
- **Files.** The saved game is in `shell/saved.goose` and the roster's operations in
  `shell/roster.goose`, both in the `shell` namespace, so their callers didn't change.
  The settings' data is in `shell/prefs.goose`, in the `settings` namespace for the same
  reason. The end cards are in `game/ending.goose`. `Overlay` (with `OVER`) and `touch`
  are in `board`. `touch` takes `gui::Input`, so `board` now builds on `gui`, a leaf
  (`docs/architecture/README.md` says so).
- **`face_chars` stays in the shell.** `test/shell/faces` checks it headless, and
  `app/text.goose` imports gfx and ui, which a test can't.
- **`app/dev.goose`** holds `--tap`, `--go`, `--win`, `--hold`, `--bench`, `--rest`, and
  `--frames`, called at five fixed points of the frame. Checked against a build from
  before it: the flat-board shots of eight flag runs (taps, `--go` with `--hold`, a win
  held by `--win`, a puzzle's taps) were byte-identical, and so was their output. The 3D
  shot matched by eye (its fade is timed). `--bench` and `--rest` print as before.
- **Constants.** `gui::phone` and `gui::PHONE` replace the five 600 dp checks.
  `gui::PAD` (12) and `gui::PAD_WIDE` (16) name the paddings where they are one. Corner
  radii, the shader's numbers, and one-off sizes keep their literals. The panel's glass
  insets are `panel::TALL_IN` and `WIDE_IN`, with `panel::inside`. Settings' 0.94 is
  `PREVIEW_SHARE`, and the bar's 72 dp is `panel::BAR_SPARE`.
- **Widget ids** count from per-screen bases in `gui` (`PANEL_IDS`…`PICKER_IDS`), with
  `gui::IDS` and `IDS_SPAN` as the table. `test/gui/ids` fails when a range runs into
  the next, or when a theme has more puzzles than the picker's range holds. The table
  found a shared id: the picker's back and the who card's backdrop were both 500, on
  screens never declared together. The picker's and settings' ids were renumbered into
  their ranges. Ids are only slot and scroll keys, so nothing showed it.
- **Asks.** The shared asks are numbered once, negative: `gui::ASK_NOTHING`, `ASK_BACK`,
  `ASK_SETTINGS`, `ASK_CHANGED`, `ASK_SHOWN`, and `ASK_RESTART`. Each screen's own asks
  are 0 and up, as is the puzzle index the picker returns. Home's `NOTHING` also meant
  "no setup open", and the tests print that value. It is now `home::NO_SETUP` (0), apart
  from the ask.
- **Not measured.** Nothing here runs more often than before. Quick Mac `--bench` runs
  of both builds swung with the window's vsync state alike (120 or about 850 fps).
