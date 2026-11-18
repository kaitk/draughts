# 02: SDL's pull requests and issues

Status: todo (after the goose_gfx branches)

SDL's `CLAUDE.md` asks that no AI-written code or text go into its reports or pull
requests, so the user writes and sends each; a session only checks a newer SDL first and
keeps this list. Each was still in SDL `main` on 2026-11-18 (release 3.4.20; we pin
3.4.16). Details and numbers in `docs/goose-findings.md`.

## Pull requests, easiest first

1. Mips of a non-square texture: `VULKAN_GenerateMipmaps` blits the last levels at zero
   size; clamp each axis with `SDL_max(1, ...)`, as the copy path does. No patch here
   (`render3d::baked` stops at the shorter side's 1 pixel); the A33 loses the device.
2. `0001` the swapchain leaked on every Android resume (28.4 MB each).
3. `0004` a size change in the background leaves the window black.
4. `0006` a rotation on iOS stretches the picture.

## Issues first

5. `0005` the iOS simulator's Metal device refused: the family check may be deliberate.
6. The Android safe area includes the system gestures' strips: a behavior change, so
   perhaps a hint. No patch since 2026-11-18; `DraughtsActivity`'s surface sends its own
   insets.
7. `0003` large Vulkan allocations rounded up to 64 MiB blocks: an allocator choice; send
   the tablet's numbers.
8. `SDL_WaitEventTimeout` busy-waits on Android (the poll sentinel).
9. No `WaitEventTimeout` or `SendWakeupEvent` on UIKit (a 1 ms poll).
10. The Android Java keeps the accelerometer on at 50 Hz.

## Acceptance criteria

- [ ] Each sent, or dropped with the reason here
- [ ] When one lands in a release: bump SDL, delete its patch or workaround, update
      `docs/goose-findings.md`
