# 037: A better puzzle set

Status: in-progress

Task 007's 30 International puzzles work, but the user (2026-11-08) found them odd, mostly
too simple, with a strange difficulty curve (the first ones are fine), and some buggy:
"more moves could be made than the puzzle expected". They read more like a tutorial than
puzzles. This task keeps the best of them as a Learn theme and replaces the rest with a
proper set grouped by theme, with the picker redesigned around it: real combinations,
motifs taken from real sources, our own positions, a curve that goes well past today's
tier 3, and black to move in a share of them.

The findings below are from an engine pass on 2026-11-08 (a scratch program over
`puzzles::judge`, `puzzles::value`, and the rules, not committed) and from the web.
The audit was of the set before this task rebuilt it (below, "Built").

## Audit of the current 30

`build/puzzles` reports 0 problems: every line is legal, every first move that solves a
puzzle is listed, and none solves it in fewer moves. The problems are in what the checks
don't look at.

**What "more moves could be made" is.** A puzzle is solved the moment its last move
reaches the goal, while the position often still has an obvious capture due next: the
board stops with a capture on it, so the child sees more to play than the puzzle let them.
Confirmed in these (the end position, black to move, and what happens next):

| Puzzle | After the line | What is left on the board |
|---|---|---|
| 13 (crown) | `13x2` crowns | Black must capture at once: `32x41` takes the man on 37. "Solved" with a capture due, and the crown costs a man. |
| 6 (king from afar) | `47x33` | Black's only move `6-11` hands the king `33x6`: every reply gives white another capture. |
| 9 (king lands safe) | `46x23` | All three black replies leave white a capture (`14-19` → `23x14x5`, `14-20` → `23x5`, `10-15` → `23x10`/`23x5`); white is two up by the next move, not one. |
| 8 (which capture) | `39x30` | White still threatens `37x28`; two of black's four replies give it (`23-29`, `19-24`). |
| 16 (crown) | `24x13x2` | Two of four replies give white a capture again (`5-10` → `36x27x18`, `22-28` → `36x27`). |
| 19 (king takes two) | `46x19x35` | Black's `25-30` gives the king another capture (`35x24` and four more landings). |
| 28, 29 (shots) | the big capture | Two replies of six and of five give white more (`22-28` → `5x32`/`5x37`/`5x41` in 28); 29 nets 5 by depth 8, not 3. |

The search agrees: the material after the line keeps rising past the goal in 9 (1 → 2
in two plies), 16, 19, 21, 28, and 29, and 6, 11, 14, 15, 17, and 30 end with the other
side about to lose everything.

**Other findings**

| Puzzle | Finding |
|---|---|
| 1, 2, 3, 4, 5, 11, 12, 15, 17 | Only one legal move: the capture is forced, so the "puzzle" can't be got wrong except by tapping a wrong piece. 2 ("which of two men") and 4 ("the double, not the single") teach a choice the rules already made; 11, 12, 15, 17 are tier 2 yet easier than tier 1's 7 to 10. |
| 20 (crown in 2) | The second move `8-3` crowns as well as the listed `8-2`. The screen accepts it (any line counts), but the hint shows only `8-2`, and `puzzles::check` only checks first moves for unlisted solutions. |
| 26, 29 | The second move has two capture routes of the same length that both solve it (26: `33x24x13x2x11` and `33x24x13x22x31`; 29: `30x19x8x17x6` and `30x19x8x17x28`); only one is listed. Not judged wrong, but unlisted. |
| 8, 10, 7, 24 | The computer player at full skill scores the position after the right move badly for the solver (8: −302, about three men down; 10: −112; 24: −88; 7: −3): the "right" move wins a man the puzzle counts and then loses the game. |
| 13 | The other capture `37x28` wins the same material; only the goal "crown" makes it wrong, and the crown is taken back in material at once (above). |
| 21, 23, 25, 26, 28, 29, 30 | One pattern seven times: give one man, the reply is forced, take three to five. Positions are random men (`find`), unlike a game; 30's twelve men on six files look made up. |
| 22, 24, 27 (safe) | Sound at the solver's two plies, but the hardest in the set for a child: no idea to find, only a scan of seven to ten moves. They sit among the shots, where they break the curve. |
| all "take N" shots | The goal is the balance: "Capture 2" for a shot that takes three and gives one. A young child counts three. |

