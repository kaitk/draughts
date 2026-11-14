# 073: One executable, the renderer chosen at run time

Status: in-progress (steps 1 to 3 on main; steps 4 and 5 on the branch `renderer-choice`
2026-11-12; step 6's device checks under way)

Bring task 065's ngfx renderer into main as one the app picks when it starts: ngfx where
the device has it, gfx everywhere else and on Android, and a flag to force either (the
user, 2026-11-11). The reason is NoGraphicsAPI's, not the app's: Draughts as a real
program on its API, to show its author and to back the pull requests
(`docs/goose-findings.md`). On the RTX 4090 ngfx takes 26 to 41% less GPU time a frame
and 54 to 74 MB less GPU memory (task 074), so `auto` on Windows is the case to get right
first.

## Done

1. **ngfx in main as a build option** (`088ca59`); the `ngfx` branch deleted.
2. **One copy of the drawing**: each drawer is what it draws plus a `_gpu` recorder per
   renderer ([decisions](../docs/decisions/README.md#the-codes-layout)); `src/ngfx/`
   holds only recorders and shaders (`cf7a17f` to `553a407`).
3. **The 2D shaders in one copy**: written from gfx's GLSL by
   `scripts/ngfx_2d_shaders.py` on `scripts/ngfx_glsl.py`, the hand ports deleted
   (`9b7de3d` to `ef185cf`). `down`, `mip`, and `smaa.slang` stay hand-written Slang.
   FXAA was removed (2026-11-12, the user: ugly, not worth its speed over SMAA).
4. **Both in one executable** (on `renderer-choice`, `3926908`, `c298f16`): gfx's
   recorders copied as `*_gfx`, ngfx's named `*_ngfx`, and a facade of each twin's name
   calling one or the other by `nx::ngfx_on` (`src/ngfx/render3d/nx.goose`). Apple links
   Metal 4 weakly through the NoGraphicsAPI fork's `below-26` (`f57ffae`), so macOS 13.3
   and iOS 16 still start. The executable is 17.9 MB against gfx's 15.4.
5. **Choosing** (`db88532`): `--renderer auto|gfx|ngfx`; Android is always gfx; the
   choice and why printed at start; no setting in the UI.
   - A check before any window: on Apple `__builtin_available(macOS 26, iOS 26)` and
     `supportsFamily:` Apple7 and Metal4; elsewhere the Vulkan loader at 1.4 and a device
     with the required extensions. Only a system that passes opens a hidden window for
     `ngfx::open`; if that fails everything closes and gfx opens its own window.
   - A marker beside the settings (`renderer-start.txt`), written before ngfx's device and
     removed at its first `present()`, keyed to the GPU, driver, and app version: a start
     that finds it picks gfx; an update or `--renderer ngfx` tries ngfx again.
     `DRAUGHTS_AUTO_NGFX=1` and `DRAUGHTS_RENDERER_TEST=fail|crash` exercise it.
   - `auto` by platform: ngfx first on Windows only; gfx first on the Mac and iOS (task
     077) and on Linux (task 076).

Checked on the Mac at every step: shots of the 13 screens flat and 3D against the builds
before (flat identical, 3D within 3 of 255 but the puzzle's 3D board's known noise);
`--bench 60` and `--rest 4` footprints unchanged within run-to-run spread. The tablet's
gfx-only APK: 3D `--bench 60` 9.34 ms waited P50, 94 fps. The iPhone 13 mini: `auto`
takes gfx, 3D P50 9.43 ms at 119.9 fps; `--renderer ngfx` 60 fps.

## Left

- **Windows (RTX 4090), the user**: `python scripts/ngfx.py src/app/draughts.goose`, then
  `build\ngfx\draughts.exe` alone (it should print `renderer: ngfx (auto: ...)`),
  `--renderer gfx`, and `DRAUGHTS_RENDERER_TEST=fail` (the marker is
  `%APPDATA%\kaitk\draughts\renderer-start.txt`, deleted after). Then
  `EXE=build/ngfx/draughts.exe FLAGS="--renderer ngfx" python scripts/windows_perf.py`
  and the same with `--renderer gfx`, against task 074's rows, and the 13 screens headless
  with each `--renderer` against main's builds.
- **The Bazzite PC (RX 6800), the user**: the same; `auto` says `gfx first on Linux`;
  `--renderer ngfx` on Wayland and with `SDL_VIDEO_DRIVER=x11`; `DRAUGHTS_AUTO_NGFX=1` for
  the Vulkan check and the hidden window; task 076's benches with each `--renderer`.
- An iOS 16 to 25 device or a Mac before 26: none at hand, so the old-system path is
  unchecked.
- The pull requests, one at a time, sent by the user (drafts in `build/notes/prs/`,
  local): NoGraphicsAPI's `linux-presentation`, then its MSAA branch; goose_gfx's
  `window-only-linux` after `window-only`.
- Merge `renderer-choice` into main once the user has seen it; the decisions,
  architecture, and README updated.

## Acceptance criteria

- [x] ngfx on main as a build option, the gfx build unchanged
- [x] The drawing in one copy, both renderers' shots as before
- [x] The 2D shaders generated from gfx's GLSL, the hand ports gone, ngfx's shots as
      before
- [ ] One executable per platform holding both renderers, starting on Apple systems
      without Metal 4 (built; the old systems unchecked)
- [ ] `--renderer auto|gfx|ngfx`, `auto` picking ngfx where it runs and gfx elsewhere,
      and gfx after a start that didn't reach its first frame on ngfx (built; Windows and
      Linux to check)
- [ ] Checked on the Mac, the iPhone, Windows, and an Android device, recorded here
- [x] The `ngfx` branch retired
- [ ] The decision and the architecture docs updated

## Later

- Extra ngfx downloads on each GitHub release, marked as for recent GPUs and drivers,
  until this task's one executable makes them unneeded. Not now (the user, 2026-11-12).
