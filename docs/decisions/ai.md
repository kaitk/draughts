# Computer player decisions

The decisions behind the computer player, dated, with their reasons and the self-play
behind them. How it plays now: [Architecture: Computer player](../architecture/ai.md).
The full tables of the 2026-11-09 tuning rounds are in git history
(`git log -S 'Easy a hair stronger' -- docs/decisions/ai.md`).

## Thinking on a worker

A worker, not slices of the search on the drawing thread (2026-11-08): hard takes up to
0.2 s on the tablet's big cores and 0.65 s on its little ones, 20 to 60 uneven frames if
sliced.

## Search

The transposition table is 4 MB: against 2 MB hard's searches are a fifth faster on the
Mac and a ply deeper in International middlegames; 8 MB was slower then, when it was
cleared each search, and wasn't measured again since.

The table isn't cleared for each search (2026-11-14): an entry carries the search's
generation in its spare byte, and one of another generation is a miss. Clearing 4 MB had
cost more than easy's whole search: easy went from 0.43 M to 2.7 M nodes a second in
`tools/aibench`, with the same moves and the same games in 1,338 games of `aimatch`.
Rejected: keeping earlier searches' entries as hints, which makes a reply depend on what
was searched before.

The node limit stops a search mid-iteration and drops that iteration (2026-11-14).
Rejected: not beginning an iteration predicted not to finish, which saved hard 30 to 40%
of its nodes but cost it plies: 0.475, 0.417, and 0.517 against hard without it over 120
games a variant (Russian, International, Brazilian).

## Evaluation (2026-11-14)

What hard knows at the leaves limits it (9 to 12 plies in Russian and Brazilian, 7 to 8
in International), so three terms cheap on the bitboards joined material, advance, back
row, and centre: a runaway man (most of a king, less the further it has to go), a king on
the main road (+10) or with no empty square beside it (−25), and men unevenly spread over
the wings (−2 a man). New against old, `aimatch`: hard 0.550, 0.622, 0.553 (180 games a
variant), medium 0.542, 0.634, 0.550, easy within the noise (400 games). The levels'
ladder measured again within its noise, so the table, skills, and ratings stand; a man
stays 100, and the judge's marks barely moved. Rejected: trading down when ahead (no
gain, and it stretches scores past a man of 100); tempo, which the advance table counts;
endgame tables of kings against men. Each weight is a first plain value, not tuned.

## Levels

- Medium starts at skill 40 (2026-11-08); easy is a new player's default (2026-11-09).
- Easy starts at 8, and a win in a player's very first game on a level moves the skill 16
  (2026-11-11, replacing the start at 0 of 2026-11-09): a grown-up found easy at 0 too
  weak, and the app is for all ages. One win takes it to 24, past 15, where it no longer
  hangs a piece to a one-piece capture; a first loss still brings it to 0. Self-play,
  400 games a pair: 8 against 0 scores 0.57 to 0.59. Rejected: starting at 4 (changed
  little), +16 for every early win. A level no game has ended on reads as its start.
- A player's first three games on a level move the skill by 8, not 4 (2026-11-09).
- Play again and start over begin at the skill as adapting left it (2026-11-09).
- Easy's start and overlooks are to be tuned once the child has played them more.

## Easy's pace

