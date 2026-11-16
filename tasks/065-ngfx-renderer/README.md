# 065: The NoGraphicsAPI renderer through goose-ngfx

Status: in-progress (on the `ngfx` branch; steps 1 to 7 on Windows, the Mac, and the
iPhone, 2026-11-11; goose-ngfx v0.5.0)

Draw Draughts through goose-ngfx (github.com/kaitk/goose-ngfx, NoGraphicsAPI over Metal 4
and Vulkan 1.4) on devices that have it: Apple silicon Macs, later iPads and iPhones, and
Windows and Linux GPUs with `VK_EXT_descriptor_heap`. In the end it is the main renderer
wherever it's supported, chosen at run time, with gfx (SDL_GPU) as the fallback and on
Android ([decisions](../docs/decisions/README.md), `docs/product.md` item 6). This task is
the prototype: a build-time choice on the `ngfx` branch. Draughts is ngfx's first real
user, so ngfx changes as Draughts needs, in its own repository, with a release when this
branch needs one. Task 065/01 carries it to main and to a run-time choice.

## Subtasks

- `01-renderer-choice.md`: one executable, the renderer chosen at run time (task 073
  until 2026-11-16)
- `02-uncapped-windows.md`: ngfx against gfx, uncapped, on Windows (task 074 until
  2026-11-16)
- `03-msaa-and-older-apple.md`: ngfx's MSAA on Apple and NoGraphicsAPI on older systems
  (task 077 until 2026-11-16)

## How it is built

- `scripts/ngfx.py` copies the program into `build/ngfx/tree/` and lays `src/ngfx/` over
  it (`host`, `render`, `scene`, `draw`, `widgets`, `photo.c`, `render3d`); `src/app/` is
  untouched. The package is a checkout (`NGFX`, slangc from `NGFX_SLANGC`).
- Shaders are compiled ahead into ngfx's blobs and embedded
  (`tools/ngfx_shaders.goose.in`); the 3D board's modules are written from
  `render3d/shaders.goose`'s GLSL at every build (`scripts/ngfx_3d_shaders.py`), so both
  builds keep one source. `mip.slang` makes sRGB mips, which ngfx's `generate_mips` can't.
- ngfx has no SDL: it takes the native window, and Draughts' gfx opens it `WINDOW_ONLY`
  (`patches/goose_gfx/0008-window-only.patch`) and keeps the input, time, and idle wait.
  In a window the screen is the drawable itself, so a window's screen can't be read back;
  shots are headless.
- NoGraphicsAPI has no MSAA, so the 3D pass is antialiased with SMAA 1x (`--aa
  off|fxaa|smaa|ssaa`, ngfx build only; `third_party/smaa/`, HIGH preset, luma edges).
  ASTC 6 × 6 comes from the user's NoGraphicsAPI fork (`astc-6x6`).
- iOS: `scripts/ios.py --device --ngfx`, iOS 26 minimum, installed under the gfx build's
  bundle id (a new id was refused offline). It needs three drawables, or the A15 locks
  to 30 fps.

## Results

Shots against the gfx build at the same flags (3D at `--frames 20000`): flat cases
identical or within 1 of 255; the 3D board with SMAA within 0.14 to 0.41 of 255 on
average, along the board's edges and in the wood's grain. Nothing drawn at rest on any
platform. The one Windows executable imports only `vulkan-1.dll` beyond Windows' own.

SMAA against the other modes on Windows (RTX 4090, 2560 × 1440, mean difference from gfx's
4× MSAA on the board's edges, wood):

| `--aa` | edges / rest | GPU busy P50, whole frame | pass targets |
| --- | --- | --- | --- |
| gfx 4× MSAA | 0 / 0 | 2.02 ms | 88 MB |
| off | 4.58 / 0.07 | 1.90 ms | 7 MB |
| fxaa | 4.40 / 0.36 | 2.13 ms | 22 MB |
| smaa | 3.74 / 0.12 | 2.25 ms | 44 MB |
| ssaa | 3.63 / 0.94 | 2.65 ms | 88 MB |

On the M1 Pro supersampling costs about 1.8 ms over `off` against SMAA's 1.0 to 1.3.

Frames: every build presents at the display's rate on Windows (165 Hz), the Mac (120 Hz),
and the iPhone (60 Hz). Footprint at rest after ngfx's memory work (pools sized from use,
the screen into the drawable, the Metal 4 command allocators remade when idle):

| Footprint at rest | flat | 3D |
| --- | --- | --- |
| Mac, ngfx (window, 1280 × 800) | 118 MB | 315 MB |
| Mac, gfx | 115 MB | 358 MB |
| iPhone 13 mini, ngfx | 42 MB | 204 MB |
| iPhone 13 mini, gfx | 59 MB | 204 MB |

Since the screen is the drawable, ngfx's waited and CPU times on the bench include the wait
for a free drawable, so they aren't comparable with gfx's (`agents/testing.md`).

## Pull requests to open (the user, later)

- `aardappel/goose_gfx`, from `kaitk/goose_gfx`: `no-clip-distance`, `draw-on-demand`,
  `screen-without-depth`, `compressed-textures` (each on upstream `main`);
  `msaa-resolve-without-store` (after `screen-without-depth`); `end-on-device-lost` and
  `ios-run-loop-wait` (after `draw-on-demand`); `window-only` (after `ios-run-loop-wait`).
  Added 2026-11-12: `no-vsync-immediate` on `main`, `gamepad-wake` (task 072),
  `window-only-linux` (task 010/01). Once merged, Draughts drops the patches.
- `sebbbi/NoGraphicsAPI`, from `kaitk/NoGraphicsAPI`: `astc-6x6` (`03a36c3`).

## Left

- Upstream NoGraphicsAPI's `ffd9f2a` (roots need a 16-byte stride) into the fork and ngfx.
- Windows at goose-ngfx v0.5.0: its window and present changed since v0.3.0.
- ngfx on an iPad and the simulator; presenting on Linux (task 010/01).
- SMAA in the gfx build in place of 4× MSAA, if the tablet's numbers favour it.
- Displays over 60 Hz on iOS need `CADisableMinimumFrameDurationOnPhone`, and
  `ios_perf.py`'s `HZ = 60` should read the display's rate.

## Acceptance criteria

- [x] goose-ngfx at Goose v2026.4 and released (v0.3.0), its tests and samples passing on
      the PC and the Mac
- [x] `scripts/ngfx.py` builds Draughts on ngfx on Windows and the Mac, with the gfx build
      unchanged
- [x] Every screen, the flat board, and the 3D board drawn by ngfx, compared against the
      gfx build at the same flags, on the PC and the Mac
- [x] Nothing drawn while idle; shaders built ahead, no Slang or Vulkan SDK at run time;
      ASTC on the Mac
- [x] Frame time against the gfx build on the PC and the Mac, recorded here
- [x] What ngfx gained recorded in its own docs, and gaps in Goose in
      `docs/goose-findings.md`
