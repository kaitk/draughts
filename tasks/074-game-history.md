# 074: Games' history, marked moves, and a rating

Status: in progress (designed and prototyped 2026-11-11; the engine side built on the
`history` branch; the screens to choose and finish)

A family asked for a history of the games played, minimal at first, and moves rated as
GoDraughts rates them: was a move a blunder or not (2026-11-11). Three parts:

1. **The moves of the game in progress**, each marked by how good it was, on the game
   screen where there is room (a panel in the landscape's right column, under the play
   panel), and hidden by a per-player setting for a child it would only crowd or
   discourage.
2. **The games played**, kept per player, with a screen of their own: the rating, wins,
   draws, and losses by level, and the recent games with their marks.
3. **A rating** per player and draughts, as the Elo scale chess and draughts players
   know, from games against the computer, whose levels get ratings of their own.

## What others do (searched 2026-11-11)

- **FMJD** rates players by Elo, with separate lists for 100 and 64 squares
  (FMJD Annex 9). **Lidraughts** uses Glicko-2 (a deviation and a volatility beside the
  rating), and warns that numbers from different systems don't compare.
- **Move marks**: lichess marks a move by how much it lowered the mover's chance to win:
  inaccuracy (?!), mistake (?), blunder (??) at 10, 20, and 30 points of its
  win-chance scale (−1..1, so 5, 10, 15 points of a probability). Chess.com uses expected
  points lost: 0.05, 0.10, 0.20. Both turn the engine's score into a chance through a
  logistic, so a move that keeps a won game won is no blunder whatever it costs.
- GoDraughts shows the computer as "Easy 800" and a move list with the last move lit.

## Proposed design

### Marks

- Each move of either side is judged once, after it is played, by the computer's search
  at full strength (hard's depth, nothing overlooked, no gifts) from the position before
  it: the best move's score and the played move's, in hundredths of a man from the
  mover's side. One search gives both (`Engine.main_score`, every root move's score; a
  move outside the margin has only an upper bound, which is enough: its loss is at least
  the margin).
- A score becomes an expected result through a logistic, `E(s) = 1 / (1 + e^(-s/100))`:
  a man up 73%, two 88%, three 95%; a won or lost score (past `ai::WON`) is 1 or 0.
- The loss is `E(best) - E(played)`, and the mark by it, chess.com's cut-offs:

  | Mark | Loss | Shown |
  | --- | --- | --- |
  | best | the best move, or within 0.01 | a filled star, the glow color |
  | good | under 0.05 | nothing |
  | inaccuracy | 0.05 to 0.10 | `?!`, autumn's gold |
  | mistake | 0.10 to 0.20 | `?`, orange |
  | blunder | 0.20 or more | `??`, the forced-capture red |
  | only move | one legal move (a forced capture with one way) | nothing |

- A game's **accuracy** per side, as lichess's: each move's
  `103.17 · e^(−4.354 · loss) − 3.17` percent, clamped to 0..100, averaged.
- The judging runs on the worker that thinks for the computer, at a lower priority than
  the computer's move, the hint, and the lookout's traps: when none of those is open, it
  takes the oldest unjudged move. A newer ask drops it and it starts again later. A
  move judged stays judged across undo for as long as the move stays in the game.

### Rating

- Elo, per player and per draughts (64 and 100 squares differ, as FMJD's lists do; the
  three draughts are three numbers). A new player starts at 800. Only games against the
  computer count: a friend's game on one tablet has no second rated player.
- The computer's rating at a game's skill comes from self-play between skills
  (`build/aimatch`), the difference between two skills `400 · log10(won / lost)` with
  draws as halves, anchored at skill 0 = 500. The table is in `ai::skill_rating`.
- After a game: `R' = R + K · (S − E)`, `E = 1 / (1 + 10^((Rc − R) / 400))`, S 1, ½, 0;
  K 40 over a player's first 20 rated games of that draughts, then 20 (FMJD's K for
  juniors is 40 too). Never under 100.

### Games kept

- `history-N.txt` beside `player-N.txt`, one line a finished game, newest last, at most
  `history::MAX_GAMES` (200; the oldest dropped when written): when (seconds since the
  epoch), the draughts, the opponent (the computer's level and skill, or a friend), the
  player's side, the result, the player's rating before and after, each side's marks
  counted and accuracy, and the moves in PDN with their marks.
- Start again clears it with the rest of the player's games; remove deletes it.
- A game counts once it ends (won, lost, drawn; a flag fall too). A game left or started
  over before its end isn't kept.

### Setting

- Settings gets a **Moves** row per player: hidden, the list, or the list with marks.
  Default the list with marks. A child's parent turns it off; the history and rating are
  kept whatever it says.

### Screens

Prototyped in `prototypes/history.html` (takes there, see its README row):

- The game's panel in the right column in landscape where at least four rows fit under
  the play panel; in portrait under the play row where the board leaves room, else not.
- The games screen: reached from who's playing (the player's sheet), or from home.

## Native work

- [x] `ai/judge.goose`: a position's moves judged, the mark and loss, the accuracy
- [x] `ai::skill_rating`, `history::elo`, the rating's update
- [x] `src/shell/history.goose`: a game's line written and read back, the file capped
- [x] The worker judging moves (`game::JUDGE` asks), the game keeping its moves' marks
- [x] The game's end recorded in the player's history, the rating updated
- [ ] The setting's row in settings
- [ ] The moves panel on the game screen
- [ ] The games screen

## Open questions

1. Where the panel goes (right column, the take proposed), and what portrait shows.
2. Where the games screen is reached from: the player's sheet, home, or both.
3. The marks shown to a child at all, or the list alone (the setting's middle value).
4. Ratings per draughts (proposed) or one for all.
5. Show the computer's rating beside its level in the setup ("Medium · 1500")?

## Acceptance criteria

- [ ] The prototype's takes compared and one chosen
- [ ] Every move of a game judged on the worker without slowing the computer's reply
- [ ] A finished game written to the player's history, its rating updated, start again
      clearing both
- [ ] The moves panel and the games screen built as chosen, every tap 88 dp, strings in
      English and Estonian
- [ ] Headless tests: judging known blunders and best moves, the rating's update, the
      history file read and written back and capped
- [ ] Checked on the Mac at the tablet's and a phone's sizes, then on the tablet
