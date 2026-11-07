# 004: 2D board and pieces

Status: done

Draw the board and pieces as `docs/architecture/rendering.md` describes: the board in one pass,
the pieces as one instanced draw that pulls from a storage buffer, and SDF shapes. Map
touch to squares.

## Acceptance criteria

- [x] Board and pieces fill the tablet in landscape and portrait, crisp at native resolution,
      with nothing under the system bars (full screen on Android, as task 001's
      proof of concept does: `docs/development.md`)
- [x] Tap a piece: it lifts and its legal targets glow; tap a target: the move animates,
      including each hop of a multi-jump. Taps act on press and release, not
      `gfx::mouse_down` (`docs/development.md`)
- [x] Dragging a piece to its target works too
- [x] Pieces that must capture pulse when the player touches any other piece
- [x] Kings are clearly distinct at a glance
- [x] No allocation in the frame loop (checked, and how is recorded)

## Notes (2026-11-07)

- The look, with every color and size, is settled in `docs/architecture/rendering.md`
  ("Look"), from the prototypes in `prototypes/` (`game.html`, `boards.html`).
- The icons (a gold crown on kings, and the panel's back, undo, hint, restart) need a
  native form: SDF shapes drawn in a shader, or glyphs baked into the font atlas from
  their SVG paths (`prototypes/kabe.js` has the paths). Decide here and record it in
  `rendering.md`.
- The engine for legal moves and playing them is `rules/` (`rules::generate`,
  `rules::play`); a move's `path` gives each hop of a multi-jump to animate.

## Outcome (2026-11-07)

`app/kabe.goose` draws the board as `rendering.md` describes: one full-screen pass for
the page, frame, squares, light, and marks, and every piece in one instanced draw pulling
from a storage buffer, with the season's theme. `board/` holds the logic with no
graphics (layout, hits, taps, drags, the move animation, the draw lists), tested by
`test/board/taps.goose`. Two play on one screen, white at the bottom; the side panel,
the background photograph, and the turn piece are the game shell's (task 008).

- Kings: a crown drawn as a signed-distance polygon in the piece shader, dark on light
  pieces and gold on dark ones. Icons: recorded in `rendering.md` (strokes as SDF).
- Multi-jumps: the piece hops stop by stop (0.2 s each, a small arc), the pieces it took
  stay until the move ends and then fade (0.18 s), and a Russian man crowned mid-capture
  wears the crown from that stop on.
- On the tablet (Galaxy Tab A11+, full screen 1920×1200 and 1200×1920): taps select and
  move, `adb shell input swipe` drags a piece onto its target, and rotation relays out
  the board. A bug found there: the frame after an animation ended was never drawn, so
  the last move's marks were missing until the next input; `board::update` now reports
  it and the test covers it.
- Idle (`scripts/idle_cpu.sh 60`, the board on screen): the program thread used 0.02 s
  of CPU in 60 s (0.03%) with 60 voluntary switches, one wakeup a second. The process
  used 1.20 s, SDL's accelerometer (task 011).
- No allocation in the frame loop: nothing the loop calls builds a resizable or a string
  (no `[>..]`, `str`, `format`, `append`, or `copy` in `board/board.goose`,
  `app/draw.goose`, or the loop); the legal moves, pieces, and marks are fixed buffers in
  `board::Board`, and the storage buffer is uploaded whole from a fixed array. Measured:
  after 300 taps that each redraw, the native heap held at 26,025 KB over 600 more, and
  graphics memory at 177,448 KB.
- Graphics memory: 148 MB at a fresh start, about 210 MB after both orientations,
  holding there over 6 `scripts/lifecycle_memory.sh` cycles (no leak). That is above the
  POC's 112 to 114 MB; not yet explained (the screen and depth textures are 18 MB per
  size; the driver's pipelines are a guess). Worth a look when memory matters.
