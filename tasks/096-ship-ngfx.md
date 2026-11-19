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
  (`MTL4CommandBuffer` and others). `scripts/ios.py` builds gfx alone for the Simulator.
- CI clones goose-ngfx's default branch, unpinned.
- Since the layout refactor, no release build, Windows or Linux build, or device run has
  been checked. The tablet check of goose_gfx `b8cd74b` is still open (task 010).

## Checked (2026-11-18)

- The ids, read from the built APK (`io.github.kaitk.draughts`) and the iOS Simulator's
  and release's `.app` (`io.github.kaitk.draughts.app`, named Draughts).
- The Mac (M1 Pro, macOS 26.3.1): `renderer: ngfx (auto)`, `--renderer gfx` on gfx, the 3D
  game drawn on ngfx. The iOS Simulator (iPhone 13 mini): gfx, the 3D game in portrait.
  The Pixel 7a: a build beside Play's (`--id-suffix check`, as Play's signature can't be
  installed over), first start and the 3D game.

- The release builds (0.9.1): the Mac's disk image signed, notarized, and stapled, every
  part built for macOS 13.3 and goose-ngfx's Metal 4 classes imported weakly (not started
  on a macOS older than 26: none at hand); the iOS `.ipa` (0.9.1, build 6) and Android's
  APK and AAB (version code 7), not uploaded.
- 2026-11-19: ngfx drew the glass light with dark text (its widget root lacked gfx's new
  Run block, shifting the theme by one), fixed in 27db1df. The Mac's 0.9.1 disk image on
  the release was swapped for one built from 4516be5, and the iOS `.ipa` (0.9.1, build 6)
  rebuilt from it; Windows still needs the same rebuild and swap.

## Windows and Linux releases

On Windows, with the Vulkan SDK, goose-ngfx beside the repository (or `NGFX`) on its
`main`, and slangc 2026.18.2 or later in `NGFX_SLANGC`:

1. `python scripts/windows.py --release`: the zip and the installer in
   `build/windows/release/`.
2. `build\windows\draughts_ngfx.exe --frames 10` prints `renderer: ngfx (auto: <GPU>|<driver>|0.9.1 <commit>)`,
   and `--renderer gfx` draws on gfx.
3. The installer over 0.9.0 keeps the settings; settings' About shows 0.9.1 and the commit.
4. `Get-FileHash -Algorithm SHA256` of both files, for `store/release-notes.md`.

On Linux, gfx alone:

1. `scripts/linux_release_docker.sh`, or `CC=clang-20 scripts/linux.py --release` in the
   `draughts-jammy` box: the newest glibc it needs is 2.35.
2. The tarball's `Draughts/draughts` starts on Wayland and with `SDL_VIDEO_DRIVER=x11`;
   settings' About shows 0.9.1 and the commit.
3. `sha256sum` of the tarball.

## Acceptance criteria

- [ ] Each platform script builds the shipped app with no program given, and with
      `--release`; `--gfx-only` and a program path work as above
- [ ] The decision recorded in `docs/decisions/` (it replaces "gfx ships everywhere"),
      with `docs/architecture/rendering.md`, README.md and `docs/development.md` matched
- [ ] Release builds made and run: macOS (signed and notarized), iOS (TestFlight),
      Windows, Android, Linux, each picking the renderer the table says
- [ ] Shipped ids unchanged: `io.github.kaitk.draughts`, `io.github.kaitk.draughts.app`
- [ ] Once everything else is done, checked on the Mac, in the iOS Simulator, and on the
      Pixel 7a over USB
- [ ] Version 0.9.1, released to the stores and the downloads
- [ ] The showcase post's renderer claims match what ships
