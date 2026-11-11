# 068: A desktop's layout, tuned by eye

Status: in-progress (before task 064's Steam release)

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
   that rejected a second set of desktop sizes; record why.

## Acceptance criteria

- [ ] Each note built, shot on the Mac at 1280 × 800, a MacBook's full screen, and a 27"
      2560 × 1440 (`--display-scale 1`), and agreed with the user.
- [ ] A touch screen's layout unchanged (`--touch on`, the tests' sizes).
- [ ] `docs/architecture/rendering.md` and `docs/decisions/rendering.md` updated.
