# Archive

Done or cancelled tasks whose files were deleted. Each line: number, title, outcome, file,
and the commit that last has it.

- 001: Goose on Android proof of concept. Done: Goose runs on the tablet through Vulkan,
  full screen, with flat memory over 20 lifecycle cycles after an SDL patch.
  `001-goose-android-poc.md`, `6c1264e`
- 002: Rules engine for Russian and International draughts. Done: `rules/` plays
  Russian, International, and English; perft matches published values (International to
  depth 10, English to 11) and an independent Python generator (Russian to 10).
  `002-rules-engine.md`, `cb8ab4a`
- 003: UI prototypes. Done: seven HTML pages settled the look (Snowtime's glass over a
  pre-blurred seasonal scene, a wood board with crowned kings, Libertinus Sans), recorded
  in `docs/architecture/rendering.md`. `003-ui-prototypes.md`, `878aa1f`
- 005: Draw only when something changes. Done: a goose_gfx patch makes `frame()` present
  only what was drawn and wait for events when idle, with SDL's poll sentinel off on
  Android so the wait blocks; the idle program thread went from 17% of a core to 0.02%.
  `005-on-demand-frames.md`, `522ce35`
- 012: Seasonal themes in the prototypes. Done: the season picks the board (autumn wood,
  winter stone, spring birch, summer sea) with each board's palette, glow, and glass
  tint over photo backgrounds, a key-light model, and crown/stack/auto kings with a 3D
  stacked king; backgrounds to ship as embedded JPEGs decoded with stb_image.
  `012-seasonal-themes.md`, `5187404`
- 004: 2D board and pieces. Done: `app/kabe.goose` draws the board in one pass and the
  pieces in one instanced draw with the season's theme and key light; taps, drags, and
  hop-by-hop moves work on the tablet, idle at 0.03% of a core, nothing allocated per
  frame. `004-board-2d.md`, `1d60fce`
- 017: The native board on the season. Done: the blurred season photograph behind a flat
  board with a thin lip and faint per-theme surfaces, soft-lit pieces, hints on mistakes
  only; idle at 0.03% of a core and flat memory over 20 lifecycle cycles on the tablet.
  `017-native-look.md`, `55b0f28`
- 018: The pieces' shape and shine. Done: flat matte discs with a groove at 70% of the
  radius shaded as a cut, a rounded outer shoulder with a soft highlight, and shade
  toward the color squared, after the 3D reference. `018-piece-shape.md`, `d515400`
- 009: String table. Done: `strings/` with English (the default) and Estonian, a
  constant per key, lookups as views into the embedded files, the language from SDL's
  preferred locales; `test/strings/` fails on a key missing from any file.
  `009-strings.md`, `ecfe920`
