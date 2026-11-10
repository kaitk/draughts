# 04: Stage 3, layout

Status: todo

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

- [ ] `panel::Layout` holds every rect and a mode; `game()` and `leave()` only declare
- [ ] No orientation worked out from a rect's shape; one shared portrait bar
- [ ] `gui::stack` in `gui`, with a test, used by settings and at least home's menu
- [ ] `shell::still` doesn't run a screen's frame; home and settings have pure layouts
- [ ] `sizes.out` and every other expected output byte-identical
- [ ] Idle CPU, the bench, and a transition's frame time recorded here
