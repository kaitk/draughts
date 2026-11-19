# 03: Take puzzles and kings

Status: done

"Win N men" mustn't teach a trade a game would lose: a king is worth more than a man
unless it is lost at once. The checks now refuse a line that leaves the other side a
king; look at the rest in detail.

- 870 library puzzles (309 International, 328 Russian, 230 Brazilian) have a wrong
  first move whose line makes the solver a king, so the solver may call a fair move
  wrong. Sample them against the computer player.
- Weighting kings at three everywhere changes 230 International puzzles, 221 of them
  takes, mostly a shot whose last capture crowns.

## Measured (2026-11-19)

Every library puzzle was measured, not sampled: the kings check of
[02](02-kings-in-the-solver.md) scores each first move with the computer player
wherever a line makes a king for either side, more widely than the wrong moves' lines
above, so 5,432 of 7,920 puzzles were checked. 406 were dropped (192 International, 92
Russian, 122 Brazilian); the numbers by theme, the margin, and examples are in 02.

| Kind | Checked | Dropped |
| --- | --- | --- |
| Take (shots, king shots, captures) | 3,847 (1,505, 1,317, 1,025) | 395 (181, 92, 122) |
| Safe move (International) | 40 | 11 |
| Crowning | 1,545 (544, 522, 479) | none: always passes |

A take is dropped mostly where a wrong move the engine scores as well or better crowns
(International 1488: 24-29 +302, 8-13 +303) or wins outright (Brazilian 2079: e5-f6 +618,
e5-d6 a forced win). Crowning puzzles pass whatever the engine scores, as their goal is
the king and the engine judges by material; 521 would have failed otherwise.

The built-in puzzles the check refuses are to be replaced: the list is in
[04](04-refill-the-libraries.md).

## Acceptance criteria

- [x] Each group sampled against the computer player, with the numbers here
- [x] The puzzles that teach a bad trade or turn down a fair move dropped or fixed:
      library ones dropped; the built-in ones listed for replacing in 04
