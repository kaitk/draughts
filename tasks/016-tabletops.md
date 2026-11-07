# 016: Tabletop pictures for the 2D game

Status: todo

The 2D game sits on a flat tabletop, for now a gradient with noise in the theme's table
color ([rendering](../docs/architecture/rendering.md#scene-and-glass)). Try generated
tabletops in ChatGPT, one per season, with a few objects at the edges that belong with
the board. Images stay local until the user agrees to add them to git.

The prompts keep to these:

- **The season is in the colors and the light, not the objects.** Leaves and acorns on a
  table read as a stock photo, not a place to play (the first autumn try, 2026-11-07).
  The things around are what you'd have at a game at home: a mug on a coaster, a
  candlestick, the wooden box the pieces live in, books and a pencil, a sand timer, a
  blanket's corner.
- **Things only at the left and right edges, cut off by the frame.** In landscape the
  board fills the height and only about the outer 9% shows on each side (the panel's
  glass blurs part of the right). A square picture loses its corners to the crop, so
  landscape and portrait are made separately (3:2 and 2:3), portrait with things at the
  top and bottom.
- Looking straight down, warm soft light from the top, calm fine grain, low contrast and
  a little dark; no board, pieces, or text.

Ready to paste: `design/tabletops/prompts.txt`, autumn first in three styles
(realistic, the 1990s Amiga look at modern resolution, a felt mat on the table) and a
busier realistic one; the other seasons once a style is picked.

## Acceptance criteria

- [ ] Autumn tried in the three styles, then the other seasons in the chosen one,
      behind `prototypes/game.html` at both sizes
- [ ] The user picks a style, or keeps the plain table
- [ ] If pictures win: stored as the scenes are, added to git only once the user agrees
