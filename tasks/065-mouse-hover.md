# 065: Light the tile under the mouse

Status: todo (before task 064's Steam release)

A desktop's window is laid out for a mouse since 2026-11-11 (0.75 points a dp at most,
`gui::DESKTOP_DP`), but nothing shows what the pointer is over: a tile only answers when
pressed. Light the tile under the mouse, on a desktop only.

How (scoped 2026-11-11, half a day to a day):

- Every tile goes through `gui::hold`, which knows the pointer (`g.input.at`): keep the
  hovered id there, and fade it in and out as `set_down` and `pressed` fade a press.
- The UI shader takes the fade in the tile's spare `extra.z`, and lifts the fill a
  little and the border more for it, in each style that takes a tap (PLAIN, PRIMARY,
  CHOICE, CHOSEN, ON, OFF, ROW, ROW_PRIMARY, FLOAT, the icon button). Build the app after
  the shader change (`agents/testing.md`).
- The app draws only when something changed (`docs/architecture/rendering.md`): a move
  of the mouse wakes a frame only when the hovered tile changes or its fade runs.
- Off on a phone and a tablet, and with `--touch on`: Android leaves the pointer where
  the last touch was, which would leave the tapped tile lit.

The fade, not a motion (the user and the agent, 2026-11-11): about 0.1 s in and out, as
long as the press's (`gui::PRESS`, 0.12 s), so a sweep across a row doesn't flicker; no
growing or lifting, which would make the screen busy under a child's mouse and blur the
press, the one tile that moves.

## Acceptance criteria

- [ ] The tile under the mouse lit with a short fade on the Mac, in every tile style that
      takes a tap, and nothing lit on Android or with `--touch on`.
- [ ] A dimmed tile (off, taking no tap) stays unlit.
- [ ] The idle app still draws nothing while the mouse rests, and a move within one tile
      draws nothing new.
- [ ] A test in `test/gui/` drives the pointer over a tile and off it and checks the fade.
- [ ] `docs/architecture/rendering.md` ("Controls", the states) and
      `docs/decisions/rendering.md` say how a hovered tile looks and why.
