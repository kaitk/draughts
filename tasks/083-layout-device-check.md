# 083: Check 2026-11-13's layout changes on the devices

Status: todo

The game and puzzle screens' layout changed on 2026-11-13 (`docs/decisions/rendering.md`,
from "No moves yet is centered" to "In portrait the camera buttons are always a row"), and
was checked only on the Mac (`build/notes/master.html`, every size, the game flat and 3D
and a puzzle, local):

- the way out's tiles alone on glass's tint, no panel, in landscape and in portrait's bar;
  on a touch screen back and settings side by side over start over
- the moves panel at the left under them (tablet, desktop), above the 3D board on 4:3 and
  a foldable, with the catch's counts in its head; a phone's moves' line headed "Move
  list", with no chevron or tap before the first move
- 4:3 and foldable tablets' narrow panels on the 3D board
- the portrait bar's row (the catch, the moves' pill) on a strip of glass; the camera
  buttons a row in portrait
- Stays before Turns in the setup's board row

## Acceptance criteria

- [ ] Checked on the Tab A11+ in both orientations and on a phone (Pixel 7a or A33), each
  shown only where the Mac can't tell (touch, glass over the real photograph, the 3D
  board's fit)
- [ ] What looks off is fixed or written down as a follow-up
