# 072: Keyboard and controller focus

Status: todo (implementation waits; scoped 2026-11-11)

Every screen played with the keyboard alone, and later a gamepad, as a desktop game is
expected to be: arrow keys move a visible focus between the controls, Enter presses the
focused one, Escape goes back as it does now (`host::back`). The gamepad of task 064's
"Controllers" criterion feeds the same moves through SDL's gamepad API, so the screens
don't change for it. Home's menu comes first, with a Quit row on a desktop.

Built once in `gui`, not per screen: the UI is immediate mode, each control declared each
frame with its id, so focus is an id in `gui::Gui` as `active` and `under` are.

## Plan

1. Focus in `gui`: `Gui.focus`, an id or 0. Each control that takes focus (`row`,
   `button`, `icon_button`, `bare_x`, the choice tiles) records its id and rect in a
   fixed array reset each frame, in declaration order. Nothing allocates.
2. Moves: up and down step through that order; left and right, and up and down on a
   grid (the setups' tiles, settings' groups), go to the nearest control that way by
   rect. Enter clicks the focused control as a release over it does. The moves come in
   as `gui::Input` fields from `host::input`, so tests can drive them.
3. Look: the focused control drawn lit as `hover` lights the one under the mouse (task
   066), perhaps with a ring if hover's light reads too faintly as focus; to agree with
   the user. The first arrow press focuses the screen's primary control (Continue on
   home); moving the mouse or a tap clears focus, as games do. A screen change focuses
   the new screen's primary control while keys are in use.
4. Home's menu with a Quit row: on a desktop only (`host::DESKTOP`), the last row after
   settings in the landscape column, `gui::CLOSE` and a new `HOME_QUIT` string in every
   `strings/` file, picking `home::EXIT`. Not in the portrait sheet, where the
   2026-11-08 decision rejected a last row for taking the board's room (agreed
   2026-11-11). The corner X and the Quit row are one way out shown two ways, as settings
   is the gear or a row: the X shows only where the row doesn't (the portrait sheet, a
   column too short for it, Android), so no screen has both (agreed 2026-11-11).
   `menu_height` counts the row, so `gear_beside` still folds settings into the gear
   where the column doesn't fit, and the row goes back to the X with it.
5. The other screens: settings, the setups, puzzles' picker, who's playing, the game's
   panels. The board itself (a cursor on the squares, choose a piece and its target) is
   a further step, with task 067's lit square as its likely look.
6. Gamepad, with task 064: D-pad and left stick move, A presses, B goes back, with
   gamepad glyphs where a key's name would show.

## Acceptance criteria

- [ ] Home's menu worked with the arrow keys and Enter on the Mac, the focus visible and
      its look agreed with the user.
- [ ] The Quit row on a desktop's landscape column only; never on Android, iOS, or with
      `--touch on`; the corner X shown only where the row isn't; a touch screen's layout
      unchanged.
- [ ] Every screen but the board worked with the keyboard alone.
- [ ] A focus that rests draws nothing; a key press draws one frame
      (`docs/architecture/rendering.md`), and the frame loop allocates nothing.
- [ ] A test drives the keys through home and a setup and checks the focus and the pick.
- [ ] The board played with the keyboard (step 5), agreed with the user.
- [ ] A gamepad does all of it (with task 064).
- [ ] `docs/architecture/rendering.md` and `docs/decisions/rendering.md` updated, the
      Quit row recorded as narrowing the 2026-11-08 decision against a last row.
