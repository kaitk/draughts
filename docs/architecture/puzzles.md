# Puzzles

Puzzles are the package `puzzles/` (namespace `puzzles`): plain text read into a fixed
table at start, and an exact search over [`rules`](rules.md) that says whether a move
solves one. No graphics, tested headless in `test/puzzles/`. The screen that plays them
is in `shell/` ([rendering](rendering.md#controls)).

## The file

`puzzles/international.txt` holds 30 International puzzles in three tiers of ten (chosen
2026-11-08: International is the default game; Russian ones come later from them):

1. Find the capture: one or two pieces taken, the majority rule, men taking backward, a
   king taking from afar, and which of two captures isn't taken back.
2. Many jumps and crowning: three and four jumps, the route that takes most, a capture
   that crowns by ending on the far row and one that passes it and goes on uncrowned,
   kings zigzagging, a man walked past a guard to the far row.
3. Shots and the only safe move: give a man, take three to five; and a man in danger
   that one move alone saves.

A puzzle is a block of `key value` lines, a blank line ending it; `#` starts a comment.

```text
variant international           the variant of the puzzles after it

# give one, take three
id 21                           stable, 1 to 60: progress is kept by it
tier 3
goal take 2                     take N, crown, win, or safe
position W:W33,38,43,45,47,48:B3,11,21,23,24,29
line 33-28 23x32 38x27x16x7     the solver's move, the reply, and so on
source own, found by tools/puzzles.goose find and verified by the engine
```

- **position** is PDN's FEN, as `rules::parse_fen` reads it; the side to move solves the
  puzzle.
- **line** is a solving line in PDN: moves `32-28`, captures by their stops `28x19x10`
  or only their ends `28x10` when that names one capture. A puzzle lists every first
  move that solves it, each starting a line, and up to four lines. Its moves are the
  solver's moves in its longest line.
- **source** says where it came from. All 30 are composed here: tiers 1 and 2 by hand,
  tier 3 picked from positions `tools/puzzles.goose find` turned up, and each verified
  by the solver, the computer player, and `test/perft.py`. None is copied from a
  collection, so none carries another's license.

The file is built into the program (`embed_file`) and read once at start into
`puzzles::all`, a fixed table; nothing is read or allocated after.

## Goals

A move is right when it reaches the goal, or keeps it within reach of the moves left
whatever the other side replies; any line that does counts, listed or not. The search
counts pieces, nothing else, and plays out the captures that are due after a move, since
captures are forced.

- **take N**: the solver's move is a capture, and once the captures due after it are
  played out the solver has taken N more pieces than it has lost. The goal is the
  balance, so a shot that gives a man and takes three is "take 2".
- **crown**: the move makes a king that the reply doesn't take.
- **win**: the other side is left with no move: everything taken or blocked. Leaving it
  no move reaches any goal.
- **safe**: nothing is lost over the next two plies (a reply and an answer), the
  captures due after them played out. A safe puzzle has one such move.

The other side's reply, when the puzzle goes on, is the line's when the child has played
the line so far, and otherwise the reply after which the solver needs the most moves.
The piece the hint shows is the line's next move's, or the first right move's off the
lines.

The search keeps each position's moves on one fixed stack in a `puzzles::Solver` the
caller owns, so it allocates nothing and needs little native stack. The 30 puzzles cost
at most 387 positions to check, well under a millisecond.

## Checks

`puzzles::check` (run by `test/puzzles/set.goose` on every puzzle, and by
`tools/puzzles.goose`) refuses a puzzle when:

- a line's move isn't right, or a line's last move doesn't reach the goal, or an earlier
  one does;
- the goal can't be forced within the puzzle's moves, or can be in fewer;
- a first move that solves it starts no line: the file lists every way in;
- along a line, another legal move goes from and to the same squares, which a tap
  couldn't tell apart;
- it has no source.

`tools/puzzles.goose` adds the computer player's view at full skill: its root scores,
and whether the moves it rates best solve the puzzle, a second engine sharing only the
rules with the solver. It plays for material, so it is not asked about crowning.
`test/perft.py puzzles international puzzles/international.txt` plays every line with
the independent generator, checking each move and each position's moves against
`build/perft`. `tools/puzzles.goose try FEN GOAL MOVES` and `find` help compose new ones.
