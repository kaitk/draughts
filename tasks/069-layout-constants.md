# 069: Name the layout's sizes, then thinner tiles on a desktop

Status: todo (a session of its own, before task 068's note 5)

The tap's 88 dp height is written out about 60 times (`src/game/panel.goose`,
`ending.goose`, `src/shell/home.goose`, `settings.goose`, `picker.goose`, `who.goose`,
`src/gui/gui.goose`), and the panels' heights are tuned numbers rather than sums of what
they hold: `panel::CORNER_H` 352, `CORNER_PUZZLE` 504, `CORNER_PLAY` 368, `TALL_H` 132,
`STACK_H` 96, home's menu and setup heights, settings' `ROW_H`. Task 068 wanted thinner
tiles and less side padding on a desktop, and a branch per screen would make the layout
code worse (the user, 2026-11-11: only if it can be done nicely).

1. Name the tap's height once in gui (88 dp on a touch screen) and use it everywhere a
   tile's height or a tap's least size is meant; name the other repeated sizes the same
   way where they mean one thing (the margins, the gaps, the side padding).
2. Write each panel's height as the sum of its rows, gaps, and insets, so it follows the
   tap's height. Where a tuned number doesn't come out of its parts exactly, say so and
   keep it rather than force it.
3. Then a desktop's tap height and side padding as one value each (task 068's note 5),
   shot on the Mac at 1280 × 800, a MacBook's full screen, and 27" for the user to pick
   (a few heights: 72, 64, 56 dp; shoot a few runs at a time).

## Acceptance criteria

- [ ] Steps 1 and 2 with every test's output byte-identical (a touch screen's layout
      unchanged), and no bare 88 left meaning a tap.
- [ ] Step 3's heights shot and one picked by the user, the desktop's layout checked on
      every screen.
- [ ] `docs/architecture/rendering.md` and `docs/decisions/rendering.md` updated.

## Done (2026-11-11)

Steps 1 and 2, with every test's output and 102 headless shots (the desktop at 1280 × 800,
a MacBook's full screen, and 27"; the tablet both ways; a phone; every screen, flat and
3D, the win, a clocked game with taps) byte-identical before and after.

- `gui::TAP` (88 dp) is a tile's or a row's height and a tap's least size everywhere;
  `gui::WORD_SIDE` (16 dp) the room a tile sized to its words keeps either side (settings'
  tiles and languages, the setup's draughts, the puzzles' switch); the picker's page
  margins are `picker::MARGIN` and `MARGIN_PHONE`. 88s that mean something else stay
  numbers: a puzzle theme's mark on the library (`picker::theme_row`) and the compact
  bar, now `ICON_H + 2 × gui::PAD`.
- Sums of their parts: `panel::CORNER_H` (back, `BACK_GAP`, two stacked tiles, and
  `IN_ALONG` above, between, and below them), `TOP`, `TOP_STACKED`, `BOTTOM`,
  `BAR_SPARE`, `TOP_COMPACT`, `BOTTOM_COMPACT`, settings' `HEAD_H` (a tap and the
  language's glass round it), the picker's `SWITCH_H`; settings' rows, home's menu and
  setup, and who's card were sums already and now follow `gui::TAP`. `STACK_H` is a tap
  and 8 dp for the word under the icon, `TALL_H` half again a tap: both were tuned by eye
  (`TALL_H` dates from 72 dp rows), and tied to the tap they keep the corner panel's gap
  between its two rows at 36 dp whatever the tap.
- Kept as tuned, a few dp over what they hold: `panel::CORNER_PUZZLE` 504 (its parts come
  to 495) and `CORNER_PLAY` 368 (362). A face's line is its size in the app as in the
  tests (Nuklear scales a face by `stbtt_ScaleForPixelHeight`), so the gap is real slack,
  not the font's.
