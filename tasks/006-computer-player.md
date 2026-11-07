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
  pinned to its little ones, over ten middlegames of both variants (below). Measure
  again in the app, where thinking shares the frame.
- [x] Works for both variants from task 002: every `test/ai/` test and the benchmark use
  Russian and International positions.
- [ ] Wired into home ("The computer") and the game screen

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

## Wiring it in (next)

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

## Open for the user
