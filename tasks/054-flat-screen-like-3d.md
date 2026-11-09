# 054: The flat game screen in the raised one's look

Status: todo

The flat (2D) game screen looks needlessly different from the raised (3D) one and could
look more like it (the user, 2026-11-09), keeping the flat board's clarity.

## Differences

Compared headless on 2026-11-09 (the app's copy with `gfx::open_headless`, `--fen` of a
late game, the tablet's landscape at 1280 × 800 and a phone's portrait at `--size
1080x2400 --dp 540 --inset 0,59,0,42`):

- **The board's frame.** Flat: a thin lip 1.1% of the board in the dark square's color,
  a light line on its outer edge. Raised: a frame of the look's material (winter's veined
  slate) 2.4% of the board, which reads about 4% at the near edge, rounded corners, a
  front edge with depth.
- **Its shadow.** Flat: short and soft under the board (down 1.4%, 3.6% soft). Raised: a
  long soft shadow on the photograph, and the pieces' shadows cast by the light.
- **The light.** Flat: even colors, cream pieces. Raised: a pool of light on the board,
  the squares and pieces shaded, the light pieces cooler.
- **Size and place.** Landscape, flat: the board fills the height less the margins
  (720 dp), centered, 40 dp from the top. Raised: the bounds about 890 × 615 dp, the near
  edge on the 24 dp bottom margin, the far edge between the panels. Portrait: both as wide
  as the screen less the margins; the raised one is shorter and has the buttons' row under
  it, so its bar sits higher.
- **The panels.** Landscape, flat: both as tall as the board, settings at the top and
  start over at the bottom of the left one, whose turn at the top and undo move at the
  bottom of the right one. Raised: short panels in the top corners (232 × 352 dp), the
  tiles packed together. Portrait: the same bar and play panel in both.
- **The side buttons.** Raised: round floating buttons (view, zoom, showcase in
  landscape; view and showcase in portrait) under the play panel or above it. Flat: none.
- **The background's blur.** Flat: the app's blur (14 px at 1280 px, dimmed to 0.8),
  which in the shots leaves no shapes. Raised: the renderer's blurred and graded
  backdrop, lighter, the trees' shapes showing.
- **Turning.** Against a friend the raised board turns to face the side to move; the
  flat one stays.

## Takes (2026-11-09)

`prototypes/game-unified.html` sets the raised screen, the flat one as built, and the
flat one after side by side, in landscape and portrait; each frame is
`prototypes/game-captured.html` with `&cap=off`, which opens full size.

- **a, framed in place.** The flat board in a frame like the raised one's, seen straight
  from above (the look's frame color with a sheen and a light outer line, rounded
  corners, the squares set in it by the flat board's own lip), the raised board's long
  shadow, on the raised screen's lighter blur; the panels and their places as built. The
  squares lose the frame's width: 704 dp across now, 662 at a 4% frame, 685 at 2.4%.
- **b, the raised screen's layout too.** a, with the corners layout: short panels in
  the top corners, the board as tall as the screen less the margins between them
  (744 dp with its frame, the squares 684 at 4%), one floating button under the play
  panel that raises the board to 3D (`&btns=none` drops it); in portrait the raised
  order, the bar, the board, the button's row at the right, the play.
- The pieces and squares keep the flat board's even light, for clarity; the raised
  board's pool of light was left out.

Every view (the main checkout's path):

- `file:///Users/kaitkasak/projects/personal/draughts/prototypes/game-unified.html?take=b`
  (its header changes take, frame, btns, port, and season)
- `file:///Users/kaitkasak/projects/personal/draughts/prototypes/game-unified.html?take=a`
- `file:///Users/kaitkasak/projects/personal/draughts/prototypes/game-unified.html?take=b&port=tablet`
- `file:///Users/kaitkasak/projects/personal/draughts/prototypes/game-captured.html?cap=off&flat=b`
  (one screen at the window's size; the switcher changes flat, frame, btns)
- `file:///Users/kaitkasak/projects/personal/draughts/prototypes/game-captured.html?cap=off&flat=a&frame=a`

Open choices for the user:

1. a or b, or the flat screen as it is.
2. The frame's width: 2.4% (as the raised board's is) or 4% (as it reads there).
3. The background: the raised screen's lighter blur for both, or keep the flat one's
   heavier one behind the flat board.
4. A floating button on the flat screen (raise the board), or none.
5. Whether the flat board turns to face the side to move against a friend, as the raised
   one does.

## Acceptance criteria

- [x] The differences listed, from headless shots of both screens
- [x] Takes drawn side by side with the raised screen, before and after, in landscape and
  portrait
- [ ] A decision with the user on the take and the open choices
- [ ] If taken: the flat screen built to it at every size, compact included, checked on
  the Mac and the tablet, and `docs/architecture/rendering.md` updated
