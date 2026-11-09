# 01: The next stop on the 3D board

Status: todo

After a second wrong square in the same capture, the flat board lights the capture's
next stop (`marks.next`, `flash.z`); the 3D board never shows it, as `view3d::fill` never
maps them (found with the 3D pips, 2026-11-09, `96d70e0`). Map them as the pips are,
with no new buffer and nothing per frame beyond the marks' cost.

## Acceptance criteria

- [ ] The next stop shows on the 3D board as on the flat one, tested in `test/game/`
