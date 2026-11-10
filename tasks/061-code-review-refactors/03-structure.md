# 03: Stage 2, structure

Status: done (2026-11-10)

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

- [x] One screen table; adding a screen touches one place in `shell`
- [x] No flag set by one package and cleared by another; one `apply_prefs`
- [x] `main` reads `shell::Frame` and writes no shell field
- [x] One card helper, and one showcase-drag function
- [x] Every expected output byte-identical (but the two the user approved, below)

## Outcome

One commit per item. After each, `scripts/test.sh` passed and the app built on the Mac.
Every expected output stayed byte-identical but three, each its own commit: the
puzzles' note dropped (verdict 1: `puzzle_set.out`, `strings.out`), and a draw against
the computer counted (`adapt.out`, below).

- **The screen table.** `shell::KINDS`, a row per screen: whose board it shows, its blur,
  where back goes (a screen, `NO_WAY`, or `RETURN` to where settings opened from), and
  the screens it switches to through a transition, a bit each. `animates`, `blurred`,
  `which`, `board_of`, and `back` read it. The screens' own code is chosen in three
  `match`es right after it: `screen_frame` (the live frame), `still` (the one a
  transition leaves), and `animating`. A new screen is a row and an arm in each, in one
  place at the file's head.
- **Events.** `game::frame` returns a `game::Event`: where to go, whether a game against
  the computer ended this frame and how, whether it was started over, and whether the
  lookout's eye was turned. `puzzle::frame` returns a `puzzle::Event`: where to go and
  whether it was solved. `Game.result`, `Game.restarted`, and `Play.fresh` are gone.
  Tests read the game's last result from `drive::result`.
- **A draw found uncounted.** The game set its result to 0 on a draw, meant to count
  ("a draw counts too, as 0", and `ai.md` says so), but the shell took 0 as no result,
  so a draw never reached `played[level]`. With the event's `ended` apart from its
  result, the shell counts it (the user, 2026-11-10); `test/shell/adapt` now draws a game
  on hard: played 1, skill kept.
- **`apply_prefs`.** One function puts the settings where they act: the game's hints and
  lookout, both boards' kings, and the lookout's skill. It is called where the settings
  change (settings, home's setup, a player entered or started again, a game ended),
  where a game starts (play, played again, restored, `shell::new`), where the puzzle is
  new (`load_set`), and once by the app after the flags (`shell::open`). The four copies
  of the hints and the per-frame pushes of the kings and the lookout are gone; the
  lookout's eye comes back to the settings through the event. `--hints moves` now sets
  the player's hints for the run, as `--board` and `--lookout` set theirs. Tests that set
  `sh.prefs` themselves call `shell::apply_prefs` after, as the app does.
- **The asks' order** is written at `game::open_ask`: the computer's move, then the
  hint's, then the lookout's traps, and why the first two never overlap. The order of
  `shell::frame` before `think::frame` is said at both places.
- **`shell::Frame`** (`sh.out`, passed by reference, returned by `shell::frame`) holds
  what a frame leaves for the app: changed, the screen, whose board shows, the layout,
  the pieces over the UI, the blur, the hole, the 3D board's view, place, fade, and hold,
  the keyboard, `save`, and `quit`. The app hands in the 3D board's ready and shown as
  `shell::frame`'s parameters (tests through `drive::ready3d` and `shown3d`), after
  asking `shell::board3d` whether it is `WANTED`, `KEPT`, or `DROPPED`;
  `shell::board_n`, `wake_in`, and `pause` answer the loop's other questions. `save`
  is the old "changed and no transition"; the app calls `shell::wrote` once it wrote
  them, since `Shell.changed` stays as tests read it. The flags' launch setup moved to
  `dev::setup`, and the rest of it to `shell::launch` and `shell::open`, so `main`
  writes no shell field. It still reads `sh.prefs` (the season, the language, the file
  it writes) and hands `sh.game` to `think::frame`.
- **Merges.** The win's and the draw's cards share `card_size`, `card_at` (centered,
  kept off a piece), and `card_end` (the buttons, the fade and slide);
  `board::showcase` is the showcase drag the game and a puzzle share.
- **On the Mac,** against a build of `f5ea195` (from before this stage), flat-board shots
  of eight flag runs were byte-identical: taps, `--hints moves` with a tap, a setup,
  `--go settings` and `--go puzzle` held mid-transition, the picker, the lookout. The
  settings shot differs only in the preview's flash box, as two runs of the old build
  do; the 3D game matched by eye (its fade is timed). The `--frames` runs hang with
  stdin or stdout left to a shell loop: give each `< /dev/null` and no redirect to a
  file, from `src/app` (2026-11-10).
- **Not measured.** Nothing runs more often than before; the per-frame copies of the
  settings are gone.
