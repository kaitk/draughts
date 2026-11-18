# Testing

How to run everything: `docs/development.md`, "Test the rules". Run `scripts/test.sh`
before committing a change to `rules/`.

- In a separate working tree, make `build/` a real directory holding only a symlink to
  the main checkout's `build/goose-v2026.4-macos-arm64`, never a link to all of `build/`:
  tests and tools write `build/perft`, `build/test/`, and the like.
- `scripts/test.sh` first runs `goose check` on the app, which compiles every shader its
  `embed_shader` calls reach (a GLSL error is a compile error) in half a second.
  `test/run_tests.py` alone compiles no app shader, so after a shader change run
  `scripts/test.sh` or build the app. With `NGFX` set it checks `draughts_ngfx.goose` too
  (`scripts/ngfx.py`, which compiles its shaders with `NGFX_SLANGC`, or else puts empty
  stand-ins for them, as CI does); `scripts/check_roots.py` checks the two roots and their
  sidecars list the same packages and C. The program's own C (`src/native/*.c`) only a build
  compiles.
- Badge art: `tools/assets/badge_trace.py <animal> <png>` traces a black-on-white silhouette into
  `assets/badges/<animal>.svg`; then `test/run_tests.py --bless badges`.
- A frame holds `gui::MAX_QUADS` quads; one past it prints `gui: N quads dropped` (in a
  test's output and in the app). A layout test can print `g.quads.len`.
- The layout tests print their checks, passed or WRONG, and which tiles show in what
  order, not pixels: a copy edit or a few dp moved needs no re-bless. Coordinates, dp
  sizes, and quad counts print only with `DRAUGHTS_TEST_VERBOSE=1` (`drive::verbose`),
  which `test/run_tests.py --dump [NAME]` sets, writing to `build/test/dump/`: dump before
  and after a change and diff to see whether a layout moved. `shell` names both a test
  and the area, so `--bless shell` blesses the whole area.

## What each kind of test is for

- `test/<area>/<name>.goose` with `test/expected/<area>/<name>.out`: one program per behavior,
  printing what a reader can check by eye (positions as FEN, moves sorted, pieces taken).
  A test says in a comment what rule it shows and why the position shows it.
  A name on the command line runs every area's test of that name.
- The areas:
  - `rules`: move generation, crowning, draws, FEN, per variant.
  - `board`: taps, drops, snapping, hints, a capture tapped stop by stop, the lookout's
    marks, the 3D scene and its picking.
  - `gui`: widget ids' ranges (one per screen, each screen's named ids inside its own), `gui::stack`, hover, keyboard focus,
    scrolling.
  - `game`: the game screen driven through the pointer and keys: undo, start over, the
    win, clocks, the computer's turn (answered with `ai::think` as the worker would), its
    time a move (`pace`), capture choice and aim, draws, the capture count, the lookout,
    the hint, what each side has taken.
  - `shell`: home, settings, setups, puzzles, players, transitions, replay, play from
    here, the moves line, back on every screen, the 3D board on every screen, and the
    layouts. `sizes` lays every screen out at many phone, tablet, iPad, and desktop sizes
    with insets, checking taps of 88 dp, the safe area, and overlap; it exits non-zero on
    any failure not on its `ALLOWED` list (add an entry only for a failure the user
    accepted, with its reason). `faces` checks the title and clock faces hold every
    character drawn in them.
  - `strings`: every language file has every key.
  - `badges`: each badge's SVG baked into its distance field; bless after replacing one.
  - `ai`: the search against plain minimax, levels in known shots, no skill from 15 on
    hanging two pieces (`blunders`), the lookout, the overlooks' rates over 4000 seeds
    (`overlook`), draws.
  - `model3d`: the 3D board's bake plan, each season's material, and the board's
    measures in the shaders' GLSL equal to the mesh's (`geometry`).
  - `puzzles`: the file format and refusals, `puzzles::check`, goals, and every built-in
    set (`set`, `russian_set`, `brazilian_set`) with its counts by theme and level.
- `test/perft.py`: an independent generator sharing no code with `rules/`, and the only
  check of Russian. `test/perft.py moves VARIANT FEN` gives a new test position's expected
  moves before blessing; `compare` sweeps random games after any change to move
  generation.
- `build/perft`: published counts, speed, and `--divide` to find the subtree that
  differs.

### Writing a test

