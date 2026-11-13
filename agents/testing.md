# Testing

How to run everything: `docs/development.md`, "Test the rules". Run `scripts/test.sh`
before committing a change to `rules/`.

In a separate working tree of the repo, make `build/` a real directory holding only a
symlink to the main checkout's `build/goose-v2026.4-macos-arm64`, not a symlink to its
whole `build/`: the tests and tools write `build/perft`, `build/test/`, and the like,
which would overwrite the main checkout's while another session uses them.

The tests never compile the app's shaders: after any change to a shader (`src/app/*.goose`'s
embedded GLSL), build the app itself (`docs/development.md`, "Run on the Mac") and check
it succeeds. A shader with a stray parenthesis passed both test runs and kept the app
from building (2026-11-09).

Badge art: `tools/badge_trace.py <animal> <png>` traces a black-on-white silhouette into
`assets/badges/<animal>.svg`, its viewBox fitted round the shape's enclosing circle so it
sits inside the piece's inner ring; then `test/run_tests.py --bless badges`.

## What each kind of test is for

- `test/<area>/<name>.goose` with `test/expected/<name>.out`: `expected/` is flat, so a
  name must be unique across the areas (a `test/shell/keys` overwrote `test/ai/keys`'s
  output, 2026-11-11). One program per behavior,
  printing what a reader can check by eye (positions as FEN, moves sorted, how many
  pieces each takes). A test explains in a comment what rule it shows and why the
  position shows it. Areas so far: `rules`, `board` (taps, hints, and a capture tapped
  stop by stop through the board package, a game and a puzzle alike, never played on
  by itself: `steps`; any of a capture's ways tapped, a last square two ways reach, a tap on
  the selected piece putting it down, and a tapped stop's hop: `ways`; a press or drop off the dark squares snapping to the nearest it
  could mean: `snap`, and several pieces that can capture under each draughts' rule:
  `several`; a capture to or past the far row, dropped on the turned board: `stuck`;
  the lookout's drained pieces, shaded crowning square, and the hint's ghost on the flat
  and 3D scenes: `lookmarks`;
  the count of pieces a capture takes, a capture played jump by jump by taps and by
  drops through the game's frames, straight to its last square, the hints after one
  and two wrong squares, and take back mid-capture, on a child's position read from a
  photo: `count`, whose `state` fills the board a moment on, so a pulse at its start,
  which is at full, shows as pulsing), `gui` (and the widget ids' ranges, one per
  screen, none running into the next: `ids`; `gui::stack`'s columns and rows: `stack`; the mouse's hover, its fade and turn, and none with `desktop_scale` 0: `hover`; the
  keys' focus, its moves by the controls' rects, Enter, the mouse taking over,
  Enter held filling a hold tile, and Tab on a screen of one group: `focus`; a focused row scrolled into its list's view:
  `scroll`; in `shell`, `continue_row`: Continue's note and its hidden first run; `kept_screen`: a game kept on each screen restored, on the screen it comes back on; `home_keys`: a desktop's Quit row or the X, and home walked and
  pressed with the keys (`drive::key`); in
  `shell`, `rest_hover`: a mouse resting anywhere on home, settings, the game, and the
  puzzles asks for no frames), `game` (the game screen driven through
  the pointer: take back, start over, home and settings, presses kept apart, the
  celebration and its moments to the still frame (`win`), a clocked game with its
  frames, pause, and flag, the turned board; the computer's turn, answered at once with
  `ai::think` as the app's worker would; the clock value on its own; and the computer's
  time a move on the clock, over whole games with simulated time, in `pace`; several captures of
  one piece each, black against the computer on 10×10, every capture and each landing of a
  king's chosen by taps and by a drag, on the flat and the 3D board, nothing played unchosen,
  and the must-capture rings and counts before and after a mistake: `choice`; anywhere on
  a landing square, 25 points, tapped and dropped on the turned flat and 3D boards in
  both orientations, plays that capture: `aim` (a 3D drop is aimed with the held piece
  over the point, as `board::touch` keeps it where the finger took it, a stacked king two
  discs high); a draw by a count tapped to its last move, its countdown, card, frames, undo,
  against the computer, kept in a saved game, and by repetition: `draw`; when a capture's
  count shows, on mistakes only from a mistake to the next right jump and with move
  hints at once, and the next stops lit after a second wrong square, on the flat and the
  3D board: `pips`; the lookout's eye and marks, held targets, the filter by skill, and
  traps answered as the worker would: `watch`; the hint's two presses, its ask and pips,
  and each side's against a friend: `hint`; the board with the keys, its
  cursor, Enter as a tap, a mistake, off the edge and back, Tab between the groups, the
  turned board, the computer's turn, Escape putting a piece down: `board_keys`; what each side has taken, men and kings apart,
  a king taken counting as a king, after captures by men and kings, undo, and its rows on
  the screen: `taken`), `shell`
  (home, the switch to the game and back, settings and their file, their taps, the
  material and the language list, and the board beside them, settings laid out at the
  tablet's, the Pixel 7a's, and the iPhone 13 mini's sizes both ways in both languages,
  every tap 88 dp and the preview at least `board::SMALLEST`: `settings_sizes`, the transitions between home and settings, home and the game, and
  the puzzles to pick from and a puzzle (their frames, the end, a tap during them, turning
  round, the game's clock and the computer frozen, a won game's way home, the screen
  reached as opened straight: `transition`, `game_transition`, `puzzle_transition`),
  home's setup and play, the setup's board (each
  draughts' start, turned for black, a friend's board turning once round for Turns, the
  game in progress back on the menu, the game play starts, and the setup laid out at the
  tablet's, the Pixel 7a's, and the iPhone 13 mini's sizes, where play is and how far the
  choices scroll, `setup`), the puzzles' library and a theme's page and a puzzle played through
  its misses, hint, reply, and stars, a black puzzle on the turned board, next after a
  theme's last (`puzzles`), a wrong move's answer shown before it slides back, and a
  wrong move with none sliding back as before (`puzzle_answer`, which reads its own
  puzzles into `puzzles::all`), the library and every theme's page laid out at the tablet's
  and a phone's size (`picker`), the draughts switch on the library (each draughts' set,
  the file, home's count, a
  scrolled list back at its top, and the layouts: `puzzle_set`), a capture made by hand in a puzzle (tapped and dragged
  stop by stop, dropped on its last square, left partway and next pressed: a miss) and
  no targets in any puzzle, a Russian player's set read on home, its library, a puzzle
  crowned mid-capture made by hand, and its stars kept apart (`russian_puzzles`),
  the saved game of any variant and damaged images of it, the players' files read and
  written back, their migration (killed after each step too), adding, switching,
  starting again, and removing (`players`), who's playing and a player's sheet, the
  holds let go early and held, the name typed, the first run, and their layout at the
  tablet's and a phone's size (`who`), every screen with a board on the 3D board (home's and
  settings' bounds at eight sizes, a puzzle tapped through the perspective with its ghost
  and hint ring, the win's card on the 3D bounds, the transitions moving one image:
  `screens3d`), home's 3D board turned by a drag on it, kept in its room, and at rest
  again once home is left (`home_turn`), the 3D board getting ready: a still mark in its place, taps on it left
  alone while the panels answer, then ready (`wait3d`), the computer's skill moving
  across games, home's X closing the app and where it sits, Android's back and Escape
  on each screen against its own back tile, which must be the arrow, in landscape and
  portrait (`back`), a past game's replay from its results row, its steps, a jump, the
  keys, the line over its board, back and play from here level, and nothing of
  it written or reaching the game in progress, at the sizes with the list's rows in view
  (`replay`; `drive::past_line` makes a history line of a game played out by rule), a
  game played on from a replay's move, against the computer and a friend: its opponent,
  side, and numbering, the hint, undo, the lookout, start over, a win, every way back to
  the replay, and nothing of it kept, counted, or written, the game in progress's image
  the same throughout (`play_here`; `sizes` places its button beside back, the same way,
  and the line over the board saying that it doesn't count at every size), the
  moves' line, its catch, and its sheet at the Pixel 7a's, the A33's, and the iPhone 13
  mini's sizes with their insets, flat and 3D, the sheet opened and closed by taps, back,
  and the keys, the setting off and the moves alone, and a mark's tip on the tablet's
  panel by touch and under the mouse (`moves_line`), and every screen at a
  foldable, 4:3, and a 20:9 phone in both orientations, and the phone's layout at 540
  and 480 dp (`gui::short_dp`, with a 9:16 phone at 480), its tiles on the screen and
  apart, every tap 88 dp at least, the phones again with the Pixel 7a's insets in both
  orientations (the cutout at either side in landscape), every tile and the board inside
  the safe area, the 16:10 tablet with its 72 px hidden navigation bar and the 13" and 11" iPad's
  landscape with their bars (settings declares its whole list on each), and on a phone settings' language list open and the puzzles' crown:
  `sizes`, which exits non-zero on any failure not on its `ALLOWED` list (each entry with
  its reason; add one only for a failure the user accepted, never to pass a regression); the title's and the clock's faces holding every character drawn in them, the
  app's name in every language and every clock time: `faces`), `strings` (every language
  file has every key), `badges` (each badge's SVG baked into its distance field, drawn
  coarsely, and the path syntax a tracer writes: bless it after replacing an animal), `ai` (the computer player:
  its search against a plain minimax, the table changing no score, keys, what each level
  plays in known shots, the same move in steps as at once, that no skill from 15 on
  hangs a piece but to a capture it overlooked, of two pieces or more (`blunders`), the
  lookout's threats now and after each move, traps, and what each skill is shown
  (`lookout`), the
  overlooks by tension, a capture's size, and its distance from the moved piece, with
  each one's rate over 4000 seeds through `ai::notice` and `ai::overlooked`, no search
  needed (`overlook`), and draws scored 0, steered into when behind and clear of when ahead (`draws`)), `model3d`
  (the 3D board's bake in steps, every row of each surface once, and the photograph's
  light as harmonics: `plan`; each season's look for each material, as the flags pick
  them: `material`), and `puzzles` (the puzzle file's format and refusals, what `puzzles::check`
  refuses beyond the format, what a move does to each goal, and every built-in puzzle
  passing `puzzles::check`, with its counts by theme and level: `set` International's,
  `russian_set` Russian's, `brazilian_set` Brazilian's). A new puzzle is checked with
  `build/puzzles FILE` (the engine's view too) and `test/perft.py puzzles` before
  `test/expected/set.out`, `russian_set.out`, or `brazilian_set.out` is blessed. With no FILE, `build/puzzles` checks the set built into
  it, so rebuild it after a set changes, or an old build checks the old set. In tiny positions the engine sees the
  game's end, so a Learn puzzle of a few men can fail its view (a right move scored as
  lost, or another move winning sooner) though the solver passes it: add men, or pick
  another from `find` (2026-11-09). `build/puzzles FILE` reads at most `MAX_PUZZLES` (150)
  ids, so a pool of `find`'s candidates checked as one file goes in files of 150; a set
  carried to another variant is checked one puzzle at a time with `try --variant`, which
  says what solves it there and makes its line (2026-11-10). A
  test that lays out text calls `gui::test_faces` for glyph sizes without an atlas, and
  `strings::use` before reading a string. Shared helpers are in
  `test/check.goose` (`check::show`, `check::play_only`), imported as
  `import check from "../";`, and, for the UI tests, in the package `test/drive/`
  (`import drive from "../drive";`): squares by name (`drive::at`, `name`, `marked`),
  the tiles a frame declared (`tile`, `rect`, `control` leaving out the clocks), and the
  pointer driving the game screen or the shell (`frame`, `tap`, `idle`, with the game's
  pieces over the UI in `drive::over` and the shell's screen size in `drive::size`).
  The game's frames' last result against the computer is `drive::result`; what the
  shell's frames are told of the 3D board, `drive::ready3d` and `drive::shown3d`. A
  shell's frame output is `sh.out` (`shell::Frame`); a test that sets `sh.prefs` itself
  calls `shell::apply_prefs(sh)` after, as the app does at launch. Importing it means declaring every package it reaches (`rules` through `shell`, `ai`);
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
- Self-play against a skill as it played before the overlooks (task of 2026-11-09):
  `build/aimatch VARIANT 0 10 400 --overlooks 100 0`. Skills 0 and 10 without overlooks
  are the yardsticks of easy's strength, which no overlook change touches. A simple child
  model is skill 0 overlooking three times as often, `--overlooks 100 300` (or `300` on
  its side). 400 games of easy take seconds; anything with hard, many minutes.
- `--hangs` adds each side's hanging moves in quiet and tense positions (task 053's
  table in `docs/architecture/ai.md`). Seven pairs of 400 games in three variants, with
  `--hangs`, take about 2 minutes on the Mac in parallel; skills up to 55 are quick. A
  change to the overlooks moves the self-play games in `test/game/pace.goose` (its
  plies and times), `test/ai/levels.goose`'s easy moves, and `blunders`' counts: bless
  them with the reason.
