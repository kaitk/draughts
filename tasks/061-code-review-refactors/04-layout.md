# 04: Stage 3, layout

Status: done (2026-11-10)

Stage 2 (`03-structure.md`) first. Every expected output stays byte-identical:
`sizes.out` is the check that nothing moved by a pixel.

The core is sound. `gui`'s rect cuts (`cut_top`/`bottom`/`left`/`right`, `inset`,
`center`, `cell`, about `gui.goose:327–362`) are small and flat, and hit-testing always
uses the rect that was drawn. The hard part to read is the screens: each works out its
own sizes with formulas and "try this, else that" chains. Predicting where something
lands takes running `sizes`.

## The panel as regions with a mode

`panel::game` (`panel.goose:805–1012`, about 200 lines) is the hardest function to read:

- It has three orientation and size branches. In landscape it works out `column`,
  `beside`, `tight`, and `squeezed` from inequalities over literal heights (833–836), and
  every later cut depends on which combination held.
- It works out the orientation again from a rect's shape (`l.left.z < l.left.w` at 709,
  790, 808).
- `taken_in_bar` (531–544) writes out the compact bar's `12 + ICON_W + 12 …` again, to
  line up with the cuts in `leave` (736–743), and `leave` works out `tiles_h` again from
  `taken_as` (750). Change one and the other silently drifts.

To fix it:

1. Give `panel::Layout` a `mode` (landscape, corners, portrait, compact) and every rect
   the screen uses: the eye, the hint, undo, the clocks, the taken pieces, and the bar's
   tiles.
2. `game()` and `leave()` then only declare into those rects. `taken_in_bar` and the
   shape-based orientation checks go away.
3. Split `game()` into one function per mode.
4. `corners_in` (180–277) and `layout_in` (432–473) repeat their portrait branches
   almost line for line. Share them as one `portrait_bar(area, s, game, compact)`.
5. Measure the panel's text first and pass the widths in, as settings already does with
   `declare = false`.

## `gui::stack`

A helper of about 100 lines, nothing more: `gui::stack(area, specs, out_rects)`.

- It takes a fixed array of child specs. Each child is fixed, fit-to-text, or grow, with
  a gap and an alignment.
- It fills the rects in one pass.
- There is no tree, no retained state, and no allocation, and hit-testing still uses the
  same frame's rects.

Use it where a column or row of text-sized children is now worked out by hand:

- settings' rows (`lay(…, declare)` at 486, `group_height`);
- home's menu;
- the cards;
- the picker's grid.

Leave the fit decisions as code: whether the board is as big as it can be, whether the
panel goes beside or below it, and the 3D camera's fit. `stack` doesn't express those.

## Pure layouts for home and settings

`home::frame` (`home.goose:153–275`) and `settings::frame` (`settings.goose:803–947`)
work out sizes and declare widgets in one function. So `shell::still`
(`shell.goose:663–689`) runs a whole screen's frame with input off, only to learn where
the board goes during a transition. Give each a pure layout function that returns a
regions struct. `frame` declares into it, and `still` asks for it without declaring.
This saves the extra frame during transitions.

## Acceptance criteria

- [x] `panel::Layout` holds every rect and a mode; `game()` and `leave()` only declare
- [x] No orientation worked out from a rect's shape; one shared portrait bar
- [x] `gui::stack` in `gui`, with a test, used by settings and at least home's menu
- [x] ~~`shell::still` doesn't run a screen's frame~~ (dropped: it must declare, below);
      home and settings have pure layouts
- [x] `sizes.out` and every other expected output byte-identical
- [x] ~~A transition's frame time on the Mac, before and after~~ (nothing to save, below);
      the shell's frame timed headless before and after instead

## Outcome

One commit per item. After each, the tests passed with every expected output
byte-identical; `stack.out` is new.

- **`shell::still` stays.** Its premise was wrong: `still` doesn't declare the screen a
  transition leaves only to learn where its board goes. `shell::blend` fades those quads
  out (`gui::fade(g, first, middle, 1.0 - e, out)`) and the screen left is drawn, fading
  and drifting, under the one come to. Not declaring it would take that fade away, so
  there is no frame to save, and nothing for the transition's timing to show.