- Shared helpers: `test/check.goose` (`check::show`, `check::play_only`, imported as
  `import check from "../";`) and, for the UI, the package `test/drive/` (`import drive
  from "../drive";`): squares by name (`drive::at`, `name`, `marked`), the tiles a frame
  declared (`tile`, `rect`, `control`), the pointer and keys (`frame`, `tap`, `idle`,
  `key`), `drive::ui_pieces`, `drive::size`, `drive::result`, `drive::ready3d`,
  `drive::shown3d`, `drive::past_line`. Importing it means declaring every package it
  reaches; `test/run_tests.py` skips the directories in its `PACKAGES`.
- A test that lays out text calls `gui::test_faces` and `strings::use` first. To lay out
  at another `gui::short_dp`, set it, then `g.scale = gui::scale_of(...)` before
  `gui::test_faces`; put it back to 800 after. `g.insets` (pixels) survives
  `gui::begin`: put it back to zero after.
- The headless faces make each character half the face wide, about a fifth wider than
  Libertinus Sans, so a test may stack or shrink a word the app fits. Real widths come
  from the font's `hmtx` (a 30-line Python reader; fontTools isn't installed).
- A shell's frame output is `sh.out`; a test that sets `sh.prefs` calls
  `shell::apply_prefs(sh)` after.
- The game's controls (`drive::control`) are back, settings, start over, undo, the hint
  (4), then a card's back and play again (5, 6). The lookout's eye is a floating disc:
  `drive::eye`; `drive::camera_disc` tells the 3D camera's buttons from it. Tiles are
  found by the order of `gui::BUTTON` quads; the clocks are `BUTTON` quads too, so the
  helpers skip styles from `gui::CLOCK_RUN` on.
- During a transition both screens' quads are declared, the one left first: a shell test
  idles past `shell::DURATION` before tapping again.
- A state change made inside a screen's frame shows only when that frame is drawn with
  it, or draw on demand never draws it.
