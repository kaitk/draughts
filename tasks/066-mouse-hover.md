# 066: Light the tile under the mouse

Status: done (2026-11-11)

A desktop's window is laid out for a mouse since 2026-11-11 (0.75 points a dp at most,
`gui::DESKTOP_DP`), but nothing shows what the pointer is over: a tile only answers when
pressed. Light the tile under the mouse, on a desktop only.

How (scoped 2026-11-11, half a day to a day):

- Every tile goes through `gui::hold`, which knows the pointer (`g.input.at`): keep the
  hovered id there, and fade it in and out as `set_down` and `pressed` fade a press.
- The UI shader takes the fade in the tile's spare `extra.z` and mixes in the glow tint
  and border for it, in each style that takes a tap (PLAIN, PRIMARY,
  CHOICE, CHOSEN, ON, OFF, ROW, ROW_PRIMARY, FLOAT, the icon button). Build the app after
  the shader change (`agents/testing.md`).
- The app draws only when something changed (`docs/architecture/rendering.md`): a move
  of the mouse wakes a frame only when the hovered tile changes or its fade runs.
- Off on a phone and a tablet, and with `--touch on`: Android leaves the pointer where
  the last touch was, which would leave the tapped tile lit.

The look: the chosen tile's, much fainter (the user, 2026-11-11). A chosen tile is the
theme's glow at 22% with a 2 dp glow border (CHOSEN, `src/app/widgets.goose`, the glass
tile); a hovered one takes the glow at about a third of that, a tint of about 8% and a
1 dp glow border at about 40%, whatever its own style, so the mouse shows in the theme's
color everywhere. Fainter by far than chosen, so a child still tells the tile they
picked (settings' choices always have one) from the one the mouse is over. A chosen or
lit tile under the mouse brightens its own glow a little instead. Only the press moves
a tile (it sinks to 0.96 today); hover doesn't scale or lift.

The fade, not a motion (the user and the agent, 2026-11-11): about 0.1 s in and out, as
long as the press's (`gui::PRESS`, 0.12 s), so a sweep across a row doesn't flicker; no
growing or lifting, which would make the screen busy under a child's mouse and blur the
press, the one tile that moves.

## Acceptance criteria

- [x] The tile under the mouse lit with a short fade on the Mac, in every tile style that
      takes a tap, in the theme's glow, clearly fainter than a chosen tile, and nothing lit
      on Android or with `--touch on`.
- [x] A dimmed tile (off, taking no tap) stays unlit.
- [x] The idle app still draws nothing while the mouse rests, and a move within one tile
      draws nothing new.
- [x] A test in `test/gui/` drives the pointer over a tile and off it and checks the fade.
- [x] `docs/architecture/rendering.md` ("Controls", the states) and
      `docs/decisions/rendering.md` say how a hovered tile looks and why.

## Done (2026-11-11)

- `gui::hold` notes the topmost tile under the pointer each frame (`g.under`); the next
  `gui::begin` makes it `g.hovered`, the one it left `g.left`, each fading over
  `gui::PRESS` and turned from where it stands; drawers pass `gui::hover(g, id)` in
  `extra.z`. Hovering by the first `hold` over the pointer flipped between who's card
  and its tiles every frame, so the topmost one wins, a frame later.
- Shots at 1280×800 points, `--touch off --board flat`, `--mouse` on settings' Spring
  beside the chosen Winter, birch: the tile's inside (R, G, B) 24.0, 30.7, 21.3% plain,
  26.4, 34.6, 27.5% hovered, 28.4, 37.4, 38.3% chosen; its edge #566352 plain, #7096A0
  hovered (1 dp), #8FD4FF chosen (2 dp). Sunset: 45.5, 34.8, 31.0% plain, 49.9, 37.5,
  32.5% hovered, 53.4, 36.5, 29.8% chosen. The game's Settings, the hint, and the eye
  light too; two runs of 2000 and 4000 frames are identical, the fade done.
- At rest with the mouse away, `--rest 15` drew 0 frames on settings and home. Moves
  can't be scripted here (`agents/testing.md`), so `test/shell/rest_hover` rests the
  pointer on every 20 px point of home, settings, the game, and the puzzles at 1280 × 800:
  two frames on, none asks for more. The user's own run, sweeping and clicking over
  settings, drew 943 frames in 15 s of real moves; hover itself was fine.
