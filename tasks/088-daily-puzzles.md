# 088: Daily puzzles from a large generated library, at the player's level

Status: in-progress

Children who solved every puzzle in the themed sets (task 037) ask for more. The themed
sets stay as the course and gate the daily puzzles; a few daily puzzles come from a large
library generated offline and embedded, picked by the local date and the player, easier or
harder by a puzzle rating per player. The children solved all three sets in a day
(2026-11-14), so the library must reach well past the course, up to puzzles that make a
grown-up think.

How it works: `docs/architecture/puzzles.md` ("Daily puzzles"); why, and what was
rejected (importing, a streak, "one more", Today's own page, gating on every theme):
`docs/decisions/puzzles.md`; the commands: `docs/development.md` ("Daily puzzles").
The generator follows Lichess's `lichess-puzzler` where it fits (positions that turn,
not already won, one clear move, dedup, two passes, themes tagged from the line); the
difficulty is estimated offline (`tools/puzzles.goose rate`), as there is no play data.

## Numbers (2026-11-14)

The estimate puts kabe.ee's five grown-up puzzles (`tools/calibration/kabe.txt`) at 1149,
1365, 1569, 1571, and 1904, in their author's order; International's course rates 280 to
1316. The user's look at 30 random library puzzles (`build/library/sample-30.md`, local):
the estimate accurate, none bad or misplaced.

The library after the trap run:

| Draughts | Puzzles | Bytes | Difficulty: min, median, max | Over 1400 | Traps |
| --- | --- | --- | --- | --- | --- |
| International | 3,579 | 507,183 | 341, 952, 2290 | 376 | 312 |
| Russian | 2,328 | 273,327 | 300, 859, 1991 | 87 | 242 |
| Brazilian | 2,080 | 244,438 | 300, 847, 2119 | 112 | 227 |

International's batch took 46 min on ten processes, the 8×8 ones 33 min together; the
traps about 40 min more. On 8×8 the camps repeat (over half seen before), so a larger 8×8
library wants new kinds, not more time. Puzzles from the computer's own games
(`games`) are a poor source as built: 7 of 286 forced swings passed the checks, at 5 min a
puzzle, and why the rest fail isn't counted.

## Left

- The tablet: home, the library, the daily puzzle's screen with its word, and the setting.
- Grab traps need a core that makes the forcing 2-for-1 (camps found none new), and
  Russian's bigger capture a better generator than baits in camps (13 in 30 min).
- How many traps the children meet, and their results per puzzle against the estimate.
- Next, once the library has been tested with the children: more puzzles where the
  obvious move is wrong, generated with the trap as a filter.

## Acceptance criteria

- [x] The UI takes prototyped, checked on the tablet's and a phone's sizes in both
      orientations, and chosen; the choice recorded in `docs/decisions/puzzles.md`
- [x] A generation sample with how many pass the checks, how long each costs, and a look
      at a random 30 by the user
- [x] The difficulty estimate on the sample, its spread, and the user's 30 ordered by it
- [x] The library generated for International, Russian, and Brazilian, embedded, tested
      headless (`test/puzzles/library`), with the size in this file
- [x] The daily pick and the rating as pure functions, tested headless; nothing allocated
      in the frame loop
- [ ] Home, the library, and the setting built as chosen, with strings in `strings/`;
      checked on the Mac (done), then on the tablet
- [x] `docs/architecture/puzzles.md` and `docs/product.md` updated; this task's numbers
      recorded here
