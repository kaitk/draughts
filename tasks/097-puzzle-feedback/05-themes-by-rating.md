# 05: Today's themes by rating

Status: done

A tester: "easy puzzles are just forced moves". A study (2026-11-19) found no daily
puzzle with a single legal first move, but a grown-up who solves Learn and goes to Today
gets only Captures, since a theme opens only once a course puzzle in it is solved
(`opened_themes`): every pick capture-first, about 85% of International's under 500 a
choice between two captures one move deep, and the picks stuck near 500 while the
rating climbs past 900 (Captures has about 33 puzzles above 600).

Open themes by rating as well as by the course: Crowning, Shots, and King shots at 600,
Safe move at 800 (guesses, where the libraries' quiet puzzles begin). Simulated, a
flawless International player with only Learn solved: capture-first on days 2 to 8 from
100% each day to 87, 33, 44, 31, 21, 17, 9%; Russian and Brazilian to 25 to 47%. A young
beginner (true skill 300) never reaches 600 and sees no change.

## Acceptance criteria

- [x] Today opens a theme by the course or by the player's puzzle rating, with the thresholds
      (`puzzles::themes_by_rating`, `SHOTS_RATING` and `SAFE_MOVE_RATING`; the shell's
      `opened_themes` keeps to the themes the set has)
- [x] A test: a rating past each threshold opens the theme, a beginner's doesn't
      (`test/puzzles/daily.goose`, `test/shell/today.goose`)
- [x] Recorded in `docs/decisions/puzzles.md` and `docs/architecture/puzzles.md`

## Measured

`build/scratch/ramp.goose` (not in git) with the app's `themes_by_rating` and `rated`,
2026-11-19: 50 seeds, 20 days, 4 a day, a flawless player from 470 with Learn and
Captures open. Captures' share of the picks by day, days 1 to 10 (day 1 is Captures
alone, the rating under 600 at the day's start):

| Draughts | Before | With themes by rating | With 06 too |
|---|---|---|---|
| International | 100% every day | 100 25 25 11 4 4 7 1 0 2 | 100 25 9 1 12 6 5 2 0 0 |
| Russian | 100% every day | 100 32 25 25 25 25 25 25 25 25 | 100 25 25 25 27 28 25 22 2 0 |
| Brazilian | 100% every day | 100 31 25 25 26 25 25 25 25 25 | 100 25 25 25 26 26 25 3 0 0 |

This is the theme's share, not the capture-first share the study above counted. By Elo
against a true skill (200 seeds), a player of 300 ends 20 days at 505 and never opens a
theme by rating; one of 450 ends at 672, past 600, so an older beginner does get Shots.
