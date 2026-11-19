# 04: Refill the libraries

Status: in-progress (International and Russian refilled; Brazilian not yet)

Dropped puzzles leave their ids unused, so the libraries have holes: by 2026-11-19, 245
International (156 shots, 49 king shots, 27 safe moves, 9 crownings, 4 captures), 96
Russian (81 shots, 11 captures, and 4 earlier), and 132 Brazilian (119 shots, 3
captures, and 10 earlier). The kings check (02) dropped 406 of them; a new puzzle must
pass it too (`build/puzzles kings`). Generate new
puzzles of the same themes, levels, and difficulty bands (`docs/development.md`, "Daily
puzzles"), under the checks as they then stand, so each band keeps its count.

## A real choice from 500 up (2026-11-19)

`puzzles::real_choice` (`src/puzzles/check.goose`): a capture-first puzzle needs three
legal first moves or more, or two of the solver's moves or more, once rated 500 or more
(`CHOICE_FROM`). `rate` prints it as the shape's tenth number, `library.py assemble` and
`candidates` leave out a puzzle without it, and `test/puzzles/library` counts every
library puzzle without it (0).

The README's "2 or more pieces able to capture" was not taken as enough on its own: the
README's counts (33, 28, 31, less the 27 one-glance re-rated in 07) match only a rule
that refuses two-way captures from two pieces too, and "two-way one-move captures stay
for beginners" says the same. Measured: 61 without a real choice (36 one piece with two
ways, 25 two pieces with one each); counting two pieces as a choice would leave 36. Two
one-piece puzzles with three ways or more pass.

| Library | Without a choice | Re-rated under 500 | Dropped |
|---|---|---|---|
| International | 29 | 8 (234, 235, 236, 242, 247, 363, 795, 1439: now 350 to 450) | 21 |
| Russian | 4 (609, 842, 844, 869) | 0 | 4 |
| Brazilian | 28 | 1 (121: 500 to 390) | 27 |

Re-rated by today's `rate` (which no longer gives these the misses it once did); the rest
it still rates 500 or more.

## The one-glance captures and the engine (2026-11-19)

`build/puzzles kings FILE --every` now marks `PREFERS` where the computer player at full
skill scores a wrong first move 50 or more above a right one, crowning and right moves
that win by force aside. Of the 25 Russian one-glance puzzles re-rated in 07, 9 fail and
were dropped: 874, 878, 879, 1001, 2046, 1905 (a wrong capture wins by force, the right
one +400 to +700), 2002 (−111), 1925 (−135), 2026 (−80). 2025 stays: −20, a tie. The 4
crown-in-1s (762, 828, 846 lose to a forced win elsewhere) pass, as the kings check
exempts crowning. International 1368 and Brazilian 777 (crown in 1) pass.

The margin: `kings --every` over the three libraries (before the drops, 21 minutes on
30 processes), non-crowning puzzles whose right moves don't all win by force; the right
move's gap over the best wrong one, in bands of 25:

| Gap | International | Russian | Brazilian |
|---|---|---|---|
| −100 to −75 | 45 | 9 | 14 |
| −75 to −50 | 21 | 6 | 4 |
| −50 to −25 | 25 | 8 | 5 |
| −25 to 25 | 288 | 41 | 50 |

Ties gather at −25 to 25 and a man lost near −100, so 50 (half a man, as the kings
check's). Under it the libraries hold 120 International, 54 Russian (9 of them the
one-glance ones dropped), and 64 Brazilian puzzles the engine plays otherwise. They were
not dropped at first (the brief covered only the one-glance ones); the user chose to drop
them (2026-11-19), and the ones still in the libraries, 110 International, 43 Russian, and
41 Brazilian, were replaced from the refill's spare passed puzzles by `pick.py` (95, 42,
and 40). The replacements rate about 400 lower: the bands of 1400 and 1600 and over went
International 152 and 209 to 159 and 140, Russian 38 and 25 to 28 and 18, Brazilian
(refilled, then swapped) 25 and 24.

## Counts by theme and level

Before 097 (`git show 44b65df:src/puzzles/library-V.txt`), after the drops (a44d456),
and now:

