# 100: An antique chess clock on the table

Status: todo

A prop on the 3D board's table (task 095), after the taken pieces (task 099): a German
chess clock of about 1900, era-appropriate for the Baltic German manor (the user,
2026-11-20), modelled from the references in `design/props/chess-clock/` (local; its
README lists them): two round drum movements in nickel with brass bezels, white dials
with Arabic numerals and a small seconds dial, blued spade hands, a cast brass rocker with
scrolls joining them on top, on a walnut plinth with a small plaque. An English Jaques
timer was set aside for it.

A modelling session of its own: the mesh as data (`src/model3d/`, as the table's), its
materials in the bake and the lit pass, placed on the table beside the board where it
doesn't hide the board at any view. Later, perhaps: the rocker tipped to the side to
move, and the hands showing the game's clock.

The German clock is the one to try, not settled: its drums, rocker, and scrolls may not
render well at the table's size, and a plainer case is the fallback (2026-11-20).
Whichever case, the dial is `dial-seconds-01.png` (2026-11-20): cream enamel, Art Nouveau
Arabic numerals, a small seconds dial under the 12, no hands. It is generated flat
artwork with no light in it; crop off its painted brass ring, which the modelled bezel
replaces. The hands are flat cut-outs from `hands-01.png` (hour and minute, blued spade)
and `hand-seconds-01.png` (blued, a counterweight tail). `flag-01.png`, a brass lever
with a red tab, is the flag that drops at the hour; flags came in around 1900 and the
references have none, so it is optional. The images the app uses go in git once chosen,
cut to the size they show at.

The hands, when they show a timed game's clock (5+3, 10+5): the minute hand moves once
a minute, the seconds hand once a second, and each move is a redraw, against drawing
only on a change (`docs/architecture/rendering.md`). So the seconds hand runs only on a
desktop or a laptop, only while the clock is on screen and the game is timed; on a phone
or a tablet, and in an untimed game, the hands stand still (2026-11-20).

## Acceptance criteria

- [ ] The clock on the table beside the board, lit and shadowed with it, at every view
- [ ] Its dials readable at the rest view on the tablet
- [ ] In a timed game on the Mac, the hands show each side's time left, and the frame
  loop redraws no more than once a second for them; still on the tablet
- [ ] GPU time and memory against before on the Mac and the A33, in this file
