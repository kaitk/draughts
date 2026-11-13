# 082: New game's icon

Status: in-progress

Home's New game row has a plus in a ring (`gui::NEW_GAME`), a generic "add" that the
players' plus already uses. The user wants an icon about draughts, and isn't happy with
any take yet (2026-11-13).

## Takes so far

`prototypes/home.html?newgame=a..h` (the menu as the app has it, New game outlined under
Continue), drawn in `prototypes/draughts.js` (`newPair` .. `newJump`), in the icons'
24-unit grid at stroke 2:

- a, a light and a dark piece side by side from above: reads as glasses at 34 dp.
- b, a piece with a plus at its shoulder: clear, but still "add".
- c, a small checkerboard, its dark squares filled: the user's favourite of these, though
  it reads a little as a racing flag.
- d, the app icon's angled board with its dark piece; f, the angled board as c is; g, f
  with a light piece: an angled board is half as tall as wide, so these look small and
  flat beside home's square icons.
- e, two pieces seen from the side, one behind the other (after a reference the user
  showed: two stacked coin-like pieces in outline).
- h, a jump: a solid piece on the board, an outlined one higher up (empty inside, nothing
  showing through it), a short arc rising into it, as the app icon's jump.

## What drawing them taught

- At stroke 2 a side-view piece needs about 3 units of height in its top ellipse, or its
  outline fills in and an outlined piece reads as solid. Two such pieces fill the grid,
  which leaves an arc little room.
- A solid piece needs its ring and top's front edge cut out of it (an SVG mask), or it is
  a blob.
- Check a take at the row's 34 dp, not only large: `prototypes/README.md`, "Checking a
  page", with agent-browser.

## Ideas not yet tried

- h simpler: no ring on the solid piece, or no arc, the height alone saying jump.
- c's checkerboard with one piece, or a corner of it, square so it fills the icon.
- The user may draw it: `agents/design.md` says how the user makes images.

## Acceptance criteria

- [ ] The user picks an icon in the prototype
- [ ] It is drawn for the app (`gui::NEW_GAME`, its glyph where home's icons are drawn) and
  checked on the Mac at home's row size
- [ ] The takes left in `prototypes/home.html` and `draughts.js` are removed once built
