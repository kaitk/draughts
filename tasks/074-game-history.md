# 074: Games' history, marked moves, and a rating

Status: in progress (built 2026-11-11 and 12 and merged into main 2026-11-12, checked
on the Mac's desktop app by the user; take d and the replay built in task 078; left: the
tablet's and the A33's checks)

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
`rendering.md` ("The moves panel", "The results screen"), and `README.md` ("Players"); the
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
- `src/shell/results.goose`: the results screen, from home's results row (its menu scrolling
  where the row doesn't fit, 2026-11-12) and who's playing's new tile.
- The `moves` setting (off, moves, marks; default marks) in the player's file, set in
  settings' game group (2026-11-12, after issue 1 took the draughts' row out), there
  alone since 2026-11-13 (task 078: the results screen's tiles taken out, a line saying
  what the chosen one shows).
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
| 90 – 100 | 62 | 73 | 65 | 5 |
| 8 – 25 (check) | 0 | 7 | 193 | 700 |
| 25 – 40 (check) | 18 | 37 | 145 | 260 |

The chain 8 to 25 (849) was scaled to 775, between it and the direct match. Russian came
out a little closer (0 – 8: 61, 37, 102, a gap of 72; 8 – 25: 440; 25 – 40: 212).
Skill 0 overlooking three times as often (a child model) against skill 0: 46, 42, 112,
about −120. 90 – 100: 62, 73, 65, a gap of 5 (2026-11-12): past 90 skill adds little
strength, so hard's ratings are 2716 to 2721. A score near 0 or 1
over 200 games is a wide estimate (±60 or more).

### Judging's cost (2026-11-11)

`build/judgebench` (`tools/judgebench.goose`), medium's start against itself, each move
judged as the worker does, on the Mac built: International 80 moves, 25 ms a move on
average, 34 at most, 300,000 nodes; Russian 72 moves, 25 ms, 43 at most. Marks over the
International game: 14 only moves, 46 best, 16 good, 1 ?!, 1 ?, 2 ??. On the tablet's
big cores the search runs at about half the Mac's speed, so about 50 ms a move; the A33
to measure.

## Takes to choose

The prototype (removed 2026-11-13, in git history at 086f47d): `prototypes/history.html` (`?view=game&take=a|d`, `view=games`,
`view=replay`, `view=settings`, `view=entry`). Built: take a, the entry from home, the
setting in settings. Takes b and c, the setting on the player's sheet, and the entry as a
tile on the player's sheet were removed from the prototype 2026-11-12 (in git history
before that commit).

Take d, a phone in landscape (`?view=game&take=d`, `&grid=1` for all of it side by side;
2026-11-12): a line of the last move and its mark (`23. 41-36 ?!`) and a chevron under
the left column; a tap opens a sheet from the screen's left edge to the board's edge (350
dp on the Pixel 7a, 293 on the A33; on the 3D board the column's 280 and 264), the moves
two a row, the last lit, each side's accuracy at its foot, 6 rows on the Pixel and 7 on
the A33; its head, the line, or back closes it. The board stays whole and playable. The
fit at 1066 × 480 dp: the left column as built (336 dp) leaves 47 dp under it on the Pixel
(its 37 dp gesture bar) and 84 on the A33 (no bottom inset), where the captured pieces sit
now. A tap-high line fits beside them on neither, so two ways:

- `fit=row` (default): back and settings side by side (90 × 96 each, icon over word),
  start over under them on its own; the column 204 dp, the line a full 88 dp tap, the
  captured pieces still under it (Pixel 79 dp, two rows, 0 spare; A33 88, 28 spare). It
  changes the left column's built order.
- `fit=slim`: the column as built; the line in the captured pieces' place, as wide as the
  left side (Pixel 273 dp, A33 233), as tall as the room (Pixel 47 dp, 41 under a tap;
  A33 84, 4 under, which an 8 dp gap under the column in place of 12 would make up), its
  tap running on through the bottom margin (71 and 108 dp). The captured pieces become
  counts in it; on the 3D board, too narrow for them, they go to the line at the top
  between the panels, the board shrinking under it.

The A33's insets are assumed, not measured (a notch of about 80 px at the left, a
three-button bar of 135 px at the right in landscape); `adb shell dumpsys window` gives
the real ones.

## Open questions

1. ~~The panel's place~~: under the play panel, scrolling through the whole game; on a
   desktop the 3D frame wider while it shows and the panel as long as costs the board
   nothing (the user, 2026-11-12).
2. ~~A phone in landscape~~: take d, `fit=row` with the moves under the captured pieces
   and the earlier rows faded (the user's direction, 2026-11-12), built in task 078.
3. ~~Portrait~~: the last move in the bar's row between what each side has taken, its tap
   opening the moves as a sheet from the foot, on a phone and a tablet alike, costing
   the board nothing (the user's choice for a phone, task 078, 2026-11-13; built for a
   tablet's portrait too, which had no panel either).
4. ~~The results screen from who's playing only, or also a row on home?~~ A row on home,
   the menu scrolling where it doesn't fit (the user, 2026-11-12).
5. The setting's default: marks (built), or off for a new player, so a young child sees
   nothing unless a parent turns it on?
6. Too many stars? Most moves come out best; a star only for a move that stood out (the
   only good one) would be quieter.
7. Ratings per draughts (built) or one for all; show the computer's rating beside its
   level in the setup ("Medium · 1644")?
8. Dates are UTC; the local date needs the system's time zone (a small C call).
9. ~~A past game's replay~~: built in task 078 (2026-11-13), from a results row.

## Native work

- [x] `ai/judge.goose`: a position's moves judged, the mark and loss, the accuracy
- [x] `ai::skill_rating`, `ai::rate`, the rating's update
- [x] `src/shell/history.goose`: a game's line written and read back, the file capped
- [x] The worker judging moves (`game::JUDGE` asks), the game keeping its moves' marks
- [x] The game's end recorded in the player's history, the rating updated
- [x] The setting (in settings' game group; on the results screen too until 2026-11-13,
      task 078)
- [x] The moves panel on the game screen (landscape, flat and 3D), scrolling
- [x] Home's results row, the menu scrolling where it doesn't fit
- [x] A desktop's narrow play panel fitted to its tiles (Estonian's undo move spilled)
- [x] Take d on a phone in landscape, and the last move in portrait's bar (task 078,
      2026-11-13)
- [x] The results screen
- [ ] A summary at the panel's foot (each side's accuracy and marks counted), as the
      prototype has
- [x] The replay of a past game (task 078's C, 2026-11-13)
- [ ] The results screen in `test/shell/sizes`' sizes, with insets

## Acceptance criteria

- [x] The prototype's takes compared and one chosen (a; d for a phone in landscape)
- [x] Every move of a game judged on the worker without slowing the computer's reply
- [x] A finished game written to the player's history, its rating updated, start again
      clearing both
- [x] The moves panel and the results screen built, every tap 88 dp, strings in English
      and Estonian
- [x] Headless tests: judging known blunders and best moves, the rating's update, the
      history file read and written back and capped
- [ ] Checked on the Mac at the tablet's and a phone's sizes (headless shots taken
      2026-11-11 at 1280 × 800, 800 × 1280, 1066 × 480; the desktop app by the user
      2026-11-12), then on the tablet; the judging's CPU on the A33
