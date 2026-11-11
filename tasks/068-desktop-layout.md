# 068: A desktop's layout, tuned by eye

Status: done (2026-11-11; note 5 through task 069)

The user's notes on the desktop layout (2026-11-11), from the Mac and a 27" screen:

1. Settings' board, flat and 3D, its top level with the Game group's top, as the game's
   board meets its corner panels on a large window; and the game's and a puzzle's flat
   board at mid sizes (1280 × 830), whose top sits below the panels'.
2. Home's menu and the setup's column at the top of the side bar, not centered down it.
3. The setup's side bar a little wider, so its choices aren't cramped.
4. On a 27" screen the controls a little larger: `gui::DESKTOP_DP`'s 0.75 points a dp
   is too small there.
5. Tiles thinner on a desktop, with less padding at their sides: the back, the game's
   corner panels, settings' tiles and language. This replaces the 2026-11-11 decision
   that rejected a second set of desktop sizes; record why. Done in task 069 (2026-11-11):
   64 dp taps and 12 dp beside a tile's words on a desktop.

## Acceptance criteria

- [x] Each note built, shot on the Mac at 1280 × 800, a MacBook's full screen, and a 27"
      2560 × 1440 (`--display-scale 1`), and agreed with the user.
- [x] A touch screen's layout unchanged (`--touch on`, the tests' sizes), but for the left
      corner's even spacing, which the user asked for on every screen (task 069).
- [x] `docs/architecture/rendering.md` and `docs/decisions/rendering.md` updated.

## Done (2026-11-11)

Notes 1 to 4, agreed by the user from shots at 1280 × 800 and 27" (`--size 1280x720
--display-scale 1`): `panel::flat_frame`, `settings::level`, `home::DESKTOP_TOP` and
`DESKTOP_COLUMN_W`, and `gui::DESKTOP_DP_LARGE` 0.9 from a 1000 to a 1440-point shorter
side. `test/shell/rest_hover`'s counts moved with home's and the game's desktop layout;
every other output is unchanged.
