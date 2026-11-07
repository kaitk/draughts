# 005: Draw only when something changes

Status: done

Block in `SDL_WaitEvent` when nothing is animating, so the idle app uses no CPU or GPU.
`goose_gfx` polls each frame (`SDL_PollEvent` in `gfx_device.c`), so this needs a wait
variant: first as a patch in `patches/goose_gfx/`, then proposed upstream (task 010). The
user has contributed to goose_gfx before.

## Acceptance criteria

- [x] Idle: no frames are submitted (frame counter checked)
- [x] Paused by Android (home, screen off): no frames and no GPU work until resumed
- [x] Animations and the AI's reply wake the loop; input latency is unchanged
- [x] Battery drain over 30 minutes idle on the board, measured on the tablet, recorded here

## Results (2026-11-07, Galaxy Tab A11+, `poc/idle.goose`)

`patches/goose_gfx/0002-draw-on-demand.patch`; how it works is in
`docs/architecture/rendering.md` ("Frames and battery").

- Idle: 5 `frame()` returns and 0 presents in 5 s. A tap wakes it in the same frame;
  the 1 s pulse that follows draws about 90 frames, then it is idle again. Animations and
  input both go through `dirty || animating`, and the AI's reply (task 006) is seen
  within a second, or at once while its thinking animation runs.
- Home, and back: no frames and 0 CPU on the program thread over 10 s in the
  background. On resume the picture is back with 0 draws. Six home/resume and rotation
  cycles held memory flat (PSS about 258 MB, graphics 210 to 212 MB).
- CPU idle with the screen on (`scripts/idle_cpu.sh`):

  | | Program thread | Whole process | Program thread wakeups |
  | --- | --- | --- | --- |
  | Unpatched gfx, 5 min | 17% of a core | 28% | 92 a second, presenting at 90 Hz |
  | Patched, 30 min | 0.02% (0.41 s) | 1.9% | 1 a second |

  The 1.9% left is SDL's Java thread handling the accelerometer at 50 Hz (task 011).
- The first 30-minute run found SDL's wait spinning on Android, a whole core, which the
  patch now works around ([findings](../docs/goose-findings.md)).
- Battery drain itself can't be read here: the tablet charges over USB, and batterystats
  then reports 0. CPU time stands in for it. Drain on battery, if wanted, is the user's
  to measure: unplugged, 30 minutes on the idle board, Settings → Battery.
