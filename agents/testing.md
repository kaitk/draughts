# Testing

How to run everything: `docs/development.md`, "Test the rules". Run `scripts/test.sh`
before committing a change to `rules/`.

In a separate working tree of the repo, make `build/` a real directory holding only a
symlink to the main checkout's `build/goose-v2026.4-macos-arm64`, not a symlink to its
whole `build/`: the tests and tools write `build/perft`, `build/test/`, and the like,
which would overwrite the main checkout's while another session uses them.

## What each kind of test is for

- `test/<area>/<name>.goose` with `test/expected/<name>.out`: one program per behavior,
  printing what a reader can check by eye (positions as FEN, moves sorted, how many
  pieces each takes). A test explains in a comment what rule it shows and why the
  position shows it. Areas so far: `rules`, `board` (taps and hints through the board
  package), `gui`, `game` (the game screen driven through the pointer: take back, start
  over, home and settings, presses kept apart, the celebration, a clocked game with its
  frames, pause, and flag, the turned board; the computer's turn, answered at once with
  `ai::think` as the app's worker would; and the clock value on its own), `shell`
  (home, the switch to the game and back, settings and their file, their taps and the
  board beside them, home's setup and play, the saved game of any variant and damaged images of it, the computer's skill
  moving across games), `strings` (every language file has every key), and `ai` (the computer player:
  its search against a plain minimax, the table changing no score, keys, what each level
  plays in known shots, the same move in steps as at once, and that no level hangs a
  piece). A
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

## The computer player's tests

- The search counts nodes, so a test's moves change with `Engine.node_limit`. Tests that
  call hard lower it to stay quick through TinyCC (`test/ai/blunders.goose`, the seeds
  in `test/ai/levels.goose`); the whole `ai` area takes about 10 s that way.
- Positions come from the computer's own games (`build/aimatch ... --fens PLY`) and from
  scanning them for moves a deep search rates far above the rest. A shot's line goes in
  the test's comment only after each move is checked with `test/perft.py moves`; a
  line printed by repeated searches stops mid-combination unless it runs on until the
  material settles.

## Screenshots on the Mac

- A `--frames` run reads the Mac's settings from `~/Library/Application
  Support/kaitk/draughts/settings.txt` (`app/storage.c`), and there is no flag for most
  of them (the kings, the draughts settings show). To shoot settings as chosen, copy the
  file aside, write the keys wanted (`kings = stack`, `draughts = russian`, `hints =
  moves`), run, and put the copy back.
- The prototypes' painter (`Paint` in `prototypes/draughts.js`) is a port of the piece
  shader, so a native crop beside the prototype's at the same scale shows a shader
  change exactly (the stacked king was checked that way).

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
- Tests that tap tiles find them by the order of `gui::BUTTON` quads; the clocks are
  `BUTTON` quads too, so the game's helpers skip styles from `gui::CLOCK_RUN` on.
- To see when something happens on the tablet, log from the program's C with
  `extern void SDL_Log(const char *, ...)` (Android only; it shows in `adb logcat` as
  `SDL/APP`) and remove it after. The clock's lag was measured that way.
- In a git worktree: `build/` is a real directory holding a link to the main checkout's
  `build/goose-v2026.4-macos-arm64` (tests write `build/test/`, so never link all of
  `build/`). Init the submodules, and inside `third_party/goose_gfx` also
  `third_party/nuklear` and `third_party/SDL` (the app's C needs nuklear's headers,
  `scripts/android.py` SDL's revision); link `build/android/SDL_src` to the main
  checkout's to skip copying SDL. The first Android build then takes about 35 s.
- Flags reach the app on the tablet through the intent, quoted twice:
  `adb shell am start -n com.kaitk.draughts/.DraughtsActivity --es args "'--clock 5+3'"`.
  A run with flags neither reads nor writes `game.bin`. Clean the app's data (settings
  and the game) with `adb uninstall com.kaitk.draughts` and a fresh install.
- A button's press shows in a screenshot taken during a long press:
  `adb shell input swipe X Y X Y 2500 &`, then `adb exec-out screencap -p` a second later.
- The batterystats estimate reads 0 while the tablet charges over USB, so it says
  nothing; CPU time is the measure.
- When the lock screen asks for a PIN (`adb shell dumpsys window | grep
  isKeyguardShowing` stays true after `wm dismiss-keyguard`), the app is paused at
  once and never draws; ask the user to unlock. Headless programs still run through
  `scripts/android_cli.sh`: the computer's worker was timed that way, with its threads'
  state read from `/proc/<pid>/task/*/stat` while the program waited (2026-11-08).
