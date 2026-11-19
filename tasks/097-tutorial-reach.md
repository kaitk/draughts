# 097: How to play within reach while learning

Status: in-progress

A tester took the game for checkers, and once they saw it wasn't, found How to play only
in settings and the library: home's row had gone when they answered "I know how" or began
a game. They were also unsure how a king jumps on in a multi-capture, which the tutorial
didn't show.

Home's How to play now stays for a player still learning, a row of its own under Continue
or Replay, until they finish a tutorial in any draughts, win a game against the computer,
or solve the half of Learn that opens the other themes (`shell::past_basics`). "I know
how" only skips the tutorial offered then; `how_to_play = known` is no longer read, and a
win is kept as `won = yes`. A new step, Kings jump on too (`W:WKa1:Bc3,f4`), follows Kings
take from afar in every draughts: the king takes c3 and must land on e5, the one square
from which it takes f4.

## Acceptance criteria

- [x] How to play shows under Continue while a game is kept, first and lit without one,
  and goes once a tutorial is done, a game against the computer won, or half of Learn
  solved in any draughts (`test/shell/tutorial`).
- [x] The king's multi-capture step in all three draughts, its only moves through e5
  (`test/shell/tutorial`); its strings in English and Estonian, the Estonian checked by
  Gemini (kept as written).
- [x] Every layout fits the four rows (`test/shell/sizes`, "home, still learning"); the
  iPad's smallest window has a fifth row under 88 dp, as its compact rows were accepted.
- [ ] Checked on the Mac and on the tablet.
