# 119: A lean test suite, the long checks apart

Status: in-progress (built and measured 2026-11-25; the user to agree the split, then archive)

`scripts/test.sh` runs everything before a commit and takes a long time (the user,
2026-11-25: "SUPER long"). It runs, in order: the strings' keys and the two roots' check;
`goose check` of the app (its shaders compiled) and with `NGFX` the ngfx root through
`scripts/ngfx.py`; `test/run_tests.py` (about 130 programs against golden output, through
TinyCC, 7 at -O2); `tools/perft.goose` built natively, then perft from four start positions
(depths 8 and 9); `test/perft.py compare` playing random games against the independent
Python move generator in three variants; and `test/perft.py puzzles` checking every puzzle's
lines for each variant. Most of these test the rules, which change rarely, but every
commit to the 3D scene pays for them.

## Acceptance criteria

- [x] Each step's time measured on the Mac (cold and warm), written here
- [x] What each step catches that the others don't, and which ones have broken in the
      last months (git log)
- [x] A split proposed to the user: a quick suite for every commit (seconds, not minutes,
      at least the shaders' compile and the fast golden tests), and the long checks
      (perft, the Python comparison, the puzzles, the -O2 builds) run when `rules/`,
      `puzzles/` or the AI change, and in CI
- [x] Slow tests made faster where that is cheap (smaller depths that still catch the
      same bugs, parallel runs), checked to still fail on a planted bug
- [x] The scene's timing too (`agents/perf.md`): a quick check of about a minute for a
      small change such as a new prop (the user, 2026-11-25: as the tablet's), one view
      with the object in it and the corner only if needed, one size, before and after
      alternated, with a script; the long batch (four views, two sizes, two rounds, about
      ten minutes) kept for optimization work
- [x] `agents/testing.md`, `docs/development.md` and `AGENTS.md` updated to say which suite
      to run when

## Results (2026-11-25, the Mac, 10 cores)

Each step of the old `scripts/test.sh`, cold and then warm (s):

| Step | Cold | Warm |
|---|---|---|
| strings' keys, the two roots | 0.1 | 0.1 |
| `goose check` of the app | 1.4 | 1.4 |
| `scripts/ngfx.py` (NGFX set) | 3.0 | 2.5 |
| `test/run_tests.py` | 41.9 | 38.1 |
| perft: build, four counts | 1.2 | 1.2 |
| `compare`, four variants one after another | 31.9 | 31.6 |
| `puzzles`, three sets | 2.1 | 2.1 |
| All | 81.6 | 77.0 |

Through TinyCC, test by test, the 127 tests took 105 s of CPU, 81 of it the seven
`SLOW` ones: `aim` 28, `library` 19, `camera` 11, `pace` 10, `levels` 5, `blunders` 4.5,
`tree_whole` 3. Built at -O2, `aim` and `camera` take 15 s to build and 1.6 and 0.6 s to
run; `pace` 8 and 1; the others under 4 together. Every other test takes 0.2 to 2.7 s.

What each step catches that the others don't: `goose check` the shaders' GLSL and the
app's types; the golden tests what each area prints; perft published counts, the only
check of move generation's totals; `compare` move lists the golden tests' positions
don't reach, and Russian's only independent check; `puzzles` each puzzle's line against
the independent generator. In git, 59 of 1,876 commits touched `src/rules/`,
`src/ai/`, `src/puzzles/`, `tools/perft.goose` or `test/perft.py`, 171 with
`src/board/` and `src/game/`, against 306 for `src/render3d/`, `src/model3d/` and the tuner.
A search of the commit messages found none saying perft, `compare` or the puzzles' lines caught a bug since
the rules' first commits; they guard a part that rarely changes.

The split (`docs/decisions/layout.md`, "Tests: a quick suite and the whole"):

| Suite | Before | After |
|---|---|---|
| `scripts/test.sh quick` | (none) | 16 s |
| `scripts/test.sh` | 77 s | 40 s |
| `test/run_tests.py --quick` | (none) | 11.5 s |
| `test/run_tests.py` | 38 s | 22 s |

- One `goose FILE` a test, as workers come free, beat `--multi-test` batches: a batch of
  1 or 2 files 11.6 to 11.9 s, 4 12.4 s, 8 14.2 s, the old alphabetical tenths 17.4 s
  (`--quick`).
- The seven `test/perft.py` checks at once: 34 s to about 11, `compare english` (10 s)
  the longest.
- Planted bugs: Russian's crowning mid-capture turned off in `src/rules/rules.goose`
  failed 8 tests of the quick suite (`rules/russian_crowning`, `ai/judge`,
  `puzzles/russian_set`, …); the same bug in `test/perft.py` alone failed the full suite at
  `compare` (10 and 12 positions differ) and the Russian puzzles (23 problems), with exit 1.
- Perft's depths stay: 0.2 s a variant.

The scene's quick timing, `tools/perf/mac_room_bench.py` (the table's view, 3840 × 2160,
two rounds A B A B): 35 s for one view, 63 s with the corner. One build against itself:
12.60 and 12.55 ms (table), 14.00 and 13.95 (corner). Builds aeacc3c2 against f4b53a40,
the chairs' round 2 between them: 12.10 against 12.60 ms, +4.1%. A fresh binary's first
runs read 26 to 38 ms all through, so the script warms each build with 3 s at 640 × 360 in
the first view, after which it reads 12.6 to 12.7.

On 2026-11-25 macOS's update left the Command Line Tools' 27.2 SDK newer than Xcode
26.4's linker: every native build failed to link (`unknown architecture` in
`libSystem.tbd`). These numbers were taken with
`DEVELOPER_DIR=/Library/Developer/CommandLineTools` (`agents/testing.md`).
