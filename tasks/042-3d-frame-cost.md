# 042: The 3D board's frame cost

Status: in-progress

The moving 3D board took about 14 ms on the Pixel 7a and the tablet, over the tablet's
11 ms at 90 Hz. The review's candidates were tried on the tablet (2026-11-09) and with
task 059 the frame goal is met: the tablet's release holds 9.2 ms waited with the shadow
map, 90 fps at the 1% low, none of 1000 frames dropped (2026-11-10). Getting the 3D
board ready in steps with a still mark, and the grey fade on a season change, were built
here too (`docs/architecture/rendering.md`, "Getting ready"). The candidates, the
per-step tables, and the device runs are in git at 314c3b5. What this task holds now is
the idle wakeup and a few notes.

## The idle wakeup

The tablet's 3D board at rest wakes once a second, as the flat board does, but spends
about 2.7 ms CPU a wakeup against the flat board's 0.3. On the Mac (2026-11-09) the app's
loop doesn't draw at rest on either board, so the extra 2.4 ms is outside the app's own
work: in the patched `frame()` (whether `drew` holds and a command buffer is submitted)
or in SDL's and the driver's Vulkan work on the program thread. To check on the tablet:
in a build copy, `SDL_Log` in `frame()` for both, and per-thread CPU (`agents/testing.md`)
for 3D against 2D; simpleperf can't sample there.

## Notes for later

- Fewer, larger getting-ready steps on fast devices: steps back to back within a frame
  under a budget (say 8 ms), the bake's compile and the photograph's decode still a frame
  each. A season change is 28 steps, 66 to 95 ms of work on the M1 Pro, so 0.47 s at
  60 Hz is the frame count, not the work; an 8 ms budget would take it to 9 to 15 frames.
  Print the iPhone's and the Pixel's step times first (`--frames` prints `3D board
  prepared in N steps`).
- A low-quality mode for weak phones (2026-11-09, not built): when the moving board stays
  under about 30 fps, cut the 3D pass's resolution, then its geometry.
- The A33 (2026-11-13): the lit shader is more than half the frame (about 6.5 M of 12 M
  cycles), its shadow taps about 15%; 2× MSAA saves a quarter and looked fine to the user,
  a fallback for devices that miss 60 fps.
- Unexplained: a theme prepared again over another differs from the same theme prepared
  at launch by up to 11 levels of 255 (PSNR 38 dB); some old theme state may carry over.
- Left open by task 015: the pulsing marks' frame time on a device; the drag threshold
  measured only on the flat layout.

## Acceptance criteria

- [x] Each candidate measured on the tablet with `--bench 300` and kept only for a win
- [x] The tablet's moving 3D board within 11 ms (2026-11-10)
- [ ] The idle wakeup's cost explained, and fixed if it draws