- New puzzles: `build/puzzles FILE` (the engine's view too) and `test/perft.py puzzles`
  before blessing a set's `.out`. With no FILE it checks the set built into it, so
  rebuild after a set changes. It reads at most `MAX_PUZZLES` (150) ids per file; a set
  carried to another variant is checked one puzzle at a time with `try --variant`. In
  tiny positions the engine sees the game's end, so a Learn puzzle of a few men can fail
  its view though the solver passes it: add men or pick another.

## Rules

- Add a test for behavior that could break unnoticed, not to cover lines. A new rule
  edge case gets a position in `test/rules/`, checked against `test/perft.py moves`.
- An expected output changes only with a reason in the commit. Read the diff `--bless`
  makes before committing it.
- Tests run through TinyCC by default, but those in `SLOW` (`test/run_tests.py`) build
  at -O2; `--build` builds all, `--tinycc` runs all through TinyCC. A difference between
  the two is a compiler finding (`agents/goose.md`). A test that takes TinyCC's code more
  than about 5 s goes in `SLOW`.

## The computer player's tests

- The search counts nodes, so a test's moves change with `Engine.node_limit`; tests that
  call hard lower it to stay quick (the `ai` area takes about 10 s).
- Self-play: `build/aimatch VARIANT 0 10 400 --overlooks 100 0`. Skills 0 and 10 without
  overlooks are the yardsticks of easy's strength. A simple child model is skill 0
  overlooking three times as often, `--overlooks 100 300`. `--hangs` adds each side's
  hanging moves in quiet and tense positions. Easy runs take seconds; anything with hard,
  minutes.
- A change to the overlooks moves `test/game/pace.goose`, `test/ai/levels.goose`'s easy
  moves, and `blunders`' counts: bless them with the reason. Tuning a level:
  `docs/architecture/ai.md`, "Tuning the levels".
- `pace.goose` plays twelve whole games on the clock with hard at 20,000 nodes (about
  12 s); for full-strength numbers build a copy with `NODES` at `ai::NODE_LIMIT`. Widen a
  level's `LOW`/`HIGH` only with a reason in the doc. A new caller of the pace must pass
  `pace::tense` (computed from the reply in `game::answer`).
- Positions come from `build/aimatch ... --fens PLY`. A shot's line goes in a comment only
  after each move is checked with `test/perft.py moves`.

## Screenshots on the Mac

- `--frames N` saves `draughts.png` after N drawn frames; a run with taps needs a few
  thousand frames for a move to play out, and a shot past the last animation never comes.
  `--tap` takes up to 256 taps.
- A windowed run reads and may write the Mac's settings in `~/Library/Application
  Support/kaitk/draughts/` (`settings.txt` names the player, `player-N.txt` their
  settings, `game-N.bin` the game). Copy the folder aside before any run that taps or
  presses Enter in settings, plays out a game against the computer (its skill moves), or
  runs without flags, and put it back after. A run with flags leaves `game-N.bin` alone.
- Setups come from flags: `--screen computer --variant russian --computer white`; add
  `--lang en` when the Mac's settings name another language. Open settings' language list
  with `--languages open`, About with `--about open`; pick the board with `--board` and `--material`. Settings with no
  flag (the kings, say) are written into the player's file for the run.
- `--keys ...,enter` on settings presses whatever the focus reached and writes the
  change.
- `--size` is in points on a Retina screen and the PNG is twice it; a window taller than
  about 1098 points is shrunk to fit. Shoot tall portraits at the same proportions:
  9:19.5 `450x975`, 9:20 `450x1000`, 9:16 `540x960`, the tablet `600x960`. Check with
  `sips -g pixelWidth -g pixelHeight`.
- The layout depends only on the proportions (the shorter side is 800 dp, or `--dp N`).
  Insets: `--inset L,T,R,B` in dp of the layout (fractions allowed). At `--dp 540` the
  Pixel 7a is about `0,60,0,43` in portrait, `60,0,0,43` in landscape; the tablet's
  bottom bar is 72 px both ways. Apple devices at points times scale: the iPhone 13 mini
  `--size 1125x2436 --dp 500 --inset 0,66.7,0,45.3` (landscape `2436x1125` with
  `66.7,0,66.7,30`); the 13" iPad `--size 1376x1032 --inset 0,0,0,15.5` (the app hides the
  status bar); an iPad window `--size 748x968 --display-scale 2 --density-floor 0.75`.
- A hovered tile: `--mouse X,Y` (window pixels) and `--touch off`. Clicks and mouse moves
  can't be posted from the agent's shell (no Accessibility rights): for a UI path, a
  local copy that feeds `gui::begin` presses; for `--rest`, the real mouse.
- In a shell loop, run each shot from `src/main` with `< /dev/null` and stdout to
  `/dev/null`, under `perl -e 'alarm 30; exec @ARGV'` (the Mac has no `timeout`), and at
  most about four at a time, or runs hang.
- In a worktree, copy `design/backgrounds/masters/*.jpg` from the main checkout (ignored
  by git) and touch `src/native/background.c`, or shots show the page color.
- The prototypes don't port the board and piece shaders: check a shader change on native
  crops before and after. The port is in git history at fed389b.

### Headless and byte-identical shots

- `GOOSE_GFX_HEADLESS=1` makes both renderers headless: `--frames N` saves the PNG in the
  working folder and exits, with no window in the user's way. Headless loops run fast, so
  shoot the 3D board settled at `--frames 20000`. Sizes are real pixels.
- Windowed runs of one build differ, so `cmp` says nothing about them. For
  byte-identical checks, build a headless copy with a fixed clock (`host::time()` adding
  1/60 s a call) and `dirty = true;` heading the loop, so `--frames N` is N loops at the
  same moments. To compare two commits, `git archive` each into the scratchpad with
  `third_party/goose_gfx` and `build/goose-v2026.4-macos-arm64` linked in and build each
  from its `src/main` with `build/mac/goose/goose build`. Never commit such copies.
- State with no flag (a daily puzzle, a scrolled list, the camera, a season mid-run, a
  held piece) is set from a temporary flag in the copy only, never committed.
- Compare with ImageMagick (Python has no PIL here): `magick a.png b.png -compose
  difference -composite -alpha off -separate -evaluate-sequence max`, then `-format
  "%[fx:round(255*maxima)]" info:` for the largest difference, `-threshold 12.6%` with
  `-format "%[fx:round(mean*w*h)]" info:` for pixels over 32, and `-format '%@'` for
  their box.

### The renderer check

A change to the drawing is checked on both builds (gfx and ngfx), each before and after,
compared against itself: 13 screens as `GOOSE_GFX_HEADLESS=1 <exe> --size 1280x800 --lang
en --touch off <flags> --board flat|3d --frames 20000`, each in a folder of its own, four
at a time, with `F` for `--variant russian --fen W:Wc3,e3,Kh2:Bd4,f6`:

| Shot | Flags |
|---|---|
| home | `--screen home` |
| game | `--screen game F` |
| taps | `F --tap c3` |
| settings | `--screen settings` |
| stone | `--screen game --theme stone F` |
| birch's settings | `--screen settings --theme birch` |
| sunset plain | `--screen game --theme sunset --background plain F` |
| home plain | `--screen home --background plain` |
| puzzle | `--puzzle 21 --tap f4 --tap e5` |
| win | `--variant russian --fen W:Wa1,c1,g1,b2,h2,e3:Bf4 --tap e3 --tap g5 --win 1.2` |
| held | `--go settings --hold 0.5` |
| portrait | `--screen game --size 800x1280 F` |
| lookout | `--screen game --lookout on F` |

Two runs of one build differ in the 3D shots along edges, the puzzle's most (up to 67 of
255 at a few pixels), so a pixel over 32 is the test once its place is checked. For the
3D renderer also each `--aa`, and `--bench` and the footprint at `--rest` against the
commit before. A change to the ngfx build alone leaves gfx's binary the same: `cmp` it.

- The build with both renderers takes `--renderer auto|gfx|ngfx` and prints its choice.
  `DRAUGHTS_AUTO_NGFX=1` makes `auto` try ngfx where it wouldn't; `DRAUGHTS_RENDERER_TEST=
  fail` makes ngfx's open fail after the hidden window, `crash` ends the program before
  its first frame. Delete the marker `renderer-start.txt` in the storage folder after.
- On ngfx, `--bench`'s waited frame and CPU time include waiting for a free drawable;
  compare the presented rate instead.

### Memory on the Mac

Run headless with `--screen home` (or `--board flat --screen game --frames 100000000`),
wait about 14 s, then `footprint PID` (its "graphics" rows are the GPU's) and kill it.
Headless runs read the same MB run to run, so compare two runs of the same screen.
`vmmap -w PID` splits the rows: "IOAccelerator (graphics)" is GPU memory mapped into the
process, "owned unmapped (graphics)" GPU-only heaps and textures.

## Windows

- `--bench 60` and `--rest 4` run headless too; `--rest` keeps running after its line:
  take `footprint` then and kill it. Compare medians of five runs, builds in turn.
- `tools/perf/windows_perf.py` (`EXE=`, `FLAGS=`): PresentMon's GPU busy time is the frame
  time both builds report alike. Uncapped, ngfx flips only while its window is in front:
  check the present mode on every run and never run two benches at once.
- A real window is driven from Python with ctypes: `SetProcessDPIAware()`, find the window
  by process id (`EnumWindows`), `SetForegroundWindow`, then real clicks (`SetCursorPos`,
  `mouse_event`; posted messages don't arrive), `SetWindowPos` to resize, and
  `PIL.ImageGrab.grab(bbox=..., all_screens=True)`. Changing settings writes
  `%APPDATA%\kaitk\draughts\`: copy it aside first.

## Linux

- On an SELinux system (Bazzite, Fedora) TinyCC's runs fail with `mprotect failed`: run
  the tests with `test/run_tests.py --build`.
- `--frames N` saves the PNG from gfx's window; under ngfx only headless does. `import
  -window Draughts out.png` grabs an X11 window. Never call the screenshot portal for a
  Wayland window: its permission dialog stalls every SDL Wayland start until
  `systemctl --user restart xdg-desktop-portal`.
- `WAYLAND_DEBUG=1` shows the app id, scale, viewport, and each presented frame.
- End a run with `timeout -s KILL` (SIGTERM asks to quit) and stray ones with
  `pkill -x draughts` (`pkill -f` kills the Bash tool's shell too).
- `gdctl set -L -M HDMI-1 --primary --scale 1.25` sets a fractional scale for a check.

## On the tablet and phones

What can't run headless is checked on a device with scripts that print numbers:
`tools/perf/lifecycle_memory.sh` and `tools/perf/idle_cpu.sh`, at the end of a larger iteration
or when a change may move idle or memory. A run during which the device was touched isn't
an idle figure; one while charging has no battery estimate, so CPU time is the measure.

- First `adb shell svc power stayon usb`, after `adb shell svc power stayon false`. A
  locked device (`dumpsys window | grep isKeyguardShowing` true) pauses the app: ask the
  user to unlock.
- Flags go through the intent, quoted twice, with `-S` so a running app restarts:
  `adb shell am start -S -n io.github.kaitk.draughts/.DraughtsActivity --es args "'--clock 5+3'"`.
  A run against the computer moves its skill in the player's file: put it back.
- Rotation: read `accelerometer_rotation` and `user_rotation`, set the first to 0 (before
  each start: it can turn itself back on), `user_rotation` 0 portrait, 1 landscape, then
  restore. `input keyevent KEYCODE_BACK` goes back; a back swipe first only shows the
  hidden bars.
- Logs: `print` shows in `adb logcat` under `goose`; `extern void SDL_Log(...)` from the
  program's C as `SDL/APP`. Remove them after. To log inside SDL, edit the copy in
  `build/android/SDL_src/` (never the submodule) and delete its `.draughts-stamp`.
- Threads: `/proc/<pid>/task/*/stat` (fields 14 and 15) and `voluntary_ctxt_switches`
  tell spinning from waiting; the program runs on `SDLThread`. simpleperf can't sample
  here.
- GPU clock without root: `/sys/kernel/gpu/gpu_clock` and `gpu_busy`. Where the governor
  moves the clock (the A33, the Pixel 7a), compare GPU cycles a frame, not milliseconds.
- Presented frames: `dumpsys SurfaceFlinger --timestats -enable -clear`, play, then
  `-dump` and `-disable`; the app's `SurfaceView` layer has a present2present histogram.
- Memory: compare `dumpsys meminfo` at the same point of a run, after the same frames.
  Native Heap's Pss well above Heap Alloc is Scudo's cache, not growth.
- A launch frame by frame: `adb shell screenrecord` started before `am start -W`, stopped
  with `pkill -INT screenrecord`; `ffprobe -show_entries frame=pts_time`.
- Old commits for a bench install beside the app as their own `--id-suffix` builds.
- In a worktree: init the submodules (`git -c protocol.file.allow=always submodule update
  --init`, then `third_party/nuklear` and `third_party/SDL` inside goose_gfx), link
  `build/android/SDL_src` to the main checkout's, and copy in the backgrounds'
  `masters/*.astc` and `*.jpg`. `build/android/draughts/native` is bound to the main
  checkout: build a copy under another name (`src/app/x.goose`, `x.build`, deleted after).
  CMake doesn't track `#embed`: delete `background.c`'s object after copying assets in.

## iOS

- A worktree links only the toolchains into a `build/` of its own: `build/ios/` holds
  CMake caches tied to one checkout.
- Rotating the simulator: `simctl` can't, so a throwaway constructor in a file added to
  `platform/ios/CMakeLists.txt` calls `requestGeometryUpdateWithPreferences:`; record with `xcrun
  simctl io booted recordVideo --codec h264 --force out.mp4`.

## Frame pacing

- **The Mac:** `xcrun xctrace record --template 'Metal System Trace' --launch --
  build/draughts …`. A frame's time on screen is `ca-client-presented-handler`'s
  requested time, joined to `ca-client-present-request`, `metal-command-buffer-completed`,
  and `metal-gpu-intervals` (parse the large export with `iterparse`). `xctrace` can hang
  after its app exits: run it under a 2-minute watchdog. GPU time is the union of the
  app's `metal-gpu-intervals` in a window of presents, whatever their `event-depth`;
  compare builds only at the same GPU performance state. `tools/perf/mac_gpu_time.py EXE
  --aa off` records and reads one 3D bench.
- **The iPhone:** `tools/perf/ios_perf.py` (Animation Hitches; `--renderer` passes flags).
  For GPU time, launch with `ios_perf.launch(..., console=True)`, attach Metal System
  Trace with its `record`, and take the union of `metal-gpu-intervals` over the loop
  phase, counted from the end (attaching misses the first presents).
- **Android:** Perfetto with its config on stdin: `adb shell "perfetto --txt -c - -o
  /data/misc/perfetto-traces/x.pftrace --background" < config.pbtx`, atrace `gfx view
  sched freq` with the app id, 384 MB and 140 s for the 3D bench. The SurfaceView has no
  frame tokens: a latch is a drop of its `BufferTX` counter, the hand-over a top-level
  `queueBuffer` on `SDLThread`. Read it with Perfetto's trace processor.

## GPU profiling

- `tools/perf/shader_report.py --core Mali-G615` (or G710, G68) with Arm's `malioc` on PATH:
  each shader's registers, spills, and cycles. Weigh a feature with a scratch copy that
  replaces it by a constant.
- Streamline on the Pixel 7a (a `--debuggable` build): push gatord with
  `streamline_me.py`, run it by hand with `--android-pkg` alone in the background, then
  `am start -S` with the flags quoted as above (press HOME first). A `configuration.xml`
  of `ARM_Mali-G710_<COUNTER>` lines picks the counters; `Streamline-cli -report X.apc
  -timeline -o DIR` writes a counter row a millisecond.
- Nsight Graphics' GPU Trace starts only from its own window.
- To weigh a part of the frame, measure a throwaway build without it.
