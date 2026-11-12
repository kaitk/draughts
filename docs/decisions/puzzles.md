# Puzzles decisions

The decisions behind the puzzles, dated, with their reasons. How they work now:
[Architecture: Puzzles](../architecture/puzzles.md).

## The set

Each theme is a short curve of its own in three levels, easy to hardest (2026-11-09).
Learn's set was three tiers of ten before; it keeps the ids it had then, and the new
puzzles start at 31, so a child's stars stay with the puzzle that won them.

A take puzzle's goal shows as "Win 2 men" ("Win a man" for one) (2026-11-09). Rejected:
"Capture 2", which a child counting the three pieces a shot takes reads wrong, as the
goal is the balance.

## On the screen

- Learn is open, and the other themes open once half of Learn is solved (2026-11-08).
- No puzzle shows a selected piece's targets, whatever the move hints setting
  (2026-11-08): the child is to find the move ([product](../product.md)).
- Captures of many jumps are made by hand (2026-11-08), as children often make them jump
  by jump. A stop never plays the rest of the way by itself, which would solve the puzzle
  for the child. Its last square plays it when every way there takes the same pieces, and any way
  and any square passed between stops costs no star (2026-11-11, issue 1: a king's
  capture tapped through its squares lost stars).
- A wrong move shows why (2026-11-09): when the other side answers it by taking something
  back, that answer plays, holds, and slides back before the wrong move does. Until then
  every wrong move slid back 0.35 s after it landed, as one without such an answer still
  does.

## Checks

- A line must end quiet (2026-11-08): a puzzle that stops with a capture on the board
  shows the child more to play than it let them.
- A safe move's replies may still give men (2026-11-09), since the threat it answers
  starts with one: the sacrifice is still there to make, only no longer wins.

### Rivals

The 2026-11-09 report: International's second Captures puzzle refused a good move. Its
other double, taking two too, was taken back at once by a double; its man on 39 moved to
34, so the backward double is the one capture that takes most. `puzzles::rivals` was
added to report such moves, as a report rather than a refusal until each is decided.

Six rivals were then fixed (2026-11-09): International's King shots 78 and Russian's 6,
9, 13, 20, and 45 each had a rival that needed two more of the solver's moves, not one,
its line then winning more than the count or ending with a capture due, so none could be
listed cleanly. Each position had a man added or moved instead, named in its source,
which kept its line and its lesson (Russian's 6 still the double answered by a double,
its 13's single now taken back). Both sets report none since.
