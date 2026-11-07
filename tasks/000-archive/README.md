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