No mid-capture crowning was wrong: 17 passes the far row and goes on uncrowned, and 13,
16, and 28 crown by ending there, all as International rules say.

## Sources

Positions are facts and not copyrightable as such; a curated collection's selection,
order, and text can be. So the set is built from motifs (the named shots, the ideas a
course teaches, the order they come in), with our own positions composed for each and
checked by the engine. Where a position is a famous game finish, the game is named in the
puzzle's `source`. Nothing is copied into the repo position for position.

| Source | What it has | Children? | Use | Easy end |
|---|---|---|---|---|
| [lidraughts puzzles](https://lidraughts.org/training) | Over 2,000 International puzzles (and Frisian, Russian), rated by solvers; started with 300, credited to the user BumperBalloonCars ([birthday post](https://lidraughts.org/blog/XVG35RAAACEAKSWw/lidraughts-celebrates-its-first-birthday)). Some are compositions; a forum thread lists cooks fixed in under 5% ([mistakes in puzzles](https://lidraughts.org/forum/lidraughts-feedback/mistakes-in-puzzles?page=1)). | No, adult club level. | The code is AGPL-3.0 ([repo](https://github.com/RoepStoep/lidraughts)); no license is stated for the puzzle data. Don't import it. Use for calibration: how hard a rated-low puzzle is. | Two-for-one shots, already above today's tier 3. |
| [lidraughts studies](https://lidraughts.org/study/by/BumperBalloonCars/oldest) | Tjalling Goedemoed's Pre-Course as studies: "making a combination", "sacrifice for the breakthrough", "shots with your king", "shots with a majority capture", each with exercises; "Basic structures and systems (for beginners)". | Beginners. | No license on the page. Motif order and ideas only. | One sacrifice, one multi-capture. |
| FMJD courses by Goedemoed ([introductory course](https://fmjd.org/downloads/Course/en/Introductory%20course%20in%20draughts.pdf), Pre-Course, Course 1 to 3 at fmjd.org/downloads/Course/en/) | Free PDFs, 2011 on; the introductory course "for beginners and children", examples from real games. The PDFs were too large to read here; their copyright notice is still to check. | Yes, the pre-course and intro. | Motifs and their order; game finishes named by game. | Single shots, kinging breakthroughs. |
| [GoDraughts](https://godraughts.com/en/courses) (free web, Wouter Nijenhuis) | Seven courses of four themes, from "capture and maximum capture" through "recognise threats", "exchange and sacrifice", "breakthrough", "recognise combination motifs", "free moves and forcing"; puzzles added daily ([puzzles](https://godraughts.com/en/puzzles)); counts and grading not stated. "© DevDad, all rights reserved". | Partly. | The user allows it for ideas only (2026-11-08): themes, motifs, how difficulty ramps. Never a position or text copied. Each puzzle built from an idea there records the motif, not GoDraughts, as its source, and its position is ours. | Its course 1 is our Learn theme. |
| Eesti Kabeliit ([kabeliit.ee](http://kabeliit.ee/)) and Nõmme Kabeklubi ([kabe.ee](https://www.kabe.ee/viited/)) | No exercise collection of their own online: the federation's menu links "Kabeülesanded" to lidraughts.org. Children's tournaments (preschool, minicadets) show the level children play at. | Events, not material. | Nothing to take; the user's own Estonian links (asked for, not yet recorded) may add more. | — |
| KNDB (Dutch federation) | School draughts (welpen up to group 6, pupillen 7 and 8), a selection day with combination tests, children's articles in DamZ ([April 2024](https://www.kndb.nl/wp-content/uploads/2023/05/6856-DamZ-april-2024_def.pdf)); children work from "damboekjes" (e.g. Pieter Bergsma's *Leer spelenderwijs dammen*). | Yes. | Books are copyrighted collections: motifs and grading only. | Count-the-pieces exercises, single shots. |
| Named classic shots (coup turc, coup Philippe, Haarlem shot, coup Raphaël, the bomb, Napoleon's shot, the royal shot) | Public knowledge, described in every course and on Wikipedia. | Their simplest forms, yes. | Free to build our own positions on. | Coup turc and the breakthrough to king are within reach of a child of about 7. |
| Russian school programmes (64 and 100 squares) | Club syllabi name "the simplest combinations": shots onto the crowning square, the "sieve", the free tempo. | Yes, juniors. | Motif lists for Russian later. | — |

The best for this task: Goedemoed's FMJD courses and their lidraughts studies for which
motif comes when, GoDraughts' course order for the ramp, lidraughts' low-rated puzzles to
calibrate how hard "easy" is for a club child, and the named shots as the top tier.

## Themes in place of tiers

The user (2026-11-08), after GoDraughts' puzzle library (themes as rows, each with an
icon, a name, "n / total solved", and a bar): group the puzzles by theme rather than in
tiers of ten, and redesign the picker around it, eventually for every board. The themes
and their order are ours; only the idea of a library by theme comes from there.

Each theme is ordered by difficulty inside it, in three levels (easy, harder, hardest),
so a theme is a short curve of its own. The counts are a first International set of about
100 (`docs/product.md` asks for 100 and more), the first release needing only the rows
marked so.

| # | Theme (icon) | What it teaches, easy → hardest | Count | First release |
|---|---|---|---|---|
| 1 | Learn (open book) | The rules in action: the first capture, backward, the king's long move, the majority capture, passing the far row uncrowned, which capture isn't taken back. 12 of today's, kept and fixed (below). | 12 | yes |
| 2 | Captures (two jumping men) | Finding the multi-capture: three and four jumps, the route that takes most, the landing a king picks, a capture whose last stop is safe. Some of today's tier 2, with a real choice in each. | 10 | yes |
| 3 | Crowning (crown) | To the far row: past a guard, by an exchange, the breakthrough sacrifice (give one, crown the next), the race of two men, crowning by a capture that ends there. | 12 | yes |
| 4 | Shots (target) | Combinations, the heart of the set: give one take two or three (level 1, two moves), the double sacrifice into one capture, the coup turc, the decoy, the free tempo (level 2, three moves), named shots, coup Philippe, the Haarlem shot, the bomb, Napoleon's, the royal shot, and game finishes (level 3, three to five moves). | 30 | 20 (levels 1 and 2) |
| 5 | King shots (king) | The king as a weapon: the long diagonal, the king's zigzag, a shot that wins a king and uses it, catching men with the king. | 10 | later |
| 6 | Safe move (shield) | The one move that loses nothing, each with a threat the child can name (a shot, not two plies of material), and the defence that stops a breakthrough. | 10 | later |
| 7 | Endgame (flag) | Man races (who crowns first), a king against men, the opposition with men, and the known wins and draws of kings (International's main diagonal; Russian's Petrov triangle later). Needs goals over more moves, see below. | 10 | later |
| 8 | Opening traps (trap) | From games a few moves in: a natural move that loses to a shot. Positions from the computer's own games (`build/aimatch --fens`), scanned for such moves. | 8 | later |

The first release is about 64: Learn 12, Captures 10, Crowning 12, Shots 20, plus a
few safe moves if they fit. Shots' three levels are the curve that goes past today's
tier 3: two-move shots a child of 5 to 7 finds, three-move combinations for a strong
older child, and named shots and game finishes for a grown-up. The library's order is
Learn first, then the rest in any order.

**Learn, 12 kept (for the youngest players):** 1 (the first capture; one legal move is right
for the very first), 3 (backward), 6, 7, 8, 9, 10, 14, 17 (passing the far row, a rule to
see once), 18, 19, 20. Each is fixed so the board is quiet at its end (no capture due for
either side against any reply): 6, 8, 9, and 19 moved or a man added; 2, 4, 5, 11, 12, 15
dropped (forced, no choice), 13 and 16 rebuilt into Crowning so the crown isn't followed
by a capture, the safe ones (22, 24, 27) and the seven random shots dropped.

**Black to move:** about a third: none in Learn (the child learns on white), three or
four in ten elsewhere. The puzzle screen already turns the board when black is to move
(`shell::puzzle_layout` and `in_tile` set `flip` from the start position's side), so the
child plays up the screen as against the computer. What it would need: a test of a
black-to-move puzzle (none exists), the panel saying whose puzzle it is ("Black to
move"; `turn.black` is there), and `tools/puzzles.goose find` taking a side (it places
white to move only).

**Endgame and longer shots** need what the solver doesn't have yet: `MAX_PLIES` is 8 (four
of the solver's moves), and an exact search over quiet replies grows fast; a goal like
"crown first" or "win" in six moves wants measuring before such puzzles are written.

### The picker

Home's puzzles opens a library: one row per theme with its icon, name, "n / total",
and a bar, Learn first; a row opens the theme's puzzles, in its three levels (rows of
tiles as today's tiers), and a tile the puzzle. Learn is open; the other themes open once
half of Learn is solved; inside a theme, everything is open and the picker lights the
first puzzle without stars, as now. Next goes on inside the theme, then back to the
library.

Work before building it: a prototype `prototypes/puzzles.html` take with the library
and a theme's page, in both orientations and on a phone, checked with agent-browser,
for the user to pick from, as task 007's screens were.

The prototype (2026-11-08) is `prototypes/puzzles.html?take=a`, `b`, or `c` (`now` keeps
task 007's tiers), with `&view=library` or `theme`, `&theme=learn`, `captures`, ...,
`&themes=first` (Learn 12, Captures 10, Crowning 12, Shots 20) or `all` (the later four
too, Shots 30), `&solved=0` to `12` for Learn's solved puzzles (the rest open at 6, below
that each says how many more), and `&lang=et`. Every tap is at least 88 dp; a theme's
levels are glass rows of tiles with stars, the first without stars lit, and rows of more
than fit split evenly (ten go five and five). Checked with agent-browser at 1280×800,
800×1280, 1040×480, and 480×1040: nothing cut or past the edge; only the later set's 30
shots, and c's eight themes with them, scroll on a phone in landscape.

- **a, a list like a library**: one glass row per theme (its mark, name, "n / total", a
  bar), in two columns when all eight are shown in landscape; a row opens the theme's
  page, its name over three level rows, back in the corner.
- **b, large theme tiles**: square glass tiles with a large mark, the name, the bar and
  count, four across in landscape and two in portrait; the theme's page sets its three
  levels side by side as columns where they fit in three rows of tiles, else stacked.
- **c, library and theme together**: the themes at the left (rows, or chips of mark,
  count, and bar where they don't fit, as on a phone in landscape) and the chosen
  theme's levels beside them; in portrait the themes are a strip of chips across the
  top. One tap switches theme, and there is no library screen to go back to.

Proposed: **a**. It is the GoDraughts library the themes came from, the names stay
readable at every size (b shrinks long Estonian ones like "Kombinatsioonid", c drops
them on a phone), the first release's set fits every size without scrolling, and it is
the cheapest to build: home's rows and today's tier rows, one list and one page. c saves
a tap on the tablet in landscape but needs two scrolling panes; b looks most like a game
but holds the fewest themes per screen.

### The file and the variants

One file per variant (`src/puzzles/international.txt`, later `russian.txt`,
`brazilian.txt`), its `variant` line as now, each puzzle with `theme NAME` and `level
1..3` in place of `tier`; a theme's puzzles are in the file's order. One file per variant
keeps a variant's set together and the themes a fixed list in code (their icons and
strings). Brazilian plays International's rules on the 8×8 board, so Russian positions
rechecked under Brazilian rules may serve it where the shot still works there.

### Stars and progress

Stars stay keyed by id (`stars = 1:3 4:2` in `settings.txt`). The kept puzzles keep their
ids, so their stars carry into Learn; new puzzles take new ids, never reused; a dropped
puzzle's stars are left out of the count (and dropped from the file on the next write).
Ids are per variant, so the key becomes `stars.international` (with `stars` read as it
on the way in), and `MAX_PUZZLES` (60, sizing the settings' table) rises to fit about 150
ids. Home's count ("7 / 90") is over the variant's set.

## How a puzzle is made

1. Pick the motif and the tier from the sources above; note it.
2. Build our own position by hand or with `tools/puzzles.goose find` seeded with game-like
   camps (not random men), and solve it with `tools/puzzles.goose try`.
3. Check it: one solution (or every one listed), the replies forced or all answered, the
   board quiet at the end, and the computer player at full skill agreeing (no "right"
   move it scores as losing). `test/perft.py puzzles` replays the lines.
4. `source` says "own, motif: coup turc", or "game: White–Black, year" for a game finish.

## Russian (8×8)

The same way, not a port: Russian's geometry is smaller, men capture backward but the
majority rule doesn't apply, and a man crowned mid-capture goes on as a king
(`CROWN_CONTINUES`), which changes which shots exist. Russian's own literature for
children is large (shots onto the crowning square, the sieve, the free tempo), so the
motifs come from there, and each position is ours, checked by `tools/puzzles.goose` with
the variant set and by `test/perft.py`, the only independent check of Russian. `find`
needs the variant and its camps as parameters.

### Built (2026-11-09)

**Plumbing.** `src/puzzles/russian.txt` (`variant russian`) is the set a Russian player
sees: `puzzles::set_of` names the set of a variant (Russian's own; International's for
International and, until it has one, Brazilian), `puzzles::load(variant)` reads it, and
`puzzles::loaded` says which is in `all`. The shell reads the other set on home when the
player's draughts change (`shell::sync_puzzles`: home is where every way to the puzzles
starts, so a puzzle open from settings keeps its set), and the picker starts at its
library. The library shows only the themes a set has. Stars are a table per variant,
`stars[variant][id]`, written as `stars.russian` beside `stars.international`.
`tools/puzzles.goose try` and `find` take `--variant`, `find` `--rows N` (a camp's rows,
the board's size less 3 by default: 5 of 8) and `--tempo` (below); with no FILE it
checks the variant's built-in set. `test/perft.py puzzles` reads `c3:e5` captures and
refuses a file of another variant; `scripts/test.sh` runs it on both sets.

**Composing.** Pools from `find --variant russian` (about 1,700 candidates over Learn's
small camps of two to four men, captures, crowns, shots in two and three moves, black's,
and free tempos), described by a scratch script over `test/perft.py` (how many each
capture takes, backward, by a king, crowned mid-capture, the other captures there were),
then run through `build/puzzles` for the engine's view, which about 87% of them passed.
Picked by motif and by eye. Four were swapped after the whole file's check: Learn 2 and
7 (two men against four, where the engine scores the right move as losing, −29,986 and
−105), Learn 6 (another capture wins the tiny ending sooner), and Captures 17 (a single
capture the engine rates at +603, above the triple). `find --tempo` was added for the
free tempo: a quiet first move no reply captures after, every reply giving a man.

| Theme | Levels 1, 2, 3 | Black to move | Goals | Most positions a check, by level |
|---|---|---|---|---|
| Learn | 4, 4, 4 | 0 | take 1 to 3 in 1, crown in 2 | 8, 8, 11 |
| Captures | 4, 3, 3 | 3 | take 2, 3, 4 in 1 | 8, 14, 16 |
| Crowning | 4, 3, 3 | 4 | crown in 1, 2, 3 | 1, 17, 100 |
| Shots | 6, 5, 3 | 5 | take 2 in 2; take 3 or 1 in 2; take 3 or 2 in 3 | 49, 38, 161 |

46 puzzles, ids 1 to 46; 12 of the 34 outside Learn are black's (35%). Learn: the first
capture, the backward one, two men that can take, the flying king's landing, the free
choice (the double where one is wanted; the single where the double is answered by a
double), a capture going on backward, a man crowned mid-capture going on as a king (twice,
once with the king's long jump after), the king's zigzag, give one to crown. Russian's
motifs: crowned in a capture, going on as a king (5: Learn 9 and 10, Captures 20 and 21,
Crowning 25), the shot onto the crowning square (Shots 37), the shot through the crowning
square (39 to 41), its double sacrifice (44 to 46, five taken in one capture in 44 and
45), and the free tempo (42, 43). The sieve isn't in it: what the syllabi mean by it
wasn't pinned down here, so no position claims it.

`build/puzzles --variant russian`: 0 problems, the engine's best solves every take, and
no right first move scores under −50; of the crowns, Crowning 24's other double from the
same square (`f4:d6:b4`) scores as high, and in Crowning 30 the engine wins the ending
by quiet moves as well. `test/perft.py puzzles russian src/puzzles/russian.txt`: 46 puzzles,
0 problems. The longest lines are five plies, within `MAX_PLIES`; the most a check takes
is 161 positions (Shots 46). Headless: `test/puzzles/russian_set.goose` (every puzzle's
checks and the counts) and `test/shell/russian_puzzles.goose` (a Russian player's set
read on home, its four-row library, Learn 9 crowned on d8 mid-capture and made by hand
stop by stop, `stars.russian = 9:3`, home's count over Russian's set, and International's
library back with its stars apart).

**Brazilian** is left: Russian's file read as Brazilian fails at once (Learn 6's single
capture is illegal where the most must be taken), and Learn and every choice-of-capture
puzzle teach what Brazilian forbids, so a Brazilian set wants its own selection, its
Learn above all, rechecked under its rules.

- [x] `src/puzzles/russian.txt` loaded for a Russian player, the library showing its set,
      stars per variant (`stars.russian`)
- [x] `tools/puzzles.goose find` and `try` taking the variant and its camps
- [x] Learn, Captures, Crowning, and Shots in levels, 46, a third black outside Learn,
      each `source` naming its motif, none copied
- [x] Every puzzle passing the checks, the engine, and `test/perft.py puzzles` under
      Russian rules; headless tests of the set and of a mid-capture crowning solved
- [ ] The set on the Mac and the tablet, and its levels' order tried by players (the user)
- [ ] Brazilian's own set

### Choosing the set on the puzzles screen (prototype, 2026-11-09)

Today the library shows `puzzles::set_of` the variant in settings, so changing the set is
a trip to settings. `prototypes/puzzle-set.html` draws the choice on the library itself,
and the library reworked with it. The count is stars throughout, as home's ("0 / 222" is
International's 74 × 3; Russian's 46 make 138); Brazilian shows International's set and
stars. Checked with agent-browser at 1280×800, 390×844, and 499×645: nothing past the
edge; on a phone and in the compact window the six themes scroll, as today's do.

- **now**, today's library, no choice, for comparison:
  file:///Users/kaitkasak/projects/personal/draughts/prototypes/puzzle-set.html?take=now
- **a, a switch in the title row**: three joined tiles (name, size) at the title row's
  right, a row of their own under the title in portrait; today's rows otherwise.
  file:///Users/kaitkasak/projects/personal/draughts/prototypes/puzzle-set.html?take=a
- **b, the name under the title, a picker**: "International · 10 × 10 ⌄" under
  "Puzzles"; a tap opens a glass list of the three with a small board, the size, and each
  set's stars (`&open=1`), and, when shared, "New games too" under it. Ideas: a Continue
  row on top (the next puzzle without stars in the theme last played), stars and "Next:
  Harder 6" per theme, locked themes as a path (pips for Learn's six, "Opens with 3 more
  in Learn"), two columns in landscape.
  file:///Users/kaitkasak/projects/personal/draughts/prototypes/puzzle-set.html?take=b
  and file:///Users/kaitkasak/projects/personal/draughts/prototypes/puzzle-set.html?take=b&v=russian&open=1
- **c, a grid with the setup's tiles**: the new game's draughts tiles (a small board,
  name, size) in the title row (under it in portrait), the themes as cards, four across in
  landscape with Continue as the first card, two across in portrait under a Continue row.
  Ideas: the grid, Continue, stars, locked themes as a path; no "next" line.
  file:///Users/kaitkasak/projects/personal/draughts/prototypes/puzzle-set.html?take=c
- **Home's Puzzles row** following the choice (`&view=home`): the count only when
  shared; the set's name over the count when the puzzles' own, or Brazilian.
  file:///Users/kaitkasak/projects/personal/draughts/prototypes/puzzle-set.html?take=b&view=home&tie=own&v=russian

Every take takes `&tie=shared` or `own`, `&br=shown` or `hidden`, `&v=`, `&stars=none`,
and `&lang=et`. New strings, English and Estonian: `puzzles.for_now` "International's
puzzles for now" / "Esialgu rahvusvahelise kabe ülesanded", `puzzles.continue` "Continue"
/ "Jätka", `puzzles.next` "Next: {}" / "Järgmine: {}", `puzzles.all_done` "All solved" /
"Kõik lahendatud", `puzzles.opens` "Opens with {} more in Learn" / "Avaneb, kui Õpis veel
{}", `puzzles.also_games` "New games too" / "Ka uued mängud".

Proposed: **b, shared**. The choice is the player's draughts, one fact settings and the
new game's tiles already write; a second, puzzles-only variant would need its own key,
home's row naming its set, and a rule for which wins after settings change. b keeps the
title row calm on a phone (a's and c's three tiles take a row of their own there, and
"Rahvusvaheline" is the tightest label), says the choice is rare (most players play one
draughts), and its picker has room for each set's count and Brazilian's "International's
puzzles for now". Brazilian shown, not hidden: hidden leaves a Brazilian player's draughts
with no lit choice, and the set it plays is a real one. Of the ideas, Continue, stars with
the next level, and the path are cheap (home's rows and today's tiles); c's grid uses the
landscape room best but holds the fewest themes on a phone.

Open: shared or own; b's picker or a's switch; which of the library ideas to take, and
whether the grid (c) replaces the rows in landscape only; Brazilian shown or hidden.


## Decisions (2026-11-09)

- **The themes in the first release**: Learn 12, Captures 10, Crowning 12, Shots 20
  (levels 1 and 2), and King shots 10, 64 in all (the user's "about 74" was these
  counts). Safe move, Endgame, and Opening traps come later and are left out of the
  code's theme list until then: adding them is a name, an icon, and a string each.
- **The take count** is worded "Win N men" ("Võida N nuppu", `nupp` being et.txt's word
  for a man, as in "Päästa nupp"), and "Win a man" / "Võida nupp" for one.
- **Black to move**: about a third outside Learn, none in Learn; the panel says "Black
  to move" / "White to move" ("Mustade käik" / "Valgete käik", as et.txt's turns).
- **The picker**: take a, the library list (the user, 2026-11-09), with King shots as a
  fifth first-release theme where the prototype's `themes=first` shows four.

## Built (2026-11-09)

**Format and stars.** `theme NAME` and `level 1..3` replace `tier`; `tier` is now an
unknown key. Learn keeps ids 1, 3, 7, 8 (level 1), 6, 9, 10, 18 (level 2), 14, 17, 19,
20 (level 3); the new puzzles are 31 to 82. `MAX_PUZZLES` is 150. Stars are written as
`stars.international` in the player's file (task 038 moved them there) and the older
`stars` is read as it. A dropped puzzle's stars (2, 4, 5, 11 to 13, 15, 16, 21 to 30)
stay in the file but aren't counted; dropping them on write was left out to keep the
settings change to the key and the table's size, for 038's rebase.

**Learn's fixes.** 6: black's man on 5, not 6, so its one move doesn't hand the king a
capture. 8: rebuilt, two men take two men onto one square (37 by 32, 39 by 33, both to
28) and 33 takes back the first. 9: a king that lands on 15, not 20, where 25 would
take it (`W:W31,K47:B8,24,25`). 10: two white men added on 48 and 49 so the material
after the double is even and the engine scores it +289 (it was −112). 19: rebuilt, the
king takes two and lands on 5, not 10 (`W:W27,K45:B14,15,20,34`). 20: rebuilt; the walk
past the guard couldn't be made quiet with two crowning squares open (a king on 3 or 2
sees every black reply), so it is now take the guard and walk on to 1
(`W:W17,47:B11,22`, 17x6 22-27 6-1).

**Composing.** `tools/puzzles.goose find` places the men in camps (each next man beside
or behind one of its own, on its own side), requires every check to pass and the game to
go on after the line, takes the side (a white puzzle turned round, checked again: the
turned position's hardest reply can differ, which once let a line through unchecked),
and kings. Candidates were picked by line shape (a quiet give answered by a capture;
for Shots level 2 two gives and one capture, `\d+-\d+ \d+x… \d+-\d+ \d+x… \d+x…`),
and by eye with a scratch board printer over `test/perft.py`. Four found ones were
swapped out: three after `build/puzzles` showed the engine rating another move as high
(a second route of the same length that also wins, or an equal quiet move), and one
black crowning whose turned line `find` hadn't yet checked again.

| Theme | Levels 1, 2, 3 | Black to move | Goals |
|---|---|---|---|
| Learn | 4, 4, 4 | 0 | take 1 to 3 in 1, crown in 2 |
| Captures | 4, 3, 3 | 3 | take 2, 3, 4 in 1, two with a king |
| Crowning | 4, 4, 4 | 5 | crown in 1, 2, 3 |
| Shots | 10, 10, 0 | 7 | take 2 or 3 in 2; take 2 or 3 in 3 |
| King shots | 4, 3, 3 | 3 | take 3 or 4 in 1, take 2 or 3 in 2 and 3 |

18 of the 52 outside Learn are black's (35%). `build/puzzles`: 0 problems, the engine's
best solves every take, and no right first move scores under −50. `test/perft.py
puzzles`: 64 puzzles, 0 problems.

**Solver's cost.** The longest lines are five plies (three of the solver's moves), under
`MAX_PLIES` (8), so the limits stay. The most positions a check takes, built: Learn 10,
Captures 8, Crowning 1, 17, and 129 by level, Shots 45 and 294, King shots 8, 81, and
415 (0.2 ms), the most of the set (task 007's 30 took at most 387).

**The picker** is take a, built natively (`src/shell/picker.goose`, its look in
`docs/architecture/rendering.md`): a library of the five themes, and a theme's page of
its levels. Two cases the prototype didn't reach needed a fallback, both Shots' page on a
phone at 480 dp with the Pixel's insets: in landscape under the gesture bar the theme's
mark and count go under back in place of the head; in 9:16 portrait each level's label
is its mark alone beside its tiles. Headless: `test/shell/picker.goose` (the tablet and a
20:9 phone at 480 dp, both orientations, every view), the Learn and Shots pages added to
`test/shell/sizes.goose` at every size, and `test/shell/puzzles.goose` through the
library, a page, a black puzzle on the turned board, half of Learn opening the rest,
and next after a theme's last.

## Safe move (2026-11-09)

Safe move is a sixth International theme (the shield), opening with the others at half
of Learn: 10 puzzles, levels 2, 4, 4 by the moves to weigh (three; five to seven; eight
to twelve), ids 85 to 94, all white to move. `SAFE_DEPTH` is 3 plies (was 2), deep
enough for a double sacrifice. `puzzles::check` adds for a safe puzzle: one move, no
capture due at the start, and every move but the right one losing to a shot
(`puzzles::shot`: no capture due, and a sacrifice after which the solver ends down); the
right move's being safe is that it leaves no shot. Quiet for a safe line is only "no
capture due after it": the threat's sacrifice is still there to offer, so the strict
rule refused every candidate. `find` requires the threat at the start (the other side
to move has a shot) and takes a CORE, a motif's skeleton for white, its men placed
first. Found over 2M tries a seed at 5 to 8 men a side: 122 candidates, of which the
engine disagreed on 12 and scored the right move as losing deeper on 30; the ten were
picked from the rest for different shapes, preferring a safe move worth 0 (not one
that also wins). Every threat is a give one, take two; none of the ten is a double
sacrifice. The most positions a check takes: 801, 1,869, 3,545 by level (0.2 ms built),
the most of the set. `build/puzzles`: 74, 0 problems, the engine agreeing on all.

## Open

- **Safe move**: black to move in a third (turn some with `find black safe`), and level
  3 threats that are double sacrifices.
- **Shots level 3** (named shots, game finishes) and the later themes. Skeletons that
  play the course lines were written for the Haarlem shot (`W:W28,32,34,37:B10,17,19,23`,
  28-22 17x28 34-29 23x34 32x5), the bomb (`W:W27,28,32,37,38,43:B16,17,18,19,23,29`,
  27-21 16x27 32x12 23x41 12x34), the heel shot (`W:W30,34,38,40,45:B21,22,23,25,28`,
  38-33 28x39 34x43 25x34 40x16), coup Philippe (`W:W27,32,34,38,40,45:B11,12,16,18,23,25`,
  27-22 18x27 32x21 16x27 34-30 25x34 40x16), and the royal shot
  (`W:W27,28,32,38,39,40,45:B12,13,14,18,19,23,24`, 27-22 18x27 32x21 23x34 40x7). `find`
  round the Haarlem core gave candidates, but the two checked (a Haarlem shot and a
  Napoleon's shot) had the engine preferring a quiet move, so neither is in.
- **The look on devices**: the new icons (book, jumps, king, the level bars) and the
  glow-colored bar and marks are shader work the headless tests don't see.

## Acceptance criteria

- [x] A prototype of the library and a theme's page, and the user's pick of a take
- [x] The file's `theme` and `level` in place of `tier`, the picker as picked, and stars
      carried over by id per variant
- [x] Learn: about 12 of today's puzzles, each fixed so no capture is due for either side
      after its line and against any reply
- [x] The first release's themes (Captures, Crowning, Shots levels 1 and 2, King shots),
      about a third black to move, each `source` naming its motif or game, none copied
      position for position from any collection (GoDraughts, lidraughts, books)
- [x] `puzzles::check` refuses a puzzle whose end isn't quiet, and one with an unlisted
      solving move later in a line, not only the first
- [x] Every puzzle passes `build/puzzles` with the computer player's best move solving it
      and no right move it scores as losing material; `test/perft.py puzzles` passes
- [x] A black-to-move puzzle tested headless on the turned board, its panel saying whose
      move it is
- [x] The solver's limits fit the longest line (`MAX_PLIES` is 8, four of the solver's
      moves), with its positions per check measured and recorded here
- [ ] The picker checked on the Mac and the tablet (the main session's screenshots)
- [ ] Children play the set and the levels' order holds (the user)
