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
- `agents/design.md`: the look's reference images (local, not in git), how the user makes
  images, how to check a look against them, and what was tried and set aside

## Working with the user

- Commit each finished step with one lean sentence: no body, no `Co-Authored-By` or other
  trailers. Don't push unless asked.
- Don't add images to git without asking. Design references, background originals, and
  masters stay local (`agents/design.md`, `design/backgrounds/README.md`).
- Never edit the submodules. A gap in Goose or goose_gfx gets a patch and a findings entry
  (above); for SDL, write only a note for the user, who decides about anything sent there.
- The user maintains goose-ngfx and contributes to Goose and goose_gfx. Snowtime
  (github.com/Snowhound/snowtime) is the model for this repo's layout (AGENTS.md, docs/,
  tasks/ with an archive, prototypes/ checked with agent-browser) and for the UI's look.
- Code is lean and game-like, in the spirit of Carmack and Sebastian Aaltonen: flat data,
  fixed buffers, no allocation in hot paths, nothing clever without a measured reason.
- Check a change that shows on screen on the Mac and then on the tablet over USB
  (`docs/development.md`), and record the numbers a task measures in its file.
- Subagents: Sonnet for searches and mechanical work, the default model for judgment.

## Code rules

- Nothing allocates in the frame loop. Per-frame data goes into arrays that are reset
  each frame or into fixed tables sized at startup.
- The app draws only when something changed (`docs/architecture/rendering.md`).
- No user-facing string literals in code; strings come from `strings/<lang>.txt`.
- Everything is in English: code, identifiers, docs, prototypes, and the app's default
  language. The app is called Draughts. Estonian is a translation, a file in `strings/`
  like any other language, never the default or a name in the code (2026-11-07).
- Game rules are pure functions over value types, with no graphics, so they can be
  tested headless.
