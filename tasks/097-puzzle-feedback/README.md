# 097: Puzzle feedback from testers

Status: in-progress

Testers' comments on the puzzles, taken one at a time. The first: a safe-move puzzle (the
daily library's 2833, 34-40) marked wrong with no visible reason. The screen showed only
White's first reply, a sacrifice; the solver called the move wrong by counting a king
as a man, at the end of 13 plies of exchanges. The second: "easy puzzles are just forced
moves" (05 to 07, and 04's real choice).

## Subtasks

- 01 [The wrong move's whole line](01-whole-line.md): done on branch `wrong-move-line`.
- 02 [Kings in the solver](02-kings-in-the-solver.md): done, an offline check by the computer player.
- 03 [Take puzzles and kings](03-take-puzzles-and-kings.md): done; the built-in puzzles to replace are listed in 04.
- 04 [Refill the libraries](04-refill-the-libraries.md): in progress. From 500 up a
  capture puzzle needs a real choice (3 or more legal moves or 2 or more moves): 52
  dropped, 9 re-rated under 500; 9 Russian one-glance captures the engine plays otherwise
  dropped. International refilled but 6 safe moves, Russian but 3; Brazilian's 159 to do
  (its batch done, resume steps in 04); the built-in replacements open.
- 05 [Today's themes by rating](05-themes-by-rating.md): done.
- 06 [A faster ramp for a flawless record](06-flawless-ramp.md): done.
- 07 [One-glance captures and International 32](07-one-glance-and-32.md): done.

## Acceptance criteria

- [ ] Each subtask done or cancelled, and the branch squashed onto main
- [ ] Checked on the Mac and the tablet: a wrong safe move's line plays and slides back
