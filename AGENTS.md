# Agent rules

This file holds what every session needs. `agents/` holds the rules for particular
work.

## Project context

- Product scope: `docs/product.md`
- How the app works now, for people: `docs/architecture/`, with its front page
  `index.html` ("Draughts from above"); the design decisions, each dated with its reason
  and what it rejected, for contributors and agents: `docs/decisions/`, one file per
  area as the architecture has
- Task tracking: `tasks/` (see `tasks/README.md`)
- The language: `agents/goose.md` first, which sums up what writing Goose here needs;
  the pinned release's `build/goose-v2026.4-macos-arm64/docs/` for the rest. Write
  Goose the way the release's `samples/` and `stdlib/` do. goose-http (another Goose
  project by the same user) is a model for layout and tests.
- Toolchain, building, and running on the Mac and the tablet: `docs/development.md`
- Google Play: the listing, privacy policy, and Play Console answers in `store/`; release
  builds and the upload key in `docs/development.md`
- UI prototypes: `prototypes/` (see `prototypes/README.md`), checked in a browser with the
  `agent-browser` CLI
- Gaps found in Goose, goose_gfx, or goose-ngfx: `docs/goose-findings.md`, each entry
  saying what to propose upstream. A goose_gfx gap that blocks us is fixed in the user's
  fork, `kaitk/goose_gfx`: a branch of its own on upstream `main` (offered upstream one at
  a time) merged into the fork's `main`, which the `third_party/goose_gfx` submodule
  follows. One in SDL gets a patch in `patches/SDL/`, applied at build time to a copy of
  the sources

Follow the recorded decisions in `docs/decisions/`. If a change contradicts one, record
the new decision there, saying which it replaces, and update `docs/architecture/` to
match, in the same change, or ask first.

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
- Images: a few essential ones the app needs, of a few MB at most (the icon's layers),
  may go in git; large ones stay local, as design references, background originals, and
  PNG masters do (`agents/design.md`, `design/backgrounds/README.md`). Ask when unsure
  (2026-11-08). The season backgrounds' JPEG and ASTC files, which the app embeds (about
  9.7 MB), are in git (2026-11-10).
- Never edit the submodules' checkouts. A gap in goose_gfx goes to the fork's branches and
  `main`, then the submodule's pointer moves (above); for SDL, write only a note for the
  user, who decides about anything sent there.
- The user maintains goose-ngfx and contributes to Goose and goose_gfx. Snowtime, a
  public time tracker (github.com/Snowhound/snowtime), is the model for this repo's layout
  (AGENTS.md, docs/, tasks/ with an archive, prototypes/ checked with agent-browser) and
  for the UI's look.
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
