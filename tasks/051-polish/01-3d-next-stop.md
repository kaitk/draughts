# 01: The next stop on the 3D board

Status: done

After a second wrong square in the same capture, the flat board lights the capture's
next stop (`marks.next`, `flash.z`); the 3D board never shows it, as `view3d::fill` never
maps them (found with the 3D pips, 2026-11-09, `96d70e0`). Map them as the pips are,
with no new buffer and nothing per frame beyond the marks' cost.

## Acceptance criteria

- [x] The next stop shows on the 3D board as on the flat one, tested in `test/game/`

## Done

`view3d::fill` maps `marks.next` into `Scene.marks.next` and `Scene.lit`'s w (1 lit
still, 2 pulsing), and `flash.z` into `Scene.next`, which `render3d::marks_over` takes as a
uniform: while the dots pulse only the marks' quad is drawn each frame (`changes` gives
MARKS), and the board is drawn again only at the pulse's start and end. No new buffer.
`test/game/pips` prints the next stops on both boards (d2 at the world's 1.6, g5 at 4.3)
and that a frame on in the pulse changes only the marks. Checked headless before and
after (`agents/testing.md`, the xshot copy): the dot on d2 shows after.