- 031: A better win. Done: take a, the pieces answer (the winning piece lifts, a glow
  passes the winner's pieces, the board dims, the card slides up), still by about 1.7 s;
  90 Hz on the tablet, no frames after. `031-win-animation.md`, `4a206e6`
- 034: The setup's board shows the game being set up. Done: the chosen variant's start,
  turned for black against the computer, switching at once; play starts the game shown.
  `034-setup-board.md`, `4609d2c`
- 022: Transitions between screens. Done: 0.25 s with one board easing between home,
  settings, the game, the setups' play, and the picker and a puzzle; the photograph
  crossfading sharp to blurred; the leaving screen's UI hidden where the board passes;
  90 Hz on the tablet, idle after. `022-transitions.md`, `6050dd6`
- 030: Phones and other screen sizes. Done: every screen fits from 9:20 phones to near
  square in both orientations with every tap 88 dp, a density floor (F = 0.75, the Pixel
  7a 549 dp across), the safe area with `patches/SDL/0002`, Android's back going back a
  screen, phones turning; checked on the Pixel 7a and the tablet, larger tablets on the
  Mac. `030-screen-sizes.md`, `27b2c23`
- 035: A way to close the app from home. Done: take b, a round 88 dp glass X in the top
  right on home's menu and setups that closes at once, the game kept; on Android
  `finishAndRemoveTask()` takes the card out of recents and the next start restores the
  game. `035-exit-button.md`, `7f998da`
- 011: Stop SDL's accelerometer listener. Done: `DraughtsActivity` gives SDL a surface
  whose `enableSensor` ignores the accelerometer, no SDL patch; idle at home the process
  went from 1.19 to 0.05 s a minute, and the screen still turns.
  `011-accelerometer-off.md`, `bde1841`
- 032: Bring memory use down. Done: the screen without depth or cycling, SDL's large
  allocations at their size, the R8 atlas, the ASTC photographs, and the malloc purge;
  on the tablet PSS at home 216 → 130 MB fresh and about 261 → 136 through the
  lifecycle, graphics at home 160 → 91 MB; the Pixel 7a at home 291 → 146 MB; each
  screen size checked on the Mac. `032-memory.md`, `65a6acc`
- 006: Computer player. Done: `ai/` searches with alpha-beta and a fixed transposition
  table at three levels with an adapting skill (medium starts at 40, never under 25);
  the user judged it good enough to ship (2026-11-08), to retune after children play it.
  `006-computer-player.md`, `8987f26`
- 007: Puzzles. Done: International puzzles in a plain text file with goals and every
  solving line counted, a picker and a puzzle screen (take c), stars, hints, and
  multi-captures by hand; the 30 puzzles of three tiers were replaced by task 037's set.
  `007-puzzles.md`, `8987f26`
- 008: Game shell. Done: the UI layer, the game panel, home, settings, and resuming the
  game after Android kills the app, in five subtasks. `008-game-shell/`, `8987f26`
- 016: Tabletop pictures for the 2D game. Cancelled by the user on 2026-11-07: the
  generated tabletops looked like flat stock textures, so the 2D board stays on the
  blurred season photograph; the prompts stay in `design/tabletops/`.
  `016-tabletops.md`, `8987f26`
- 019: Prototype the game screen's controls, a clock, and the first start. Done:
  the game screen's panel with labelled tiles, the clocks, and a setup on home settled in
  prototypes (built by 021 and 025); the first start went to task 026.
  `019-game-screen-and-first-start.md`, `8987f26`
- 020: Review the code's layout as a whole. Done: the review's changes 6, 8, 1, 2, and 5
  were made; a third was left for later. `020-code-layout-review.md`, `8987f26`
- 021: The game screen, the clocks, and a new game's setup. Done: the board between two
  panels of labelled tiles, clocks on the play side, and a setup on home for a friend
  and the computer. `021-game-screen-and-setup.md`, `8987f26`
- 023: Brazilian draughts. Done: International's rules on 8×8 as a `BRAZILIAN` variant
  in `rules/`, offered in settings and in a new game's setup. `023-brazilian.md`,
  `8987f26`
- 024: Review the Estonian translation. Done: Gemini read every key twice (two models in
  the first pass, then a second pass); the changes taken are in `strings/et.txt`, the
  screens checked in both orientations on the Mac and the tablet. The briefs and
  proposals were deleted with the folder. `024-estonian-review/`, `8987f26`
- 025: The regrouped settings with the board beside them. Done: game and look groups,
  the language in the title row, and home's board showing what the choices make.
  `025-settings-regrouped.md`, `8987f26`
- 027: The computer spends its clock as a player of its level would. Done: `game/pace.goose`
  gives each move a share of what it could spend by level, keeping its clock; the numbers
  are in `docs/architecture/ai.md`. `027-computer-clock.md`, `8987f26`
- 028: The app icon and the launch screen. Done: the winter jump icon, the launcher's
  name in the phone's language, and a launch theme with no blank frame; the icon is
  `design/icon/`. `028-icon-and-launch.md`, `8987f26`
- 015: The 3D board. Done: a 3D board from the same game state on every screen with a
  board, chosen in settings' Board row, floating on the season's blurred photograph,
  taps through the perspective, the camera buttons and the showcase, drawn only on
  change; the decisions are in `docs/architecture/rendering.md` ("Board and pieces"), the
  device numbers in its "The 3D board on devices", the frame cost in task 042.
  `015-3d-board.md`, `f2b9acc`
- 033: An icon per season. Cancelled (2026-11-09): one icon, autumn, shipped for the
  release; a seasonal icon costs its place on the home screen four times a year.
  `033-icon-per-season.md`, `a9d4cd6`
- 047: Review the code's structure and clean up. Done: the build scripts' shared steps
  in `scripts/native.py`, the app's flags in `src/app/flags.goose`, one variant-name
  table in `rules/`, stale comments, docs, and tasks cleaned up, the shots unchanged; a
  shared CMake include declined, 010's upstream list deferred.
  `047-structure-review.md`, `d41c3d9`
- 049: Draws. Done: repetition and each variant's counts in `rules/draw.goose` checked
  against the federations' texts, scored 0 by the search, a calm card and a countdown
  (a short form between the clocks where the line has no room); checked headless on the
  Mac, not on a device, by the user's choice.
  `049-draws.md`, `fb29d63`
- 051: Polish found while preparing the stores. Done: the 3D board shows a capture's
  next stops; the library's title has a soft dark halo over bright bark; settings' top
  padding gives up to 12 dp under a top inset so both groups fit an iPad's landscape;
  the Game/Look tabs sit on glass as Back does; in portrait the shown group is its own
  height and the board takes the rest (the user, 2026-11-09).
  `051-polish/`, `5066f4f`
- 053: Mistakes where the position is tense. Done: each of the child's captures after the
  computer's move is overlooked by its own seeded chance, more for more pieces and further
  from the moved piece, a tenth as often where no capture was around; easy's quiet hangs
  fell to a fifth, its tense ones rose, its strength stayed, medium misses only captures
  of three pieces or more (the user, 2026-11-09). `053-mistakes-by-tension.md`, `6a3f742`
- 050: Small windows. Done: iPad windows down to 374 × 484 pt work: a compact game,
  home, and settings (slim theme tiles), drag and wheel scrolling for the puzzles and
  settings, settings' groups side by side as a window widens, and the game's portrait
  kept until its landscape board takes about 2/3 of the height; the window control's
  margin was built and taken out, the dots may sit over back's corner (the user,
  2026-11-09). A single puzzle's compact layout is left for later.
  `050-small-windows.md`, `4cfc89b`
