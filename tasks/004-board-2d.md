# 004: 2D board and pieces

Status: todo

Draw the board and pieces as `docs/architecture/rendering.md` describes: the board in one pass,
the pieces as one instanced draw that pulls from a storage buffer, and SDF shapes. Map
touch to squares.

## Acceptance criteria

- [ ] Board and pieces fill the tablet in landscape and portrait, crisp at native resolution,
      with nothing under the system bars (full screen on Android, as task 001's
      proof of concept does: `docs/development.md`)
- [ ] Tap a piece: it lifts and its legal targets glow; tap a target: the move animates,
      including each hop of a multi-jump. Taps act on press and release, not
      `gfx::mouse_down` (`docs/development.md`)
- [ ] Dragging a piece to its target works too
- [ ] Pieces that must capture pulse when the player touches any other piece
- [ ] Kings are clearly distinct at a glance
- [ ] No allocation in the frame loop (checked, and how is recorded)