| International | Before | Dropped | Now |
|---|---|---|---|
| captures 1, 2 | 70, 99 | 67, 77 | 70, 99 |
| crowning 1, 2, 3 | 42, 123, 388 | 42, 122, 380 | 42, 123, 388 |
| king shots 1, 2, 3 | 99, 78, 452 | 97, 73, 410 | 99, 78, 452 |
| safe move 1, 2, 3 | 32, 44, 24 | 27, 28, 18 | 31, 39, 24 |
| shots 1, 2, 3 | 710, 489, 929 | 654, 466, 852 | 710, 489, 929 |
| all | 3,579 | 3,313 | 3,573 |

| Russian | Before | Dropped | Now |
|---|---|---|---|
| captures 1, 2 | 44, 48 | 35, 38 | 44, 47 |
| crowning 1, 2, 3 | 29, 121, 373 | 27, 121, 372 | 27, 121, 373 |
| shots 1, 2, 3 | 553, 263, 897 | 513, 256, 857 | 553, 263, 897 |
| all | 2,328 | 2,219 | 2,325 |

| Brazilian | Before | Dropped | Now |
|---|---|---|---|
| captures 1, 2 | 39, 40 | 30, 29 | 30, 29 |
| crowning 1, 2, 3 | 5, 105, 373 | 5, 105, 369 | 5, 105, 369 |
| shots 1, 2, 3 | 493, 288, 737 | 427, 270, 686 | 427, 270, 686 |
| all | 2,080 | 1,921 | 1,921 |

Bands of 200 (200 means 200 to 399; 1600 and up together):

| | 200 | 400 | 600 | 800 | 1000 | 1200 | 1400 | 1600+ |
|---|---|---|---|---|---|---|---|---|
| International before | 166 | 124 | 868 | 764 | 1,069 | 212 | 144 | 232 |
| International now | 177 | 136 | 874 | 747 | 1,068 | 210 | 152 | 209 |
| Russian before | 139 | 69 | 738 | 853 | 292 | 146 | 50 | 41 |
| Russian now | 168 | 71 | 735 | 835 | 300 | 153 | 38 | 25 |
| Brazilian before | 89 | 59 | 726 | 731 | 212 | 148 | 53 | 62 |
| Brazilian now (drops only) | 91 | 55 | 711 | 717 | 192 | 126 | 25 | 14 |

The hard end comes back short: many lost puzzles rated hard because the computer
player missed a move it judged otherwise (the kings check's and `PREFERS`'s cases), and a
capture with a real choice one move deep rates under 500 (International's new captures
2 reach 495 at most, where 9 of the dropped ones were 1,400 or more). International's
1,600 and up: 102 lost, 79 refilled; Russian's: 25 lost, 9 refilled.

## Method and run times (2026-11-19, the Mac shared with other sessions)

Per draughts: `batch` on 10 processes, seeds 9701 to 9710, PER 40, SECONDS 120, every
kind but safe for 8x8 and `crown1-7` for International (`--kinds`), then `--traps`
seeds 9711 to 9720, PER 20, SECONDS 60; `merge`, `split`, `rate`; `library.py
candidates` (no more than 4,096 a file, so two halves), `kings --every`, `passed`; then
a scratch pick (`build/work/pick.py`): for each lost puzzle, hardest first, the unused
passed puzzle of its theme and level nearest its difficulty, a trap kind's preferred
within 150; `assemble` the picks. Every new puzzle passed `puzzles::check` (in `batch`,
the long-line and king-given-away checks among them), the kings check, `PREFERS`, and
the real choice; `test/puzzles/library` checks them all again.

| | Batch | Traps | Rate | Kings | Candidates | Passed | Picked |
|---|---|---|---|---|---|---|---|
| International | 71 min | 8 min | 10 min | 25 min | 6,249 | 5,715 | 260 of 266 |
| Russian | 52 min | 8 min | 10 min | 9 min | 2,454 (no king shots) | 2,201 | 106 of 109 |
| Brazilian | 52 min | 8 min | 3 min | stopped | 2,173 | | |

Traps: International's lost puzzles held 38 traps (24 crown traps), the picks 34.

## Left

Moved to another machine (2026-11-19), to run as long as it takes, a cap of 90 minutes a
kind group. The targets, from the libraries before 097 (2c606a3) against now, are in
`targets-V.txt` next to this file: each theme and level's deficit as the lost puzzles of
it, hardest first, then lost puzzles of 1600 and over until that band is back to its
count before 097:

