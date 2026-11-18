# 096: Ship ngfx in 0.9.1

Status: todo

goose-ngfx is the reason the app has two renderers, but only gfx ships: every release
builds `src/main/draughts.goose`, and the scripts refuse `--release` with
`src/main/draughts_ngfx.goose`. Ship the program that holds both renderers where ngfx
runs, as 0.9.1, which also tests the layout refactor and the new goose_gfx pin
(task 010) in release builds.

## What ships where

| Platform | Ships | Why |
|---|---|---|
| macOS, iOS | both renderers | ngfx on Metal 4 (macOS/iOS 26, M1/A14 or newer), gfx otherwise |
| Windows | both renderers | ngfx with Vulkan 1.4, descriptor heap and mesh shaders, gfx otherwise |
| Android | gfx only | goose-ngfx has no Android build |
| Linux | gfx only | gfx measured faster there (task 065) |

The renderer is still picked at start, with the fallback to gfx and the crash marker as
now (`docs/architecture/rendering.md`, "Two renderers").

## The build scripts

Every platform script works the same way:

- With no program, it builds the app as it ships on that platform (the table above).
  `--release` builds the same thing.
- `--gfx-only` builds without ngfx, to compare the renderers or as a way out if ngfx
  breaks a release. Not `--gfx`: both builds hold gfx.
- A program path stays optional, for tools and benches (`scripts/mac.py tools/pace.goose`).

This replaces passing `src/main/draughts_ngfx.goose` (2026-11-18,
`docs/decisions/layout.md`). The app's ids from the sidecars' `output` and
`scripts/check_roots.py` stay.

## Known problems

- The iOS Simulator build of ngfx fails: the Simulator SDK lacks the Metal 4 types
  (`MTL4CommandBuffer` and others). The Simulator may have to run gfx only.
- CI clones goose-ngfx's default branch, unpinned.
- Since the layout refactor, no release build, Windows or Linux build, or device run has
  been checked. The tablet check of goose_gfx `b8cd74b` is still open (task 010).

## Acceptance criteria

- [ ] Each platform script builds the shipped app with no program given, and with
      `--release`; `--gfx-only` and a program path work as above
- [ ] The decision recorded in `docs/decisions/` (it replaces "gfx ships everywhere"),
      with `docs/architecture/rendering.md`, README.md and `docs/development.md` matched
- [ ] Release builds made and run: macOS (signed and notarized), iOS (TestFlight),
      Windows, Android, Linux, each picking the renderer the table says
- [ ] Shipped ids unchanged: `io.github.kaitk.draughts`, `io.github.kaitk.draughts.app`
- [ ] Version 0.9.1, released to the stores and the downloads
- [ ] The showcase post's renderer claims match what ships
