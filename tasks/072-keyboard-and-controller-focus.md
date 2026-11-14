# 072: Keyboard and controller focus

Status: in-progress (built and merged into main 2026-11-12, the gamepad in goose_gfx; its
rest on the Mac, the tablet and iOS to measure)

Every screen played with the keyboard alone, and a gamepad, as a desktop game is expected
to be: arrow keys move a visible focus between the controls, Enter presses the focused
one, Escape goes back (`host::back`). Built once in `gui` (`gui::focus_keys`,
`gui::Spot`, `gui::grid`, `gui::group`), described in `docs/architecture/rendering.md` and
decided in `docs/decisions/rendering.md`: the focus ring, home's Quit row on a desktop,
held keys repeating, the board's cursor, Tab between groups, and the gamepad (D-pad or
stick, A, B, LB and RB) through goose_gfx's `SYSTEM_GAMEPADS` (the fork's `gamepad-wake`).
The app shows no key names, so there are no gamepad glyphs to replace.

At rest with a PS5 pad on Windows (`--rest 25`): 0.14 s of CPU in 25 s, nothing drawn.
Before the gamepad moved into goose_gfx, the Mac's pad cost 0.01 s in 20 s through the
GameController framework's change handler.

## Left

1. By hand on the Mac: the held-key repeat, Enter holding a hold tile, the board with the
   keys flat and 3D, Tab (`--keys` can't hold a key).
2. By the user: a real pad's buttons, D-pad, stick, and shoulders, and `--rest` with it on
   the Mac, the tablet, and iOS (the Apple code only syntax-checked).
3. A focused control scrolled into view (`test/gui/scroll`) never seen in the app, as no
   list scrolled at the sizes tried.

## Acceptance criteria

- [x] Home's menu worked with the arrow keys and Enter on the Mac, the focus visible and
      its look agreed with the user.
- [x] The Quit row on a desktop's landscape column only; never on Android, iOS, or with
      `--touch on`; the corner X shown only where the row isn't; a touch screen's layout
      unchanged.
- [ ] Every screen but the board worked with the keyboard alone.
- [ ] A focus that rests draws nothing; a key press draws one frame
      (`docs/architecture/rendering.md`), and the frame loop allocates nothing.
- [x] A test drives the keys through home and a setup and checks the focus and the pick
      (`test/gui/focus`, `test/shell/home_keys`).
- [x] The board played with the keyboard, the look agreed 2026-11-12
      (`test/game/board_keys`).
- [ ] A gamepad does all of it (with task 064): built, checked against SDL's virtual
      gamepad; a real one's buttons to try.
- [x] `docs/architecture/rendering.md` and `docs/decisions/rendering.md` updated.
