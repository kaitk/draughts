# 006: Computer player

Status: in-progress

Alpha-beta search with a fixed transposition table allocated once. Three levels made
weaker by shallower depth and deliberate, plausible mistakes, never by obvious blunders.
It runs off the main thread or in small slices, so the UI never stalls.

## Acceptance criteria

- [ ] Levels easy, medium, hard; an older child beats easy, and hard beats a casual adult.
  Built and ordered (`ai/`, [design](../docs/architecture/ai.md)): against itself each
  level beats the one below nearly every game (measurements below). Whether children
  beat easy and hard beats an adult needs the screens wired and people playing.
- [x] Hard replies in under 1 s on the tablet: 207 ms at most on its big cores, 631 ms
  pinned to its little ones, over ten middlegames of both variants (below). The app's
  worker, run on the tablet as the app runs it, takes at most 200 ms (2026-11-08), under
  hard's 0.45 s pause, so the pause decides when its move comes. In the app on the
  tablet hard's move starts 454 ms after the child's lands, in Russian and in International
  middlegames (2026-11-08, below).
- [x] Works for both variants from task 002: every `test/ai/` test and the benchmark use
  Russian and International positions.
- [x] Wired into home ("The computer") and the game screen (2026-11-08, below): checked
  in the app on the Mac, headless, and in the app on the tablet.

## Notes (2026-11-07)

- The engine is `rules/`: `rules::generate` fills a fixed `rules::Moves` buffer and
  `rules::play` returns a new position, so a search keeps one buffer per ply and no
  undo. Perft runs at 12 to 16 million positions a second natively on an M-series Mac
  (`docs/architecture/rules.md`); the tablet's speed is not measured yet.
- An idle `gfx::frame()` waits up to 1 s for an event (`docs/architecture/rendering.md`,
  "Frames and battery"), so a reply from a worker thread is seen within that second
  unless the board animates while the computer thinks. Animate something while it does.

## Playing like a person (2026-11-07)

Engines weakened by a shallower search, noise, or an occasional second-best move play
"like a computer": they hang a piece no person would, then find a long combination a
move later. For kids the computer should be weaker the way a person is weaker. Prior
art, nearly all chess and Go (nothing found for draughts):

- Maia (McIlroy-Young et al., KDD 2020): a network trained to predict the move a human
  of a given rating plays; it matches human moves over half the time at each level,
  1100 to 1900. Maia-2 (Tang et al., 2024, arXiv 2409.20553): one model with skill as
  an input, so strength changes smoothly.
- Allie, "Human-aligned Chess with a Bit of Search" (2024, arXiv 2410.03893): learns
  from human game logs, including thinking time, and searches only where a human would
  think hard.
- Without learning (not checked against the papers): Regan and Haworth's intrinsic
  ratings (about 2011) model the chance a player of a given strength picks each move
  from how much worse it is than the best; Guid and Bratko measure a position's
  difficulty by the depth at which the best move becomes clear; piKL (Jacob et al.,
  2022) mixes a human-imitation policy with search.
- A Maia-style network for 10×10 might later be trained on Lidraughts games, if its
  database can be exported; not for the MVP.

What to build here, without learning:

1. Mistakes a person makes: miss a good move or a threat only when its point shows deep
   in the search; never one whose refutation is two plies away. The level sets how far
   the computer "sees". Forced captures already rule out the commonest silly blunder.
