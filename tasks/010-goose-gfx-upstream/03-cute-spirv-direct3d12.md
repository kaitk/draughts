# 010.03: Direct3D 12's HLSL from cute_spirv, and the first instance

Status: in-progress (Direct3D 12 draws as Vulkan does on the `direct3d12` branch; the
cute_spirv patch not sent)

On Direct3D 12 on AMD, Goose's shaders that use storage buffers draw nothing or collapse,
and one that names a local `line` stops the app. Both causes are in cute_spirv's HLSL
(`docs/goose-findings.md`, both entries proven on 2026-11-18). One patch fixes both. It
goes to cute_framework, which owns cute_spirv, and Goose then copies the header again, as
its `third_party/cute_spirv/README.md` says. A third difference, the draw's first
instance, broke Draughts' widgets there; the branch fixes it in Draughts.

Windows draws through Vulkan and there is no plan to ship Direct3D 12, so the Draughts
side lives on the `direct3d12` branch, not `main`: the widgets' change, both patches in
`patches/goose/` and `patches/cute_framework/`, and how to build it in
`docs/development.md` ("Direct3D 12"). Merge `main` into it now and then.

## The cute_spirv patch

- cute_spirv v1.11 is one file in all three places: Goose v2026.4, Goose's upstream
  `master` (`745901fd`), and cute_framework `master` (`6b00978`, the header unchanged since
  `a5c53e4`). The patch applies cleanly to both upstreams.
- Storage buffers become `(RW)ByteAddressBuffer`. Each read calls a per-buffer loader that
  reads the element at its std430 offsets. Each write (assignment, compound assignment,
  `++`/`--`, atomic) calls a helper of its own, and `.length()` is bytes over the stride.
  A write used as a value, an element as an `out`/`inout` argument, and a swizzle followed
  by a subscript are compile errors.
- Names FXC rejects (keywords, scalar/vector/matrix type names) and user functions named
  like an intrinsic the printer emits (`lerp`, `frac`, `mul`...) gain a trailing `_` in
  the HLSL only, as the WGSL backend does.
- Where it is: on the `direct3d12` branch,
  `patches/cute_framework/0001-cute-spirv-direct3d12.patch`
  (the header and 38 checks added to `tools/cute_spirv_test.c`) and
  `patches/goose/0001-cute-spirv-direct3d12.patch`. In `~/projects/goose/goose`, the local
  branch `hlsl-byteaddress-ssbo` (`a66a8fb7`, on v2026.4).
- cute_framework's own `SDL_GPU` path compiles this HLSL with FXC on Direct3D 12
  (`src/cute_graphics_sdlgpu.cpp`), which SDL tries before Vulkan on Windows, so its
  storage buffers (`test/test_compute.cpp`) should break the same way on AMD. That comes
  from reading its code; cute_framework itself wasn't built or run.

## The first instance

`gl_InstanceIndex` comes from `SV_InstanceID` in the HLSL, which leaves out the draw's
first instance; Vulkan's includes it. SDL's `SDL_gpu.h` calls `first_instance` unportable
with built-in IDs. `widgets_gpu::run` draws each run of quads with
`gfx::draw(6, count, 0, first)`, so on Direct3D 12 every run after the first reads the
first run's quads: words cut short ("Dra" for "Draughts"), icons as solid squares.
`gl_VertexIndex` with a first vertex is the same case. Two fixes, either or both:

- Draughts (done on the branch, `150b893`): each run draws from instance 0, and its first
  quad comes in a vertex uniform (`QuadRun`) that the shader adds. The 2D pieces draw
  from 0 already, and the 3D board passes its offset in `draw.w`. It is portable on every
  backend, so `main` could take it whenever it likes.
- goose_gfx/Goose: a hidden uniform with the first instance and vertex that cute_spirv's
  HLSL adds to the IDs (SPIRV-Cross's `SPIRV_Cross_VertexInfo`), or reject a nonzero first
  instance on Direct3D 12, or document it in `gfx.goose`. Raise it as an issue first.

## Measurements (Radeon 680M, driver 32.0.21045.16010, Windows 11 26H2, 2026-11-18)

- goose_gfx's showcase on Direct3D 12: 3 of 12 checks failed, 30 to 32 per channel from
  Vulkan. With the five SSBO shaders hand-edited to `ByteAddressBuffer`: 12 of 12,
  0.46 to 0.48. With the patched Goose: 12 of 12 on both drivers, 0.48 apart.
- A compute test of struct elements (stores, compound ops, `++`, every atomic): every
  thread's writes landed on element 0 with the release; 50 of 50 lines match Vulkan with
  the patch.
- The debug layer printed nothing: the core layer doesn't check a shader's buffer type
  against its view, and SDL doesn't turn on GPU-based validation.
- Goose's suite, default driver (Direct3D 12 here), JIT runs only (Goose's toolchain
  found no Visual Studio): the release fails `gfx_compute` and `gfx_render`; the patched
  compiler passes all.
- cute_framework's transpiler tests: 1506 checks before and after; with the new tests 1544
  pass, and 24 fail on the unpatched header.
- Draughts with the patched Goose, Direct3D 12 against Vulkan, mean per channel: flat
  board 1.62 (8.62 with the release), 3D board 4.40 (11.73), with MSAA 4.35 (13.86), About
  3.45 (20.32). What remains is the first instance. Bench windowed, 300 frames:
  Direct3D 12 639.8 fps average against Vulkan's 626.7; full screen 181.9 against 167.6;
  `--rest 10` 0.0% CPU on both. FXC still takes about 4 s at each launch.
- With the widgets' fix too (the branch): Direct3D 12 against Vulkan, mean per channel,
  flat board 0.00, 3D board 2.30, with MSAA 1.11, About 0.29; the largest single
  difference 1, 18, 15, and 16 of 255, spread thinly over the photograph and the board,
  with no pixel off by more than 32. Vulkan against the release's build: 0.00, 0.03,
  0.49, 0.13. Bench windowed: Direct3D 12 693.7 fps against Vulkan's 641.1; full screen
  183.9 against 174.3; `--rest 10` 0.3% CPU on both. Draughts' tests pass.
- Screenshots and logs: `build/notes/showcase/`, `build/notes/patched/`,
  `build/notes/branch/` (local).

## Acceptance criteria

- [ ] The cute_framework pull request sent (the user sends it), with the patch, its tests,
      and the measurements above
- [ ] Once merged: Goose's `third_party/cute_spirv` copied again with its README's commit,
      offered to Goose
- [x] The first instance: Draughts' widgets made portable (on the branch)
- [ ] A goose_gfx issue raised about the first instance and vertex on Direct3D 12
- [x] Draughts on Direct3D 12 matches Vulkan on every screen (flat, 3D with and without
      MSAA, About), checked on the Radeon 680M (on the branch, with the patched Goose)
- [ ] `docs/goose-findings.md` updated as each lands
