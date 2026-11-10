# 03: Stage 2, structure

Status: in-progress

Stage 1 (`02-moves.md`) first. Behaviour stays the same and every expected output stays
byte-identical.

Today the flow of one tap takes about ten hops over seven files. That isn't the problem.
The problem is state passed between packages through flags, and an order that holds
only because of where calls sit in `main`.

## First: review stage 1's four departures

Stage 1 (`02-moves.md`, "Outcome") left four places where it didn't do what its file
asked. The user wants each one reviewed before this stage starts. For each, read the code
and decide whether the choice holds or an alternative is better. Ask the user before
changing an expected output. Record each verdict here.

1. **`strings::PUZZLES_FOR_NOW` and `picker::note_of` were kept.** The note shows only
   for English, which the engine plays but the setup doesn't offer;
   `test/shell/puzzle_set` drives it. The alternative: drop the note, its key in both
   string files, and the English case in that test.
2. **`shell::face_chars` stayed in the shell** instead of moving to `app/text.goose`.
   `test/shell/faces` calls it headless, and `text.goose` imports gfx and ui. The
   alternatives: move it to another package without graphics (`game` has the clock's
   characters, `strings` the names), or split `text.goose`.
3. **`board` now imports `gui`**, because `board::touch` takes `gui::Input` (and
   `test/board/rig` declares `gui`). The alternatives: a small pointer struct in `board`,
   or `touch` taking the pointer's fields, which keeps `board` on `rules` alone.
4. **`home::NO_SETUP` (0) was split from `home::NOTHING`**, now `gui::ASK_NOTHING` (−1).
   The shared asks are negative so that the picker can return a puzzle's index. Four
   tests print the setup's raw number. The alternatives: tests that print the setup's
   name and a re-blessed output, or another numbering of the asks.

### Verdicts (2026-11-10)

1. **Dropped**, with the user's yes. Prefs read only the three offered draughts, so the
   app could never show the note. The note, its key in both files, the title's
   two-line note layout, and the English case in `test/shell/puzzle_set` are gone;
   `puzzle_set.out` and `strings.out` re-blessed (the English lines and the note's
   text only). `puzzles::set_of` still falls back to International's for English.
2. **Holds.** The characters come from `strings` (the app's name in every language) and
   `game`'s clock, and only the shell sees both with no graphics. `game` would have to
   learn home's wordmark, `strings` the faces and the clock; splitting `text.goose`
   leaves a file for one function. The shell composes the screens, so what they draw
   is its to say.
3. **Holds.** `gui` is a leaf on `std` and `vec` alone, with no graphics, and `Input` is
   the pointer both callers already have. A pointer struct in `board` would copy
   `gui::Input`; four loose fields would spread one value over four parameters at both
   calls. `board` keeps no other `gui` use.
4. **Holds.** The setup open and an ask are two things that only shared a number:
   `FRIEND` and `COMPUTER` name both, `NO_SETUP` is a state no ask is. Printing names
   would re-bless six outputs for no change in what they check.

## One screen table

`shell.goose` checks which screen is showing in eight functions:

- `declare`
- `still`
- `board_of`
- `which`
- `animating`
- `back`
- `blurred`
- `animates`

Adding a screen touches all eight. Replace them with one table or `match` per screen
kind. That table holds:

- the screen's frame function;
- its board;
- whether it is blurred;
- where back goes;
- which transitions animate.

Goose has no stored function pointers, so dispatch is a `match` on the screen value,
which costs nothing extra.

## Events instead of flags

- **Flags the game sets and the shell clears:**
  - `gm.result` and `gm.restarted` (`shell.goose` about 400–420);
  - the puzzle's `pl.fresh`.

  Make `game::frame` (and the puzzle's frame) return an event value instead.
- **Settings copied into the game in several places:**
  - `prefs.hints` is copied to `game.b.hints` in four places;
  - the lookout is synced both ways every frame (`prefs.lookout`/`game.look`, 388–394);
  - `king_look` is pushed every frame.

  Write one `apply_prefs(sh)`, called when the settings change and when a game starts.
- **The game's three ask slots** (`asking` before `hinting` before `trapping`,
  `game.goose:310`) have an unwritten priority. Write it down in the code, or make it
  one queue of asks.
- **The note "the computer is asked only after this frame"** (`shell.goose:414`) holds
  only because `think::frame` runs after `shell::frame` in `main`. Make that order
  explicit: in the shell's frame output, or in a comment at both places.

## The shell's frame output

The `Shell` struct mixes about 20 per-frame outputs with the state it keeps. The app
writes some of it and reads some of it directly:

- it writes `sh.ready3d` and `sh.shown3d`;
- it decides from `sh.screen` and `sh.from` when the 3D board can be dropped
  (`draughts.goose` about 300–310);
- it reads `sh.who.typing` and `sh.who.keyboard`;
- it refers to `settings::`, `shell::`, `home::`, and `who::` 47 times.

Move the outputs into a `shell::Frame` struct: layout, view, place, fade, hold, blur,
over, hole, tall, shows, the keyboard wanted, and the 3D board's state. Make one shell
function that says whether the 3D board is wanted, can be dropped, or must wait. The app
reads the `Frame` and hands in what only it knows (whether the 3D board is ready). Pass
the `Frame` by reference: its piece lists must not be copied each frame.

## Small merges

- `celebrate` and `settle` (the win and draw cards) repeat their sizing, the "keep off
  the piece" placement, their buttons 200/201, and their fade. Make them one card
  helper.
- The showcase drag and touch block is in both `game::frame` (about 548) and
  `puzzle::frame` (258–275). Make one shared function in `board`.

## Acceptance criteria

- [ ] One screen table; adding a screen touches one place in `shell`
- [ ] No flag set by one package and cleared by another; one `apply_prefs`
- [ ] `main` reads `shell::Frame` and writes no shell field
- [ ] One card helper, and one showcase-drag function
- [ ] Every expected output byte-identical
