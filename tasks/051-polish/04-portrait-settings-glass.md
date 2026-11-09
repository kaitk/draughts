# 04: Empty glass under settings' Game tab

Status: done

On a phone in portrait (the Pixel 7a, 2026-11-09), settings' Game tab is as tall as
Look's, so its panel ends in empty glass under the rows (the privacy note now sits at its
foot). Size the panel to its tab, or decide the equal height is wanted and say why.

## Acceptance criteria

- [x] Settings' Game tab without empty glass on the phones, or the reason recorded

## Done (2026-11-09)

In portrait the shown group's glass is its own height and the board takes the rest
(`settings::frame`); landscape's tabs keep the taller group's height, the board beside
them. The Game tab's board grows and the Look tab's stays as before, so the board changes
size when the tab does: headless (`sizes`, `screens3d`, blessed for it) the Game tab's
board at 540 dp went from 247 to 401 dp, at 480 dp from 219 to 356, the foldable's
portrait from 247 to 401, and the 9:16 phone at 480 dp now shows a 155 dp board on the
Game tab where Look shows none. Kept as its own commit so it can be dropped if the
board should stay put.
