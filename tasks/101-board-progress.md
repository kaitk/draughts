# 101: A progress bar while the 3D board is set up

Status: todo

While the 3D board is set up, the place where it goes shows "Setting up the board…"
(`gui::loading_text`, `strings::BOARD_PREPARING`, drawn by `shell.goose`). On a phone that
now takes about 2 s, or nearly 3 s with the table (task 095's numbers), so the user
(2026-11-20) wants a bar instead: a thin white bar that fills from left to right, its ends
marked so it shows how far there is to go.

`draw3d::prepare` already counts its steps: one setup, the theme's
`model3d::THEME_STEPS` (the table's bands skipped without one), then
`render3d::WARM_STEPS`. Their share done is the bar's length. The steps take very
different times, though: on the Pixel 7a the bake pipeline's step alone is about 0.85 s
of 1.9 s, and the lit pipelines' two warm steps 0.15 to 0.2 s each, while the plan's
bands are about 15 ms each. Weight the steps by what they take, or the bar stalls at its
start. Fixed weights from the Pixel's numbers are enough.

## Acceptance criteria

- [ ] A white bar with its ends marked fills from left to right while the board is set
      up, at first run, on switching to 3D, and on a theme or board change that bakes again
- [ ] It moves about evenly on the Pixel 7a and the A33, not stalling at the start
- [ ] Without anything to wait for it doesn't show
