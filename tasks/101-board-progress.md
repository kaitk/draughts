# 101: A progress bar while the 3D board is set up

Status: in-progress (on the `table-top` branch, 2026-11-20: built, to check on the Pixel and the A33)

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

## Done (2026-11-20)

- Five takes in `prototypes/loading.html` (`?take=a..e`, `?p=0.4` freezes the fill): the
  words over a 40% bar with ticks at its ends (a), the bar alone (b), a bar across the
  board's foot (c), a rounded bar under the words (d). Built as e, a with c's faint track:
  the words in the middle, 16 dp under them a 288 dp bar 3 dp tall, white at 90% over a
  track at 18%, a 2 × 12 dp tick at each end at 60% (`gui::loading_bar`).
- Weighted by each step's time on the Pixel 7a (`draw3d::theme_ms`, `warm_ms`): the
  setup 100 ms, the bake's pipeline 850, the table's first band 715 (its bake's
  compile), the photograph's pipelines 60, the lit and fading pipelines 170 each, the
  table's 150, the bands 15. `draw3d::left_ms` sums the steps prepare() would still take;
  the bar is what is done of what there was, never going back.
- Mac shots with the table (gfx and ngfx alike), frames 2, 4, 12, 30, 48, 56: 3%, 33%,
  37%, 70%, 92%, 95%. On the Mac the setup itself takes 1.5 s headless, so the bar waits
  at its start there; the Pixel's setup is about 0.1 s of its 1.9.

## Acceptance criteria

- [x] A white bar with its ends marked fills from left to right while the board is set
      up, at first run, on switching to 3D, and on a theme or board change that bakes again
- [ ] It moves about evenly on the Pixel 7a and the A33, not stalling at the start
- [x] Without anything to wait for it doesn't show
