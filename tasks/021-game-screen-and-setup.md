# 021: Build the chosen game screen, the clocks, and a new game's setup

Status: done

Bring the app to what task 019 settled (rendering.md "Game screen", "Clocks", "Home"):
the board between two panels of labelled tiles, clocks on the play side, and a setup on
home for a friend and the computer.

## Work

- `game/panel.goose`: home, settings, and start over on the left; whose turn or the
  clocks, and take back, on the right; in portrait a bar above the board and the play
  below it. Remove the hint button and the move-hints toggle (hints stay in settings;
  `board::hint` can stay for puzzles). Settings opened from the game returns to it.
- Clocks: a pure clock value in the game (time left per side, increment, which runs),
  advanced from the frame's time, paused while the app is paused and saved with the
  game; a flag fall ends the game as a loss for that side. A running clock asks for a
  frame each second and no more.
- Home's setup: a friend and the computer open it in the column: variant (International
  enabled, the default), level (computer only), clock, play; the choices are kept in
  `settings.txt`.
- Strings for every new word in `strings/en.txt` and `strings/et.txt`.

## Acceptance criteria

- [x] The game screen matches `prototypes/game.html` in both orientations, Mac and tablet
- [x] A 5+3 game counts down, adds the increment, survives a pause, and ends on a flag
- [x] Headless tests for the clock, the panel's taps, and the setup's choices
- [x] Idle with a clock stopped draws nothing; with one running, one frame a second

## Settled while scoping (2026-11-08)

- The computer's setup gets a color row the prototype lacks: white and black, white the
  default, kept in `settings.txt`. When the child plays black, the board turns so the
  child's pieces are at the bottom, and the clocks follow (the child's clock nearer the
  child). A friend's setup has no color row.
- Play replaces a saved game without asking; continue then resumes the new one.
- Variants: if 10×10 draws and plays correctly on screen, International is enabled in the
  setup and settings and becomes the default for a new game (`docs/product.md`);
  Brazilian is enabled once task 023 is merged. A saved game keeps its own variant
  (`shell::restore` no longer rejects one that differs from the default).
- Clocks run in both kinds of game; against the computer its clock runs while it thinks
  and pauses (the wiring, task 006).

## What was built (2026-11-08)

- `board::layout` gives two panels, `left` and `right`, and a `flip` the board shader,
  `board::hit`, `board::center`, and `board::fill` follow (black playing up the screen).
- `game/panel.goose`: the panels of take d with labelled glass tiles (`gui::labelled`),
  the turn's piece and words or the two clocks (`gui::clock_tile`, `gui::figures` for
  tabular m:ss in a 36 dp face). No hint button or toggle; `board::hint` stays for
  puzzles. Settings from the game returns to it (`Shell.back`).
- `game/clock.goose`: the clock value; the game advances it from the difference of `now`
  between frames, at most 2 s a frame, and counts nothing for the frame after a pause
  (`game::pause`: the app calls it while the window is unfocused and on the frame focus
  returns; the shell while home or settings shows). It starts with the first move, so
  white's first move is untimed. `game::winner` takes a flag as a loss.
- Home's setup (`shell/home.goose`, `gui::pick`, `gui::mini`, `gui::pips`): the draughts
  as a table in `shell/settings.goose` (`DRAUGHTS`, `DRAUGHTS_ON`), the level and color
  against the computer, the clock, play. Kept in `settings.txt` as `draughts`, `level`,
  `color`, `clock`. Home's computer row is enabled and notes the kept level.
- The game knows `computer` (the side it plays, or -1) and `level`;
  `game::computer_to_move` is the seam for task 006. Until then the computer's side is
  played by hand.
- Saved game `VERSION = 2`: the clock, the computer's side and level, and any variant;
  `shell::restore` checks the variant is one the rules know.
- `app/wake.c`: an SDL timer wakes the loop when a running clock's time changes
  (Android only).
- International 10 × 10 drew and played correctly on screen (pieces, last-move marks,
  targets, a capture, crowning on d10, turned and not), so it is enabled and the default
  for a new game; Brazilian is enabled now that task 023 has merged.
- Development flags: `--variant`, `--clock`, `--computer`, `--screen friend|computer`,
  taps on 10 × 10 (`--tap d10`).

## Measured (2026-11-08)

- Frames drawn while idle on the Mac (a temporary counter, 10 s each): the game screen
  with no clock, and with a 5+3 clock not yet started, 0 after the first; with black's
  clock running, one a second (drawn 31, 32, ... 40 at 3 s ... 12 s).
- On the tablet, `scripts/idle_cpu.sh 60`: no clock, the program thread 0.02 s (0.03%
  of a core), the process 1.22 s, 60 voluntary switches; a running clock 0.32 s (0.53%),
  the process 1.61 s, 60 voluntary switches.
- The clock's lag on the tablet (the time from the shown second changing to the frame
  showing it, logged through `SDL_Log` for 95 s): with only the patched `frame()`'s 1 s
  idle wait it grew 6 ms a second, from 0.20 s to 0.77 s, and would skip a second about
  every 2.5 minutes; with the wake timer it stays at 4 to 8 ms (11 ms once).
- A pause on the tablet: black's clock at 4:55, HOME for 20 s, back: 4:51 (the 4 s it
  was on screen around the pause); the 20 s didn't count.
- `scripts/lifecycle_memory.sh 10` with a 5+3 International game: one process, no
  errors, PSS 261 to 263 MB (274 MB before the first cycle), native heap 27 MB,
  graphics 211 to 213 MB, as before.

## Open for the user

- The clock starts with the first move (white's first move is untimed, then black's
  clock runs), not as soon as white is to move. Against the computer playing white the
  computer's first move starts the child's clock. Starting at once is a one-line change
  in `clock::moved`/`game::start`.
- Only time with the game on screen counts: the clock stops while home or settings
  shows, and while the window has no focus (on the Mac, a window launched from a
  terminal behind it never counts).
- Take back with a clock gives the move back but not the time: the side to move again
  keeps the time it has. After a flag, take back does nothing; start over sets both
  clocks full.
- Against the computer its side waits, or is played by hand, until task 006; the clocks
  run for it as for a friend.
- The tiles' words are in the 24 dp face where the prototype has 26 for the turn and
  take back, and the setup's tile words in 20 where it has 18; no new atlas sizes.
  "Rahvusvaheline" is wider than its tile in landscape and takes the 17 dp face
  (`gui::pick`); the Estonian review (task 024) may prefer another word.
- "Your pieces" ("Sinu nupud") names the color row; the Estonian strings are a draft.
