# Prompt: task 065 on the Mac

Paste this into the Mac session, then delete this file in that session's first commit.

---

Continue task 065 (`tasks/065-ngfx-renderer.md`) on the `ngfx` branch, on the Mac (M1 Pro,
Metal 4), and then on iOS and iPadOS. The Windows half is done; read the task's Progress,
"Left for the Mac", and "Questions from higher up" first, then `AGENTS.md`'s files for the
work (`agents/goose.md`, `agents/testing.md`, `docs/development.md`). Work through it
without stopping to ask; commit each step as AGENTS.md says.

1. **goose-ngfx v0.3.0 on Metal 4.** In the goose-ngfx checkout beside this repo, at tag
   `v0.3.0`: its tests (all 40 passed on Windows with clang-cl, `--aot`, and MSVC) and
   samples on the Mac. Fix what fails in goose-ngfx itself (it is ours; its own AGENTS.md
   rules), then update the release notes' Mac line, or release v0.3.1 if code changed.
2. **Draughts on ngfx on the Mac.** `scripts/ngfx.py` on macOS, every Slang module to a
   metallib: the 3D board's, `src/ngfx/shaders/smaa.slang` (SMAA's own HLSL through its
   porting macros, never compiled to MSL yet), and `fxaa.slang`. Shots of every screen
   against the Mac's gfx build at the same flags, 3D ones settled (`--frames 20000`), with
   `--aa off|fxaa|smaa|ssaa`; then in a window. The Windows comparison scripts were
   throwaway; `agents/testing.md` says how shots and windows were driven.
3. **ASTC** in ngfx's textures (gfx's patch 0004 does it for gfx), so the seasons'
   photographs load as ASTC 6 × 6 on Apple silicon as in the gfx build.
4. **The numbers**: `--bench` and `--rest` of both builds, flat and 3D, footprint at rest,
   and each `--aa` mode's GPU time, into the task's table form. On the M1 Pro
   supersampling's four times the shading should cost more than on the PC.
5. **iOS and iPadOS**: ngfx built for iOS 26 (NoGraphicsAPI's `docs/building.md` has the
   CMake for it; metallibs compiled for the iOS SDK, since macOS ones don't load there),
   then Draughts' `ios/` build on ngfx, on a device with an A14 or M1 or newer.
6. **Look at it from higher up**, before building more on it, and write what you find
   into the task (and ngfx's docs or decisions where it is theirs):
   - The ngfx build holds about 37 MB more than gfx's at rest on Windows in every `--aa`
     mode, so it isn't the antialiasing. Measure where it goes (the Mac's unified memory
     makes it plain): the fixed sizes in goose-ngfx's `native/ngfx_gpu.hpp` (16 MB frame
     memory per frame in flight, 32 MB upload queue, 64 MB buffer and texture chunks, the
     descriptor heaps), the screen copy, and what the driver keeps. Read how
     NoGraphicsAPI's own examples and utility allocators size memory, since it leaves
     that to the application, and decide whether ngfx should size it from what the
     program asks for. These are ngfx's sizes, so they change in goose-ngfx; NoGraphicsAPI
     needs a fork only if something of its own stands in the way.
   - Why ngfx has SDL at all: NoGraphicsAPI takes a native window (`HWND`, a
     `CAMetalLayer`). ngfx copied gfx's platform half over its own SDL3, which keeps both
     renderers out of one executable. Weigh ngfx taking the window from the program (one
     SDL, the app's, for both renderers, and the run-time choice the task's "Later"
     wants) against ngfx linking the program's SDL, and say which and why.
   - Whether the gfx build should take SMAA in place of 4× MSAA too (half the targets'
     memory on the PC; measure on the Mac and the tablet first). The user's decision.

Notes from the Windows run that aren't in the docs:

- A headless run draws thousands of frames a second, so the 3D board, which ngfx
  prepares more slowly, is still fading in after a few hundred frames: compare 3D shots
  at `--frames 20000`, or the two builds differ in ways that aren't real.
- Back up the app's settings before driving it in a window, and put them back after;
  the clicks change them.
- The SMAA area and search tables are raw bytes made from SMAA's headers
  (`third_party/smaa/README.md`); `scripts/ngfx.py` copies them next to the shaders.
- The user maintains goose-ngfx: a gap in it gets fixed there, not patched here.
