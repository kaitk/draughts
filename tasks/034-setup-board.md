# 034: The setup's board shows the game being set up

Status: in-progress (built and checked on the Mac; the tablet check is open)

Found by the user on 2026-11-08. In home's setups (a friend, the computer), the board
beside the choices is the game in progress or the last one played
(`shell::home_screen` passes `sh.game.b`), so picking International, Brazilian, or
Russian changes nothing on it, and neither does picking black against the computer. It
should show the game the setup will start: the chosen variant's starting position, 8 × 8
or 10 × 10, turned when the child plays black against the computer, and change as the
choices change. Back to the menu shows the game in progress again, as now.

## Notes

- A board of the setup's own, like settings' preview (`sh.preview`), set to
  `rules::start` of the chosen variant when the setup opens and on each change; the
  game's board stays untouched until play.
- A change of variant between 8 × 8 and 10 × 10 can crossfade the pieces with
  `board::under`, as home to settings does (task 022), or switch at once; opening the
  setup from the menu likewise. Pick whichever reads calmer on the tablet.
- Play starts the game from what the board shows, so nothing jumps on play.
- The app still draws only on change.

## What was built (2026-11-08)

- `Shell.next`, the setup's own board. `shell::home_screen` resets it to `rules::start`
  of `prefs.variant` whenever a setup is open and its draughts differ, and shows it
  (`board_of(HOME)` while `Shell.staged`); on the menu the game's board shows as before.
  `shell::turned` turns home's board: in the computer's setup when black is chosen,
  never in a friend's, and on the menu when the game in progress has the child on black.
- A tap's frame still shows what it declared (the layout's squares and the board agree);
  the next frame shows the board and the column changed together, drawn through
  `g.acted` as any tile's change is. Play leaves `staged` off, so home, come back to,
  shows the new game.
- Switch, not crossfade. The board stays in place, so a crossfade with `board::under`
  would switch the squares between 10 × 10 and 8 × 8 halfway under half-faded pieces (the
  board pass draws one layout's squares), a two-step change where home to settings hides
  it in the slide. The column beside it switches in one frame too, opening the setup and
  lighting a tile, so a board fading for 0.25 s would lag the tap it answers. Switching
  also needs no frames after the tap's.
- `--variant`, `--computer`, and `--level` with `--screen friend|computer` set the
  setup's choices for a screenshot without touching `settings.txt`.
- `test/shell/setup.goose`: every draughts tile in both setups, in landscape and
  portrait, shows its start whole on squares of its size; black turns the board and
  white turns it back; back shows the Russian game in progress, a move in; play starts
  the Brazilian game turned as shown; and half a second after each tap the shell asks
  for no frame and nothing animates (but on the game screen after play, where the
  computer's turn ring runs).

## Checks (2026-11-08)

- `python3 test/run_tests.py` and `--build`: 33 tests pass. New: `setup.out`; no other
  output changed.
- The Mac, 960 × 600 and 600 × 960: both setups with each draughts, and black against
  the computer on International and Russian, the board as chosen; the menu with a
  Russian game a move in. `settings.txt` unchanged after the runs.
- Open: the tablet, both orientations. The shell holds one more `board::Board` (about
  55 KB, by its fields), now four; check the app starts and runs as before there.

## Acceptance criteria

- [x] Each variant tile shows its starting position on the board, in both setups, both
      orientations
- [x] Black against the computer turns the board; white turns it back
- [x] Back to the menu shows the game in progress; play starts the game shown
- [ ] Headless test of the above; checked on the Mac and the tablet (headless test and
      the Mac done; the tablet open)
