# Prompt: task 065 on iOS and iPadOS

Paste this into a fresh session on the Mac, then delete this file in that session's first
commit.

---

Continue task 065 (`tasks/065-ngfx-renderer.md`) on the `ngfx` branch: Draughts on
goose-ngfx on iOS and iPadOS, on the iPhone 13 mini (A15, iOS 26), which is connected.
Read the task's Progress from "2026-11-11, on the Mac" on, "Pull requests to open", and
"Later", then `AGENTS.md`'s files for the work (`agents/goose.md`, `agents/testing.md`,
`docs/development.md`, "Run on iOS"). Work through it without stopping to ask; commit
each step as AGENTS.md says.

Where things are:

- goose-ngfx is at v0.4.0 (`~/projects/goose/goose-ngfx`, `main`): no SDL, drawing into
  a native window it is given (`ngfx::open(window, w, h, flags)`, `present(force)`,
  `resize`), memory sized from use, ASTC 6 × 6. Build with `NGFX` set to that checkout
  and `NGFX_SLANGC` to `~/projects/goose/slang/bin/slangc` (`scripts/ngfx.py`).
- The window, input, and events are gfx's, opened `WINDOW_ONLY`
  (`patches/goose_gfx/0008-window-only.patch`), which gives a `CAMetalLayer` from an SDL
  Metal view; `src/ngfx/app/host.goose` uses it. The patch was tried on macOS only:
  UIKit's Metal view, rotation (`patches/SDL/0006`), the safe area, and the run-loop wait
  (`0007`) are new ground.
- NoGraphicsAPI is the fork `kaitk/NoGraphicsAPI`, branch `ngfx`, in goose-ngfx's
  `third_party/NoGraphicsAPI`; its `docs/building.md` has the iOS CMake. ngfx has no iOS
  build yet.
- If another session holds the main checkout on `main`, work in a worktree of `ngfx`
  (the last session's was in its scratchpad, with `build/goose-v2026.4-macos-arm64` and
  `third_party/goose_gfx` linked in and the backgrounds' masters copied).

Steps:

1. **goose-ngfx for iOS.** Its CMake building NoGraphicsAPI and the layer for iOS 26
   (arm64, the device; the simulator only if Metal 4 runs there), its two shaders and
   every metallib compiled for the iOS SDK (`xcrun -sdk iphoneos metal`; macOS
   metallibs don't load on iOS). Changes go in goose-ngfx, released as v0.4.1 or v0.5.0
   with what was tested.
2. **Draughts' iOS build on ngfx.** `scripts/ios.py` and `ios/CMakeLists.txt` building the
   ngfx tree (`scripts/ngfx.py`'s) with the patched gfx and ngfx, the app's shaders as
   iOS metallibs, ASTC photographs as on the gfx build. Signing and installing as
   `docs/development.md` and the session's memory say (the paid team; each signing asks
   for the user's password, so build and install while they're there, and relaunch with
   `devicectl` after).
3. **On the iPhone:** home, the flat game, the 3D board settled, settings, rotation,
   going to the background and back, at rest (no frames drawn, CPU), memory, and frame
   time against the gfx build (`scripts/ios_perf.py`), into the task. Short shot lists:
   only what the Mac can't tell.
4. **iPadOS** if an iPad is at hand; otherwise its layouts headless on the Mac as task
   050 did, and say so.
5. Record what ngfx gained in its docs, gaps in `docs/goose-findings.md`, and what's left
   in the task. The pull requests stay the user's.

Notes from the Mac session that aren't in the docs:

- `goose run` of an ngfx program prints objc warnings of every SDL class twice: the
  compiler's built-in gfx and the fetched one. Built programs have one SDL.
- `block` and `pad` are keywords in Goose; zsh arrays start at 1; `git cherry-pick` has
  no `-q`.
- An ngfx failure (`ngfx_fail`) is kept for `ngfx::error()` and never printed: when a
  texture or pass comes back empty, print the error to find why.
