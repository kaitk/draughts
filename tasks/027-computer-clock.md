# 027: The computer spends its clock as a player of its level would

Status: todo

Against the clock the computer now answers after a fixed pause (0.8, 0.6, 0.45 s by
level, task 006), whatever the clock and the position. Over a 5 or 10 minute game its
clock barely moves, so a child racing it on time never sees it think, hurry, or run
low. It should spend its time as a person of its level would: more on a hard choice
than on a forced capture, more early in the clock than when low, and more on hard than
on easy, without playing better or worse than its skill for it.

## Work

- A time per move from the level, the clock left, the increment, and the position: a
  forced or only move quickly, a quiet choice among close scores longer (the search's
  root scores say how close), less when the clock is low.
- The pause becomes that time; the search still runs on the worker and stops at its own
  depth, so the time only decides when the move is played. Without a clock the pauses
  stay as they are.
- It never loses on time while the child's clock has more left than its own at the start.

## Acceptance criteria

- [ ] With a clock, the computer's time per move varies with the position and the clock
      left, and its total over a game is in a range set per level (record the numbers)
- [ ] Forced captures and single moves still come quickly
- [ ] Without a clock nothing changes
- [ ] Headless test over whole games at each level and clock: no loss on time, and the
      time used is within the level's range
- [ ] Checked on the tablet: idle while waiting (no frames beyond the clock's second)
