# 007: Puzzles

Status: todo

Puzzles in a plain text file: a position, the side to move, a goal ("win material",
"crown", "capture all") and the solution lines. A move that reaches the goal by a
different line counts too. About 30 for Russian 8×8, in three tiers.

## Acceptance criteria

- [ ] Format documented, loaded at startup, validated by the rules engine (every solution legal)
- [ ] Tier 1: find the capture; tier 2: multi-jumps and mid-capture crowning; tier 3: shots
      and "the only safe move"
- [ ] Wrong move: a gentle undo and retry. Hint: highlight the piece to move
- [ ] Sources recorded per puzzle, with licenses checked
