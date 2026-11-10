# 03: Stage 2, structure

Status: todo

Stage 1 (`02-moves.md`) first. Behaviour stays the same and every expected output stays
byte-identical.

Today the flow of one tap takes about ten hops over seven files. That isn't the problem.
The problem is state passed between packages through flags, and an order that holds
only because of where calls sit in `main`.

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
- [ ] Every expected output byte-identical; idle CPU and the bench recorded here
