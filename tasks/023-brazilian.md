# 023: Brazilian draughts

Status: in-progress

Brazilian draughts is International's rules on an 8×8 board: men capture backward, kings
fly, the capture that takes the most is compulsory, and a man is crowned only where its
move ends (FMJD art. 3.5 and 4.15). Lidraughts counts as many Brazilian players as
Russian (task 019). Settings and a new game's setup offer it (rendering.md "Home",
"Settings"); the first start keeps two cards, International and Russian.

## Work

- `rules/`: a `BRAZILIAN` variant as data, International's rules at 8×8 with white
  first; `rules.md`'s table gets its column.
- `test/perft.py` learns it independently; check published Brazilian perft counts, and
  sweep random games with `compare`.
- `ai/`: the evaluation's weights for it, and `test/ai/` positions.
- The tutorial for it is International's steps on the 8×8 board.

## Acceptance criteria

- [x] Perft counts match published Brazilian counts and `test/perft.py` over random games
- [x] The rules tests cover majority capture and crowning only at the end on 8×8
- [ ] Settings and the setup start a Brazilian game

## Measured

Perft from the start, 2026-11-08. Published: Rein Halbersma's generator (2009) and
Jan-Jaap van Horssen's (2017, "confirmed"), both counting a capture once per start, end,
and set of pieces taken, as `rules/` does: <https://damforum.nl/viewtopic.php?t=2666>
(posts `p=76675` and `p=120133`). Two engines on GitHub agree through depth 6
(py-draughts `test/test_move_generation_perf.py`, shadow-checkers `tests/test_variants.gd`).

| Depth | Published | `build/perft` | `test/perft.py` |
| --- | --- | --- | --- |
| 1–4 | 7, 49, 302, 1469 | same | same |
| 5 | 7473 | 7473 | 7473 |
| 6 | 37628 | 37628 | 37628 |
| 7 | 187302 | 187302 | 187302 |
| 8 | 907830 | 907830 | 907830 |
| 9 | 4431766 | 4431766 | 4431766 |
| 10 | 21560022 | 21560022 | 21560022 (120 s) |
| 11 | 105491257 | 105491257 (8.8 s, 12.0 M/s) | |

The same thread also gives counts that keep a capture once per path (depth 8 907836);
those differ from depth 8 on and between the two authors from depth 10, so they are not
a check here.

`test/perft.py compare brazilian 200 150`: 9538 positions, 0 differ (28 s).
`scripts/test.sh` checks depth 9 and sweeps 40 games of 120 plies (1849 positions).

`test/rules/brazilian.goose`: majority capture by a man, by a man taking backward, and by
a flying king; a white and a black man crossing the far row mid-capture and ending as men;
a capture ending on the far row crowning, where Russian's new king would fly on.

## Open for the user

- Squares are written a1..h8 as in Russian (lidraughts shows Brazilian with letters and
  numbers too); numbered squares (1–32, as Halbersma's FEN) would be one flag in
  `rules::VARIANTS`. Reading accepts both either way.
