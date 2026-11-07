# 004: 2D board and pieces

Status: todo

Draw the board and pieces as `docs/architecture/rendering.md` describes: the board in one pass,
the pieces as one instanced draw that pulls from a storage buffer, and SDF shapes. Map
touch to squares.

## Acceptance criteria

- [ ] Board and pieces fill the tablet in landscape and portrait, crisp at native resolution,
      with nothing under the system bars (task 001 left the app under the status bar)
- [ ] Tap a piece: it lifts and its legal targets glow; tap a target: the move animates,
      including each hop of a multi-jump. Taps act on press and release (`gfx::mouse_pressed`,
      `mouse_released`, or events), not `mouse_down`: a quick tap can press and release
      within one frame (task 001)
- [ ] Dragging a piece to its target works too
- [ ] Pieces that must capture pulse when the player touches any other piece
- [ ] Kings are clearly distinct at a glance
- [ ] No allocation in the frame loop (checked, and how is recorded)
