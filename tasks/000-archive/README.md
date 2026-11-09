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
