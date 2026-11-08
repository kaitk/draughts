# 022: Transitions between screens

Status: in-progress (all built and checked on the Mac; checked on the tablet 2026-11-08:
smooth at 90 Hz and idle after, but settings' first opening in a run skips half its
frames, and three kinds read busy where the board passes under the fading panels; see
"On the tablet")

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
- On the tablet: "On the tablet" below.

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
- On the tablet: "On the tablet" below.

## On the tablet (2026-11-08)

The APK built from `8dadb5c`, both orientations (1920 × 1200 and 1200 × 1920, 90 Hz).
Each switch was a real tap (`adb shell input tap`) in a run started with flags, so
`game.bin` was neither read nor written, and recorded with `adb shell screenrecord`,
which writes only changed frames. Span is from the frame showing the button pressed to
the last frame that moves: the 0.25 s plus the pressed frame and the switch frame.

| Transition | Landscape: span, frames, median / max interval | Portrait |
| --- | --- | --- |
| Home to settings, first in a run | 300 ms, 17, 11.0 / **129 ms** | 286 ms, 15, 11.0 / **132 ms** |
| Home to settings, later | 298 ms, 28, 11.0 / 12 ms | 297 ms, 27, 11.0 / 16 ms |
| Settings to home | 264 ms, 25, 11.0 / 12 ms | 308 ms, 28, 11.0 / 16 ms |
| Home to the game (continue) | 291 ms, 26, 11.0 / 17 ms | 281 ms, 26, 11.0 / 17 ms |
| The game to home | 308 ms, 28, 11.0 / 17 ms | 298 ms, 28, 11.0 / 12 ms |
| A friend's setup to play | 303 ms, 28, 11.0 / 16 ms | 283 ms, 27, 11.0 / 13 ms |
| The computer's setup to play (child on black, turned) | 310 ms, 28, 11.0 / 18 ms | 307 ms, 26, 11.0 / 35 ms |
| A won game to home (the card's arrow) | 300 ms, 27, 11.0 / 19 ms | 276 ms, 25, 11.0 / 17 ms |
| The picker to puzzle 1 | 300 ms, 27, 11.0 / 17 ms | 301 ms, 27, 11.0 / 19 ms |
| Puzzle 1 to the picker | 297 ms, 28, 11.0 / 12 ms | 297 ms, 26, 11.0 / 29 ms |

- **Frame times:** apart from settings' first opening, every frame of every transition
  came within 20 ms but two: 35 ms (the computer's play) and 29 ms (puzzle to picker),
  both portrait, both on the switch frame, where smoothstep has barely moved; repeated,
  the same two had at most 21 and 18 ms. The switch frame and the one after are the slow
  ones in all of them (13 to 19 ms); the rest run at the display's 11 ms.
- **Settings' first opening skips half:** the frame that switches to settings stalls
  129 to 132 ms, and the next frame shows the transition about 60% through: settings
  nearly opaque, the board already 10 × 10 and moved (frames 3 and 4 of the landscape
  recording). The stall is `scene::thumbs()` (`app/draughts.goose`, loaded on the first
  frame settings is the screen): with settings opened at launch (`--screen settings`)
  and left, the next home to settings ran smoothly at most 17 ms a frame, as does every
  later opening. Every other transition, the first in a run included, has no such stall.
- **Frames stop:** after each transition the recordings hold no new frame until the
  next tap (gaps of 2.2 to 3.0 s, and 14.8 s after a continue left untouched). Settings
  draws about 2.8 s more for the preview's flash and pulse, then stops; against the
  computer, frames run on for its turn and stop after its move.
- **Idle on the game reached through continue,** `scripts/idle_cpu.sh 60`: landscape
  the program thread 0.01 s (0.02% of a core), the process 1.10 s, 60 voluntary
  switches; portrait 0.02 s (0.03%), 1.17 s, 60. As task 021's game screen.

How it reads, from frames at 25, 50, and 75% of each:

- **Calm:** landscape continue and the game's home, a friend's play, the computer's
  play, and a won game's way home. The board's motion carries them; the panel it
  passes under (the game's right panel at 50%, home's column at 75%) tints one column
  of squares at the board's edge for about 0.1 s, and home's column and the game's
  panels cross-fade text over text in the left column at 50%, which reads as a fade.
- **Busy: home and settings when the sizes differ** (home's game 8 × 8 and the preview
  10 × 10, or the reverse), both orientations. Around 50% both piece sets show at once,
  about 40 pieces in two sizes off each other's squares, with two red rings, and the
  squares switch at the halfway frame (the one large change in the recording). With the
  same size it is calm.
- **Busy: the picker and a puzzle,** both orientations. The board slides under the
  picker's three glass rows, so at 50% it is striped by three translucent bands
  carrying the tiles' outlines, stars, and locks, with a bright seam between rows.
- **Busy: portrait into the game,** worst from the computer's setup. The setup's sheet
  is tall, so at 50% the board's bottom two rows lie under it with its title and back
  button over the pieces, and the game's top bar over its top row; at 75% the bottom
  three rows are still tinted. From a friend's setup at 75% "A friend" lies over the
  bottom row; continue at 50% cuts the bottom row with home's sheet's edge, and the
  game's home at 25% prints the wordmark over it.

Frames and recordings are kept locally, not in git. The notes above already name the
changes for the busy ones: fade the incoming panels in later (on e² rather than e), or
drop the drift for the panel the board passes; slide the game's pieces into settings and
show the preview's on arrival. The stall needs the thumbnails loaded before settings
first opens.

## Acceptance criteria

- [ ] Continue, a friend, settings, and back animate in both orientations (on the Mac; on
  the tablet open: settings' first opening skips half, and three kinds read busy)
- [x] A tap during a transition lands on the new screen
- [x] Headless tests: a transition ends and stops asking for frames
- [x] The game counts no time and the computer doesn't think during a transition
- [x] The tablet draws no frames once a transition has ended