| | Deficits | 1600+ before → now | Targets |
|---|---|---|---|
| International | safe move 1 9, 2 10, 3 3 | 232 → 140 | 105 |
| Russian | crowning 1 2, captures 2 3 | 41 → 18 | 25 |
| Brazilian | captures 1 4, captures 2 9 | 62 → 24 | 51 |

## Refilled on the Windows PC (2026-11-20)

The three draughts at once, five processes each (8 cores, 16 threads, below normal
priority), the short themes' kinds then the hard ones, `batch SEED 1000 SECONDS --kinds`.
`batch` runs a kind for SECONDS times its share (3 for the hard kinds), so the plan's
2,700 would have run some 11 hours; SECONDS was set from the shares instead:

| | Kinds, SECONDS | Hard kinds, SECONDS | Total |
|---|---|---|---|
| International | `safe-10,safe-15`, 600 (40 min) | `king3-10,king3-12,shot3m-12,shot3m-14,shot4m-12,shot4m-14,shot3t-12,tempo-10`, 545 (200 min) | 240 min |
| Russian | `crown1-7,capture-8,capture-13`, 600 (30 min) | `shot3m-12,shot3m-14,shot4m-12,shot4m-14,shot3t-12`, 840 (210 min) | 240 min |
| Brazilian | `capture-8,capture-13`, 900 (30 min) | as Russian's | 240 min |

Then `merge`, `split` and `rate`, and a scratch filter before `candidates`
(`build/work/keep.py`): only the theme levels the targets hold and, for shots and king
shots, no more than 300 under the easiest target of that level, so a hard target isn't
filled by a far easier puzzle and the kings check runs on fewer; then `kings --every`,
`passed`, `pick.py`, `assemble`, and the tests. Python on Windows writes the library with
CRLF; convert it back to LF before committing.

**International**: 11,444 found (about 120 safe moves, most of the safe kinds' sound
positions seen before), 9,551 new, 968 kept by the filter, 222 passed the kings check
and `PREFERS` (745 failed), all 105 targets picked: 84 of 1600 and over; the 22 safe
moves rate 516 to 1,400, lower than the lost ones, as the count was what they were for.
Every theme and level is back to its count before 097 or more; 3,662 puzzles.

| International | 200 | 400 | 600 | 800 | 1000 | 1200 | 1400 | 1600+ |
|---|---|---|---|---|---|---|---|---|
| Before 097 | 166 | 124 | 868 | 764 | 1,069 | 212 | 144 | 232 |
| Before this refill | 178 | 135 | 874 | 744 | 1,078 | 249 | 159 | 140 |
| Now | 178 | 140 | 878 | 749 | 1,081 | 251 | 161 | 224 |

## Built-in puzzles to replace

The kings check refuses these, or a wrong move in them wins by force, which beats
crowning (2026-11-19). The engine's scores of the right move and the wrong one at fault:

- International 92 (safe move, level 3): 22-18 −59; 39-34 −97, a gap of 38.
- Russian 18 (captures, level 2, take 3): f6:d4:f2:h4 +403; f4:h2 +452.
- Brazilian 64 (safe move, level 1): f6-e5 −110; g3-h2 −128, a gap of 18.
- Russian 30 and Brazilian 30 (crowning, level 3, crown in 3, the same position):
  c3-b4 −91; g3-f4 a forced win (+29985), g3-h4 too.

Replaced (2026-11-19), each by a puzzle that passed every check and the kings check with
`--every`, at a new id, the old id left unused; a crowning puzzle's sacrifice also had to
be the engine's choice (gap 0 or more), though crowning is exempt from PREFERS:

- International 92 by 105: library 1352 (836, black, 33-39), dropped from the library.
- Russian 18 by 67: library 151 (450, black, d6:b4:d2:f4), dropped from the library.
- Russian 30 by 68: a spare (1165, e3-d4 h8-g7 e5-d6 c7:e5 d4:f6:h8), gap 106.
- Brazilian 30 by 67: a spare (906, a3-b4 a5:c3 e3-d4 c3:e5 f4:d6:b8), gap 184.
- Brazilian 64 by 68: a trap found for it (635, black, 12 pieces, f8-e7), gap 373.

## Acceptance criteria

- [ ] Each library's count per theme and level back to what it was before 097, or more:
      International short 21 safe moves, Russian 4, Brazilian 13 (captures)
- [x] New puzzles take new ids; the dropped ones stay unused
- [x] The five built-in puzzles above replaced, each passing the kings check
