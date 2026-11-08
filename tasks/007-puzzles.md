# 007: Puzzles

Status: done (on the Mac; the tablet is checked at the merge)

Puzzles in a plain text file: a position, the side to move, a goal ("win material",
"crown", "capture all") and the solution lines. A move that reaches the goal by a
different line counts too. About 30 for International 10×10 first, in three tiers
(2026-11-08: the default game, and a starting point for Russian ones later).

## Puzzle screen takes (2026-11-08)

`prototypes/puzzle.html`; the user picked take c on 2026-11-08; `?take=` and `&state=play`,
`wrong`, `hint`, or `solved`. All keep the game screen's layout (puzzles, settings, and
start over on the left; the goal, three stars at stake, and one big tile on the right),
and a wrong move slides back by itself, its square flashing the red ring over a fading
ghost of the piece, with "try again" and a star going out.

- **a**: the goal as the side to move, the theme's icon, and "Capture 2"; a hint tile
  where take back is, which makes the piece to move pulse a glow ring; a miss or the hint
  costs a star; solved shows the card over the dimmed board, again or next.
- **b**: the goal drawn as the pieces to take, which dim as they go; the hint tile
  appears only after a miss and is free; the theme's ten as dots with next on the left,
  to move on at any time; solved shows the card.
- **c**: no hint tile, as in a game: after two misses the piece to move glows by itself;
  next is the big tile, dim until solved, then lit, with the stars filling in the panel
  and no card over the board.

## First, from task 020's review

- [x] Move the game panel's layout from `board::layout` to `game` (review item 2), so the
  puzzle screen's panels are laid out where the game's are: `panel::layout`.
- [x] A `test/drive/` package for the UI tests' shared helpers (item 5) before the puzzle
  tests add another copy.

## Acceptance criteria

- [x] Format documented, loaded at startup, validated by the rules engine (every solution legal)
- [x] Tier 1: find the capture; tier 2: multi-jumps and mid-capture crowning; tier 3: shots
      and "the only safe move"
- [x] Wrong move: a gentle undo and retry. Hint: highlight the piece to move
- [x] Sources recorded per puzzle, with licenses checked

## Built (2026-11-08)

- `puzzles/` ([puzzles.md](../docs/architecture/puzzles.md)): the file format and its
  loader, an exact search for the goals (take N, crown, win, safe) with its moves on one
  fixed stack, and `puzzles::check`. `tools/puzzles.goose` checks the file with the
  computer player too, and its `try` and `find` help compose; `test/perft.py puzzles`
  replays the lines with the independent generator.
- `puzzles/international.txt`: 30 puzzles, ten a tier, all composed here. Tiers 1 and 2
  by hand; tier 3's shots and safe moves picked from positions `tools/puzzles.goose find`
  turned up (random men in a game's camps with exactly one first move that solves them),
  the safe ones a man attacked that one move saves. None copied, so no license applies.
- The screens: the picker (`prototypes/puzzles.html`) and the puzzle (take c), from
  home's puzzles row, which now notes the stars won ("0 / 90"). `prototypes/solved.html`
  is take a's and b's card, not used by take c. The board gained a move sliding back
  with the ghost and red ring (`board::slide_back`) and a hint glow
  (`board::glow_on`), in place of the unused `board::hint`. Five icons: two stars, a
  lock, a crown, a shield.
- Progress: `stars = 1:3 4:2` in `settings.txt`.

## Measured (2026-11-08)

- Puzzles: tier 1 10, tier 2 10, tier 3 10; 4 to 14 pieces; 22 of one move, 8 of two
  (the crown past the guard and seven shots).
- `build/puzzles`: 30 puzzles, 0 problems. The computer player at full skill (4 million
  nodes) rates a solving move best in all but puzzle 13, a crown, where it plays the
  other capture for material, as expected. One safe candidate was dropped when the
  engine found its "safe" move lost more later (a shot past the solver's two plies).
- `test/perft.py puzzles international puzzles/international.txt`: 30 puzzles, every
  line's move legal and every position's moves the same as `build/perft`'s.
- Cost of the checks: at most 387 positions for a puzzle (puzzle 27), under 0.1 ms
  built; the screen's judging of a move searches no more.
- Tests: 27 through TinyCC and built at -O2, all passing; `test/puzzles/` (goals,
  the set) and `test/shell/puzzles.goose` are new.
- Mac: a `--frames` run draws about 1,600 frames a second, so the shots wait 1,600
  frames for a wrong move's slide and 6,000 for the hint and solved. Left alone, the app
  takes the same CPU on the puzzle screen, the picker, and the game screen on the Mac,
  where a window started from a terminal never idles; the headless test checks that
  nothing animates once a puzzle is still, and `scripts/idle_cpu.sh` measures it on
  the tablet.
- Screenshots (local): `play`, `wrong`, `hint`, `solved`, `picker`, `home`, in 960 × 600
  and 600 × 960, English and Estonian, beside the prototype's take c.

## Open for the user

- **Estonian drafts** for task 024's review: Edasi (next), Proovi uuesti (try again),
  Lahendatud (solved), Löö {} (capture N), Saa tammiks (become a king), Võida mäng (win
  the game), Ära anna nuppu (stay safe).
- **"Capture N" counts the balance**: a shot that gives a man and takes three says
  "Capture 2". "Win 2 pieces" would say it exactly; the prototype's word was kept.
- **A miss** is a wrong move or a tap the board flashes as a mistake (a piece that can't
  move, an empty square); the must-capture pulse is held back in puzzles, as it shows
  the answer. Stars never go below one, and start over keeps the misses until solved.
- **Tier 1 shows the targets** of a selected piece whatever the move hints setting, as
  `docs/product.md` has moves on in the first puzzles; tiers 2 and 3 follow the setting.
- **Tiers open** at half the previous tier solved; every puzzle in an open tier can be
  played in any order.
- **The safe move** looks two plies past the move (a reply and an answer), captures
  played out; a deeper look would catch shots, which the tier's man-in-danger puzzles
  don't need.
- **The ghost** fades from 80% to nothing over the 1.2 s flash; the prototype holds it
  at 35%.
- **Portrait picker tiles** are 66 dp, under the 88 dp for small hands, to fit ten in a
  row on 800 dp.
