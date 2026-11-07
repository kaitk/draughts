# Testing

How to run everything: `docs/development.md`, "Test the rules". Run `scripts/test.sh`
before committing a change to `rules/`.

## What each kind of test is for

- `test/<area>/<name>.goose` with `test/expected/<name>.out`: one program per behavior,
  printing what a reader can check by eye (positions as FEN, moves sorted, how many
  pieces each takes). A test explains in a comment what rule it shows and why the
  position shows it. Areas so far: `rules`, `board` (taps and hints through the board
  package), `gui`, `game` (the game screen driven through the pointer: undo, hint,
  restart, the toggle, presses kept apart, the celebration), `shell` (home, the switch
  to the game and back, settings and their file, the saved game and damaged images of
  it), and `strings` (every language file has every key). A
  test that lays out text calls `gui::test_faces` for glyph sizes without an atlas, and
  `strings::use` before reading a string. Shared helpers are in
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
`scripts/idle_cpu.sh` for CPU while idle. Run them when a larger iteration finishes (a
task, or a group of subtasks), or when a change is likely to move idle or memory (new
textures, threads, frame pacing), not after every small change (2026-11-07). A run
during which the tablet was touched or rotated isn't an idle figure. Things learned
measuring there:

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
- Rotation for a screenshot: `adb shell settings put system accelerometer_rotation 0`,
  then `user_rotation 0` is portrait (1200 × 1920) and `1` landscape on this tablet;
  read both settings first and put them back after.
- A button's press shows in a screenshot taken during a long press:
  `adb shell input swipe X Y X Y 2500 &`, then `adb exec-out screencap -p` a second later.
- The batterystats estimate reads 0 while the tablet charges over USB, so it says
  nothing; CPU time is the measure.
