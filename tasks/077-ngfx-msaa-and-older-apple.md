# 077: ngfx's antialiasing on Apple, and NoGraphicsAPI on older systems

Status: todo

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
2. **MSAA in the NoGraphicsAPI fork** (`kaitk/NoGraphicsAPI`, a branch of its own on
   upstream `main`, merged into the fork's `ngfx`): a sample count in `TextureDesc`, a
   resolve target per color attachment when a pass ends, on Metal 4 and Vulkan. On Metal
   the multisampled target memoryless (`MTLStorageModeMemoryless`), so it never leaves
   tile memory, which gfx can't have (SDL picks the storage mode, rendering.md's GPU
   memory); on Vulkan a transient, lazily allocated image. Then goose-ngfx's
   `TextureDesc` and `PassDesc`, and `--aa msaa` in the ngfx build (render3d's ngfx
   recorder: the pass at 1x into the 4× target, resolved into the image; SMAA's targets
   not made). Its tests on the Mac and the Bazzite PC. Measured as step 1, against gfx's
   MSAA, with the GPU memory at rest; if it wins, MSAA becomes ngfx's default as gfx's.
   A pull request candidate: a missing feature with a measured gain.
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

## Acceptance criteria

- [ ] gfx traced with `--aa off` and `smaa` beside ngfx's, the numbers here, and what the
      gap is
- [ ] MSAA in the fork with memoryless (Metal) and transient (Vulkan) targets, its tests
      passing; the ngfx build's `--aa msaa` measured on the Mac against gfx's
- [ ] NoGraphicsAPI builds below 26 and fails at run time there, checked as above
- [ ] `docs/goose-findings.md` and task 073 updated
