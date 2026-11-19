# 02: Kings in the solver

Status: done

The solver counts a king as a man, so a line ending with a king made reads as a loss or a
win it isn't. The computer player counts a flying king as three men (`ai/eval.goose`).

## Tried (2026-11-19)

- A king worth three men at the solver's three plies: right safe moves turn wrong and
  wrong ones right, a king made at the horizon counted whether it lasts or not.
  International's library: 9 safe puzzles change; Russian's built-in 64 loses its answer
  (g3-f4, which the computer player rates best, +112) and Brazilian's 64 gains a second.
- Worth two: neither puzzle fixed.
- Worth three with two plies more past a king made: Brazilian's 64 fixed; Russian's 64
  still has no safe move, and 2833 four (34-40 among them, which the computer player
  scores about two men worse than 18-22).

## Done instead (2026-11-19)

The solver keeps counting pieces. An offline check judges the puzzles where a king is
made: `build/puzzles kings FILE [PART PARTS]` (`tools/puzzles.goose`, `king_check`).

- A first move makes a king when it crowns, when the solver's best play after it over
  `SHOW_DEPTH` plies and the captures due crowns for either side, when a wrong move's
  answer as the screen plays it crowns, or when a file line starting with it, or the
  screen's answer after that line, crowns.
- For a puzzle with such a move, the computer player at full skill scores every first
  move exactly: `ai::begin` with a margin past `2 * INF`, so no root move gets only a
  bound, depth 15 and 14 plies of captures, at most 8 million nodes (depth 9 to 15
  reached for 96% of the puzzles, less where a forced win ends the search; about a
  second a puzzle).
- It passes when every right first move scores at least 50 above every wrong one, of the
  pairs where either move makes a king, or when every right move wins by force (a small
  position, where the engine sees the game's end).
- A crown puzzle always passes (the user's call, 2026-11-19): its goal is the king, and
  the computer player judges by material. Without that, a third of the crowning
  puzzles failed (521 of 1,545), mostly where another move scores as well as crowning
  (International 3497: 12-7 and 19-13 both +231).

The check agrees with the computer player on Russian's 64 (g3-f4 +112, the best wrong
move +7, a gap of 105) and refuses the library's 2833 (18-22 +115; 12-17 +78, 34-40 −20).

### The margin: 50

Gaps over the 3,887 library puzzles with a king made, crowning aside, cluster at −25 to
25 (149: the engine scores a wrong move level with the right one) and around each 100,
the men won, with positional terms on top (215 at 75 to 125); 25 to 75 is a trough (61).
So 50, half a man, splits "as good" from "a man worse". Moving it changes few puzzles:
International fails 174 at 25, 192 at 50, 207 at 75, 243 at 100.

### Only the pairs with a king

Comparing every right move with every wrong one fails puzzles where no king is made at
about the same rate (International 20% of 1,437, Russian 15% of 485, Brazilian 17% of
566) as where one is (25%, 10%, 16%, crowning aside): that strict test mostly finds
rivals and engine ties, which the solver judges by its own rules and `puzzles::rivals`
reports. Taking only the pairs where either move makes a king fails 12%, 7%, and 12%.

### Numbers (2026-11-19)

30 processes over 10 cores: 832 s for the puzzles with a king made, 867 s for every
puzzle with `--every` (which marks the moves that make a king with `*`).

| Library | Puzzles | Checked | Crowning (passed) | Dropped |
| --- | --- | --- | --- | --- |
| International | 3,526 | 2,089 | 544 | 192 |
| Russian | 2,324 | 1,839 | 522 | 92 |
| Brazilian | 2,070 | 1,504 | 479 | 122 |

By theme, checked and dropped:

- International: shots 1,196, 133; king shots 292, 45; safe move 40, 11; captures 17, 3.
- Russian: shots 1,279, 81; captures 38, 11.
- Brazilian: shots 1,004, 119; captures 21, 3.

The built-in sets (36 International, 43 Russian, 32 Brazilian puzzles with a king made)
are kept; the ones to replace are listed in [04](04-refill-the-libraries.md).

Examples from the libraries:

- Brazilian 2079 (shots, take 2 in 2), dropped: e5-f6 +618; e5-d6 a forced win.
- International 1488 (take 2 in 4), dropped: 24-29 +302, 8-13 +303.
- Russian 1619 (shots, take 2 in 3), kept: e3-d4 +581, the best wrong move −43.
- Russian 1690 (crown in 3), kept by the exemption: e3:c5:a7, crowning, +212;
  e3:c5:a3 a forced win.

## Acceptance criteria

- [x] The solver, or a check by the computer player, agrees with the computer player on
      every built-in puzzle and on 2833, 34-40 wrong: the check agrees on Russian's 64
      and refuses 2833; the built-in puzzles it refuses are to be replaced (04)
- [x] What a king is worth recorded in `docs/decisions/puzzles.md`
