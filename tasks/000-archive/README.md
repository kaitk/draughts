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
