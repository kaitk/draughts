# 088: Daily puzzles from a large generated library, at the player's level

Status: in-progress

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

## Chosen so far (2026-11-14)

- Home's Puzzles row: today's dots alone (`home.html?daily=a`).
- No streak of days, anywhere: it makes a missed day a loss, which pushes a child rather
  than inviting one. Kept behind `?streak=1` in the prototypes only.
- The library: today's puzzles as tiles inside the Today row, each its level's bars and
  its stars, a tile opening its puzzle (`puzzles.html?daily=b`); the row's mark turns to
  the moon and its note to "New puzzles tomorrow" once all are solved. Today's own page
  (`daily.html`) is then not needed.
- How to play and Today: while Today is locked, How to play heads the list as now and
  Today's locked row ends it ("Solve n more in Learn"); once it opens, Today heads the
  list across the columns, and How to play becomes a tile with its mark beside the title
  in landscape, and ends the list in portrait, where the title row has no room.
- Home's Puzzles row before Today opens: the puzzles solved in the player's draughts,
  not stars ("31 / 74"); after, today's dots.
- Today opens once Learn is solved, all of it, not half: Learn is the rules, which a daily
  puzzle may use. Gating on the other themes too was rejected as too strict (a young
  child would stall on Safe move); the daily pick keeps to the themes opened instead.
- No "one more" after the day's set: the moon ends the day.
- The level's bars stay on the tiles: which one is hard shows without words.
- Puzzles a day: 4 by default; 3, 5, or 10 in settings.
- A daily puzzle's screen shows today's dots over next (`puzzle.html?daily=1`); the
  prototype places them only for the tablet's landscape, so the build fits them into
  the puzzle's corner panels and portrait bar as the screen's other parts are.

## Generation sample (2026-11-14)

`tools/puzzles.goose batch SEED PER SECONDS` runs a table of kinds (`KINDS`: the goal,
moves, men in each camp, kings, and how a take in more moves starts), keeps each puzzle
once by its position and by its line (the course's own among them), turns a third for
black, and tags each puzzle's theme and level from its line (`motif`: the safe move, a
crown, a king's capture, men given or a free tempo, else a capture). `games SEED GAMES
SKILL NODES` plays the computer against itself from four random plies and keeps, one a
game, a position where the material is even, the side that just moved scored its move
within 60 of even, and the game then won n men within four moves: tried as "take n" in
the fewest moves that force it, any quiet first move allowed. Lines may now run to 16
plies (`puzzles::MAX_PLIES`, 8 before), which kabe.ee's warm-up needs.

The sample: four `batch` seeds (6 a kind, 60 s a kind at most) and six `games` runs of 60
games at skill 90 and 300,000 nodes a move, ten processes at once, 6.5 min on the Mac:
374 International puzzles, 112 of them black to move, none kept twice across the runs.

| Kind | Tried | Sound | Kept | s a puzzle |
|---|---|---|---|---|
| capture-8 (take 2 in 1, 8 v 8) | 1,011,217 | 26 | 24 | 0.12 |
| capture-13 (take 3 in 1) | 53,203,786 | 25 | 24 | 7.9 |
| shot2-10 (take 2 in 2) | 869,170 | 25 | 24 | 0.12 |
| shot2-15 | 33,747,315 | 24 | 24 | 5.5 |
| shot3-12 (take 3 in 2) | 19,337,558 | 24 | 24 | 2.8 |
| shot3m-12 (take 2 in 3) | 20,961,126 | 28 | 23 | 4.7 |
| shot3m-16 (take 3 in 3) | 51,838,312 | 0 | 0 | none in 240 s |
| shot4m-14 (take 2 in 4) | 21,365,088 | 11 | 9 | 26.7 |
| tempo-10 (take 1 in 2, a free tempo) | 1,528,590 | 34 | 24 | 0.23 |
| crown1-7, crown2-8, crown3-9 | 5,392,620 | 86 | 72 | 0.09 to 0.36 |
| king1-8, king2-9, king3-10 (a king) | 9,073,081 | 73 | 72 | 0.11 to 1.2 |
| safe-10, safe-15 | 45,448,748 | 64 | 47 | 8.5, 1.5 |
| games: 360 games, 11,038 swings | 11,038 | 7 | 7 | 325 |

Of the positions `find` places, between 1 in 25,000 and 1 in 2 million pass every check;
the solver's exact search is the cost, and the most men and moves cost most. The games
are a poor source as built: of 286 swings the solver forces, 7 pass the checks (which check
the rest fail is not yet counted), at 5 min a puzzle, so the full library is from `batch`
alone until the games' failures are looked into.

## Difficulty estimate (2026-11-14)

`tools/puzzles.goose rate FILE` scores each puzzle, about 0.75 s each:

- **The computer as judge**: of skills 0, 5, ..., 100 (`ai::think` as a hint searches,
  nothing overlooked), how many don't find the right first move, times 5, and 20 more
  if full skill with 4 M nodes misses it too. A skill finds it when it would play it, or
  scores it as well as any move and better than one. The count, not the lowest skill
  that finds it: shallow skills that score every move alike find quiet moves by luck.
  The engine plays for material, so a crown puzzle counts 50 misses at most.
- **Shape**: the solver's moves, men given, moves at the first turn (log), a first move
  forced as a capture (easier), moves skill 30 scores as well as the right one (rivals),
  pieces on the board (log), and a line that lets the other side crown.
- **Motif level**: 1 to 3, from `motif`.

Blended (`blend`): 400 + 10 misses + 50 (moves - 1) + 30 given + 60 log2(moves to weigh
/ 2) + 10 rivals + 50 log2(pieces / 6) + 40 (level - 1) + 80 if it lets a crown - 120
if forced.

kabe.ee's five, transcribed from the page's diagrams into `tools/calibration/kabe.txt`
and checked by playing its solutions (the page's no. 2 has a man on h8, not a king; it
writes a capture by its ends, "f6:h6" for f6:d8:a5:d2:h6), as win puzzles, the line the
author's:

| No. | Author's label | Estimate | Misses |
|---|---|---|---|
| 1 | warm-up | 1149 | 25 |
| 2 | | 1365 | 45 |
| 3 | already harder | 1569 | 40 |
| 4 | here you have to think | 1571 | 50 |
| 5 | | 1904 | 60 |

In the author's order and medium to hard, though 3 and 4 are two points apart. Only no. 1
is a puzzle our solver checks (win in 6); the others' wins are endgames past its reach.

The course is the floor: International's 74 rate 280 to 1316, by level 1, 2, 3 a mean of
430, 697, 986; Russian's and Brazilian's 280 to 1260. The sample rates 341 to 2308,
median 737: captures 425, crowning 720, king shots 743, safe move 806, shots 792 at the
median; 24 of 374 over 1400. The full library weights the hard kinds three times (a
kind's `share`) and adds take 3 in 3, take 2 in 4 among 12, and a king's take 2 in 3
among 25, so its range reaches past kabe.ee's.

The 30 random sample puzzles by the estimate, for a look (open each with
`build/draughts --variant international --fen FEN`), are in `build/library/sample-30.md`,
local.

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
