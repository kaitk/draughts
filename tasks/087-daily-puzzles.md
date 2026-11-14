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

The UI's prototypes are made and chosen first, in the session that wrote this task;
the build starts in a new one after.

## How hard the library must go

The themed sets are made for children and are easy next to real puzzles: the user's
children solved all three draughts' sets in a day (2026-11-14), and the kabe.ee page's
warm-up (below) is one the user would need to set up on a board to start thinking
about. So the course is the floor, not the middle: the library's difficulties must
reach well past the course's hardest, up to puzzles that make a grown-up player think,
and a child's rating must climb fast at first (a large step while it is new, as Glicko's
deviation does) rather than start them among puzzles they have outgrown.

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

## Against the open generators

Read 2026-11-14: Lichess's `lichess-puzzler` (its `generator/generator.py` and
`tagger/cook.py`), the widely used open generator, and `chess-variant-puzzler`
(Fairy-Stockfish, the same scheme for variants). Lidraughts' 2,000+ International
puzzles were built by its community, not generated; automatic generation from games was
only a plan.

What Lichess does, and what we take:

- **Positions from real games, not composed.** It scans 300 M games' positions for a
  sudden swing, the side to move's winning chances rising by 0.6 or more to at least
  +2 pawns, and builds the line from there. Taken: the computer's games as a second
  source beside `find`'s camps.
- **Sources tiered by quality**: games by stronger players and slower clocks rank
  higher, and lower tiers lose the shortest puzzles. Taken: mine hard skill's games,
  and keep one-movers only for the easiest end.
- **Not already won**: a position already up material, or already scoring over +3, is
  rejected; the puzzle has to be the moment it turns. Taken: the start roughly even by
  the computer's score, no side up a man.
- **One clear move at each turn**: the best move's winning chances 0.7 over the second
  best, else rejected; the line ends on the solver's move, and stops once the gain is in.
  Ours is stricter already, by exact search: exactly one move reaches the goal at each
  turn, and the line ends quiet (`puzzles::check`).
- **Dedup**: each position kept once, and one puzzle per game. Taken.
- **Two passes**: a cheap pass with loose filters, then a strict one deeper. Ours is
  the same: `find`'s guards, then the solver and the checks.
- **Themes tagged by detectors over the line**, not by where a puzzle came from:
  `sacrifice` when the solver is two points down at some point, length tags by plies
  (one move, short, long, very long), and others by pattern. Taken: tag each generated
  puzzle's motif from its line (a shot by men given then taken, crowning, a king's
  capture, the safe move, the free tempo), so the daily pick can keep to the themes the
  child has opened.
- **Difficulty comes from players, not the generator**: each puzzle is rated like a
  player (Glicko-2) from every attempt, and the next puzzle is picked near the player's
  rating, with easier and harder settings shifting it (about ±300 and ±600). Not
  possible for us without data leaving the device, hence the estimate below; the day's
  shape is the offsets.
- **Bad puzzles go by votes.** No votes here; the user's look at samples stands in.

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

Calibration references, used to check the estimate and never shipped: kabe.ee's
"Kabeülesandeid isadele" (2021-11-13), five Russian 8×8 puzzles for grown-ups who
aren't players, white to win, labeled by its author from warm-up (1) through "already
harder" (3) to "here you have to think" (4), lines of five moves and one of eight. The
positions are diagram images, so they are transcribed by hand; the page shows no solve
counts. The user finds them medium to hard, not a warm-up (2026-11-14): the author's
labels order them, but the estimate should place them by the user's reading, and by how
the user's children find them.

Puzzle 1, the warm-up, transcribed from its diagram: `W:Wc7,f2,h2,g1:Bd2,Ka7`, Russian
(the page's "e2:f4" is the man on d2's capture). `build/puzzles try --variant russian ...
win 6` finds the one first move, `f2-e3`, and the win in 6 (the page's 5 stops before
the black king's last move, which loses it), searching 16,485 positions. Listing its line
then stops at a full array (`tools/puzzles.goose:195`): the tool's buffers are sized for
the course's short lines, and grown-up puzzles need them larger.

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
