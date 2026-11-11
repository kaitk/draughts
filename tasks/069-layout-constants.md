# 069: Name the layout's sizes, then thinner tiles on a desktop

Status: done (2026-11-11)

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

- [x] Steps 1 and 2 with every test's output byte-identical (a touch screen's layout
      unchanged), and no bare 88 left meaning a tap.
- [x] Step 3's heights shot and one picked by the user, the desktop's layout checked on
      every screen.
- [x] `docs/architecture/rendering.md` and `docs/decisions/rendering.md` updated.

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

Step 3 (the user picked 64 dp from shots of the game's corners at 72, 64, and 56 dp at
1280 × 800, a MacBook's full screen, and 27"): `gui::tap()` is 88 dp on a touch screen
and `gui::DESKTOP_TAP` 64 on a desktop, `gui::side()` 16 and `DESKTOP_SIDE` 12; the
heights built from the tap are functions, as a top-level `let` is computed once at start.
What 64 and 56 broke, and what the user chose (2026-11-11):

- Undo move's tall tile, half again a tap, was 96 dp at 64: its word went to the small
  face on one line, as two lines want 108 (`gui::lines_at`), and settings' seasons and
  kings ran over 64 dp tiles. A tile with its icon or picture over its word is
  `gui::stacked()`, a tap of 72 dp at least: the panel's stacked and tall tiles,
  settings' rows (one height, as most hold two rows), and the setup's level, pieces,
  and clock.
- At 56 whose turn ran into the hint and undo move: the play's corner panel is the
  larger of its touch height (352 dp) and the clocks over undo move (314 on a desktop).
- On every screen the left corner's settings and start over are 20 dp apart, as from
  their glass's ends (the gap was 36): the left column is back and two rows,
  `panel::left_h`, 336 dp on a touch screen (240 on a desktop), stacked tiles sharing
  it evenly apart. `game/corners`, `game/game`, `game/taken` (the pieces under it 16 dp
  higher), `board/taps`, and `shell/sizes` moved with it; `shell/rest_hover`'s counts
  of points over a lit tile with the desktop's smaller tiles, still 0 asking.
- Home's rows in a small window are at most a tap, and the gear's reach over the
  wordmark's row none where the tap is no taller than the row.

Touch screens' headless shots (the tablet both ways, a phone) were byte-identical with
the desktop values in, before the left corner's spacing. Every screen at the three sizes
was checked at 64 dp, flat and 3D, with the clocks and the win.