2. Consistent strength: choose among good moves with chances that fall off with how much
   worse each is (Regan's model), one skill setting for the whole game, so no genius
   moves among random blunders.
3. No long combinations on easy: it never searches past the depth it plays at.
4. Adapt to the child: move the skill a little after each win or loss, so each child
   meets an opponent they beat about half the time.
5. Leave chances to learn: on the easiest level, now and then prefer a move that leaves
   the child a capture or a combination to find.

## What was built (2026-11-07)

`ai/` searches with alpha-beta cut into steps (`ai::start`, `ai::step`, `ai::reply`), a
4 MB table made once, and three levels from one skill setting (0 to 100) that sets how
far it sees, how it chooses among good moves, and how often it leaves a combination on
the easiest skills. `ai::adapt` moves the skill after each game. The design and its
reasons are in [the computer player](../docs/architecture/ai.md).

Tests (`test/ai/`): `search` (the stepped search against a plain recursive minimax; the
table changes no exact root score), `keys` (incremental Zobrist keys over random games
of all three variants), `levels` (each skill's settings; every level's move in five
known shots with what a deep search thinks of it; the same move in steps of 7 nodes as
at once, under four seeds; adapt), `blunders` (no level, under varied seeds, plays a move
the opponent's captures punish unless its own search sees the material come back; the
combinations left for the child never leave a capture).

Tools: `tools/aibench.goose` (reply time and nodes a second per level),
`tools/aimatch.goose` (the computer against itself), `scripts/android_cli.sh` (a headless
program built for and run on the tablet).

## Measurements (2026-11-07)

Reply times from `tools/aibench.goose`: five Russian and five International positions
(the starts and middlegames from the computer's own games), seed 1, the slowest of the
ten. Built at -O2 (Mac) or with the NDK's clang at -O2 (tablet, `scripts/android_cli.sh`,
no other app running). The table is 4 MB and hard's node limit 800,000.

| | Easy | Medium | Hard | Hard's speed |
| --- | --- | --- | --- | --- |
| Mac, M-series, built | under 1 ms | under 1 ms | 103 ms | 9.3M nodes/s |
| Mac, `goose run` (TinyCC), Russian only | 1 ms | 3 ms | 756 ms | 1.1M nodes/s |
| Tablet, default scheduling (big cores) | under 1 ms | 2 ms | 207 ms | 4.3M nodes/s |
| Tablet, `taskset 0f` (little cores) | under 1 ms | 7 ms | 631 ms | 1.5M nodes/s |

Easy and medium finish their depth in at most 9,000 nodes. Hard reaches 9 to 13 plies of
free moves in Russian middlegames and 7 to 8 in International before the node limit; it
plays the same moves on the Mac and the tablet, since it counts nodes.

How the limit and the table were chosen, hard against hard, 20 games, colors swapped:

| | Russian | International |
| --- | --- | --- |
| 1,000,000 nodes against 100,000 | 7 won, 8 drawn, 5 lost | 8 won, 12 drawn, 0 lost |

More nodes help on 10×10, so hard gets as many as stay under 1 s on the little cores:
1M took up to 986 ms there with a 2 MB table, 800,000 takes 631 ms with 4 MB. Against
the 2 MB table, 4 MB made hard a fifth faster on the Mac and a ply deeper in International
middlegames; 8 MB was slower than 4.

Strength by skill, the higher skill's wins, draws, and losses over 20 or 30 games:

| | Russian | International |
| --- | --- | --- |
| Hard (90) against medium (45) | 20, 0, 0 | 20, 0, 0 |
| Medium (45) against easy (10) | 20, 0, 0 | 20, 0, 0 |
| 15 against 0 | 25, 2, 3 | 16, 3, 1 |
| 30 against 15 | 19, 7, 4 | 20, 0, 0 |
| 45 against 30 | 18, 7, 5 | |
| 60 against 45 | 19, 7, 4 | |
| 75 against 60 | 16, 4, 0 | |
| 90 against 75 | 15, 5, 0 | |

A first depth formula, `2 + s² / 1000`, held depth at 2 from skill 0 to 31: skill 30
drew even with 10 (8, 5, 7), so adapting within easy changed nothing a child would feel.
`1 + s / 12` from skill 0, steeper above 60, makes each 15 points win about three games
in four.

## Wiring it in (plan, 2026-11-07; the worker settled below replaced the slices)

- The game screen starts a search when the computer is to move, calls `ai::step` each
  frame with a time budget (`clock()` around steps of a few thousand nodes), and plays
  `ai::reply` through the board's move animation. The reply should not appear at once:
  easy answers in under a millisecond, so give it a short pause, as a person takes.
- Animate something while it thinks (a pulse on the side to move): an idle frame waits
  up to 1 s for an event.
- Threads: `goose run`, how the app runs on the Mac, refuses a program that starts one,
  so the stepped search on the drawing thread is the one form that works on both. On
  the tablet a frame's slice runs at the drawing thread's speed; at 10 ms a frame on a
  big core hard takes about 20 frames, on a little core about 60. If that is too slow,
  a worker thread (`thread_fn` with `ai::think`, positions and moves through typed
  queues) works on Android, but only if the Mac also builds the app with `goose build`.
- The `ai::Engine` (about 6 MB) is owned by `main` or a global root and lent to the game
  screen; `ai::init` once at startup.
- Home's "The computer" sets the level; the skill per level and child can be kept in the
  settings and moved with `ai::adapt` after each game. A seed per move (game count and
  ply) keeps replies varied yet reproducible.


## Settled while scoping (2026-11-08)

- The computer thinks on a worker thread (`thread_fn`), not in slices on the drawing
  thread. The Mac then runs the app with `goose build`, not `goose run`;
  `docs/development.md` and `ai.md` say so. The thread stays in `app/`, so `game/`,
  `shell/`, and the tests run headless through TinyCC with the search called directly.
  The worker steps the search and checks between steps whether the game still wants the
  reply, so take back or leaving the game drops a search under way.
- Take back against the computer takes back the computer's reply and the child's move,
  so it is the child's turn again; while the computer thinks it drops the search and
  takes back the child's move.
- The child picks white or black in the setup (task 021); the computer plays the other.
- With a clock, the computer's clock runs while it thinks and during its pause, with the
  same increment.

- The worker thread follows Goose's own patterns for threads (`thread_fn`, typed queues,
  a worker building its own root), as the release's `docs/` and samples
  `23_mandelbrot_threads.goose` and `32_pool_worker_snapshots.goose` write them.

