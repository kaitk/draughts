# 06: A faster ramp for a flawless record

Status: done

The puzzle rating's step starts at 96 and falls by 6 a rated puzzle to 24, so a flawless
player takes 8 days to reach 1000 and 18 to reach 1500 (International, start 470).
While every rated first try so far has three stars, keep the step at 96; the first miss
returns it to the schedule by count, as a game's skill moves more after early wins
(`docs/decisions/ai.md`, "Levels").

Simulated (2026-11-19, medians, day and puzzles): flawless to 1000 d8/29 → d4/13, to
1500 d18/72 → d6/24. An adult of true skill 1200 gets days with two or more 1-star
puzzles 6% → 15% while it settles. Children are unaffected: 0.7% of young ones (true
skill 300) and 3% of those at 450 are flawless on day 1, essentially none after day 2.

## Acceptance criteria

- [x] A "still flawless" mark per draughts beside `puzzle_rating` in the player's file,
      kept and read like it; starting again clears it (`Settings.puzzle_flawless`,
      `puzzle_rating.international = 812 14 flawless`; a line without the mark is
      flawless only with nothing rated, so older files read as before)
- [x] The step stays at its first while flawless, then follows the schedule
      (`puzzles::rated`'s `flawless`, the shell's `daily_solved`)
- [x] A test of both, and the decision recorded (`test/puzzles/daily.goose`,
      `test/shell/today.goose`, `test/shell/players.goose`)

## Measured

`build/scratch/ramp.goose` (not in git) with the app's `rated`, 2026-11-19, a flawless
player from 470 with Learn and Captures open, 50 seeds, 4 a day; medians, day and
puzzles:

| Draughts | To 1000, before | after | To 1500, before | after |
|---|---|---|---|---|
| International, themes by rating (05) | d8/30 | d4/13 | d18/72 | d7/25 |
| Russian, 05 | d8/30 | d4/13 | d18/71 | d6/24 |
| Brazilian, 05 | d8/30 | d4/13 | d18/72 | d7/25 |
| International, Captures alone | d10/39 | d4/15 | not in 20 days | d8/29 |

By Elo against a true skill, International with 05, 200 seeds, 20 days: an adult of 1200
has days with two or more 1-star puzzles 14.7% → 25.1% (ending at 1268 → 1306); a child
of 450 68% → 68% and one of 300 70% → 70%, their ratings at day 20 the same (673, 505).
The study's 6% → 15% for the adult counted otherwise; this counts all 20 days.
