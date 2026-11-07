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
