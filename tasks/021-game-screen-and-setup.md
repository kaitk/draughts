# 021: Build the chosen game screen, the clocks, and a new game's setup

Status: todo

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
  dimmed until it exists), level (computer only), clock, play; the choices are kept in
  `settings.txt`.
- Strings for every new word in `strings/en.txt` and `strings/et.txt`.

## Acceptance criteria

- [ ] The game screen matches `prototypes/game.html` in both orientations, Mac and tablet
- [ ] A 5+3 game counts down, adds the increment, survives a pause, and ends on a flag
- [ ] Headless tests for the clock, the panel's taps, and the setup's choices
- [ ] Idle with a clock stopped draws nothing; with one running, one frame a second

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

## Open for the user
