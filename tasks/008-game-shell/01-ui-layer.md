# 008-01: UI layer and glass

Status: done (awaiting review)

The immediate-mode UI layer and glass panels, and the first panel: the game screen's,
beside the board (landscape: right of the board and as tall; portrait: below it).

## Work

- **`gui/` package**, pure Goose with no graphics, so it is tested headless as `board/`
  is: rect cuts (`cut_left`, `cut_top`, ..., `inset`, grid cells); `begin(input, now)`
  each frame; `panel(rect)`; `button(id, rect, icon)`, true on release inside the rect it
  was pressed in; a small fixed table of per-id state for the press animation; every
  call appends quads to one fixed array, reset each frame. Nothing allocates.
- **Drawing**: one pipeline, one instanced draw: each quad pulls `{rect, color, kind,
  radius, icon, ...}` from one storage buffer and its fragment shader draws it as a
  signed-distance shape: a glass panel with its shadow, a button tile, a line icon.
- **Glass** (rendering.md, "Scene and glass"): the 512 px blurred scene copy blurred
  further once, when the season is picked, into a small texture (the blur a 24 px one
  would be at 1280 px); a panel samples it at its screen position, then the theme's
  dimming and saturation 1.3, the glass tint, a 1 px border of white at 14%, a 1 px top
  highlight of white at 12%, the shadow `0 12px 32px -14px` of black at 55%, radius
  28 px; sizes in dp, scaled with the layout.
- **The panel**: undo, hint, restart, and back as glass tiles with their line icons, in a
  2 × 2 grid in landscape and a row in portrait. They draw their press but do nothing yet
  (subtask 02).
- **Test**: `test/gui/`: cuts, a press and release on a button and off it, a drag off,
  the state table's animation, and the quads a frame makes.

## Acceptance criteria

- [x] `gui/` with rect cuts, `button`, and the state table; no allocation per frame;
      tested in `test/gui/`
- [x] All UI quads in one storage buffer, drawn by one pipeline in one draw
- [x] The glass panel beside the board in both orientations, sampling the further-blurred
      scene, with the tint, border, highlight, shadow, and radius rendering.md gives
- [x] Checked on the Mac at 1920 × 1200 and 1200 × 1920 for every season next to the
      design boards, then on the tablet over USB
- [x] `scripts/idle_cpu.sh 60` and `scripts/lifecycle_memory.sh 20` re-run, numbers
      recorded here; still no frames while idle

## Outcome (2026-11-07)

- `gui/gui.goose`: rect cuts, `center`, `cell`; `begin`, `panel`, `fill`,
  `button(id, rect, icon)`; a 32-slot state table for the press (0.12 s, eased);
  `animating` keeps frames coming only while a button moves; 128 quads in a limited
  array, cleared each frame. `g.took` tells the app a press landed on the UI, so it never
  reaches the board.
- `app/widgets.goose`: one storage buffer (the whole fixed array, so SDL can cycle it)
  and one instanced draw after the pieces; the quads are copied before the screen's pass
  opens, since copies happen between passes. `app/draw.goose` now leaves the pass open
  for it.
- Glass: `app/scene.goose` blurs the 512 px copy into a 256 px one (sigma 3.9 texels),
  256 KB more graphics memory. The shader dims and saturates it, tints it, and adds the
  border, the top highlight (a port of CSS `inset 0 2px 0 -1px`), and the shadow.
- The panel: `app/panel.goose`, with the panel widened to the prototype's 272 dp in
  landscape and 240 dp in portrait (`board::layout`; `test/expected/taps.out` changed
  only in those numbers). Tiles 104 dp in the 2 × 2 grid, 88 dp in the portrait row. The
  icons' stroke is 2.4 units of their 24-unit grid, as the prototypes' SVGs draw it
  (rendering.md said 2.4 px, which read too thin beside them).
- The theme gained the glass tint and the text color, with the glass dimming
  (`theme::Theme.glass`, `.text`).
- `test/gui/gui.goose`: cuts and cells; a tap, a hold (halfway at 0.06 s, all the way at
  0.12 s), a press slid off, a press from the panel released on a button, a press off
  the UI, a tap within one frame; the quads of a frame.

### Compared

Mac screenshots at 1920 × 1200 and 1200 × 1920 for all four seasons beside
`prototypes/game.html` (at the same pixel size) and the autumn and winter design boards:
the glass, tint, border, highlight, shadow, tiles, and icons match the prototype. Left
as they are:

- The top row is empty until 02 adds the side to move and the hints toggle; in portrait
  the buttons sit low in the panel for that reason.
- The design boards' icons are a little heavier and their bulb is filled; the
  prototype's stroke is kept.
- The autumn design board stacks five tiles in a column; rendering.md and the winter
  board have the side to move, a rule, and a 2 × 2 grid, which is what is built.
- A tap that goes down and up within one frame works but shows no press; on the tablet
  down and up arrive in different frames.

### On the tablet

Built and installed as `com.kaitk.draughts` (the APK 5.0 MB). All four seasons in
landscape, and portrait, look as on the Mac; a held button shows its press. The tablet's
locale is `en-GB`, so English. Idle, untouched, 60 s: the program thread 0.01 s of CPU
(0.02% of a core) with 60 voluntary switches, the process 1.28 s (the accelerometer,
task 011): as before. Over 20 cycles of home, resume, and rotation
(`scripts/lifecycle_memory.sh 20`), one process throughout, no errors: PSS 255 to 259
MB, native heap 26 MB, graphics 210 to 215 MB, with the same two 2 MB steps as before
the UI. The old `com.kaitk.kabe` build is still installed on the tablet.
