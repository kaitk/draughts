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
