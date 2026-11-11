# 074: Games' history, marked moves, and a rating

Status: in progress (designed, prototyped, and built on the `history` branch
2026-11-11; the takes to choose, the screens to check on the Mac and the tablet)

A family asked for a history of the games played, minimal at first, and moves rated as
GoDraughts rates them: was a move a blunder or not (2026-11-11). Three parts:

1. **The moves of the game in progress**, each marked by how good it was, on the game
   screen where there is room, and hidden by a per-player setting for a child it would
   only crowd or discourage.
2. **The games played**, kept per player, with a screen of their own: the rating, wins,
   draws, and losses by level, and the recent games.
3. **A rating** per player and draughts, on the Elo scale chess and draughts players
   know, from games against the computer, whose levels get ratings of their own.

## What others do (searched 2026-11-11)

- **FMJD** rates players by Elo, with separate lists for 100 and 64 squares
  (FMJD Annex 9). **Lidraughts** uses Glicko-2 (a deviation and a volatility beside the
  rating), and warns that numbers from different systems don't compare.
- **Move marks**: lichess marks a move by how much it lowered the mover's chance to win:
  inaccuracy (?!), mistake (?), blunder (??) at 10, 20, and 30 points of its
  win-chance scale (−1..1). Chess.com uses expected points lost: 0.05, 0.10, 0.20. Both
  turn the engine's score into a chance through a logistic, so a move that keeps a won
  game won is no blunder whatever it costs.
- GoDraughts shows the computer as "Easy 800" and a move list with the last move lit.

## What was built

How it works now is in `docs/architecture/ai.md` ("Judging a move", "Ratings"),
`rendering.md` ("The moves panel", "The games screen"), and `README.md` ("Players"); the
reasons in `docs/decisions/ai.md` and `rendering.md`, 2026-11-11.

- `src/ai/judge.goose`: a move judged by the fall in the mover's expected result (one
  search of the position before it, at skill 100's depth, 300,000 nodes at most); the
  marks best, good, ?!, ?, ??, and the only move; lichess's accuracy.
- `src/ai/rating.goose`: the computer's rating by skill from self-play, a player's Elo
  update (from 800, K 40 for 20 games then 20, per draughts).
- `src/game/notes.goose`: the moves read off the undo history with their marks, judged on
  the worker (`game::JUDGE`, last after the computer's move, the hint, and the traps);
  the moves panel.
- `src/shell/history.goose`, `record.goose`: `history-N.txt`, a game written when it ends
  and again once its marks are in; the rating moved by a game against the computer.
- `src/shell/games.goose`: the games screen, from who's playing's new tile.
- The `moves` setting (off, moves, marks; default marks) in the player's file, set on the
  games screen.
- Tests: `test/ai/judge` (marks in known positions, the cut-offs, the ratings),
  `test/shell/history` (a game judged as played, written, its marks filled in, ratings,
  start again, the file capped), `test/shell/games` (the screen's taps and layouts).

### The computer's ratings (2026-11-11)

`build/aimatch international A B 200`, A's score, and the gap it gives:

| Skills | Won | Drawn | Lost | Gap |
| --- | --- | --- | --- | --- |
| 0 – 8 | 59 | 33 | 108 | 87 |
| 8 – 12 | 13 | 13 | 174 | 387 |
| 12 – 16 | 68 | 37 | 95 | 47 |
| 16 – 20 | 76 | 32 | 92 | 28 |
| 20 – 25 | 13 | 13 | 174 | 387 |
| 25 – 30 | 64 | 58 | 78 | 24 |
| 30 – 40 | 23 | 27 | 150 | 260 |
| 40 – 50 | 16 | 42 | 142 | 257 |
| 50 – 60 | 16 | 53 | 131 | 227 |
| 60 – 90 | 0 | 13 | 187 | 589 |
| 8 – 25 (check) | 0 | 7 | 193 | 700 |
| 25 – 40 (check) | 18 | 37 | 145 | 260 |

The chain 8 to 25 (849) was scaled to 775, between it and the direct match. Russian came
out a little closer (0 – 8: 61, 37, 102, a gap of 72; 8 – 25: 440; 25 – 40: 212).
Skill 0 overlooking three times as often (a child model) against skill 0: 46, 42, 112,
about −120. 90 – 100 was still running; 100's 2800 is an estimate. A score near 0 or 1
over 200 games is a wide estimate (±60 or more).

### Judging's cost (2026-11-11)

`build/judgebench` (`tools/judgebench.goose`), medium's start against itself, each move
judged as the worker does, on the Mac built: International 80 moves, 25 ms a move on
average, 34 at most, 300,000 nodes; Russian 72 moves, 25 ms, 43 at most. Marks over the
International game: 14 only moves, 46 best, 16 good, 1 ?!, 1 ?, 2 ??. On the tablet's
big cores the search runs at about half the Mac's speed, so about 50 ms a move; the A33
to measure.

## Takes to choose

The prototype: `prototypes/history.html` (`?view=game&take=a|b|c`, `view=games`,
`view=replay`, `view=settings`, `view=entry&entry=home|sheet`). Built: take a, the entry
from the player's card, the setting on the games screen.

## Open questions

1. The panel's place: under the play panel (built), and the 3D board 11% smaller while
   it shows: worth it, or a smaller panel there?
2. Portrait: a one-line strip of the last moves under the play row (the prototype's
   proposal, the board 12 dp smaller), or nothing (built)?
3. The games screen from who's playing only (built), or also a row on home (fits the
   tablet, not a phone in landscape)?
4. The setting's default: marks (built), or off for a new player, so a young child sees
   nothing unless a parent turns it on?
5. Too many stars? Most moves come out best; a star only for a move that stood out (the
   only good one) would be quieter.
6. Ratings per draughts (built) or one for all; show the computer's rating beside its
   level in the setup ("Medium · 1644")?
7. Dates are UTC; the local date needs the system's time zone (a small C call).
8. A past game's replay (the prototype's `view=replay`): the moves are kept in the file,
   the screen isn't built.

## Native work

- [x] `ai/judge.goose`: a position's moves judged, the mark and loss, the accuracy
- [x] `ai::skill_rating`, `ai::rate`, the rating's update
- [x] `src/shell/history.goose`: a game's line written and read back, the file capped
- [x] The worker judging moves (`game::JUDGE` asks), the game keeping its moves' marks
- [x] The game's end recorded in the player's history, the rating updated
- [x] The setting (on the games screen)
- [x] The moves panel on the game screen (landscape, flat and 3D)
- [x] The games screen
- [ ] A summary at the panel's foot (each side's accuracy and marks counted), as the
      prototype has
- [ ] The replay of a past game
- [ ] The games screen in `test/shell/sizes`' sizes, with insets

## Acceptance criteria

- [ ] The prototype's takes compared and one chosen
- [x] Every move of a game judged on the worker without slowing the computer's reply
- [x] A finished game written to the player's history, its rating updated, start again
      clearing both
- [x] The moves panel and the games screen built, every tap 88 dp, strings in English
      and Estonian
- [x] Headless tests: judging known blunders and best moves, the rating's update, the
      history file read and written back and capped
- [ ] Checked on the Mac at the tablet's and a phone's sizes (headless shots taken
      2026-11-11 at 1280 × 800, 800 × 1280, 1066 × 480), then on the tablet; the judging's
      CPU on the A33