Easy was made much slower on 2026-11-09, most where something can be taken: it had spent
0.15 of its clock capped at 4 s. Over whole games of easy against itself a move now takes
about 3.6 s on 5+3 and 6.0 s on 10+5, at most 12 (`test/game/pace.goose`, whose ranges
for easy's mean are 2.5–5 s and 4–8 s).

## Mistakes where a person makes them

Easy and medium err where a person does: more where captures are around, less in a quiet
position, where an obvious blunder looks like a machine. In chess every strength errs more
in complex positions (Guid and Bratko, 2006 and 2011; Regan and Haworth), and tactics are
among the strongest signals of a human blunder (Maia, McIlroy-Young et al., 2020). Before,
easy overlooked with a flat chance (60 and 90 per thousand at 0), mostly in quiet
positions.

### Mistakes by tension (2026-11-09)

Task 053. `build/aimatch VARIANT A B 400 --hangs` counts moves that hang a piece; a
position is tense when the side to move must capture or the other side could. Hanging
moves per 100 games at skill 0 against 10, quiet then tense, went from 36, 12 to 6, 32 in
Russian (72, 22 to 10, 79 in International), and easy at 0 scored about as before against
the fixed yardsticks. Fifteen skill points still win 80 to 97% at the bottom of the scale
and 63 to 75% from 25 to 40, which adapting's steps rely on.

The two-piece overlook at skill 0 was then tuned the same day: 160 per thousand (task 053)
→ 300 ("a touch weaker": of the easy-only knobs, it weakened easy most for the fewest
quiet hangs) → 240 (the user found 300 "a little too much"). Skills from 25 on, medium
and hard, play as before.

## Judging moves and ratings (2026-11-11)

Task 074, a history of games rated as GoDraughts rates them.

- Marks by the fall in the expected result, as lichess and chess.com mark moves, not by
  the score lost: a score lost in a won game is no mistake. (The cut-offs were replaced by
  lidraughts', below.)
- One search a move gives the best and the played move's score, bounded past 2.5 men.
- Judged on the worker, last in line, so the reply and the hint never wait.
- Elo, not Glicko-2: FMJD rates by Elo, and a child's few games against a fixed opponent
  gain little from a deviation. Per draughts, as FMJD's lists are; K 40 for the first 20
  games, FMJD's for juniors.
- A game played on from a replay counts for nothing (2026-11-13, task 078): no rating, no
  skill adapted, nothing in the history; it plays at the past game's skill.
- The computer is rated from self-play, skill 0 anchored at 500, so easy's start (587)
  sits under a new player's 800, as GoDraughts shows "Easy 800".

## Lidraughts' marks and the judge's hint (2026-11-14)

A move the hint had shown was marked ??: the hint searched at 15 above the computer's
skill, and gave a blunder up to skill 40.

- The hint is the judge's best move (`ai::judged_best`) at full strength whatever the
  level: a hint the list then marks a blunder teaches nothing, and the judge's 300,000
  nodes answer within hard's time.
- Lidraughts' curve and cut-offs (`Advice.scala`): a unit of 2.5 men and falls of 0.0375,
  0.075, 0.15 of a game, replacing a unit of a man with chess.com's 0.05, 0.10, 0.20,
  which marked about 1.8 times as harshly. Letting a forced win go for under six men is a
  blunder, as lidraughts' lost-win rule marks it.

## Draws offered and giving up (2026-11-22)

Task 112. Testers asked for a draw offer and a way to give up: a kings' ending ran its
rules' count to the end (up to 60 moves each), and start over cancelled a lost game for
nothing, so a loss could be dodged and never reached the rating.

- **Giving up** goes through start over: in a game against the computer, from the child's
  fifth move, start over asks "Give up this game?" over the dimmed board. Giving up is a
  loss: the history, the rating, and the skill count it as the computer's win. Before the
  fifth move, in a friend's game, in a game played on from a replay, and once the game
  has ended, start over stays free. This replaces "a game started over or replaced
  before it ends doesn't count" (2026-11-09, `ai.md`'s "Skill"), which let a loss be
  dodged. Rejected: a give-up tile of its own, one more tile for a rare act.
- **The computer's answer** to "Offer draw" is at once, from the score of its last search
  (`offer::accepts_draw`): it accepts unless it is winning by half a man or more. The score
  misjudges kings' endings that are dead draws, two kings against one looking won, so a
  check on the material comes first (`offer::dead_draw`): only kings on the board, and the
  stronger side with at most two, or three against a lone king on the long diagonal.
  Rejected: a search of its own for the answer, a wait for an answer that the last
  search already gives.
- **A refusal** keeps the tile dim for the child's next five moves, so tapping until yes
  doesn't work.
- **The computer offers** a draw once a game (`offer::offers_draw`), after its own move, when
  both sides have a king and the material is a dead draw, or only kings stand and its
  score is within a fifth of a man of even. Play on says the child wants to win, so it
  never asks again; the child can still offer.
- **An agreed draw** counts as a draw: ½ for the rating, the skill left as it is, a line
  in the history. In a friend's game the draw tile ends the game at once with no second
  player's say, and undo takes it back as it takes back any ending; asking the other
  player first was a lot of code for a corner case.
- Each counts once: an ending taken back by undo and ended again counts no more, as a
  win taken back does.
