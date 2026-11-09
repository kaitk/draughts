# 054: The flat game screen's controls as the 3D one's

Status: done

The flat (2D) game screen looked needlessly different from the raised (3D) one (the user,
2026-11-09). The task's first takes (`prototypes/game-unified.html`: a frame, the 3D
board's shadow and lighter blur, the corners layout with a floating button) went further
than asked. The user corrected them: the task is the UI **around** the board only. The
flat screen's controls become the 3D screen's: the same short corner panels, the same
buttons, in the same places. The boards themselves are not touched: no frame, shadow,
blur, size, or turning changes on either.

## What was asked

- Landscape: top left back, then settings and start over; top right whose turn, the
  lookout's eye, the hint and undo move; the clocks where the 3D screen has them. The
  3D-only round buttons (view, zoom, showcase) stay 3D-only; the flat screen has no
  round button of its own to keep.
- The flat board keeps its own size and place, unless the corner panels free room it can
  grow into.
- Portrait and compact already share the bar and the play panel: check they still match
  between flat and 3D, and change nothing that already matches.
- Phones' and tablets' landscape both.

## Built (2026-11-10)

- **Landscape** (`panel::flat_corners`, taken by `layout_in` for the game, `game: true`):
  the 3D screen's short corner panels, 232 × 352 dp (192 on a phone), the play panel 368
  dp tall where it is narrow, as the 3D phone's. `Layout.corners` now marks the corner
  panels flat or 3D, and the play panel's choices that were the 3D board's
  (`l.three`: the shorter tile, the countdown between the clocks, the closed-up gaps)
  follow it, so the flat screen lays out whose turn, the eye, the hint beside undo move,
  and the clocks exactly as the 3D one does.
- **The board**: the same size and place at every size. The corner panels free no room
  it can grow into: it is a square of the height less the margins, so it must clear the
  panels across whatever their height, and the corner panels at the screen's edges leave
  it the same width the old panels beside it did. On the tablet it is still 720 dp, 280
  dp from the left.
- **Portrait**: the bar and the play were as wide as the flat board, the 3D screen's as
  wide as the screen less the margins. They differed where the board is narrower than the
  screen (4:3 and the foldable in portrait, and near-square windows kept in portrait); the
  game's are now as wide as the 3D screen's there, and the bar's stacked words follow
  the bar's width as the 3D screen's do. On phones and the tablet they already matched
  and are unchanged. Compact already matched.

## Decisions

- **Near square, the panels narrow on the flat screen only.** The 3D screen's corner
  panels are 232 dp on any tablet. At 4:3 and the foldable that would leave the flat board
  507 and 439 dp where it has 587 and 519, so the flat screen's corner panels are no wider
  than its old ones (`side_of`): 192 dp there, the play panel then 368 dp tall as a
  phone's for the hint over undo move. The boards keep their size; the panels differ from
  the 3D screen's by 40 dp across there. `test/shell/sizes` says so on those lines.
- **A puzzle keeps its flat layout** (panels as tall as the board). The task is the game
  screen; a puzzle's goal and stars were laid out for the tall panels and the 3D corner
  panel alike, so it could follow, but that is a change of its own (`layout_in`'s `game`
  flag, `shell::puzzle_layout`).
- **The win's card** and everything on the board are as they were.

## Numbers (headless)

- Landscape boards unchanged: tablet 720 dp, 4:3 587, foldable 519, the 20:9 phone at 540
  dp 492 (`test/game/game`, `test/shell/sizes`). The smallest tap on the flat tablet's
  landscape is now the 3D screen's: hint and undo move side by side in the play panel,
  94 dp across (from 200).
- Portrait, the bar and the play 752 dp wide at 4:3 (from 647, the board's) and on the
  foldable (from 579).

## Shots

Headless, before and after, in the session's scratchpad
(`/private/tmp/claude-501/-Users-kaitkasak-projects-personal-draughts/b7477f16-67e8-47ad-8c8d-5690c6660fd1/scratchpad/054-052/`,
`before/` and `after/`): flat and 3D at 1280 × 800 and 1920 × 1200, a phone's portrait
(1080 × 2400 at 540 dp with the Pixel 7a's insets), and the iPad's smallest window,
each early and late in a game. Not yet seen on the tablet.

## Acceptance criteria

- [x] The differences listed, from headless shots of both screens
- [x] Takes drawn side by side with the raised screen (set aside: the user asked for the
  controls only)
- [x] A decision with the user: the controls round the board as the 3D screen's, the
  boards untouched (2026-11-09)
- [x] The flat screen built to it at every size, compact included, checked headless, and
  `docs/architecture/rendering.md` updated
