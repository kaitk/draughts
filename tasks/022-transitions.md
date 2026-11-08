# 022: Transitions between screens

Status: in-progress (home to settings, home to the game, the photograph's crossfade, and
the puzzles to a puzzle built and checked on the Mac, 2026-11-08; the tablet check is
open)

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

## Home to settings and back (2026-11-08)

Built as the notes planned, with two changes found in the code. It took about 25 minutes,
reading included, and about 12 of those were building it. There was no prototype: the
notes described it.

- **What it does:** 0.25 s, smoothstep. The board slides and resizes from home's place to
  settings'. In landscape it moves right, about 110 px at 1280 × 800. In portrait settings'
  title row comes above the board, so it doesn't go up as the notes guessed: it goes down
  about 30 px as it shrinks from 640 to 543 px at 800 × 1280. Home's column or sheet fades
  out and settings' fade in, both drifting 40 dp the way the board moves. The photograph
  stays sharp. Back reverses it, and back during it turns it round where it is.
- **Fading after declaring, not a layer set before:** a screen's quads are faded and
  moved after both are declared (`gui::fade` over a range of `g.quads`). The way the board
  moves, and so the drift, is known only once both screens have laid it out. The fade is
  the quad's `extra.w`, which the UI shader multiplies its result by. Input is the
  separate `gui::listen`: the screen left is declared with no pointer, so a tap lands on
  the screen come to. Its hit rects are where it will rest, at most 40 dp from where it
  is drawn.
- **One board, two piece sets:** the board is one rect sliding, drawn once. But settings'
  preview is a board of its own on a fixed position (white bound to capture two, to show
  the hints and kings), and home shows the game. So as the board slides the game's pieces
  fade out under the preview's (`board::under`, from `shell::fill`). `MAX_PIECES` went
  from 48 to 96 for that, which uploads 2.3 KB more per drawn frame. The marks switch
  halfway. So do the squares when the game and the preview differ in size (the game 8 × 8,
  the preview 10 × 10 by default). The other way would be to slide the game's pieces and
  show the preview's position on arrival. It is a few lines to change if the crossfade
  reads as busy on the tablet.
- **The preview's wrong move** is staged for when the board arrives, so its red ring
  flashes once the board is in place, not while it slides.
- **The switch frame:** the frame in which a tap switches screens shows what it declared,
  and the state the app fills and draws agrees with it. At the start that is the screen
  left as it stands. When the transition is turned round, it is the same moment the other
  way, so the board doesn't jump: 650, 657, then 650 px on the frames around a back.
- **Quads:** 352 of the 512 in a landscape transition frame (settings 278, home 74).
- **Development flags:** `--go settings|home` switches on the second frame through the
  transition, and `--hold T` holds it at T for a screenshot (`docs/development.md`).

Checked:

