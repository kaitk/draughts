# 034: The setup's board shows the game being set up

Status: todo

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

## Acceptance criteria

- [ ] Each variant tile shows its starting position on the board, in both setups, both
      orientations
- [ ] Black against the computer turns the board; white turns it back
- [ ] Back to the menu shows the game in progress; play starts the game shown
- [ ] Headless test of the above; checked on the Mac and the tablet