- 048: A report of a forced capture with a king. Done, not reproduced: the engine, the
  game screen's taps, drags, rings, and hints, and every point of each landing on the
  turned flat and 3D boards play the capture chosen (`test/game/choice`, `aim`). If it is
  seen again: a screenshot or the position, the taps, and which side's king.
  `048-equal-capture-choice.md`, `5a01306`
- 039: Procedural wood for the 3D board. Done: growth rings with pores and a fibre
  relief the default wood, a black marble for winter's frame, summer's variants kept
  beside its look; the bake 0.27 to 0.30 s warm on the tablet; the defaults kept by the
  user (2026-11-09). `039-procedural-wood.md`, `6c3ae96`
- 040: The coach and the hint. Done: the lookout (*Valvur*), a round eye toggle on whose
  turn's line, off by default and kept per player, drains the pieces in danger and shades
  a crowning square under a ghost king, while dragging what the move would leave, and
  the computer's traps (on the worker), filtered by skill to nothing at hard; the hint, a
  tile with three pips, lights the piece and then its square, from a search at 15 above
  the opponent's skill on the worker. Three rounds of prototypes (`prototypes/coach*.html`).
  `040-coach-and-hint.md`, `08e55e1`
- 054: The flat game screen's controls as the 3D one's. Done: the user set aside the
  takes' frame, shadow, and blur (the UI round the board only); the flat board between
  the 3D screen's short corner panels in landscape, the same tiles in the same places,
  narrowed to 192 dp near square so the board keeps its size; portrait's bar and play as
  wide as the 3D screen's. A puzzle keeps its tall panels. `054-flat-screen-like-3d.md`,
  `3331ab9`
