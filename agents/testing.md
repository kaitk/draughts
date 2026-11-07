# Testing

How to run everything: `docs/development.md`, "Test the rules". Run `scripts/test.sh`
before committing a change to `rules/`.

## What each kind of test is for

- `test/<area>/<name>.goose` with `test/expected/<name>.out`: one program per behavior,
  printing what a reader can check by eye (positions as FEN, moves sorted, how many
  pieces each takes). A test explains in a comment what rule it shows and why the
  position shows it. Areas so far: `rules`, `board` (taps and hints through the board
  package), and `strings` (every language file has every key). Shared helpers are in
  `test/check.goose` (`check::show`, `check::play_only`), imported as
  `import check from "../";`.
- `test/perft.py`: an independent generator sharing no code or layout with `rules/`.
  Use `test/perft.py moves VARIANT FEN` to get the expected moves of a new test position
  before blessing it, and `compare` to sweep random games after any change to move
  generation. Keep it plain and independent: it's the only check of Russian.
- `build/perft`: published counts, speed, and `--divide` to find which move's subtree
  differs when a count is off.

## Rules

- Add a test for behavior that could break unnoticed, not to cover lines. A new rule
  edge case gets a position in `test/rules/`, checked against `test/perft.py moves`.
- An expected output changes only with a reason in the commit. Read the diff
  `--bless` makes before committing it.
- Tests run through TinyCC by default and with `--build` natively. A difference
  between the two is a compiler finding (`agents/goose.md`).

## On the tablet

What can't run headless is checked on the tablet with scripts that print numbers:
`scripts/lifecycle_memory.sh` for memory across pause, resume, and rotation, and
`scripts/idle_cpu.sh` for CPU while idle. Things learned measuring there:

- The screen sleeps after 5 minutes and Android then pauses the app, so a longer run
  measures a paused app. Run `adb shell svc power stayon usb` first (and
  `adb shell input keyevent WAKEUP; adb shell wm dismiss-keyguard`), and
  `adb shell svc power stayon false` after. A paused app may also be killed by the
  system's backup.
- simpleperf can't sample here (no `cpu-cycles` or `cpu-clock` events), and debuggerd
  needs root. Per-thread `/proc/<pid>/task/<tid>/stat` (fields 14 and 15, in 1/100 s)
  and `voluntary_ctxt_switches` in `.../status` tell a spinning thread (near 100%, no
  voluntary switches) from a waiting one. The program runs on the thread named
  `SDLThread`.
- To see inside SDL, add `SDL_Log` lines to the copy in `build/android/SDL_src/`
  (never the submodule), then delete `build/android/SDL_src/.draughts-stamp` so the next
  build copies it fresh. Grep the APK's `libSDL3.so` with `strings` to make sure the
  logs are gone.
- The batterystats estimate reads 0 while the tablet charges over USB, so it says
  nothing; CPU time is the measure.