- **The panel's mode.** `panel::Layout.mode` is `LANDSCAPE` (a puzzle's flat panels as
  tall as the board), `CORNERS` (the game's flat board and the 3D board in landscape),
  `PORTRAIT`, or `COMPACT`, in place of the `corners` and `compact` flags; `columns(l)`
  replaces the `l.left.z < l.left.w` checks in the panel, the puzzle, and `sizes`.
  `portrait_bar` (a `Bar`: mode, gap, the bar's and the play's heights, stacked) is the
  portrait branch `corners_in` and `layout_in` shared line for line.
- **Regions.** The layout holds what doesn't change with the game: the bar's tiles' room
  (`tiles`), `stacked`, and what each side has taken, worked out from the same cuts as the
  tiles (`bar_tiles`, the compact icons through one `icons`), so `taken_in_bar` and its
  copy of `12 + ICON_W + 12` are gone. What depends on the clocks, the countdown, a draw,
  and the words is laid out per frame by pure functions that declare nothing: `way_out`
  (an `Out`: back, settings, start over, the glass, the arrangement) and `column_play`,
  `compact_play`, and `portrait_play` (a `Play`: the clocks, the short form, the piece,
  the words, the eye's name, the countdown's room, the eye, the hint, undo move, and how
  each lays out). `leave` and `game` measure the words their mode reads (`Words`), ask for
  the regions, and declare. One declaring sequence serves the three modes, in the old
  order of quads. Split per mode are the layouts, not the declaring, which would repeat
  the same calls three times. The words inside one region (a fitted face, the countdown's
  dots) stay with the widget that draws them.
- **`gui::stack`** (`gui.goose`, about 40 lines): items of a size and a grow weight, a gap
  before each, across the whole width or their own placed by an alignment, the rest
  justified at the start, middle, or end; positions run on from the start as cuts do.
  `test/gui/stack.goose` checks it. Home's menu uses it (the wordmark, the rows, settings),
  and settings' landscape column (the title row, then the groups centered down the rest).
  Not used where it gives other last bits than the cuts (settings' groups side by side,
  cut from the bottom: one test printed 824.889 for 824.88904), where a glass taller than
  its room is clamped by a cut (one group at a time), or where it adds nothing: settings'
  rows run on with heights known only once their tiles wrap, the cards already share
  `card_size` and `card_at` (stage 2), and the picker's is a grid (`gui::cell`).
- **Settings' rows** are worked out before they are declared: `lay` puts a row's tiles
  in an array, `rows_at` returns each row's name, tiles, and switch (`Rows`), `rows`
  declares them. The `declare` flag and the `over` the measuring passed are gone.
- **Pure layouts.** `settings::layout` returns a `Page` (which of COLUMN, BOTH,
  TABS_BESIDE, and TABS_UNDER, the title row, the tabs, each group's glass and bleed, the
  preview and the 3D room), setting only `s.name_w` and `s.slim`, which the rows read;
  `home::layout` returns a `Home` (the glass, the content, the head, the way out, the
  board's side, the board and the 3D room, the menu's gear and gaps). Each `frame`
  declares into it.
- **Frame cost**, timed headless (`goose build`, test faces, 9,600 frames each, a
  throwaway program driving `shell::frame` through `test/drive`), against `3de9dde`: home
  and settings in a transition 28.6 µs a frame before and 28.9 after in landscape, 28.1
  and 28.5 in portrait; home and the game 3.64 and 3.68; the game at rest 1.66 and 1.69
  in landscape, 1.76 and 1.79 in portrait (run to run the numbers move about 1%). Measuring
  every word each frame had cost the game 0.2 µs (1.82), so the panel measures only what
  its mode reads.
- **On the Mac,** against a build of `3de9dde`, nine shots byte-identical or differing
  only where two runs of the old build differ: home, settings (the preview's flash),
  a game with taps, a clocked game, the computer's setup, a puzzle reached through its
  transition, home to settings held at half, a capture game (a pulsing ring), and the 3D
  game (its timed fade, matched by eye).
