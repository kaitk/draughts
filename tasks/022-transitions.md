# 022: Transitions between screens

Status: in-progress (home to settings first, 2026-11-08)

Optional, after the MVP (2026-11-07): quick, not instant, changes between screens for
feel: home's menu fading or sliding away on continue while the board grows into its
place in the game, settings fading in, the background going from sharp to blurred.
About 0.2 to 0.3 s each.

The user (2026-11-08): wanted if they are easy, starting with home to settings and back;
the rest follow if that one is cheap and keeps the app idle afterwards.

## Notes

- The shell keeps one transition: when it started and the screen left. While it runs,
  `shell::animating` is true, so frames come; after it the app is idle again.
- `gui` gets a layer multiplier (opacity, offset) applied in `gui::add`; during a
  transition the shell declares both screens, the old fading out and the new in, and
  only the new one takes input.
- The board's rect eases from home's `board::layout_at` to the game's (`panel::layout`). With the 3D home
  board (task 015) its camera tilt eases to top-down as well.
- The board pass crossfades the sharp and blurred photograph with one uniform.
- Settings' preview is home's board: opening settings slides it to the right half
  (portrait: up) and the choices come in beside it, rather than a new board appearing.
- Prototype the takes first, as for the other screens.

## Acceptance criteria

- [ ] Continue, a friend, settings, and back animate in both orientations
- [ ] A tap during a transition lands on the new screen
- [ ] Headless tests: a transition ends and stops asking for frames
- [ ] The tablet draws no frames once a transition has ended
