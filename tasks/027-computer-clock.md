# 027: The computer spends its clock as a player of its level would

Status: in-progress

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

- [x] With a clock, the computer's time per move varies with the position and the clock
      left, and its total over a game is in a range set per level (record the numbers):
      `game/pace.goose`, ranges and numbers below (2026-11-08)
- [x] Forced captures and single moves still come quickly: a single move (a lone capture
      too) after the level's pause, a choice among captures half an ordinary choice
- [x] Without a clock nothing changes: the pauses, the pulse, and every no-clock line of
      `test/game/computer.goose` are as they were
- [x] Headless test over whole games at each level and clock: no loss on time, and the
      time used is within the level's range (`test/game/pace.goose`, below)
- [ ] Checked on the tablet: idle while waiting (no frames beyond the clock's second).
      Checked on the Mac (below); the tablet after merging.

## The rule (2026-11-08)

`pace::seconds` (`game/pace.goose`), a pure function, gives the time from the computer's
turn to its move while its clock runs:

- What it could spend each move and keep its clock: `left / 30 + increment`. That falls
  as its clock runs down, so it spends less when low.
- A share of that by level for an ordinary choice (three close moves): easy 0.15, medium
  0.3, hard 0.45.
- Times how hard the choice is: the close moves (`ai::close`, the moves whose root scores
  are within 0.15 of a man of the best, as far as the level's margin scores them exactly)
  over three, from one third (one move stands out) to five thirds (five or more). A
  choice among captures takes half; a single move, a lone capture too, only the pause.
- The first moves come quickly, as a player knows them: the time grows from 1/12 at the
  first ply to all of it from the 12th (the board's history length).
- Never more than 4, 8, or 15 s by level, nor more than a tenth of its clock; never
  less than the level's pause (0.8, 0.6, 0.45 s) unless a tenth of its clock is less.
- White's first move is untimed, so the computer playing white makes it after the pause.

Wiring: the worker's `Thought` carries `close`; `game::answer` takes it and sets the
game's `wait` from the clock as it stands; the move comes `wait` after the turn began.
The search is unchanged and stops at its own depth, so strength is the same.

Why these numbers: a child's opponent should feel like a person across the table, not a
clock-watcher. Easy is a beginner who plays at once and rarely thinks long: about 2 s a
move, at most 4 even on 10+5. Medium thinks a little on choices, up to 6.5 s on 5+3.
Hard visibly stops on a real choice, up to about 10 s on 5+3 and 15 on 10+5, but plays a
clear move in 2 s, and it never sits longer than a child would wait without wondering.
The tenth-of-the-clock cap keeps it from running low: with the increment the clock
settles (the worst case below never goes under 13 s), so it can't lose on time from a
start equal to the child's.

At the start of the clock, past the opening (`test/game/pace.goose`):

| | One move | Captures | Close moves 1 | 2 | 3 | 4 | 5+ |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 5+3 easy | 0.80 | 0.97 | 0.80 | 1.30 | 1.95 | 2.60 | 3.25 |
| 5+3 medium | 0.60 | 1.95 | 1.30 | 2.60 | 3.90 | 5.20 | 6.50 |
| 5+3 hard | 0.45 | 2.93 | 1.95 | 3.90 | 5.85 | 7.80 | 9.75 |
| 10+5 easy | 0.80 | 1.88 | 1.25 | 2.50 | 3.75 | 4.00 | 4.00 |
| 10+5 medium | 0.60 | 3.75 | 2.50 | 5.00 | 7.50 | 8.00 | 8.00 |
| 10+5 hard | 0.45 | 5.63 | 3.75 | 7.50 | 11.25 | 15.00 | 15.00 |

Hard on 5+3 with five close moves: 1.6 s at ply 1, 4.9 at ply 5, 9.75 from ply 11; with
its clock at 120 s 5.25 s, at 60 s 3.75, at 30 s 3.0, at 10 s 1.0. The worst case, 300
moves each its hardest choice after the other side's 1.5 s capture on its clock: never
under 13.5 s, 16.5 at the end.

## Ranges and whole games (2026-11-08)

Each level against itself on each clock (the longest games it meets: about 60 moves a
side), time simulated as the app spends it: a side's clock runs from the start of the
other side's move (its animation) until its own move starts. The range is the mean time
a move over a level's games; the most a move is the level's cap.

| Mean seconds a move | Easy | Medium | Hard |
| --- | --- | --- | --- |
| Range, 5+3 | 1.5 to 3 | 2.5 to 5 | 3.5 to 7 |
| Range, 10+5 | 2 to 4 | 4 to 8 | 5.5 to 11 |

Full strength (hard at 800,000 nodes), built, 4 Russian and 4 International games each
(a copy of the test with `GAMES = 4`, `NODES = ai::NODE_LIMIT`):

| | Plies a game | Mean | Most | A side's most in a game | Its clock's least | Lost on time |
| --- | --- | --- | --- | --- | --- | --- |
| 5+3 easy | 114 | 2.40 s | 3.56 s | 232 s | 296 s | no |
| 5+3 medium | 105 | 3.51 s | 6.79 s | 292 s | 199 s | no |
| 5+3 hard | 124 | 4.13 s | 9.88 s | 388 s | 153 s | no |
| 10+5 easy | 114 | 3.09 s | 4.00 s | 292 s | 600 s | no |
| 10+5 medium | 105 | 5.30 s | 8.00 s | 430 s | 498 s | no |
| 10+5 hard | 124 | 7.54 s | 15.00 s | 716 s | 299 s | no |

The test itself (one game of each variant, hard at 20,000 nodes, about 12 s through
TinyCC): 5+3 2.20, 3.81, 4.20 s a move; 10+5 2.91, 5.78, 7.69; none lost on time, all in
range. Hard spends only a little more than medium on average: its margin scores fewer
moves exactly, so fewer count as close, and it thinks long on fewer moves.

## Idle while it waits (Mac, 2026-11-08)

The pulse no longer runs the whole wait: it pulses once (1.2 s, the cycle it had) and
the ring then stays full, the clock's second showing that it thinks. The game tells the
app when the move is due (`game::due`) and the app's timer (`wake.c`) wakes the loop
then. Without a clock the waits are under the pulse, so nothing there changed.

Built app with a draw log (removed after), `--variant russian --screen game --computer
black --level hard --clock 5+3 --tap c3 --tap d4`, before the opening ramp: hard took
9.75 s over its first reply. Draws: every vsync for the pulse's 1.2 s (and the search's
0.1 s before its answer), then one a second, at the clock's seconds (8), then the move
at 10.055 s against 10.051 due. With `--clock 10+5`, after the ramp: 3.12 s, the pulse
until 1.50 s, draws at 2.10 and 3.10, the move 1.3 ms after it was due. Once the reply
landed, one draw a second for the child's clock. On the Mac the loop doesn't wait
(rendering.md), so the timer for the due move matters on the tablet; there it should
show as the move starting within a frame of its time.

## Open for the user

Taken as defaults, each easy to change in `game/pace.goose`:

- The shares (0.15, 0.3, 0.45), the caps (4, 8, 15 s), the horizon (30 moves), the
  close window (0.15 of a man), and the opening ramp (12 plies). Retune after children
  have played against the clock.
- The pulse runs once, then the ring holds still while the clock counts; the
  alternative, pulsing the whole wait, draws every vsync for up to 15 s.
- The opening ramp counts the board's history, so a game from `--fen` (or any set
  position) plays its first moves as an opening.
- No randomness in the time: the same position and clock take the same time; the close
  count and the clock make it vary from move to move.
- It doesn't watch the child's clock: it neither hurries when the child is low nor
  slows to match a slow child.
