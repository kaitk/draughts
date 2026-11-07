# Agent rules

## Project context

- Product scope: `docs/product.md`
- Architecture decisions: `docs/architecture/`
- Task tracking: `tasks/` (see `tasks/README.md`)
- The language: the pinned release's `build/goose-v2026.4-macos-arm64/docs/`: read
  `tutorial.md` before writing Goose, look things up in `reference.md` (every feature
  with a compiling example), check `goose_spec.md` before assuming a feature exists, and
  `stdlib.md` for the library. Write Goose the way the release's `samples/` and
  `stdlib/` do. goose-http (another Goose project by the same user) is a model for
  layout and tests: one program per test under `test/<area>/`, its output checked
  against `test/expected/<name>.out`, batched with `goose --multi-test`
- Toolchain, building, and running on the Mac and the tablet: `docs/development.md`
- UI prototypes: `prototypes/` (see `prototypes/README.md`), checked in a browser with the
  `agent-browser` CLI
- Gaps found in Goose or goose_gfx: `docs/goose-findings.md`. A gap that blocks us gets a
  patch in `patches/<package>/`, applied at build time to a copy of the sources (never in
  the submodule), with its findings entry saying what to propose upstream

Follow the recorded decisions. If a change contradicts one, update the doc in the same
change or ask first.

## Writing

- Lead with the decision, behavior, or action, then explain why. Use concrete facts and
  cut filler.
- Record a decision in `docs/architecture/` with its reason, and what was rejected when
  that matters. Keep each fact in one place and link to it elsewhere. Use absolute dates.
- Tasks follow `tasks/README.md`, with concrete acceptance criteria. Use sentence-case
  headings, backticks for identifiers and commands, and wrap prose at about 90 characters.

## Code rules

- Nothing allocates in the frame loop. Per-frame data goes into arrays that are reset
  each frame or into fixed tables sized at startup.
- The app draws only when something changed (`docs/architecture/rendering.md`).
- No user-facing string literals in code; strings come from `strings/<lang>.txt`.
- Game rules are pure functions over value types, with no graphics, so they can be
  tested headless.
