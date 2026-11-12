# 077: ngfx's antialiasing on Apple, and NoGraphicsAPI on older systems

Status: in-progress (step 1 done 2026-11-12)

ngfx exists in Draughts to show NoGraphicsAPI's author a real program on it and to back
the pull requests (task 073, the user, 2026-11-12). Two gaps stand in the way on Apple.

**ngfx's 3D frame is slower on the Mac, and it looks like the antialiasing.** Task 070's
Metal System Trace, 3D board full screen on the M1 Pro, GPU ms a frame: gfx with 4× MSAA
3.05, ngfx with SMAA 3.47 (+14%), ngfx with none 2.58. On Apple's tiled GPUs MSAA's
samples stay in tile memory and are resolved as each tile is stored, so it costs little;
SMAA is three more full-screen passes, each storing a target (about 0.9 ms at
3600 × 2260). NoGraphicsAPI has no MSAA (`docs/goose-findings.md`). A second suspect:
gfx's encoders overlap about × 1.3 in the trace, ngfx's × 1.05; the per-pass barrier
was ruled out (task 070).

**NoGraphicsAPI won't build for an app that also runs below macOS and iOS 26.** Its
`CMakeLists.txt` stops a deployment target under 26 ("The Metal 4 backend requires macOS
or iOS 26 or newer"), while Draughts runs on iOS 16 (`scripts/ios.py`'s `MIN_IOS`), which
blocks task 073's step 4 on Apple. It already fails at run time on a GPU without Metal 4
(`supportsFamily:MTLGPUFamilyMetal4` in `NoGraphicsAPIMetal.mm`'s device creation,
returning `Error::unsupported`), so the OS is the only thing the build-time stop adds.

## Steps

1. **The missing comparison** (first: it says whether 2 is the whole answer). Trace gfx
   with `--aa off` and `--aa smaa` on the Mac, as task 070 traced ngfx: full screen,
   `--bench 300 --no-vsync`, the 3D game (Russian, wood, the start), `xctrace` Metal
   System Trace, three traces each, interleaved with ngfx's `off` and `smaa`, at the
   GPU's Maximum state; the loop's frames' GPU union and the overlap. If gfx's off and
   SMAA match ngfx's, the renderers cost the same and MSAA is the gap. The runs take the
   screen: one batch, the user told first (memory: Mac shots in one batch).
2. **MSAA in the NoGraphicsAPI fork** (`kaitk/NoGraphicsAPI`, a branch `msaa` of its own
   on upstream `main`, merged into the fork's `ngfx`, which goose-ngfx's submodule
   follows). What its API has today (`include/NoGraphicsAPI/NoGraphicsAPI.hpp`):
   `TextureDesc` has no sample count; textures are placed in a `TextureHeap`
   (`create_texture(commands, desc, heap, offset)`); `ColorAttachment` and
   `DepthAttachment` take a load and a store op (`StoreOp` store or discard), no resolve;
   the raster pipeline's desc names its color and depth formats but no sample count. So:
   - `TextureDesc::sample_count` (1, 2, 4), checked against the device's caps
     (`DeviceCaps` gains the supported counts).
   - Transient attachments: a `TextureUsage` bit (or `MemoryType`) for a target that is
     never stored. Metal can't place a memoryless texture in an `MTLHeap`, so it is
     made from the device with `MTLStorageModeMemoryless`, outside the heap; on Vulkan
     `TRANSIENT_ATTACHMENT` usage in `LAZILY_ALLOCATED` memory where the device has it
     (desktop GPUs mostly don't: then ordinary device memory). Decide the shape so it
     reads as NoGraphicsAPI's style (its `docs/` and `AGENTS.md` first).
   - A resolve: `ColorAttachment::resolve_view` and a `StoreOp::resolve` (Metal 4's
     `MTLStoreActionMultisampleResolve` with a resolve texture; Vulkan dynamic
     rendering's `resolveImageView` with `VK_RESOLVE_MODE_AVERAGE_BIT`); depth stored
     or discarded, no depth resolve needed here.
   - The pipeline's sample count, on both backends.
   - Tests beside its others (a 4× clear-and-resolve, a triangle edge resolved to a
     known value), run on the Mac and on the Bazzite PC (task 076's way: built in the
     `goose` box, run on the host).
   Then goose-ngfx: `TextureDesc`'s samples, a transient render target, and `PassDesc`'s
   resolve; its tests and a sample. Then the ngfx build's `--aa msaa`
   (`src/ngfx/render3d/render3d_gpu.goose`): the pass drawn at 1x into a 4× color and
   depth, both transient, resolved into the image, as gfx's recorder does
   (`src/render3d/render3d_gpu.goose`, its kept depth and the pulsing marks included);
   SMAA's targets not made. Shots against gfx's MSAA (a few levels of 255 apart at most
   at the edges, the two resolving alike), then measured as step 1 (Metal System Trace,
   the loop's frames, three traces each, interleaved with gfx's MSAA), with the GPU
   memory at rest. If ngfx's MSAA frame is at or under gfx's, it becomes ngfx's default,
   as on gfx; the A key and `--aa` take `msaa`. Windows and Linux measured by the user
   (`scripts/windows_perf.py`, task 076's benches). A pull request candidate: a missing
   feature, with a measured gain on a tiled GPU.
3. **Building below 26 in the fork** (a branch of its own; offered upstream only if it
   reads as useful beyond Draughts, the user's call): `CMakeLists.txt` takes a deployment
   target under 26, with a comment why (the app checks at run time); device creation
   returns `Error::unsupported` unless `@available(macOS 26, iOS 26, *)`; the Metal 4 code
   marked `API_AVAILABLE(macos(26), ios(26))` so `-Wunguarded-availability` proves
   nothing reaches it before the check. The linker weak-links Metal 4's classes. Checked:
   built at iOS 16 and macOS 13, the tests pass on macOS 26, and a binary run on an older
   system (or the oldest Simulator runtime at hand) gets `unsupported` rather than a
   missing-symbol crash at launch. This is Apple's own pattern, in place of a separate
   library loaded only on 26 (an embedded framework on iOS, signed and opened by name).
   It decides task 073's step 4 on Apple; record it there and in `docs/decisions/`.

## Step 1: done (2026-11-12)

gfx and ngfx at `main` (`b499e73`, goose-ngfx `82517d6`), the M1 Pro on mains power,
`scripts/mac_gpu_time.py` (new: the trace, the loop phase, the union, the overlap),
three rounds interleaved, every run at the GPU's Maximum state for 90 to 98% of the
window. GPU ms a frame, the 3D board full screen (3600 × 2260):

| build | ms a frame | overlap |
|---|---|---|
| gfx, off | 2.70 / 2.64 / 2.66 | × 1.29 to 1.37 |
| ngfx, off | 2.49 / 2.51 / 2.49 | × 1.04 |
| gfx, 4× MSAA (its default) | 3.01 / 3.00 / 3.02 | × 1.35 |
| ngfx, SMAA (its default; task 071) | 3.35 to 3.39 | × 1.07 |
| gfx, SMAA (task 071) | 3.47 to 3.50 | × 1.35 |

gfx's MSAA matches task 070's 3.05, so the script reads as task 070's one-offs did.

- **The renderers:** ngfx draws the same frame in 6% less GPU time (2.50 against 2.67),
  and with SMAA on both 3% less. Nothing in ngfx itself is slower on the Mac.
- **The whole gap is the antialiasing:** MSAA costs gfx 0.35 ms a frame on the tiled
  GPU, SMAA costs either renderer 0.85 to 0.9. ngfx is slower at the defaults only
  because NoGraphicsAPI has no MSAA. If ngfx's MSAA costs what gfx's does, its frame
  comes to about 2.85 ms, 5% under gfx's; memoryless targets may take it lower.
- **The overlap** (gfx's encoders running alongside each other, × 1.3, ngfx's hardly)
  isn't a cost: ngfx is faster without it. Nothing to chase there.

## Acceptance criteria

- [x] gfx traced with `--aa off` beside ngfx's (`smaa` from task 071), the numbers here,
      and what the gap is: the antialiasing alone
- [ ] MSAA in the fork with memoryless (Metal) and transient (Vulkan) targets, its tests
      passing; the ngfx build's `--aa msaa` measured on the Mac against gfx's
- [ ] NoGraphicsAPI builds below 26 and fails at run time there, checked as above
- [ ] `docs/goose-findings.md` and task 073 updated