## Wired in (2026-11-08)

- `app/think.goose`: one worker thread (`thread_fn`), started at the first ask, builds
  and inits its own `ai::Engine`, waits on the queue for `game::Ask` (id, position,
  skill, seed), steps the search 10,000 nodes at a time and polls for a newer ask
  between steps, which drops the search; it answers with a `Thought` (move, nodes,
  time). The app gives the worker the game's ask when it changes and the game the answer.
- `game/`: on the computer's turn the game opens an ask, plays the answer through the
  board's move animation once the pause is over (0.8, 0.6, 0.45 s by level, from the
  child's move landing), pulses the computer's ring on the panel meanwhile (also on its
  clock's piece before the clocks start), and keeps the child's hands off its pieces.
  Take back takes two plies (one while it thinks; none before the child's first move);
  start over, home, settings, and Android pausing drop the ask. The game reports its
  result once, as it first ends.
- `shell/`: `settings.txt` keeps `skill_easy`, `skill_medium`, `skill_hard` (from
  `ai::level_skill`, kept within the level's band when read) and `games`, the games
  begun against the computer. Play against the computer starts the game at its level's
  skill with the count as its number (seed: number × 1000 + ply) and raises the count;
  a reported result moves the level's skill with `ai::adapt`. The saved game keeps its
  skill, number, and whether its result was counted (`VERSION` 3).
- The Mac builds the app (`goose build -o ../build/draughts draughts.goose`, about
  3 s); `docs/development.md` says how. `--level` joins `--computer`; `--tap` no longer
  plays the computer's moves.
- Tests: `test/game/computer.goose` (the ask, legal answers at each level after their
  pauses, the pulse, no moving the computer's pieces, take back of two plies and while
  thinking, dropped and stale answers ignored, leaving and returning, the child playing
  black, start over, the result once; nothing animates once the reply has landed) and
  `test/shell/adapt.goose` (a win on easy raises its skill to 14, a loss on medium
  lowers it to 41, start over counts nothing, the file keeps the skills and clamps them
  to the band, a restored game asks at its own skill); `resume`, `settings`, and `shell`
  show the skill and count.

## Measurements in the app (2026-11-08)

The tablet was PIN-locked, so the app couldn't come to the foreground there. The worker
was measured on the tablet as a headless program running the app's `think.goose`
unchanged, driven over the same queues (`scripts/android_cli.sh`, default scheduling):
the worker's own time per ask over four middlegames (black to move, from
`tools/aibench.goose`'s), and the round trip from `qput` to the answer.

| Tablet, worker | Easy | Medium | Hard | Hard's nodes |
| --- | --- | --- | --- | --- |
| Russian, each middlegame | 0.2 ms | 0.4 to 0.7 ms | 167 to 184 ms | 800,000 |
| International, each middlegame | 0.2 to 0.3 ms | 0.9 to 2.0 ms | 178 to 200 ms | 800,000 |
| Round trip, slowest | 2.6 ms (the first ask, with the engine's init) | 2.1 ms | 201 ms | |

- A hard search dropped 5 ms in for an easy ask: the easy answer came 2.1 ms after it was
  asked, so a take back never waits on a stale search.
- The worker idle: blocked in `qget`, state `S`, its CPU time (1.46 s, all of it the
  searches) and voluntary switches (25) unchanged over 12 s: it waits, it doesn't spin.
- From the child's move landing to the computer's move starting, in the app built on the
  Mac, hard, eight moves of a Russian middlegame: 450.0 to 450.5 ms, the pause; the
  search took 91 to 100 ms (800,000 nodes) and its answer reached the game within a
  frame of finishing. On the tablet the worker finishes inside every level's pause on
  the big cores, so the move starts at 0.8, 0.6, or 0.45 s after landing plus at most a
  frame; on the little cores hard's search (631 ms in the benchmark) would decide.
- The drawing thread no longer searches: it only puts the ask on the queue once a turn
  and polls for the answer each frame.
- Idle after a reply, headless: once the reply has landed nothing animates
  (`test/game/computer.goose`), so the app draws nothing more (a running clock still
  draws once a second).

## In the app on the tablet (2026-11-08)

The app built from `564931d`, run on the tablet with flags (`--computer black --level
...`, so `game.bin` was never read or written), landscape, the screen recorded with
`adb shell screenrecord` while `adb shell input tap` played the child's move. The time
is from the frame the child's piece lands (its last-move marks appear) to the frame the
computer's move starts, read from the recording's frame times; the display runs at 90 Hz,
so a frame is 11 ms.

| From landing to the move | Easy (0.8 s) | Medium (0.6 s) | Hard (0.45 s) |
| --- | --- | --- | --- |
| Russian, after c3-d4, 3 runs each | 804 to 805 ms | 606 to 607 ms | 454 ms |
| International, hard, 4 middlegames from `tools/aibench.goose`, 6 runs | | | 453 to 454 ms, once 465 |

- The worker finished inside every pause: each move started at the pause plus at most a
  frame (the 465 ms is one frame late). The worker thread's CPU time per process, its
  engine's init and one hard search, was 0.21 to 0.24 s, and it last ran on a big core
  (CPU 4 to 7) every time.
- While the computer thinks the app draws every vsync (the pulse): about 89 frames in
  easy's 0.8 s. Once its move lands the recording gets no more frames: nothing is drawn.
- Idle after a hard reply in an International middlegame, 60 s untouched: no clock, the
  program's thread 0.01 s (0.02% of a core), the process 1.25 s, 60 voluntary switches;
  the child's clock running (5+3), 0.31 s (0.52%), the process 1.60 s, 60 switches, the
  clock showing 3:57 after the minute. Task 021 had 0.03% and 0.53%. The worker meanwhile
  sleeps in `qget` (state `S`): its CPU time (0.20 s) and voluntary switches (2) didn't
  change over the minute.
- `scripts/lifecycle_memory.sh 10` in a 5+3 International game against hard, after its
  reply: one process, no errors. The first run held PSS at 333 to 335 MB and graphics at
  272 to 274 MB from the first cycle on (269 and 205 before it); a second run, in a fresh
  process, 269 to 271 MB, graphics 206 to 208, and a friend's 5+3 game 267 to 269,
  graphics 211 to 213. Native heap 27 to 28 MB in all. Each run was flat over its cycles,
  so nothing leaks; the first run's extra 65 MB of graphics was the driver's (at rest a
  minute later the same process was at 241 MB, graphics 180) and didn't repeat. Task 021
  had 261 to 263 MB, graphics 211 to 213. The worker adds about 5.6 MB of anonymous
  memory (`Unknown` in `dumpsys meminfo`, 1.1 MB before the first ask, 6.7 after).
- The pulse: the computer's ring on the panel fades from full gold to dim and back, as
  described; within easy's 0.8 s pause it goes from full to about a third
  (`006-pulse-strip.png`, three frames 0.3 s apart).
- Take back after the reply returns the start position with white (the child) to move.
  Take back 0.2 s into the pause takes back the child's move, and the computer plays
  nothing in the 3 s after.
- The computer's pieces don't move: a 0.5 s drag of a black man from b6 to a5 during the
  pause, and a tap on d6 then c5 on the child's turn, left them where they were; the
  computer then played its own move.

Screenshots and recordings are in the session's scratchpad, not in git.
`scripts/idle_cpu.sh` found two `SDLThread`s once the worker existed and printed
negative times; it now takes the first, the program's (these numbers came from a copy
that did the same).

## Open for the user

- The levels' skills stay as they are for now (the user, 2026-11-08: medium looks fine,
  adapting is bounded to 20 either side of each level's start); retune after children
  have played.
- Taken as defaults (2026-11-08), each easy to change:
  - The pauses: 0.8 s on easy, 0.6 on medium, 0.45 on hard, counted from the child's
    move landing; the pulse: the ring from full to a third and back every 1.2 s.
  - A game counts once, when it first ends; taken back and ended again it doesn't count
    again. A loss on the clock counts as any loss. The rules have no draw; one would
    leave the skill.
  - Take back right after the computer's first move (the child playing black) does
    nothing, as at the start, rather than make the computer play it again.
  - `games` counts games begun against the computer from home's play; a game started
    with `--computer` uses the count without raising it.
  - Leaving the game or Android pausing the app drops the search, and the pause starts
    again on return.
- Whether an older child beats easy and hard beats an adult needs people playing.
