# 07: One-glance captures and International 32

Status: done

- Russian's library has puzzles where only one capture takes the N the goal names, so the
  goal gives the answer away; 25 are rated 500 or more (18 at 800 and up), International
  and Brazilian one each. Rate them as the easiest band, or drop them, and make `rate`
  see it for new ones.
- International's course puzzle 32 (Captures level 1) is now a single legal move: its
  second double was moved on 2026-11-09 to remove a rival, which removed the choice too.
  Make it a choice again (a second capture that is taken back) without the rival.

## One glance

`rate` (`tools/puzzles.goose`) marks a puzzle at a glance (`at_a_glance`): one move, more
than one legal, and only one of them crowns, for a crown, or takes as many as the goal's
N, for a take. Its difficulty then counts none of the computer's misses; the rest of the
estimate stays. `rate`'s shape column prints it as a ninth number.

Measured 2026-11-19 with the study's scratch classifier (its class G, the same test): the
libraries hold 153 such puzzles in Russian, 42 in International, and 5 in Brazilian. Of
them, 27 were rated 500 or more:

| Library | 500 or more | 800 or more | Were | Now |
|---|---|---|---|---|
| Russian | 25 | 18 | 501 to 1,461 | 300 to 406 |
| International | 1 (1368, crown in 1) | 1 | 841 | 341 |
| Brazilian | 1 (777, crown in 1) | 1 | 800 | 300 |

Russian's are 11 shots (level 1, a king's capture of three), 10 captures, and 4 crowns
in 1. The computer missed them at skills up to 100 (misses 15 to 125) because it reads
past the goal; a child counts the pieces.

Re-rated, not dropped: they are sound puzzles (every check, the kings check), and the
easy band is where beginners start. Re-rating keeps each id, so no player's had or
today's puzzles move. `tools/library.py rerate` sets the new difficulties from `rate`'s
output and sorts the file as `assemble` does (difficulty, then position); with no
changes it rewrites each library byte for byte. Afterward no one-glance puzzle is rated
500 or more (the highest: Russian 466, rated before and left as it was). The 173 rated
under 500 before were left: re-rating them would only lower them a little.

For 04: these 27 no longer count among the captures from 500 up that lack a real choice.

## International 32

Before: `W:W25,27,34,43,44,50:B3,4,21,26,32,33`, one legal move, 27x38x29.

Now: `W:W25,27,34,43,44,47,50:B3,4,13,21,22,26,32,33`, line 27x38x29. The man on 27 has
two doubles: backward over 32 and 33 to 29, safe, or forward over 22 and 13 to 9, which
3x14 takes back (the line the screen plays for it, 2 plies). The forward one is where a
child looks first, so the choice is real; the rival reported on 2026-11-09 (39x28x37,
taken back by 21x32x41) stays out. White's 47 keeps black's men on the left from running
to crown: without it the computer player scored the right move −219.

Found by placing one white man and up to two black men round the old position (a scratch
search over `test/perft.py`'s generator and `build/puzzles try`), keeping those where
27x38x29 is the only right move, every wrong capture's last stop is taken back, and the
checks pass.

- `build/puzzles`: 0 problems, 0 rivals; the computer player plays 27x38x29 and scores it
  +88 (the set's count of right moves scored as losing stays 4, none of them 32).
- `build/puzzles kings`: 32 makes no king and isn't checked; with `--every`, 27x38x29 +88
  and 27x18x9 −7. The set's one failure is 92, listed in 04.
- `test/perft.py puzzles international`: 84 puzzles, 0 problems.
- The set's test output changes only in 32's piece count (12 to 15).

## Acceptance criteria

- [x] No one-glance capture rated at 500 or more; `rate` keeps new ones low
- [x] International 32 has a real choice and passes `build/puzzles` and the kings check