- To make a level stronger or weaker, `docs/architecture/ai.md`, "Tuning the levels":
  each knob, which way is stronger, how much a step moves the score, the aimatch runs
  to measure, and the tests to re-bless.
- `test/game/pace.goose` plays twelve whole games on the clock (each level against
  itself, both clocks, Russian and International) with hard at 20,000 nodes: about 12 s
  through TinyCC. For numbers at full strength, build a copy with `NODES` at
  `ai::NODE_LIMIT` and more `GAMES` (the task 027 numbers came that way).
  It first prints easy's planned time on three positions (quiet, a man threatened, a
  choice of captures) with its own search's close moves, the before/after table in
  `docs/architecture/ai.md`. A change to `pace.goose` moves the game means: widen a
  level's `LOW`/`HIGH` only with a reason in the doc. `pace::tense` is what makes easy
  slow, and the caller computes it from the reply (`game::answer`), so a new caller
  must pass it too.
- Positions come from the computer's own games (`build/aimatch ... --fens PLY`) and from
  scanning them for moves a deep search rates far above the rest. A shot's line goes in
  the test's comment only after each move is checked with `test/perft.py moves`; a
  line printed by repeated searches stops mid-combination unless it runs on until the
  material settles.

## Screenshots on the Mac

- A `--frames` run reads the Mac's settings from `~/Library/Application
  Support/kaitk/draughts/` (`src/app/storage.c`): the playing player's `player-N.txt`
  (`settings.txt` names N and the language), and there is no flag for most
  of them (the kings, the draughts settings show). To shoot settings as chosen, copy the
  file aside, write the keys wanted (`kings = stack`, `draughts = russian`, `hints =
  moves`), run, and put the copy back.
- A setup is shot with its choices from flags, leaving the player's file alone:
  `--screen friend --variant brazilian`, or `--screen computer --variant russian
  --computer white` for the child on black (`docs/development.md`). Add `--lang en`
  when the Mac's settings name another language (2026-11-08).
- `--keys` that end in `enter` on settings press whatever the focus reached, and a
  setting changed that way is written to the player's file on the Mac: `right,right,enter`
  meant for the language button chose Plain instead (2026-11-13). Open settings' language
  list with `--languages open`, and pick the board with `--board` and `--material`; copy
  the player's file aside before any run that taps or presses Enter in settings.
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
- A hovered tile is shot with `--mouse X,Y` (window pixels, twice the points on a Retina
  Mac) and `--touch off`. Mouse moves can't be scripted from here to count draws: events
  posted with `CGEventPost` never reach the app without Accessibility rights, and
  `gfx::inject_mouse` is ignored by a window started from a terminal, which never has
  focus (`--rest` drew 0 frames even with moves across tiles). Rest the real mouse
  over the window during `--rest` instead (2026-11-11).
- Shoot a few runs per command (up to about four) with a short `alarm` (30 s for a flat
  `--frames 300`): fifteen runs under `alarm 90` in one command once sat for over 8
  minutes with nothing to show (2026-11-11).
- Windowed `--frames` runs of one build differ from each other over the board and the
  photograph, so `cmp` says nothing about them. For a check that must be byte-identical,
  build headless copies of both commits with a fixed clock: `host::time()` adds 1/60 s
  a call and `dirty = true;` heads the loop, so `--frames N` is N drawn loops at the same
  moments every run. Two runs of one such build matched in all 102 shots (every screen,
  flat and 3D, the win, a clocked game with taps, at the desktop's, the tablet's, and a
  phone's sizes); about 50 s for the lot, four at a time (task 069, 2026-11-11).
- Shots scripted in a shell loop hang until killed when the app inherits the loop's
  stdin or writes stdout to a file: run each from `src/app` with `< /dev/null` and
  output to `/dev/null`, outside the sandbox, and `perl -e 'alarm 25; exec @ARGV'` in
  place of `timeout`, which the Mac lacks (2026-11-10).
- `--tap` takes up to 256 taps (`flags::MAX_TAPS`), two a move, so a draw by any count can
  be played to its last move from a `--fen`; `--win T` holds a draw's ending at T too
  (2026-11-09).
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
- A frame holds `gui::MAX_QUADS` (512) quads and drops the rest silently: a long line
  drawn with `gui::shadowed` (nine quads a glyph) pushed the puzzles' library past it,
  and its last rows were never declared. A layout test can print `g.quads.len`
  (2026-11-09).
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
- Apple devices headless, at their points times their scale (2026-11-09): the iPhone 13
  mini in portrait `--size 1125x2436 --dp 500` (the density floor's 0.75 × 3 px a dp)
  with `--inset 0,66.7,0,45.3` (50 and 34 points), in landscape `2436x1125` with
  `66.7,0,66.7,30`; the 13" iPad in landscape `--size 1376x1032` (800 dp, 1.29 points a
  dp) with `--inset 0,18.6,0,15.5` (24 and 20 points; but the app hides the status bar,
  so the simulator's shots match `0,0,0,15.5`, 2026-11-12: at 2064 × 2752, game and
  puzzles shots within 24 pixels of the simulator's), the 11" `1210x834` with
  `0,23,0,19.2`. `--inset` takes fractions, and the layout rounds them to pixels.
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
  (local and ignored) and touch `src/app/background.c`, or shots show the page color where
  the photograph should be.
- Clicks can't be posted to the window from a script: the terminal isn't trusted for
  accessibility (`AXIsProcessTrusted()` is false), so CGEvent clicks are dropped. To run
  a UI path in the real app (home's X closing the window, 2026-11-08), build a local
  copy, never committed, that feeds `gui::begin` a press and a release at the control
  on chosen frames. A run without flags reads and writes the Mac's `game-N.bin`: copy it
  aside first and put it back after. Any run migrates a `settings.txt` from before
  players to `player-1.txt` and renames `game.bin` (2026-11-09).
- A shot of the app without a window in the user's way (2026-11-09): copy
  `src/app/draughts.goose` to `src/app/xshot.goose` with its `gfx::open(...)` replaced by
  `gfx::open_headless(width, height)`, and `draughts.build` to `xshot.build`; build it into
  `build/xshot` and run it with the usual flags and `--frames N` in a folder of its own
  (it writes `draughts.png` there and never exits by itself: end it after the shot).
  Delete both copies after; never commit them. Since task 061 `gfx::open` is in
  `src/app/host.goose`. To compare two commits, `git archive` each into the scratchpad
  (`third_party/goose_gfx` and `build/goose-v2026.4-macos-arm64` symlinked in), replace
  `gfx::open(…, w, h, …)` there with `gfx::open_headless(w, h)` in whichever file holds it,
  put `dirty = true;` first in the loop's body so `--frames` counts loops, and build each
  with `build/mac/goose/goose build` from its `src/app`: a dozen shots of both, run four at
  a time, take about 15 s (2026-11-10). Its sizes are real pixels, so 800 × 1280
  works. The 3D board was checked that way (task 015). Taps in such a run (`--tap c3
  --tap d4`) may not all play before the shot; a position from `--fen` is surer (`--fen
  B:...` shows the 3D board turned for black in a friend's game). State with no flag,
  such as the 3D camera's (`rig::put` on `sh.game.cam`), is set from a temporary flag
  pair parsed in the copy only (2026-11-09). A capture's next stops on the 3D board, lit after a
  second wrong square: `--board 3d --computer white --fen B:WK1,K21,24,28,31,32,33,45:BK35
  --tap j4 --tap i1 --tap e9 --tap a5 --tap i1 --frames 400` (task 051), which leaves the
  player's files alone. The run must still be drawing at frame N: `--frames` counts drawn
  frames, so a shot past the last animation never comes; 400 lands in the dots' pulse.
- The lookout and the hint headless (task 040, 2026-11-09): in the copy, replace
  `draughts_storage`'s folder with a scratch one holding a `player-1.txt` with `lookout =
  on`, so the Mac's players are left alone; set `dirty = true` each loop, so `--frames`
  counts loops and a still screen is still shot (the 3D board is ready and faded in by
  about 500); a temporary `--xheld FROM,TO,LOOP` feeds a press on FROM at that loop and a
  held pointer over TO after (on the 3D board the press at the piece's top through
  `view3d::project`, the drag on the lifted piece's plane, as `view3d::pick` reads it),
  and `--xhint A,B` calls `game::press_hint` at loops A and B; the worker answers as in
  the app. Shots of each state in a few seconds each.
- An iPad's window headless (task 050, 2026-11-09): its real pixels with its density
  floor, `--size 748x968 --display-scale 2 --density-floor 0.75` for the 11" iPad's
  smallest window (499 × 645 dp), `760x2380` the tallest, `2420x960` the widest. A Mac
  window's layout is the same size with `--density-floor 0`. A list scrolled part-way: a temporary flag pair in the copy
  that calls `gui::scroll_set(g, id, px)` after `gui::begin` each frame, with the list's
  id (`picker::LIBRARY_LIST`, `PAGE_LIST` + the theme, `settings::LIST` + the group);
  a theme's page or settings' tab from flags setting `sh.theme` or `sh.prefs.group` the
  same way.
- A season changed mid-run in the headless copy (2026-11-09): a clock from the loop's
  count (`now` = loops / 60; the headless loop doesn't block when nothing draws, so it
  counts on, and `--frames` ends by it) and a temporary flag pair that at loop N sets
  `sh.prefs.season` and `season_in = 2`, never `sh.changed`, which writes the player's
  file. The theme's steps then run one a loop, so a shot at N + k shows step k − 2.
- Memory on the Mac: run the headless copy with a flag that keeps the player's game
  file alone (`--screen home`), wait a few seconds, then `footprint PID` (its
  "graphics" rows are the GPU's) and kill it. Headless, settings and the 3D game read
  600 MB and more of graphics that falls over seconds, with either background, so
  compare two runs of the same screen only (task 044, 2026-11-09).
- Memory experiments on the Mac without windows (task 065, 2026-11-11): the flat and 3D
  games headless (`GOOSE_GFX_HEADLESS=1 ... --board flat --screen game --frames
  100000000`, `footprint` after 14 s) read the same MB run to run, so a change to ngfx
  can be tried there and only the result measured in a window (`--rest`). `vmmap -w PID`
  lists the regions behind `footprint`'s rows: "IOAccelerator (graphics)" is GPU memory
  mapped into the process (CPU-visible heaps such as ngfx's 4 MB upload staging and its
  frame memory, and the driver's command memory), "owned unmapped (graphics)" the
  GPU-only heaps and textures; their sizes tell chunks, staging, and screens apart.
  Instruments' Game Memory template sat stopped at launch here, and `screencapture` has
  no permission from the agent's shell ("could not create image"): count presented
  frames from the app instead (`ngfx::frame_count()`).
- On the ngfx build, `--bench`'s waited frame and its CPU time include waiting for a
  free drawable, which a frame's first pass into the screen does since the screen is
  the window's image (2026-11-11): flat 8.3 ms waited and 3.7 ms CPU against gfx's 4.8
  and 0.1 at the same 120 fps presented. Compare the presented rate and the 3D board's
  waited time, which the drawable doesn't hold up.
- To shoot an animation at a known moment (a ring's pulse, a flash) in two builds, hold
  the copy's clock: `now` fixed at T until the taps are made, then at T + L
  (`tapped >= taps.len`), so the launch's own time doesn't shift the tap. A clock that
  starts by frame count hangs: `gfx::frame_count()` counts only drawn frames, so once
  nothing draws, time and the count both stop (2026-11-09). Two such runs of one build
  differ by nothing; a third build's taken from `git archive` of the old commit into the
  scratchpad, its `third_party/goose_gfx` and `build/` linked (task 015's pulsing marks).
- A state change made inside a screen's frame shows only when that frame is drawn with
  it: the 3D board's view is aimed again after the game's frame (`shell::game_screen`),
  or a change with no animation behind it (the hot-seat turn put at once) showed a frame
  late, and draw on demand then never drew it (2026-11-09).
- The prototypes' painter (`Paint` in `prototypes/draughts.js`) is a port of the piece
  shader, so a native crop beside the prototype's at the same scale shows a shader
  change exactly (the stacked king was checked that way).

## Screenshots and windows on Windows

- `GOOSE_GFX_HEADLESS=1` in the environment makes both builds headless (gfx's and
  ngfx's `open`): `--frames N` then saves `draughts.png` in the working folder and exits.
  Headless loops run about 3,500 frames a second, so `--frames` is wall time too short
  for the 3D board: at 80 it hasn't appeared, and ngfx's board, whose preparing takes
  longer, is still fading in at 3,000 when gfx's is done. Shoot the 3D board settled at
  `--frames 20000` (about 6 s), portrait too (2026-11-11).
- A change to the drawing (a drawer or its `_gpu` recorder) is checked on both builds:
  every screen flat and 3D, headless at 1280 × 800 and `--frames 20000`, shot from both
  before and after and compared each against itself; two runs of one build differ in
  the 3D shots by a few pixels at most 2 of 255 (gfx's portrait 3D by about 3,900 of
  them), so nothing over 32 is the test. For the 3D renderer also each `--aa` way, and
  `--bench` and the footprint at `--rest` against a build of the commit before (task
  073, 2026-11-11).
- That check's 13 screens, each run as `GOOSE_GFX_HEADLESS=1 <exe> --size 1280x800
  --lang en --touch off <flags> --board flat|3d --frames 20000` in a folder of its own,
  four at a time, with `F` for `--variant russian --fen W:Wc3,e3,Kh2:Bd4,f6`: home
  `--screen home`; game `--screen game F`; taps `F --tap c3`; settings `--screen
  settings`; stone `--screen game --theme stone F`; birch's settings `--screen settings
  --theme birch`; sunset plain `--screen game --theme sunset --background plain F`; home
  plain `--screen home --background plain`; puzzle `--puzzle 21 --tap f4 --tap e5`; win
  `--variant russian --fen W:Wa1,c1,g1,b2,h2,e3:Bf4 --tap e3 --tap g5 --win 1.2`; held
  `--go settings --hold 0.5`; portrait `--screen game --size 800x1280 F`; lookout
  `--screen game --lookout on F`. The puzzle's 3D shot is the noisiest: two runs of one
  ngfx build differ there by up to 40 to 67 of 255, at 2 to 9 single pixels along the
  pieces' and the board's edges, so find where a pixel over 32 is (`-threshold 12.6%
  -format %@` below) before blaming a change (2026-11-12).
- On the Mac, Python has no PIL: compare shots with ImageMagick, `magick a.png b.png
  -compose difference -composite -alpha off -separate -evaluate-sequence max`, then
  `-format "%[fx:round(255*maxima)]" info:` for the largest difference and `-threshold
  0.9%` or `12.6%` with `-format "%[fx:round(mean*w*h)]" info:` for the pixels over 2 or
  32 (2026-11-12).
- A change to the ngfx build alone (its recorders, `src/ngfx/shaders/`, the shader
  generators) leaves gfx's binary byte for byte the same: `cmp build/draughts` against a
  copy from before settles gfx's shots, `--bench`, and footprint (2026-11-12).
- `--bench 60` and `--rest 4` run headless too, the game at 1280 × 800 (the shot list's
  flags with `--board flat` or `3d`); `--rest` prints its line and keeps running, so take
  `footprint PID` once the line is out and kill it. One build's flat waited P50 spreads
  from 0.39 to 0.82 ms over five runs: compare medians of five runs, the builds taken in
  turn (2026-11-12).
- To compare the ngfx build with gfx, run both with the same flags in folders of their
  own and diff the PNGs (mean, max, pixels over 2, 8, and 32, and the box they're in).
  A one-off script in the scratchpad does it; settled, the flat board is within 1 of 255
  everywhere and the 3D board differs along edges and in the wood's grain.
- A real window is driven from Python with ctypes: find the app's window by its process
  id (`EnumWindows`), click with real input (`ClientToScreen`, `SetCursorPos`, then
  `mouse_event` down and up, after `SetForegroundWindow`), which moves the user's cursor.
  Posted or sent `WM_LBUTTONDOWN`/`WM_LBUTTONUP` worked on 2026-11-11 and no longer do
  on 2026-11-12, after the gamepad moved into goose_gfx's idle wait (the cause is not
  pinned down); real clicks work. Resize with `SetWindowPos`, and grab the client area with
  `PIL.ImageGrab.grab(bbox=..., all_screens=True)` after `SetForegroundWindow`. Call
  `SetProcessDPIAware()` first. A game on the 3D board is played by clicking squares
  mapped through a homography of the field's four inner corners (at 1280 × 800 with the
  default camera: 355,190 · 928,190 · 1028,693 · 245,693), mirrored on black's turn, when
  the board turns. Settings at 1280 × 800: Back 100,74; the themes' tiles at y 512, x 230
  (winter) to 524 (autumn); Flat and Raised at 230,610 and 328,610; the photo and plain
  tiles at 80,522 and 143,522 (2026-11-11).
- Changing the theme or board in a window writes `%APPDATA%\kaitk\draughts\player-1.txt`:
  copy the folder aside first and put it back after.
- The build holding both renderers (`scripts/ngfx.py`, task 073) takes `--renderer
  auto|gfx|ngfx` and prints `renderer: ... (why)` at start. Two environment variables test
  the choice where `auto` wouldn't try ngfx: `DRAUGHTS_AUTO_NGFX=1` makes it try ngfx here
  (on the Mac, say), and `DRAUGHTS_RENDERER_TEST=fail` makes ngfx's open fail after the
  hidden window opened (gfx then starts alone), `crash` ends the program after ngfx opened,
  before its first frame. The marker is `renderer-start.txt` in the app's storage folder
  (on the Mac `~/Library/Application Support/kaitk/draughts/`); delete it after such a test.
  Every path runs headless (`GOOSE_GFX_HEADLESS=1 ... --frames 300`): each start's line and
  whether the marker is left say whether it chose as it should (2026-11-12).
- `scripts/windows_perf.py` measures another build with `EXE=build/ngfx/draughts.exe`
  and adds flags to each run with `FLAGS`; PresentMon's GPU busy time is the one frame
  time both builds report alike, since both wait on the display.
- Uncapped (`--no-vsync`), the ngfx build's swapchain flips only while its window is in
  front (NVIDIA's legacy presenting); a process a background script starts doesn't get the
  foreground, and DWM then copies ngfx's window (Composed: Copy with GPU GDI, 12 ms to the
  display). `windows_perf.py` brings the window forward itself; check the present mode on
  every run of a batch, and never run two benches at once (2026-11-12, task 074).

## Screenshots and windows on Linux

- `--frames N` saves `draughts.png` from gfx's window; ngfx's window image can't be read,
  so under ngfx only `GOOSE_GFX_HEADLESS=1` saves one. `import -window Draughts out.png`
  (ImageMagick, on the Bazzite host) grabs an X11 window (`SDL_VIDEO_DRIVER=x11`). Don't
  call the screenshot portal for a Wayland window: it waits on a permission dialog on the
  user's screen and stalls every SDL program's Wayland start 50 s until
  `systemctl --user restart xdg-desktop-portal` (2026-11-12, task 076).
- `WAYLAND_DEBUG=1` shows what a Wayland run did: `set_app_id`, `preferred_scale` (120
  is 1.0), `wp_viewport.set_destination` (the window's logical size), Mesa's
  `create_immed` buffers (the swapchain's pixel size), and an `attach` on Mesa's queue for
  each frame presented. That is how ngfx's presenting was checked.
- A run is ended by `timeout -s KILL`: SIGTERM is a quit, which the app asks about first,
  so a plain `timeout` never returns. Kill a stray one with `pkill -x draughts`; `pkill -f`
  with its path also matches, and kills, the Bash tool's own shell.
- `gdctl set -L -M HDMI-1 --primary --scale 1.25` sets GNOME's display scale (1.25, 1.5,
  or back to 1) without asking and not persistently, for checking fractional scales.
- `--bench` and `--rest` measure on the host; nothing CPU-heavy (a box's build) at the
  same time.

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
- The game screen's controls in tests (`drive::control`) are back, settings, start over,
  undo move, then the hint's tile (4), then a card's back and play again (5, 6). The
  lookout's eye is a floating disc, not a tile: `drive::eye` finds it, and
  `drive::camera_disc` tells the 3D board's camera buttons from it (2026-11-09).
- During a transition (home and settings, home and the game, the puzzles and a puzzle)
  both screens' quads are declared, the one left first, so `drive::tile(g, n)` counts the
  wrong screen's tiles and `drive::at(sh.out.layout, ...)` finds squares on a moving board. A
  shell test that taps again after such a switch idles past `shell::DURATION` first
  (`switch` in `test/shell/shell.goose`); a tile of the screen come to is found at rest
  beforehand, its taps being where it rests.
- Tests that tap tiles find them by the order of `gui::BUTTON` quads; the clocks are
  `BUTTON` quads too, so the game's helpers skip styles from `gui::CLOCK_RUN` on.
- The tablet's GPU clock and load, readable without root: `/sys/kernel/gpu/gpu_clock`
  (kHz, 0 at rest) and `gpu_busy` (a percentage); `gpu_freq_table` lists 265 to 1047 MHz,
  and `gpu_model` says Mali-G720 MC12, whatever the hardware is. The devfreq node's
  `cur_freq` is denied. The 3D bench runs near 1047 MHz, so its frame times show the
  work, unlike the Pixel 7a's (2026-11-10). The A33 has the same `gpu_clock` node (104 to 897 MHz,
  readable), but its governor holds 500 to 700 MHz under the 3D bench whatever the work:
  compare cycles there, waited ms × the clock sampled during the run (task 081,
  2026-11-13). Old commits for a bench install beside the
  app as their own `--id-suffix` builds, one each, built from a checkout of the commit
  (task 059); `kings = crown` goes into a debuggable build's `files/player-1.txt` with
  `run-as`.
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
  `build/`). Init the submodules (`git -c protocol.file.allow=always submodule update
  --init`: the repository's config points goose_gfx's URL at the main checkout's copy,
  2026-11-11), and inside `third_party/goose_gfx` also `third_party/nuklear` and `third_party/SDL` (the app's C needs nuklear's headers,
  `scripts/android.py` SDL's revision); link `build/android/SDL_src` to the main
  checkout's to skip copying SDL. The first Android build then takes about 35 s.
  `build/android/draughts/native` is a CMake cache bound to the main checkout's
  `android/`: from a worktree sharing `build/android`, build a copy of the program under
  another name (`src/app/x.goose` and `src/app/x.build`, deleted after) so it gets its own
  `build/android/x/`, and remove that after. A new or changed `patches/SDL` patch makes
  the shared `SDL_src` be copied again, for the main checkout too (2026-11-08). Copy
  the main checkout's `design/backgrounds/masters/*.astc` and `*.jpg` in too (ignored by
  git), or the build has no photographs; copied in after a build, they need
  `background.c`'s object deleted from `build/android/<program>/native`, as CMake doesn't
  track `#embed` (2026-11-09).
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

## In the iOS simulator

- A rotation, filmed: `simctl` can't turn the simulator and Simulator.app's window would
  be in the user's way, so a throwaway `ios/rotate_debug.m` (added to `main.c`'s line in
  `ios/CMakeLists.txt`, neither committed) runs a `__attribute__((constructor))` that
  `dispatch_after`s `-[UIWindowScene requestGeometryUpdateWithPreferences:]` with
  `UIWindowSceneGeometryPreferencesIOS` for landscape, then portrait, after
  `setNeedsUpdateOfSupportedInterfaceOrientations` on the root view controller. Record
  with `xcrun simctl io booted recordVideo --codec h264 --force out.mp4` (stop it with
  SIGINT) and lay the turn out with `ffmpeg -ss 5.5 -t 1.2 -i out.mp4 -vf
  "fps=15,scale=180:-1,tile=9x2" -frames:v 1 sheet.png`; the video stays in the device's
  portrait frame (2026-11-09).
- A worktree's own `build/`: `build/ios/` holds CMake caches tied to one checkout's path,
  so a worktree links only the toolchains (`build/goose-v2026.4-macos-arm64`, ...) into a
  `build/` of its own rather than linking the whole of the main checkout's.

## Frame pacing

How task 056 found which frames were late and why (2026-11-10):

- **The Mac:** `xcrun xctrace record --template 'Metal System Trace' --launch --
  build/draughts …`; the app's stdout doesn't reach the log. Its trace has no
  `display-vsyncs-interval` rows: a frame's time on screen is
  `ca-client-presented-handler`'s requested time (raw units are 41.67 a ns), joined to
  `ca-client-present-request`, `metal-command-buffer-completed`, `metal-gpu-intervals`
  (200 MB exported for 40 s: parse it with `iterparse`), and
  `ca-client-buffer-wait-interval`. A 50 ms stall every 5.00 s from the recording's start
  is most likely Instruments' own.
- **The GPU's own time on the Mac** (task 070, 2026-11-11), the one measure both builds
  give alike: in `metal-gpu-intervals`, the app's rows (`process` names it), the union of
  all of them in a window of presents, whatever their `event-depth`. Depth isn't
  nesting but Instruments stacking intervals that run at once, so depth 0 alone
  undercounts gfx by a third. `gpu-performance-state-intervals` gives the GPU's clock
  state over the same window; compare builds only at the same mix (full screen the 3D
  bench runs at Maximum, a window moves between Medium and Maximum). The bench's phases
  are its last 4 × N presents (3D) or 2 × N (flat), in order. gfx's waited phases cost
  its MSAA about 1 ms more fragment time than its loop's frames (the pass split at the
  flush), so compare the loop's. ngfx's `GOOSE_NGFX_BENCH=1` stamps span both of a
  frame's submissions and the wait for a drawable between them: not a GPU time. An
  `xctrace record` can hang after its app exits, at 100% CPU and deaf to SIGINT: run each
  under a watchdog that kills it after 2 minutes. `scripts/mac_gpu_time.py EXE --aa off`
  records and reads one 3D bench this way (task 077, 2026-11-12).
- **The iPhone:** Animation Hitches only (`scripts/ios_perf.py`; its tables
  `display-surface-swap`, `displayed-surfaces-interval`, `display-surface-queue`,
  `metal-command-buffer-completed`). Under Metal System Trace the app's loop runs at 120
  on the 60 Hz panel, and the display tables hold only the first half second. The GPU's
  time a frame does come from Metal System Trace (task 084, 2026-11-13): launch the bench
  with `ios_perf.launch(..., console=True)` and attach with its `record(udid, "Metal System
  Trace", ...)`, then take the union of the app's `metal-gpu-intervals` between the
  `ca-client-present-request` rows that bound the loop phase. Attaching misses the first
  presents, so count the phase from the end (presents −2N to −N). The loop phase then
  presented every 16.7 ms. `scripts/ios_perf.py N --renderer ngfx` passes flags to the app;
  Animation Hitches has no GPU durations.
- **Android:** Perfetto, its config on stdin (`/data/local/tmp` isn't readable to it):
  `adb shell "perfetto --txt -c - -o /data/misc/perfetto-traces/x.pftrace --background"
  < config.pbtx`, with `linux.ftrace` (atrace `gfx view sched freq`, `atrace_apps` the
  app id), a 384 MB buffer and 140 s for the whole 3D bench (its four phases take about
  100 s on the A33). The app's SurfaceView has no frame tokens, so SurfaceFlinger's
  frame timeline leaves it out: a frame's latch is a drop of the counter `BufferTX -
  …SurfaceView[io.github.kaitk.draughts…]`, the app's hand-over a top-level
  `queueBuffer` on `SDLThread`, and `VSYNC-sf` toggles each refresh. Read it with
  Perfetto's trace processor (`get.perfetto.dev/trace_processor`, the user allowed the
  download).

## GPU profiling

How task 059 found where the 3D frame went (2026-11-10):

- **The measure is GPU cycles a frame, not milliseconds**, where the governor moves the
  clock: the Pixel 7a runs its Mali-G710 at 350 to 470 MHz of its 850 under the 3D bench
  (`/sys/class/misc/mali0/device/cur_freq`), busy nearly all the time, so cutting work
  lowers the clock as much as the frame time. The tablet holds its top clock (above), so
  there the frame times show the work.
- **The Mali Offline Compiler:** `scripts/shader_report.py --core Mali-G615` (or G710,
  G68) with Arm Performance Studio's `malioc` on PATH (on the PC): each shader's
  registers, spills, and cycles per unit. To weigh a feature, run a scratch copy of the
  shader with it replaced by a constant. Its register count can differ from the
  driver's: a field-only variant at 32 registers changed nothing on the Pixel.
- **Streamline on the Pixel 7a** (a `--debuggable` build): `streamline_me.py` pushes
  gatord and the layers, then run gatord by hand (the headless script didn't keep the
  capture, and `Streamline-cli -generate-config` rejects every template), with a
  `configuration.xml` of `ARM_Mali-G710_<COUNTER>` lines (the IDs are in gatord's
  binary) and `MaliTimeline_Perfetto`:

  ```sh
  adb shell "cd /data/local/tmp && ./gatord --android-pkg io.github.kaitk.draughts \
    --android-activity .DraughtsActivity \
    --activity-args \"--es args '--board 3d --screen game --theme wood --variant russian --bench 1000'\" \
    --stop-on-exit yes --max-duration 100 --output /data/local/tmp/b.apc --gpu-timeline auto -c configuration.xml"
  ```

  With a test build (`--id-suffix`), `--android-activity` raced: something force-stopped
  the app a second after gatord started it (task 063). What worked: gatord with
  `--android-pkg` alone, in the background (it waits for the package), then `am start -S`
  by hand a few seconds later with `--es args "'...'"` quoted exactly as in "On the
  tablet": one more layer of quotes leaves a `'` on the first and last flags, and the app
  drops both silently. Press HOME first: an app drawer left open over it pauses the app.
  `-report X.apc -timeline -o DIR` writes `DIR/timeline.csv`, a row a millisecond of
  global counters (decimal commas); sum a window of the bench's phase and divide by its
  frames.
  Read it back with `Streamline-cli -report -timeline` and `-cam`: GPU active cycles,
  fragment against tiler time, all-register warps, texture stalls, and each pass's time
  on the Mali timeline.
- **Nsight Graphics on the PC** (clocks locked to base): its GPU Trace starts only from
  Nsight's window, not from the agent's shell. The 4090 runs the whole 3D frame in a
  quarter of a millisecond, so it shows the frame's shape and nothing finer.
- To weigh a part of the frame, a throwaway build without it (the backdrop as a plain
  copy, no `widgets::frame`) measured on the Pixel says what it costs in a few minutes.