- 052: What each side has taken. Done: take a's row of small pieces, kings after a gap
  and crowned, counted from the position with kings from the undo history; under the
  flat screen's left corner panel, above the 3D board between its panels (under the left
  panel on a phone, the board never smaller at rest), a row under the portrait bar's
  tiles (the bar 52 dp taller), and compact's bar middle. `052-captured-pieces.md`,
  `6ed79a5`
- 058 A window being resized shows a stretched picture: no build ever redrew live (c8e0afe
  stretches too); the Mac keeps its last frame in shape over the backdrop
  (`src/app/resize.c`), an iPad lays out live, and Windows' unscaled last frame with
  black where the window grew is kept. `058-resize-stretch.md`, `0c0b30c`
- 059: Profile and rework the 3D renderer. Done: the field's occlusion into a map, the
  backdrop and the UI kept while they stand still, and the crown read from a map took the
  Pixel 7a's moving 3D frame from 7.01M to 4.70M GPU cycles (−33%, −34% more with 16
  kings) and the tablet from 10.6 to 9.2 ms waited, 90 Hz with no frame dropped; the
  Mali Offline Compiler's and Streamline's numbers and the untried items are in
  `docs/architecture/rendering.md` and `agents/testing.md`. The PC's per-pass captures
  and RenderDoc were left (the user, 2026-11-10: good enough).
  `059-3d-renderer-tuning.md`, `e2b8f8f`
- 044: A plain background. Done: settings' Theme row switches between the photograph and
  a fade per season's board (`prototypes/plain.html`'s fade b), the 3D board's ambient
  taken from the fade; on the tablet about 1 MB less than the ASTC photograph, and a
  switch one late frame (22 ms, or 58 ms when the photograph uploads).
  `044-plain-background.md`, `4d50eb2`
- 057: At rest on every platform. Done: the iPhone's 16% of a core at rest to 0.08%
  (`patches/goose_gfx/0007`, the wait in the run loop), the Mac's 8.2% to 0.03% (built
  with the patched gfx, `scripts/mac.py`), Windows 0.06%; the numbers in
  `docs/architecture/rendering.md`. `057-at-rest.md`, `4d50eb2`
- 063: The UI's shader made fast in itself. Done: three pipelines at 32 registers each,
  quads only as large as their shadows, glass and tiles shaded in parts; the UI's live
  cost on the Pixel 7a halved (0.61M → 0.30M GPU cycles a frame on the flat game), the
  3D game's live layers 1.54M → 0.99M; the glyph's interpolated atlas place tried and
  undone; the tablet's bench skipped (the user, 2026-11-10). `060-ui-shader.md` (numbered 060 before the remote's task 060), `eb31a17`
- 061: The code review's refactors. Done in five stages: `sizes` failing on any unlisted
  failure, the moves, one screen table with the game returning events, the panel's layout
  as regions with `gui::stack`, and the renderer seam (`app/host` for the platform,
  `app/render` owning the pass, C decoders returning pixels, `model3d` split out); every
  expected output byte-identical, the Mac's photograph load unchanged, and the Android
  release smoke-tested by hand on the Pixel 7a; the rest of the end measurement dropped
  (the user, 2026-11-11). `061-code-review-refactors/`, `3aeb9ea`
- 066: The tile under the mouse lit on a desktop. Done: a faint form of the chosen tile's
  glow (the glow at 8% and a 1 dp border at 40%; a lit tile's own glow 6% brighter),
  fading over the press's 0.12 s, never on Android or with `--touch on`; a resting mouse
  draws nothing (`test/gui/hover`, `test/shell/rest_hover`). `066-mouse-hover.md`, `6dfe01f`
- 045: Board styles to choose from. Cancelled 2026-11-13: folded into task 080's
  material, wood, stone, carved, or auto, one choice for every season.
  `045-board-styles.md`, `b317740`
