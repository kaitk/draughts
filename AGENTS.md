# Agent rules

This file holds what every session needs. `agents/` holds the rules for particular
work.

## Project context

- Product scope: `docs/product.md`
- Architecture decisions: `docs/architecture/`
- Task tracking: `tasks/` (see `tasks/README.md`)
- The language: `agents/goose.md` first, which sums up what writing Goose here needs;
  the pinned release's `build/goose-v2026.4-macos-arm64/docs/` for the rest. Write
  Goose the way the release's `samples/` and `stdlib/` do. goose-http (another Goose
  project by the same user) is a model for layout and tests.
- Toolchain, building, and running on the Mac and the tablet: `docs/development.md`
- UI prototypes: `prototypes/` (see `prototypes/README.md`), checked in a browser with the
  `agent-browser` CLI
- Gaps found in Goose or goose_gfx: `docs/goose-findings.md`. A gap that blocks us gets a
  patch in `patches/<package>/`, applied at build time to a copy of the sources (never in
  the submodule), with its findings entry saying what to propose upstream

Follow the recorded decisions. If a change contradicts one, update the doc in the same
change or ask first.

## Rules for particular work

Read the file a task touches before starting it, and add to it what the next session
would otherwise look up again:

- `agents/goose.md`: writing Goose, its traps and speed, and recording what it lacks
- `agents/writing.md`: docs, tasks, and prose; what goes in `docs/` and what only in
  `agents/`
- `agents/testing.md`: the tests, what each kind is for, and how to run them

## Code rules

- Nothing allocates in the frame loop. Per-frame data goes into arrays that are reset
  each frame or into fixed tables sized at startup.
- The app draws only when something changed (`docs/architecture/rendering.md`).
- No user-facing string literals in code; strings come from `strings/<lang>.txt`.
- Game rules are pure functions over value types, with no graphics, so they can be
  tested headless.
