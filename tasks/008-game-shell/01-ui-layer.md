# 008-01: UI layer and glass

Status: in-progress

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

- [ ] `gui/` with rect cuts, `button`, and the state table; no allocation per frame;
      tested in `test/gui/`
- [ ] All UI quads in one storage buffer, drawn by one pipeline in one draw
- [ ] The glass panel beside the board in both orientations, sampling the further-blurred
      scene, with the tint, border, highlight, shadow, and radius rendering.md gives
- [ ] Checked on the Mac at 1920 × 1200 and 1200 × 1920 for every season next to the
      design boards, then on the tablet over USB
- [ ] `scripts/idle_cpu.sh 60` and `scripts/lifecycle_memory.sh 20` re-run, numbers
      recorded here; still no frames while idle
