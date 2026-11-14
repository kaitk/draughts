# 077: ngfx's antialiasing on Apple, and NoGraphicsAPI on older systems

Status: in-progress (steps 1 and 3 done 2026-11-12, step 2 on the Mac; its Windows and
Linux runs are the user's)

ngfx exists in Draughts to show NoGraphicsAPI's author a real program on it and to back
the pull requests (task 073). Two gaps stood in the way on Apple: ngfx's 3D frame was
slower on the Mac, and NoGraphicsAPI wouldn't build for an app that also runs below macOS
and iOS 26.

## Done

1. **Where the Mac's gap is** (`scripts/mac_gpu_time.py`, M1 Pro, 3D full screen
   3600 × 2260, three rounds at the GPU's Maximum): without antialiasing ngfx takes 2.50
   ms a frame against gfx's 2.67, 6% less. The whole gap was SMAA (0.85 to 0.9 ms on
   either) against MSAA (0.35 ms on the tiled GPU), which NoGraphicsAPI lacked.
2. **MSAA in the NoGraphicsAPI fork** (`kaitk/NoGraphicsAPI` `msaa`, `b29bd71`, on
   upstream `ffd9f2a`; merged into the fork's `ngfx`, `6140850`): `TextureDesc` and the
   PSO descs' `sample_count` (1 or 4), `TextureUsage::transient` (memoryless on Metal,
   outside the heap and residency sets; `TRANSIENT_ATTACHMENT` on Vulkan), and
   `ColorAttachment::resolve_view`; `tests/msaa_test.cpp` passes on the M1 Pro under the
   validation layer. goose-ngfx `edb5072` (`TextureDesc.samples`, `TRANSIENT`,
   `PassDesc.resolve`, `test/ngfx_msaa`, all 36 tests passing); upstream's newer API came
   in with it (`0abb9f2`: roots padded to 16 bytes). Draughts `a2465e0`: `--aa msaa`, now
   ngfx's default (the user, 2026-11-12).
   - Shots against gfx's MSAA: within 11 of 255 but the rings' phase and the puzzle's
     noise (SMAA was up to 119 apart).
   - GPU time: ngfx MSAA 2.98 to 3.08 ms, gfx MSAA 2.99 to 3.00: 2% over gfx, 10% under
     its own SMAA. Where ngfx's extra 0.2 ms over its no-AA frame goes isn't known.
   - Memory while drawing, headless 1280 × 800: ngfx MSAA 179 MB, SMAA 195 to 197, gfx
     MSAA 181; alike at rest, where the targets are given back.
   - The Mac's `auto` stays gfx first (task 073).
3. **Building below 26** (the fork's `below-26`, `68a70eb`, in `ngfx` `3338bfb`;
   goose-ngfx `2adf0ff`): the Metal backend under a
   `#pragma clang attribute push` marking it available from 26, `create_device` calling
   it under `@available` and else returning `Error::unsupported`, and
   `-Wunguarded-availability-new` an error. Built at macOS 13 with no warning; an iOS 16
   probe has 12 weak Metal 4 imports and no strong one. The Simulator's SDK declares no
   Metal 4 types, so a Simulator build of Draughts leaves ngfx out. Decision:
   [decisions](../docs/decisions/README.md#the-stack). Not run on a system before 26
   (task 073).

## For the user: Windows (RTX 4090) and the Bazzite PC (RX 6800)

Ask before pushing the fork's `msaa` and `ngfx`, goose-ngfx's `main`, and Draughts'
`main`. Then on each machine:

1. **NoGraphicsAPI** at `msaa`: Windows `cmake --preset msvc`, `cmake --build --preset
   msvc-debug`, `ctest --preset msvc-debug` (Debug enables the validation layer); Linux
   built Debug in the `goose` box, run on the host. Pass: `test_msaa` with no
   `Validation Error`, the rest as on upstream `main`.
2. **goose-ngfx** at `edb5072`: `python scripts/run_tests.py` with
   `VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation`,
   `VK_KHRONOS_VALIDATION_REPORT_FLAGS=error,warn`, and `..._VALIDATE_SYNC=true` (Linux:
   `--aot --cc clang` in the box). Pass: all 36, `ngfx_msaa` printing 204 204 102 0.
3. **Draughts' ngfx build**: headless shots of the 13 screens on the 3D board at
   1280 × 800, `--frames 20000` (`agents/testing.md`), against gfx: within about 11 of
   255 as on the Mac; and task 073's Windows shot check in the same sitting.
4. **Benches**, three rounds interleaved: Windows `scripts/windows_perf.py` for gfx,
   ngfx, and ngfx `FLAGS="--aa smaa"`, against task 074 (does ngfx keep its 26 to 41%
   GPU-time lead with MSAA?); Bazzite on Wayland as task 076's table (does MSAA close
   RADV's 13% gap? That decides Linux's `auto`).

## Acceptance criteria

- [x] gfx traced with `--aa off` beside ngfx's, and what the gap is: the antialiasing
      alone
- [x] MSAA in the fork with memoryless (Metal) and transient (Vulkan) targets, its tests
      passing; the ngfx build's `--aa msaa` measured on the Mac against gfx's
- [ ] The same on Windows and Linux, run by the user (above)
- [x] NoGraphicsAPI builds below 26 and fails at run time there (an older system to
      check: task 073)
- [ ] `docs/goose-findings.md` and task 073 updated
