# 007: Puzzles

Status: done

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

## On the tablet (2026-11-08)

The APK built from `cc08c5a`, run with flags (`--screen puzzles`, `--puzzle ID`, `--lang`,
so `game.bin` was never read or written), the moves played with `adb shell input tap`.
Solving wrote stars to `settings.txt`; the file was put back as it was (the defaults, no
stars) through a debuggable copy of the APK and `run-as`, and the normal APK installed
again.

- Layout: the picker, a puzzle (21), solved (21), and the hint's glow (7 after two
  misses), in 1920 × 1200 and 1200 × 1920, English and Estonian, match the Mac's shots
  pixel for pixel (`magick compare`, 6% fuzz) apart from the hint's label, which is
  "try again" in the Mac's frame and back to the goal by the tablet's. The wrong move,
  shot during its flash, matches by eye: the man slides back, the red ring over the
  fading ghost, "try again" ("Proovi uuesti" fits the landscape panel), a star out.
  Nothing cut off.
- Played from the picker: puzzle 1's selected man showed its target (tier 1), the
  capture solved it, the stars filled and Next lit; Next opened puzzle 2, Puzzles the
  picker with puzzle 1's three stars and puzzle 2 lit. Puzzle 7: 37x28 twice, each
  played, slid back with the ring and ghost, and put a star out; after the second the
  man on 38 glowed. 38x27 solved it with one star, Next opened puzzle 8, and the picker
  showed it. Home then read "7 / 90".
- Frames (`screenrecord`, 90 Hz, 11 ms a frame): every move, slide back, and the stars
  filling ran at 11.0 ms (median), at most 17.5 ms. The first puzzle opened from the
  picker after the launch had one 31 ms and one 20 ms gap in its 0.17 s; later opens
  (Next, the picker, puzzle 7, puzzle 8) none over 17 ms. After the second miss the
  frames stopped about 4 s after the move (the slide back, the flash, the glow coming
  in): nothing keeps drawing.
- `scripts/idle_cpu.sh 60`, landscape: the picker, puzzle 21 at rest, and puzzle 1 three
  seconds after it was solved each 0.02 s on the program's thread (0.03% of a core),
  60 voluntary switches, the process 1.50 to 1.53 s. The game screen in the same build:
  0.02 s, the process 1.47 s, so the process's rise from task 025's 1.25 s isn't the
  puzzles'.
- `scripts/lifecycle_memory.sh 10` on puzzle 21: one process, no errors, PSS 268 to
  272 MB (298 before the first cycle), native heap 27.6 to 28 MB, graphics 211 to 215
  MB; the puzzle was still on screen after. Task 006 had 267 to 271 MB in a game,
  task 025 272 to 274 on settings.
- `--tap` seemed to stop on the tablet at a tap that only selected a piece; these shots
  were played with `input tap`. The loop wasn't the cause (2026-11-08): a recorded launch
  with six taps showed one landing per 11 ms frame, since a frame that draws is never
  followed by a wait. The stop came from `am start` finding the app still running: the
  activity is `singleInstance`, so it came back with the last run's flags, its last tap
  a selection, and the new taps never arrived. `am start -S` stops it first
  (`docs/development.md`); started that way over a running app, `--variant russian` with
  nine taps (four moves, then a selection) landed every one, and a cold start of puzzle
  21 with `f4 e5 e3` played the move, got the reply, and selected e3.

Screenshots and the recording are in the session's scratchpad, not in git.

Since then, on 2026-11-08, with the APK built from `6b20e66` in landscape. The flags use
square names, not numbers: 47 is c1, 33 f4, 17 c7, 8 e9, and 37 c3.

- Puzzle 14, `--puzzle 14 --tap c1 --tap f4 --tap c7`: the king on c1 is selected, f4
  and c7 are ringed, and all three stars stay. Adding `--tap e9` solves it with three
  stars: the king ends on 8, three pieces are taken, and Next lights.
- Puzzle 4 (tier 1), `--puzzle 4 --hints moves --tap c3`: the man on 37 is selected and
  no target shows.
- The run solved by `--tap` didn't write its stars: `settings.txt` was unchanged byte
  for byte afterwards, and the picker still showed 14 with no stars.

## Open for the user

- **Estonian drafts** for task 024's review: Edasi (next), Proovi uuesti (try again),
  Lahendatud (solved), Löö {} (capture N), Saa tammiks (become a king), Võida mäng (win
  the game), Ära anna nuppu (stay safe).
- **"Capture N" counts the balance**: a shot that gives a man and takes three says
  "Capture 2". "Win 2 pieces" would say it exactly; the prototype's word was kept.
- **A miss** is a wrong move or a tap the board flashes as a mistake (a piece that can't
  move, an empty square); the must-capture pulse is held back in puzzles, as it shows
  the answer. Stars never go below one, and start over keeps the misses until solved.
  Since 2026-11-08 the stops of a capture of many jumps tapped one by one aren't misses
  (each took a star before): the board keeps them, ringed, and plays the capture at its
  last square or once only one capture goes on that way, the same in a game; a tap off
  every way is still a miss, and so is a different legal capture.
- **No targets in puzzles** (2026-11-08, the user): no tier shows a selected piece's
  targets, whatever the move hints setting, since the point of a puzzle is that the child
  thinks. Until then tier 1 showed them always and tiers 2 and 3 followed the setting.
- **Tiers open** at half the previous tier solved; every puzzle in an open tier can be
  played in any order.
- **The safe move** looks two plies past the move (a reply and an answer), captures
  played out; a deeper look would catch shots, which the tier's man-in-danger puzzles
  don't need.
- **The ghost** fades from 80% to nothing over the 1.2 s flash; the prototype holds it
  at 35%.
- **Portrait picker**: ten tiles of 66 dp in a row broke the 88 dp floor and left half
  the screen empty; since 2026-11-08 each tier is two rows of five, 122 dp at 800 dp
  wide, the three tiers ending 1128 dp down of 1280, with the title beside back as in
  settings. Landscape is as it was. The prototype has no title; that one is added.
