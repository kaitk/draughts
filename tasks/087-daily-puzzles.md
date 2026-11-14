# 087: Daily puzzles from a large generated library, at the player's level

Status: todo

Children who have solved every puzzle in the themed sets (task 037: 74 International,
and Russian's and Brazilian's) ask for more. Adding them by hand doesn't scale, and a
library of thousands on home's "93 / 222" counter would only discourage. The plan
(2026-11-14):

- **The themed sets stay** as the course: they teach the motifs in order, are checked
  by hand, and keep the stars children won by id. They gate the daily puzzles (only
  motifs of themes the child has opened) and seed the player's first puzzle rating.
- **Daily puzzles** come from a large library generated offline and embedded: a few a
  day, picked by the local date and the player, so a child can't do too many at once
  and none pile up on missed days.
- **Easier and harder by the player's level**: a puzzle rating per player and draughts,
  and a difficulty per puzzle estimated when it is generated. Each day's set has a
  shape: a warm-up below the player's rating, two at it, a stretch above.
- **Home's counter** shows today's progress, not a total over thousands.

Execution starts in a new session, once the UI below is agreed and the generation
sample has been looked at.

## Why generate, not import

Every position in the sets is our own (`docs/architecture/puzzles.md`, "source"), so
none carries another's license, and that stays. GoDraughts' puzzles are proprietary.
Lidraughts publishes its code but no puzzle export or data license was found
(2026-11-14); Lichess's public-domain puzzle database is chess only. In the EU a
collection's substantial extraction is covered by the database right even though one
position is a fact. Old compositions (before about 1950) are public domain and may
make a small hand-picked theme later, not the bulk.

`tools/puzzles.goose find` already makes game-like positions for a motif and checks
each with the solver, `puzzles::check` (quiet end, every right move listed), and the
rivals report; the computer player's `engine` view and `test/perft.py` confirm. At
scale it needs a batch mode and a dedup, and a second source: positions from the
computer's own games (`tools/aimatch.goose`) where a shot or a sole safe move stands,
which look more like real games than camps do.

Size: a puzzle is about 150 bytes of text, so 3,000 per draughts is about 450 KB
embedded, small next to the backgrounds' 9.7 MB. Generating on the device is rejected:
finding and checking a good puzzle costs search time and curation.

## Difficulty without play data

No analytics, by design, so a puzzle's difficulty is estimated offline from:

- **The computer as judge**: the lowest skill (or depth) at which `ai::think` finds the
  solving move. Found at easy's skills: easy; only at hard's: a stretch.
- **Shape**: the solver's moves, the men given, the legal moves to weigh at the first
  turn, whether the first move is a forced capture, and how many near-rivals (moves
  that look right and lose) there are.
- **Motif level**: the 1 to 3 the themes already use.

Blended into one number per puzzle in the generated file. Checked against real solves:
a few weeks of the user's children's results per puzzle, read from the player files.

## The player's rating

An Elo-style puzzle rating per player and draughts, in the player's file beside the
game rating (task 074). A solve against the puzzle's difficulty raises it, a miss lowers
it; stars count as a partial score (3 = 1.0, 2 ≈ 0.6, 1 ≈ 0.3). The first rating comes
from the course's stars. Shown to the child, if at all, as in `results.html`, never as a
number on the puzzle screen.

## UI to agree first

Prototyped as takes in `prototypes/` (URL parameters of `home.html`, `puzzles.html`, and
a new `daily.html`), checked with `agent-browser`, then chosen. The proposals:

1. **Home's Puzzles row**: "93 / 222" becomes today's set as dots that fill as they are
   solved (●●○○), a check once all are; the course's totals move into the library's
   rows, where they are already. Open: whether a streak of days shows (a small flame and
   a number) or nothing more.
2. **Where Today lives**: (a) a Today row heading the library, above How to play, as
   wide as it; (b) home's Puzzles opening straight on Today with the library a tap
   away; (c) a row of its own on home. Proposed: (a), with home's dots.
3. **Today's page**: like a theme's page, the day's puzzles as tiles with their stars,
   each tile with its difficulty as the level marks' rising bars, the first unsolved one
   lit. A puzzle plays on the puzzle screen as any other; next goes through today's set.
4. **Done for today**: after the last, the page says so with the stars won and comes
   back tomorrow (an icon of a moon or a calendar, few words). Open: an optional "one
   more" when the parent setting allows it.
5. **Retrying**: a daily puzzle may be played again the same day for stars, the rating
   moved only by the first try. Yesterday's are gone; open whether one missed day may be
   caught up.
6. **Parent setting**: puzzles a day, 3, 4, 5, or 10, in settings' puzzle or play group;
   4 by default.
7. **Before Learn is half solved**: the Today row is locked as the other themes are,
   "Solve n more in Learn".

## Acceptance criteria

- [ ] The UI takes above prototyped, checked on the tablet's and a phone's sizes in both
      orientations, and chosen; the choice recorded in `docs/decisions/puzzles.md`
- [ ] A generation sample: a few hundred International puzzles from `find` at scale and
      from the computer's games, with how many pass the checks, how long each costs,
      and a look at a random 30 by the user for quality
- [ ] The difficulty estimate on the sample, its spread, and the user's 30 ordered by it
      against how hard the user finds them
- [ ] The library generated for International, Russian, and Brazilian, embedded, tested
      headless as the sets are (`test/puzzles/`), with the size in this file
- [ ] The daily pick (date, player, rating, opened themes) and the rating as pure
      functions, tested headless; nothing allocated in the frame loop
- [ ] Home, the library, Today's page, and the setting built as chosen, with strings in
      `strings/`; checked on the Mac, then on the tablet
- [ ] `docs/architecture/puzzles.md` and `docs/product.md` updated; this task's numbers
      recorded here