- Tests: `test/shell/transition.goose`, both orientations. It covers the frames and the
  board easing all one way. The frame after the end is drawn, then no frame is asked for
  (settings once the preview's flash and pulse are over). A tap where home's continue was
  lands on a settings tile, back mid-way turns it round, and settings reached through the
  transition match settings opened straight. `test/shell/shell.goose` now idles past a
  transition before its next tap. All 29 tests pass through TinyCC and built at -O2.
- On the Mac, at 960 × 600 and 600 × 960: frames at 25, 50, and 75% both ways. Home,
  settings, and the game at rest are byte-identical before and after the change. Settings
  and home reached through the transition are byte-identical to them.
- Not yet on the tablet.

## The rest on this base

Reviewed by the main session (2026-11-08): worth it. The mechanism is generic (every
switch goes through `shell::go_to`, gui's `listen` and `fade`, `board::under`), about
half of the shell's change is home and settings split into functions, and the rest of
the screens would add roughly 150 to 250 lines. Recommended next: continue and a new
game (the board growing into the game) with the sharp-to-blurred crossfade, the ones
seen most; the picker and puzzles optional; the setups' column fade not worth it. Watch
on the tablet: home's game and the preview in different variants switch square size
halfway through the slide.


- **Continue (the board growing into the game):** easy, about an hour. Add the pair to
  `shell::animates`. Teach `shell::still` to declare the game with no pointer. It must not
  run the clock or the computer: call the panel's drawing without `game::frame`'s logic,
  or freeze it for the frame. One board, so no piece crossfade. The photograph goes sharp
  to blurred (below). Puzzles, a friend's play, and the game's settings are the same work
  again, a little each.
- **The photograph's sharp to blurred crossfade:** easy, under an hour. One uniform in
  the board pass, `scene.y`'s brightness and a mix of the two textures, both bound. The
  shell passes the mix with `sh.sharp`. The glass copy stays as it is.
- **Setups (a friend, the computer, in home's column):** easy for a fade, about an hour.
  The menu and the setup are one screen with `sh.setup`, so they need a transition on the
  setup too, or the setup as its own screen number. The board stays still; the column's
  content crossfades, its height eased.
- **The 3D home board (task 015)** adds its camera tilt to the eased layout when it comes.

## Home and the game, the photograph, a puzzle (2026-11-08)

Built on the base above in about 35 minutes, reading included. The same 0.25 s,
smoothstep, 40 dp drift.

- **Continue, play, and the game's home:** the board grows from home's place into the
  game's (`panel::layout`): at 1280 × 800 from 560 px at x 580 to 720 px at x 280, at
  800 × 1280 from 620 px at y 128 to 752 px at y 218. Home's column fades out under the
  game's panels. One board, so no piece fades. Play from a setup leaves with the setup
  as it was (`shell.left`, home's column when it was left), so its board, the game play
  starts (task 034), grows into the game without a jump, turned for black against the
  computer as it was. Back during it turns it round where it is (the board's x 386, 369,
  then 386 px on the frames around a home tap at 1280 × 800). The switch frame shows
  what was declared, as between home and settings.
- **The game frozen:** `game::frame` takes `frozen` while the transition into the game
  runs: no clock tick and no `think`; the clock counts from the frame after the end,
  never the gap across it. Leaving, the shell pauses the game (as any screen but the game
  does) and declares it with `game::still`, which declares the panels and a win's card
  and changes nothing.
- **A won game leaving:** its card fades out with the panels, and its dim, the winning
  piece's lift, and the glow fade with them (`game::cheer` takes a share: the game's
  `mix`). `gui::fade` now multiplies a quad's fade into the one it has, so a card fading
  in during a transition fades further. The other way (continue into a won game) fades
  them in.
- **The photograph:** `shell.blur` replaces `sharp`, eased with the board between the two
  screens' (0 home, settings, and the picker; 1 the game and a puzzle). The board pass
  takes it in `scene.x` (0..1, or -1 with no photograph, which was `has`), the
  brightness 1.0 to 0.8 in `scene.y`, binds the sharp texture beside the blurred one,
  and mixes them only between the ends: at rest it samples one, so the screens at rest
  are byte-identical. The glass copy is unchanged.
- **A puzzle from the picker and back:** cheap, so done. The board grows out of the
  tapped puzzle's tile (`picker::frame` reports the tile of a puzzle, `shell::in_tile`)
  into its place, and shrinks back into it on the way out; at rest on the picker it lies
  off the screen as before. The picker's board is the puzzle's now (`board_of`, `which`),
  so no other board fades under it. Next goes on to the next puzzle at once, as before.
- **Quads:** a landscape frame between home and the game declares 130 of the 512 (home
  77, the game 53); from a friend's setup 185 (the setup 132); from the picker to a
  puzzle 141. Pieces over the UI: at most 4, the limit (the computer's setup's two
  beside a clocked game's two; a won game's two beside home's wordmark).
- **Found in passing:** a game against the computer playing white, opened straight (a
  restored game, or `--computer white`), drew its pieces unturned on a turned board,
  since `shell.came` was only set by home and settings; every screen sets it now, and
  the at-rest shot of that game changed to the turned one. The `--win` flag keeps a
  negative start before 3 s of run time; `--go` waits for it.
- **Watch on the tablet:** while the board grows into the game it passes under the
  game's right panel (landscape) or home's sheet and the game's top bar (portrait) as
  they fade, and a puzzle's board grows from behind the picker's glass rows. Each lasts
  under 0.15 s at low opacity on the Mac; if it reads as busy, fade the incoming panels
  in later (on e² rather than e) or drop the drift for the panel the board passes.
- **Development flags:** `--go game|play|puzzles|puzzle` beside `home` and `settings`;
  `--go` waits for `--tap`s and a `--win` to have played out, so a won game's way home
  can be shot; `--go play` leaves `settings.txt` alone; `--hold 1` ends a transition at
  once (`docs/development.md`).

Checked:

- Tests: `test/shell/game_transition.goose` (continue and home both ways, both
  orientations: the frames, the board easing one way and growing, the end then no
  frames, take back mid-way landing on the game, the game's home mid-way turning it
  round, play from a friend's setup with its small boards fading and its board 8 × 8 all
  the way, black's clock and the computer's ask unchanged through both transitions and
  counting after, a won game's dim, lift, and card fading, and the game reached as the
  game opened straight) and `test/shell/puzzle_transition.goose` (the board from the tile
  and back, the end then no frames, the way out mid-way turning it round, the puzzle as
  opened straight). `test/shell/shell.goose`, `setup.goose`, and `puzzles.goose` idle
  past a transition before their next tap; no expected output changed. All 36 tests pass
  through TinyCC and built at -O2.
- On the Mac, at 960 × 600 and 600 × 960: frames at 25, 50, and 75% for home to the game,
  the game to home, a friend's play, the computer's play (turned), a won game to home,
  the picker to a puzzle, and back. Home, the game, a friend's setup, a won game, a
  puzzle, and the picker at rest are byte-identical before and after the change;
  settings vary run to run by their flash as before; the game against the computer
  playing white changed (turned, above). The game, home, a puzzle, and the picker reached
  through a transition are byte-identical to them opened straight.
- Not yet on the tablet.

## Acceptance criteria

- [x] Continue, a friend, settings, and back animate in both orientations (on the Mac)
- [x] A tap during a transition lands on the new screen
- [x] Headless tests: a transition ends and stops asking for frames
- [x] The game counts no time and the computer doesn't think during a transition
- [ ] The tablet draws no frames once a transition has ended
