# 005: Draw only when something changes

Status: todo

Block in `SDL_WaitEvent` when nothing is animating, so the idle app uses no CPU or GPU.
`goose_gfx` polls each frame (`SDL_PollEvent` in `gfx_device.c`), so this needs a wait
variant: first as a patch in `patches/goose_gfx/`, then proposed upstream (task 010). The
user has contributed to goose_gfx before.

## Acceptance criteria

- [ ] Idle: no frames are submitted (frame counter checked)
- [ ] Paused by Android (home, screen off): no frames and no GPU work until resumed
- [ ] Animations and the AI's reply wake the loop; input latency is unchanged
- [ ] Battery drain over 30 minutes idle on the board, measured on the tablet, recorded here
