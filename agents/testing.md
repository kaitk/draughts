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
  position shows it. Areas so far: `rules`, `board` (taps, hints, and a capture tapped
  stop by stop through the board package, as a game does and by hand as a puzzle
  does, and a press or drop off the dark squares snapping to the nearest it could mean:
  `snap`), `gui`, `game` (the game screen driven through
  the pointer: take back, start over, home and settings, presses kept apart, the
  celebration and its moments to the still frame (`win`), a clocked game with its
  frames, pause, and flag, the turned board; the computer's turn, answered at once with
  `ai::think` as the app's worker would; the clock value on its own; and the computer's
  time a move on the clock, over whole games with simulated time, in `pace`), `shell`
  (home, the switch to the game and back, settings and their file, their taps and the
  board beside them, the transitions between home and settings, home and the game, and
  the puzzles to pick from and a puzzle (their frames, the end, a tap during them, turning
  round, the game's clock and the computer frozen, a won game's way home, the screen
  reached as opened straight: `transition`, `game_transition`, `puzzle_transition`),
  home's setup and play, the setup's board (each
  draughts' start, turned for black, the game in progress back on the menu, the game play
  starts, `setup`), the puzzles' library and a theme's page and a puzzle played through
  its misses, hint, reply, and stars, a black puzzle on the turned board, next after a
  theme's last (`puzzles`), the library and every theme's page laid out at the tablet's
  and a phone's size (`picker`), a capture made by hand in a puzzle (tapped and dragged
  stop by stop, dropped on its last square, left partway and next pressed: a miss) and
  no targets in any puzzle,
  the saved game of any variant and damaged images of it, the players' files read and
  written back, their migration (killed after each step too), adding, switching,
  starting again, and removing (`players`), who's playing and a player's sheet, the
  holds let go early and held, the name typed, the first run, and their layout at the
  tablet's and a phone's size (`who`), the computer's skill moving
  across games, home's X closing the app and where it sits, Android's back and Escape
  on each screen against its own back tile (`back`), and every screen at a
  foldable, 4:3, and a 20:9 phone in both orientations, and the phone's layout at 540
  and 480 dp (`gui::short_dp`, with a 9:16 phone at 480), its tiles on the screen and
  apart, every tap 88 dp at least, the phones again with the Pixel 7a's insets in both
  orientations (the cutout at either side in landscape), every tile and the board inside
  the safe area, the 16:10 tablet with its 72 px hidden navigation bar (settings keeps
  both groups in landscape), and a phone's tabs in settings and the puzzles:
  `sizes`; the title's and the clock's faces holding every character drawn in them, the
  app's name in every language and every clock time: `faces`), `strings` (every language
  file has every key), `badges` (each badge's SVG baked into its distance field, drawn
  coarsely, and the path syntax a tracer writes: bless it after replacing an animal), `ai` (the computer player:
  its search against a plain minimax, the table changing no score, keys, what each level
  plays in known shots, the same move in steps as at once, and that no level hangs a
  piece), and `puzzles` (the puzzle file's format and refusals, what `puzzles::check`
  refuses beyond the format, what a move does to each goal, and every built-in puzzle
  passing `puzzles::check`, with its counts by theme and level). A new puzzle is checked
  with `build/puzzles FILE` (the engine's view too) and `test/perft.py puzzles` before
  `test/expected/set.out` is blessed. A
  test that lays out text calls `gui::test_faces` for glyph sizes without an atlas, and
  `strings::use` before reading a string. Shared helpers are in
  `test/check.goose` (`check::show`, `check::play_only`), imported as
  `import check from "../";`, and, for the UI tests, in the package `test/drive/`
  (`import drive from "../drive";`): squares by name (`drive::at`, `name`, `marked`),
  the tiles a frame declared (`tile`, `rect`, `control` leaving out the clocks), and the
  pointer driving the game screen or the shell (`frame`, `tap`, `idle`, with the game's
  pieces over the UI in `drive::over` and the shell's screen size in `drive::size`).
  Importing it means declaring every package it reaches (`rules` through `shell`, `ai`);
  `test/run_tests.py` skips the directories in its `PACKAGES`.
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
- `test/game/pace.goose` plays twelve whole games on the clock (each level against
  itself, both clocks, Russian and International) with hard at 20,000 nodes: about 12 s
  through TinyCC. For numbers at full strength, build a copy with `NODES` at
  `ai::NODE_LIMIT` and more `GAMES` (the task 027 numbers came that way).
- Positions come from the computer's own games (`build/aimatch ... --fens PLY`) and from
  scanning them for moves a deep search rates far above the rest. A shot's line goes in
  the test's comment only after each move is checked with `test/perft.py moves`; a
  line printed by repeated searches stops mid-combination unless it runs on until the
  material settles.

## Screenshots on the Mac

- A `--frames` run reads the Mac's settings from `~/Library/Application
  Support/kaitk/draughts/` (`app/storage.c`): the playing player's `player-N.txt`
  (`settings.txt` names N and the language), and there is no flag for most
  of them (the kings, the draughts settings show). To shoot settings as chosen, copy the
  file aside, write the keys wanted (`kings = stack`, `draughts = russian`, `hints =
  moves`), run, and put the copy back.
- A setup is shot with its choices from flags, leaving the player's file alone:
  `--screen friend --variant brazilian`, or `--screen computer --variant russian
  --computer white` for the child on black (`docs/development.md`). Add `--lang en`
  when the Mac's settings name another language (2026-11-08).
- To check that a change leaves the look alone, take the same shots before and after
  and `cmp` them: home, the game, settings, both orientations, a setup, a clocked game
  with taps, and one against the computer. Two runs of a shot are byte-identical except
  where something moves at the last frame: the computer's pulsing ring and settings'
  preview flash; compare those by eye (2026-11-08), or by where they differ:
  `magick compare -metric AE a.png b.png null:` counts the pixels, and `magick a.png
  b.png -compose difference -composite -threshold 0 -format '%@' info:` gives their box,
  which for settings is the same box as between two runs of one build. The win's
  `--win 3 --frames 3000` shot varies over the whole board from run to run: compare it
  against a second run of the old build.
- A `--frames` run with taps needs a few thousand frames for a move and what follows to
  play out (`--win`, `docs/development.md`): it doesn't wait for the display, so 90
  frames end before the second tap's move has shown.
- A run against the computer (`--computer`) that ends moves the computer's skill and
  writes it to the player's file, flags or not: put the skill back after shooting one, on
  the Mac and the tablet (2026-11-08).
- A window taller than the Mac's screen is shrunk to fit: `--size 800x1280` comes out
  800 × 1098 here, a shorter portrait. Shoot the tablet's portrait proportions at
  `--size 600x960` (the same layout at 0.75 scale) and landscape at 960x600.
- On the Mac's Retina screen `--size` is in points and `draughts.png` comes out at twice
  it (2026-11-08): `--size 960x540` is a real 1920 × 1080 shot, `1200x540` a real
  2400 × 1080, and `600x960` above the tablet's real 1200 × 1920. Up to about 1098 points
  tall fits, so phones in landscape and most tablets shoot at their real pixels. Portrait
  phones too tall for that, at the same proportions: 9:19.5 as `450x975`, 9:20 as
  `450x1000`, the foldable's 1768 × 2208 as `868x1084`; 9:16 fits as `540x960`. Check
  the PNG with `sips -g pixelWidth -g pixelHeight`. Larger tablets: landscape at real
  pixels (`1280x800` for 2560 × 1600, `1440x960`, `1024x768`, `1104x884`), portrait 4:3
  as `768x1024`, and 16:10 and 3:2 portrait as `600x960` and `640x960`.
- The layout depends only on the proportions (the shorter side is 800 dp, or `--dp N`),
  so a phone shot shows the tablet's layout in dp; how small it is on the hand is
  arithmetic from the device's size, not something a screenshot shows: a dp is 0.185 mm
  on the tablet (11", 1200 px across), and on the Pixel 7a 0.080 mm without the density
  floor, 0.118 with it.
- A layout that fits a word needs the word's real width, which the headless tests don't
  have: their faces make each character half the face wide, about a fifth wider than
  Libertinus Sans, so a test may stack or shrink a word the app fits. The real widths
  come from the font's advances (`assets/fonts/LibertinusSans-Regular.ttf`: `hmtx`
  through `cmap`, times the face's dp over `unitsPerEm`; fontTools isn't installed, a
  30-line Python reader does it). The widest so far, at the 24 dp heading face: "Alusta
  uuesti" 130 dp, "Mustad võitsid" 148 (2026-11-08).
- Phone layouts are shot with `--dp N` at the phones' proportions. Task 030 (archived)
  did it with local scripts, never committed: one taking a set of sizes and dps, one
  running each screen in parallel in its own work folder, one counting differing
  pixels. Run in parallel, the win's `--win 3` needs `--frames 9000`, not 3000, or the
  shot ends before the card (2026-11-08).
- Insets are shot with `--inset L,T,R,B` in dp of the layout: at `--dp 540` a 1080 px
  phone is 2 px a dp, so the Pixel 7a's 118 px cutout is 59 dp and its 84 px gesture
  bar 42 (at 480, 52 and 37). Tinting the insets red over each shot (a small Python
  script) shows at a glance whether anything sits under them, on the Mac and on a
  device's screenshots alike (2026-11-08). A headless test sets `g.insets` (pixels) on its
  `gui::Gui`; `gui::begin` keeps it, so put it back to zero after.
- A headless test can lay out at another `gui::short_dp` (`test/shell/sizes`,
  `test/shell/settings`): set it, then `g.scale = gui::scale_of(...)` before
  `gui::test_faces`, which sizes the faces at the scale; put it back to 800 after.
- In a working tree, copy `design/backgrounds/masters/*.jpg` from the main checkout
  (local and ignored) and touch `app/background.c`, or shots show the page color where
  the photograph should be.
- Clicks can't be posted to the window from a script: the terminal isn't trusted for
  accessibility (`AXIsProcessTrusted()` is false), so CGEvent clicks are dropped. To run
  a UI path in the real app (home's X closing the window, 2026-11-08), build a local
  copy, never committed, that feeds `gui::begin` a press and a release at the control
  on chosen frames. A run without flags reads and writes the Mac's `game-N.bin`: copy it
  aside first and put it back after. Any run migrates a `settings.txt` from before
  players to `player-1.txt` and renames `game.bin` (2026-11-09).
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
- On the Pixel 7a (2026-11-08): `user_rotation 1` is landscape with the camera on the
  left, `3` on the right. `accelerometer_rotation` can turn itself back on during a run,
  so a script sets it to 0 before each start. Its insets with the bars hidden: portrait
  0, 118, 0, 84 px; landscape 118, 0, 0, 84 and 0, 0, 118, 84 (before
  `patches/SDL/0002` left the top swipe-down strip to taps: 150 px at the top in
  portrait, 74 in landscape); so `--inset` for it in dp at its 1.969 px a dp is about
  `0,60,0,43` and `60,0,0,43`. The tablet's: 0, 0, 0, 72 in both orientations (45 px at
  the top before the patch left out Samsung's `tappableElement` strip); turning it, one
  frame has the new insets against the old size. To see what the program gets, `print`
  `draughts_display`'s insets and the layout scale from the loop for a run (and remove
  it); `adb shell dumpsys window` lists each inset type's frame, and
  `mShowingTransientTypes` whether a swipe showed the bars. `adb shell input
  swipe 5 1200 500 1200 150` is a back swipe in portrait, but the first only shows the
  hidden bars and a second one goes back; `input keyevent KEYCODE_BACK` goes back at
  once. A swipe landing outside the app (on the launcher) opens apps, so check where a
  swipe test starts. Whether the activity was finished or kept shows in
  `adb logcat -b events | grep wm_` (`wm_finish_activity`, `wm_task_removed`) and in
  `pidof io.github.kaitk.draughts` before and after; whether a card is in recents, in `adb
  shell dumpsys activity recents`. `adb shell monkey -p io.github.kaitk.draughts -c
  android.intent.category.LAUNCHER 1` starts the app as the launcher's icon does. To log from the program, `print` in the
  loop shows under `goose`; the APK's libraries are `lib/arm64-v8a/libmain.so` and
  `libSDL3.so`.
- During a transition (home and settings, home and the game, the puzzles and a puzzle)
  both screens' quads are declared, the one left first, so `drive::tile(g, n)` counts the
  wrong screen's tiles and `drive::at(sh.layout, ...)` finds squares on a moving board. A
  shell test that taps again after such a switch idles past `shell::DURATION` first
  (`switch` in `test/shell/shell.goose`); a tile of the screen come to is found at rest
  beforehand, its taps being where it rests.
- Tests that tap tiles find them by the order of `gui::BUTTON` quads; the clocks are
  `BUTTON` quads too, so the game's helpers skip styles from `gui::CLOCK_RUN` on.
- To see where a frame's time goes on the tablet, `print` from the app's loop with
  `gfx::time()` deltas around its parts, only for frames over a few ms or a switch: the
  program's output shows in `adb logcat` under the tag `goose`. Remove it after (task
  022's switch frames took under 1 ms; the frames after them 9 to 19 ms in drawing).
- A recording's frame times say little of what is slow inside: a recorded 20 ms frame
  may be the program's 1 ms and the rest presenting.
- Presented frame times without a recording: `adb shell dumpsys SurfaceFlinger
  --timestats -enable -clear`, play the animation (taps with `input tap`), then
  `--timestats -dump` and `-disable`; the layer
  `SurfaceView[io.github.kaitk.draughts/...](BLAST)` has a present2present histogram in ms
  (gaps of 350 ms and more are the app idle between taps). `--latency LAYER` prints only
  the refresh period on Android 16, and `gfxinfo` counts only the Java views' frames
  (2026-11-08). A rotation recreates the layer, so its frames don't show there; a
  season change's do (one gap of 58 to 78 ms on the tablet).
- When SDL allocates GPU memory: an `SDL_Log` before `vkAllocateMemory` in
  `VULKAN_INTERNAL_AllocateMemory` and before `vkFreeMemory` in
  `VULKAN_INTERNAL_DeallocateMemory` (in `build/android/SDL_src`, as below), then
  `adb logcat -d | grep SDL/APP` around a tap (2026-11-08).
- `dumpsys meminfo` at home right after launch counts about 24 MB more graphics than
  once a later frame has submitted GPU work (184 MB, and 160 MB with the
  thumbnails loaded in the first idle frame), likely the launch's uploads not yet let
  go: compare memory at the same point of a run, after the same frames (2026-11-08).
- Native heap: `dumpsys meminfo -d`'s Native Heap row has Pss and, further right, Heap
  Alloc (malloc's live bytes): Pss well above Alloc is memory Scudo keeps for freed
  blocks, not growth. `/proc/self/smaps` is readable from the program's own C even in
  the non-debuggable APK: summed by name, `[anon:scudo:primary]` is small blocks and
  `[anon:scudo:secondary]` large ones (each its own mapping, freed ones kept cached);
  `mallopt(M_PURGE_ALL, 0)` before a second read shows what is only kept. Android's own
  purge as the app goes to the background empties the primary's free pages, not the
  secondary cache (2026-11-08).
- A transition's frames from the program's side: `gfx::time()` around `gfx::frame()` and
  each draw call, printed for drawn frames; the wait in `frame()` is where presenting
  shows (2026-11-08). `gfx::frame_count()` counts presented frames, not loops,
  so a trigger on it never fires while the app is idle.
- To see when something happens on the tablet, log from the program's C with
  `extern void SDL_Log(const char *, ...)` (Android only; it shows in `adb logcat` as
  `SDL/APP`) and remove it after. The clock's lag was measured that way.
- In a git worktree: `build/` is a real directory holding a link to the main checkout's
  `build/goose-v2026.4-macos-arm64` (tests write `build/test/`, so never link all of
  `build/`). Init the submodules, and inside `third_party/goose_gfx` also
  `third_party/nuklear` and `third_party/SDL` (the app's C needs nuklear's headers,
  `scripts/android.py` SDL's revision); link `build/android/SDL_src` to the main
  checkout's to skip copying SDL. The first Android build then takes about 35 s.
  `build/android/draughts/native` is a CMake cache bound to the main checkout's
  `android/`: from a worktree sharing `build/android`, build a copy of the program under
  another name (`app/x.goose` and `app/x.build`, deleted after) so it gets its own
  `build/android/x/`, and remove that after. A new or changed `patches/SDL` patch makes
  the shared `SDL_src` be copied again, for the main checkout too (2026-11-08).
- Flags reach the app on the tablet through the intent, quoted twice:
  `adb shell am start -S -n io.github.kaitk.draughts/.DraughtsActivity --es args "'--clock 5+3'"`.
  Without `-S` a start that finds the app running only brings it back with its old
  flags: new `--tap`s never arrive and the screen keeps the last run's state.
  A run with flags neither reads nor writes the player's `game-N.bin`. Clean the app's data (settings
  and the game) with `adb uninstall io.github.kaitk.draughts` and a fresh install.
- A button's press shows in a screenshot taken during a long press:
  `adb shell input swipe X Y X Y 2500 &`, then `adb exec-out screencap -p` a second later.
- Which sensors the app holds: `adb shell dumpsys sensorservice`, its "Active sensors"
  (connections per sensor) and the open connections, each naming its uid and Java class;
  the log under them keeps old pids' registrations, so match the current pid. To split
  idle CPU by thread, read every `/proc/<pid>/task/*/stat` (fields 14 and 15) and `comm`
  before and after; the Java main thread is named `SDLActivity` (2026-11-08).
- The batterystats estimate reads 0 while the tablet charges over USB, so it says
  nothing; CPU time is the measure.
- A launch is checked frame by frame with `adb shell screenrecord` started before
  `am start -W` (it needs about 1.4 s to begin) and stopped with
  `pkill -INT screenrecord`. It writes only changed frames: read their times with
  `ffprobe -show_entries frame=pts_time` and decode with `ffmpeg -fps_mode passthrough`
  (this ffmpeg has no `-vsync`). Behind the lock screen it records only the lock screen. Task 028 classed
  frames by the share of navy pixels, apart from the centre (the icon) and the bottom 6%
  (the navigation bar, where a short flash hid from whole-frame averages).
- When the lock screen asks for a PIN (`adb shell dumpsys window | grep
  isKeyguardShowing` stays true after `wm dismiss-keyguard`), the app is paused at
  once and never draws; ask the user to unlock. Headless programs still run through
  `scripts/android_cli.sh`: the computer's worker was timed that way, with its threads'
  state read from `/proc/<pid>/task/*/stat` while the program waited (2026-11-08).
