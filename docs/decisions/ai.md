# Computer player decisions

The decisions behind the computer player, dated, with their reasons and the self-play
behind them. How it plays now: [Architecture: Computer player](../architecture/ai.md).

## Thinking on a worker

A worker was chosen over slices of the search on the drawing thread (2026-11-08): hard
takes up to 0.2 s on the tablet's big cores and 0.65 s on its little ones, which sliced
into frames is 20 to 60 frames of 10 ms each, and the slices make the frames uneven.
On a worker the frame loop draws as it would without the computer.

## Search

The transposition table is 4 MB: against 2 MB it makes hard's searches a fifth faster on
the Mac and a ply deeper in International middlegames; 8 MB was slower than 4, clearing
it costing more than it saved.

## Levels

- Medium starts at skill 40 (2026-11-08).
- Easy starts at 0 (2026-11-09; replaced by the start at 8 below, 2026-11-11); it started at 10 until then. A player's file still at
  that old start has had no game that moved it, and starts afresh at 0.
- Easy starts at 8, replacing the start at 0, and a win in a player's very first game on a level moves the skill
  16 (2026-11-11), after a grown-up found easy at 0 too weak even after winning a game on
  8 × 8 boards. The app is for all ages now (`store/play-console.md`). At 8 easy follows
  a capture chain one ply further and overlooks a one-piece capture 5 times a thousand
  against 25 and a two-piece one 110 against 240; one win takes it to 24, past 15, where
  it no longer hangs a piece to a one-piece capture. A young child's first loss (a step
  of 8) still brings easy to 0, so it is never harder for them than before. Rejected:
  starting at 4, which changed little (13 and 169 per thousand, the same plies); and a
  +16 for every early win, since a child's later wins should find them slowly. A level
  no game has ended on reads as the level's start now, so files from before start at 8.
  Self-play, 400 games a pair: 8 against 0 scores 0.57 to 0.59, about level with 10;
  15 against 8 scores 0.82 to 0.89 (the table in the architecture's levels).
- The default level for a new player, and for settings read fresh, is easy
  (2026-11-09), after a young player found easy hard.
- A player's first three games on a level move the skill by 8, not 4 (2026-11-09), so the
  skill finds the child sooner.
- Play again on the end's card and start over during a game begin at the level's skill as
  adapting left it, and count for the seeds as home's play does (2026-11-09); they had
  replayed at the old skill.
- Easy's start and its overlooks are to be tuned once the child has played them more.

## Easy's pace

Easy was made much slower on 2026-11-09, especially in positions where something can be
taken; it had spent 0.15, capped at
4 s, and taken half on a choice among captures. Its planned seconds past the opening
with its clock full (5+3 and 10+5) and on 10+5 with 2 minutes left, from
`test/game/pace.goose`, its own search giving the close moves:

| Position | Before: 5+3, 10+5, 10+5 at 2 min | After |
| --- | --- | --- |
| Quiet (10×10 start, 9 close) | 3.25, 4.00, 2.25 | 4.33, 8.33, 3.00 |
| A man threatened, 3 close | 1.95, 3.75, 1.35 | 9.10, 12.00, 6.30 |
| A choice of 2 captures | 0.97, 1.88, 0.80 | 6.07, 11.67, 4.20 |
| Quiet, one move standing out | 0.80, 1.25, 0.80 | 0.87, 1.67, 0.80 |
| Tense, one move standing out | 0.80, 1.25, 0.80 | 3.03, 5.83, 2.10 |

Over whole games of easy against itself (the test's 2 games a clock) a move took
2.22 s on 5+3 and 2.83 s on 10+5 on average; now 3.38 s and 5.86 s, at most 12, its
clock never under 244 s and 507 s (3.54 s and 5.79 s once task 053's overlooks changed
the test's games, 3.61 s and 6.00 s with the two-piece overlook at 240). The test's ranges for easy's mean are 2.5–5 s and
4–8 s; medium's and hard's are unchanged.

## Mistakes where a person makes them

Easy and medium should err where a person does, more
where captures are around (a long multi-capture, a capture away from the piece just
moved) and less in a quiet position, where an obvious blunder looks like a machine.
In chess every strength errs more in complex positions (Guid and Bratko, 2006 and
2011; Regan and Haworth's model, which the choosing uses, shows the same), and
tactics are among the strongest signals of a human blunder (Maia, McIlroy-Young et
al., 2020). Until then easy overlooked with a flat chance a move, fading to none by
15: at 0, 60 per thousand moves where its piece lands and 90 for a capture its move
opens (a young player had found that easy never missed a capture nor hung a piece,
so every mistake was punished, 2026-11-09); medium never did. Most of those hangs
came in quiet positions. Now they come where captures are around, and easy hangs
about as many pieces as before, so its strength stays (the numbers below).

Easy a touch weaker still (2026-11-09): a two-piece capture is overlooked
at 0 as often as a three-piece one, 300 per thousand where it was 160, fading to none
by 25 as before, so medium and hard are unchanged. It is a mistake of a tense
position, a double capture missed, and of the easy-only knobs it weakens easy most
for the fewest quiet hangs ([easy a touch weaker](#easy-a-touch-weaker-2026-11-09)).
Then a hair stronger again (2026-11-09, the touch weaker found "a little too much"): 240, halfway
back ([easy a hair stronger](#easy-a-hair-stronger-2026-11-09)).

### Mistakes by tension (2026-11-09)

Task 053's before and after.

`build/aimatch VARIANT A B 400 --hangs` counts, for each side, the moves that hang a
piece: after them the other side's captures win a man or more (a minimax over material,
the move and then captures only, four plies), when another move loses less that way,
unless the side's own search shows the material coming back (a sacrifice it sees).
Quiet and tense as above: tense when the side to move must capture or the other side
could capture were it its turn. Hanging moves per 100 games, quiet then tense, each
skill against the one in brackets (each side plays about 35 moves a game in Russian and
Brazilian, 60 in International, one in seven to nine of them tense):

| Skill | Russian, before → after | International | Brazilian |
| --- | --- | --- | --- |
| 0 (against 10) | 36, 12 → 6, 32 | 72, 22 → 10, 79 | 34, 15 → 6, 33 |
| 10 (against 25) | 12, 4 → 3, 16 | 20, 8 → 8, 78 | 11, 5 → 3, 31 |
| 15 (against 0) | 0, 0 → 2, 7 | 0, 0 → 3, 24 | 0, 0 → 0, 7 |
| 25 (against 40) | 0, 0 → 1, 5 | 0, 0 → 3, 31 | 0, 0 → 1, 6 |
| 40 (against 55) | 0, 0 → 0, 1 | 0, 0 → 1, 11 | 0, 0 → 0, 4 |
| 55 (against 40) | 0, 0 → 0, 0 | 0, 0 → 0, 1 | 0, 0 → 0, 0 |

Wins, draws, losses for the first, before → after; adapting's steps rely on 15 skill
points winning about three games in four:

| Pair | Russian | International | Brazilian |
| --- | --- | --- | --- |
| 10 against 0 | 217, 63, 120 → 198, 73, 129 | 221, 67, 112 → 192, 100, 108 | 222, 73, 105 → 198, 75, 127 |
| 15 against 0 | 339, 38, 23 → 320, 45, 35 | 376, 20, 4 → 335, 34, 31 | 336, 47, 17 → 328, 35, 37 |
| 25 against 10 | 367, 27, 6 → 363, 23, 14 | 396, 3, 1 → 386, 12, 2 | 362, 29, 9 → 360, 22, 18 |
| 40 against 25 | 267, 82, 51 → 272, 78, 50 | 274, 93, 33 → 299, 61, 40 | 248, 108, 44 → 252, 105, 43 |
| 55 against 40 | 248, 98, 54 → 252, 92, 56 | 290, 84, 26 → 300, 75, 25 | 255, 97, 48 → 257, 95, 48 |
| Easy at 0 against 10 without overlooks | 108, 62, 230 → 100, 76, 224 | 88, 67, 245 → 69, 89, 242 | 99, 78, 223 → 95, 82, 223 |
| Easy at 0 against 0 without overlooks | 113, 74, 213 → 133, 76, 191 | 98, 87, 215 → 92, 89, 219 | 104, 75, 221 → 117, 91, 192 |

Easy at 0 scores about as before against the fixed yardsticks (skill 0 and 10 without
overlooks, which the change doesn't touch): a little better in Russian and Brazilian, a
little worse in International, where long captures are common. Fifteen points still win
80 to 97% of games at the bottom of the scale and 63 to 75% from 25 to 40, as before.
International's 10 to 25 now hang more in tense positions than the other variants'
(its majority rule makes multi-captures the only replies more often); their win rates
moved little.

### Easy a touch weaker (2026-11-09)

Easy was to be a touch weaker still after task 053, about 3 to 5 points less
for easy at 0 against skill 10 without overlooks, mistakes still where the position is
tense. Easy at 0's score (a win 1, a draw a half) against that yardstick, over 2000
games a variant, for each easy-only knob tried:

| Change at skill 0 | Russian | International | Brazilian | Hangs per 100 games, quiet (Russian) |
| --- | --- | --- | --- | --- |
| None (task 053) | 0.339 | 0.283 | 0.347 | 6 |
| One-piece overlook 25 → 75 | 0.329 | 0.273 | 0.332 | 10 |
| Two-piece overlook 160 → 240 | 0.326 | 0.266 | 0.335 | 7 |
| Two-piece overlook 160 → 300 (chosen) | 0.310 | 0.249 | 0.318 | 9 |
| Chances left 125 → 200 a thousand | 0.344 | 0.286 | 0.336 | 6 |
| Temper 62 → 102 | 0.358 | 0.295 | 0.346 | 6 |

The two-piece overlook takes the most from easy for the fewest hangs in quiet
positions; one-piece captures are mostly of the piece just moved, which shows in quiet
positions too. The chances left change nothing measurable, as skill 10 doesn't look for the
combinations left, and the hotter temper makes easy no weaker, as within the margin it
already chooses nearly evenly. One value fits every variant, International's drop within the range
too, so it gets no adjustment of its own.

Before → after, 400 games a pair (the score's noise at 400 games is about 2 points
either way: the 2000 games above are the surer measure of easy's drop):

| | Russian | International | Brazilian |
| --- | --- | --- | --- |
| Easy at 0 against 10 without overlooks | 100, 76, 224 → 91, 76, 233 | 69, 89, 242 → 53, 69, 278 | 95, 82, 223 → 89, 82, 229 |
| Its score | 0.345 → 0.323 | 0.284 → 0.219 | 0.340 → 0.325 |
| 15 against 0 | 320, 45, 35 → 322, 44, 34 | 335, 34, 31 → 350, 24, 26 | 328, 35, 37 → 327, 33, 40 |
| 25 against 10 | 363, 23, 14 → 368, 20, 12 | 386, 12, 2 → 388, 9, 3 | 360, 22, 18 → 362, 23, 15 |
| Hangs at 0 (against 10), quiet, tense | 6, 32 → 9, 41 | 11, 71 → 14, 90 | 8, 30 → 10, 36 |
| Hangs at 10 (against 25), quiet, tense | 3, 16 → 4, 21 | 8, 78 → 9, 89 | 3, 31 → 5, 39 |

Fifteen points still win 80 to 97% of games at the bottom of the scale; medium and hard
play as before.

### Easy a hair stronger (2026-11-09)

The touch weaker was "a little too much": the two-piece overlook at 0 is 240
per thousand, halfway back toward task 053's 160. Over 2000 games a variant (the table
above) 240 scores 1.6 to 1.7 points better than 300 against skill 10 without overlooks.
Before → after, 400 games a pair (noise about 2 points either way):

| | Russian | International | Brazilian |
| --- | --- | --- | --- |
| Easy at 0 against 10 without overlooks | 91, 76, 233 → 92, 79, 229 | 53, 69, 278 → 61, 83, 256 | 89, 82, 229 → 96, 82, 222 |
| Its score | 0.323 → 0.329 | 0.219 → 0.256 | 0.325 → 0.343 |
| 15 against 0 | 322, 44, 34 → 323, 46, 31 | 350, 24, 26 → 344, 27, 29 | 327, 33, 40 → 337, 27, 36 |
| 25 against 10 | 368, 20, 12 → 363, 23, 14 | 388, 9, 3 → 387, 10, 3 | 362, 23, 15 → 360, 24, 16 |

Skills from 25 on, medium and hard included, play as before.

## The overlooks' history

The overlooks' history, all on 2026-11-09:

- Before task 053: a flat chance a move below 15, 60 and 90 per thousand at 0.
- Task 053: by tension, size, and distance, `MISS` 25, 160, 300, 450.
- Easy a touch weaker: the two-piece 160 → 300.
- Easy a hair stronger ("a little too much"): the two-piece 300 → 240.

## Judging moves and ratings (2026-11-11)

Asked for: a history of games and moves rated as GoDraughts rates them (task 074).

- **Marks by the fall in the expected result**, as lichess and chess.com mark moves,
  rather than by the score lost: a score lost in a won game is no mistake. Chess.com's
  cut-offs (0.05, 0.10, 0.20 of a game) over lichess's win-chance points, which are the
  same at half the scale. The logistic's unit, a man, makes a man up 0.73, which a
  draughts player reads as winning, more than a pawn up is in chess.
- **One search a move** gives the best and the played move's score: the root's scores,
  bounded past a margin of 2.5 men, which at an even position is already a blunder.
- **Judged on the worker, last in line**, so the computer's reply and the hint never wait;
  re-judging a saved game brought back costs the worker a few seconds and keeps the
  saved game's format (`VERSION` 3).
- **Elo, not Glicko-2.** FMJD rates by Elo with separate lists for 64 and 100 squares;
  lidraughts uses Glicko-2. A child's few games a week against a fixed opponent gain
  little from a deviation, and Elo's one number is what a parent knows. Kept per
  draughts, as FMJD's lists are. K 40 for the first 20 games is FMJD's for juniors.
- **The computer rated from self-play**, not by guess, anchored at 500 for skill 0 so
  easy's start (587) sits under a new player's 800, as GoDraughts shows "Easy 800".
