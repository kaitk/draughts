# 119: A lean test suite, the long checks apart

Status: todo

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

- [ ] Each step's time measured on the Mac (cold and warm), written here
- [ ] What each step catches that the others don't, and which ones have broken in the
      last months (git log)
- [ ] A split proposed to the user: a quick suite for every commit (seconds, not minutes,
      at least the shaders' compile and the fast golden tests), and the long checks
      (perft, the Python comparison, the puzzles, the -O2 builds) run when `rules/`,
      `puzzles/` or the AI change, and in CI
- [ ] Slow tests made faster where that is cheap (smaller depths that still catch the
      same bugs, parallel runs), checked to still fail on a planted bug
- [ ] The scene's timing too (`agents/perf.md`): a quick check of about a minute for a
      small change such as a new prop (the user, 2026-11-25: as the tablet's), one view
      with the object in it and the corner only if needed, one size, before and after
      alternated, with a script; the long batch (four views, two sizes, two rounds, about
      ten minutes) kept for optimization work
- [ ] `agents/testing.md`, `docs/development.md` and `AGENTS.md` updated to say which suite
      to run when
