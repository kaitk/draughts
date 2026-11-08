# 031: A better win

Status: done

The win (`docs/architecture/rendering.md`, "A win"; `game::celebrate`) dims the board,
pops the winner's crowned piece in on a glass card, and drifts fourteen glowing sparks up
over the board twice. The user (2026-11-08): it could be better; the particles in front
look odd. They float over the card and the pieces as loose dots, unrelated to the game.

## Work

- Two or three takes in `prototypes/` (checked with agent-browser, as the other screens
  were), each a still at its peak and a strip of frames, for the user to pick. Ideas to
  weigh: no particles at all, the winning side's pieces answering instead (a ripple of
  their glow across the board, the last move's piece lifting); sparks only behind the
  card, or rising from the winning piece rather than across the board; the card itself
  calmer, sliding up with the board dimming under it. Calm and warm for children of about 5
  to 8, as the rest of the look: no confetti, no shake.
- Build the pick in `game::celebrate` and the drawer, keeping it short (about 2 s) and
  then still, so the app goes idle.

## Takes (2026-11-08): a picked

The user picked a, the pieces answer (2026-11-08). The main session had recommended c.


`prototypes/win.html`, in the game's layout with a Russian game white has just won (e3
over f4 to g5). Every moment is a function of the time since the win, as
`game::celebrate` draws it; `&t=` holds one, a click plays it again. Each uses only what
the renderer has: SDF discs and rings, rounded rects, one radial gradient. The card is as
now (356 × 300, back and restart), but slides up 28 px as it fades in instead of
appearing at once.

- **a, the pieces answer** (still from 1.7 s): no particles. The winning piece lifts on
  its square with its glow ring; a ring of glow, with its square lit, passes across the
  winner's other pieces outward from it (each 0.6 s, 0.08 s later per square of
  distance), each lifting a little as it passes. Then the board dims under the winning
  piece, which stays lit above the dim, and the card slides up with the crowned piece
  fading in.
  file:///Users/kaitkasak/projects/personal/draughts/prototypes/win.html?take=a
- **b, light behind the card** (still from 2.2 s): the board dims and the card slides up
  at once; a warm glow blooms behind the card and settles to two thirds; seven sparks
  rise once from behind the card's top edge, 60 to 130 dp, and fade. The crowned piece
  pops in gently (from 0.85, a small overshoot).
  file:///Users/kaitkasak/projects/personal/draughts/prototypes/win.html?take=b
- **c, the winning piece comes to the card** (still from 1.75 s): the piece that won
  lifts with its ring, then glides on a gentle arc from its square to the card's spot,
  growing to the card's size, as the board dims and the card forms round it; there it
  takes its crown, and one soft ring of glow goes out from it once.
  file:///Users/kaitkasak/projects/personal/draughts/prototypes/win.html?take=c

Screenshots, local and out of git, under
`/private/tmp/claude-501/-Users-kaitkasak-projects-personal-draughts/bbae0a0e-8c6b-4af9-b086-c4d3ee55c554/scratchpad/win031/`:
`now/` the app's present win at frames 40 to 450 (`strip-land.png`, `strip-port.png`,
`peak-*.png`, 960 × 600 and 600 × 960 at 2×), and `a/`, `b/`, `c/` each take at 0 to
2.5 s (`strip-land.png`, `strip-port.png`, `peak-land.png`, `peak-port.png`, 1280 × 800
and 800 × 1280).

## Built (2026-11-08)

Take a, as `docs/architecture/rendering.md` ("A win") describes it, with the prototype's
timing: `game::cheer` puts the win on the board's pieces after `board::fill`
(`shell::fill` calls it on the game screen), `game::celebrate` declares the card from
1.0 s, and the sparks are gone (`gui::spark` and the UI shader's spark kind with them).

- **Layers.** The winning piece must be over the dim but under the card, and the card
  is in the UI's draw, after every board piece. So the dim moved out of the UI: the
  board pass darkens the board by `scene.z` (the board's new `dim`), and the piece
  shader darkens each piece by its own amount, which is exact for a black fill over
  both. The winning piece gets 0 and is moved to the end of the list, over its
  neighbors. The piece record grew from three float4s to four (`board::Piece.win`: dimmed
  by, square lit, the square's half side in radii); the lit square is drawn by the piece
  shader under the piece, its quad already covering the square. No other shader change.
- **The card** is the old one, faded and slid with `gui::fade` (as transitions do), its
  taps where it rests; it isn't declared before 1.0 s, so an invisible card takes no tap.
- **Still.** `game::animating` asks for frames until the celebration's still moment,
  and `game::frame` reports one more change on the first frame past it, so the frame at
  rest is drawn; then nothing. `--win T` holds a win at T s for screenshots.

Edge cases:

- **Which piece wins**: the last move's, if it is the winner's, whichever way the game
  ended (the side out of moves or out of time was to move after it). Against the
  computer this is the child's piece or, when the computer wins, the computer's last
  moved piece, and the computer's pieces answer.
- **A win on time**: the flagged side was to move, so the last move was the winner's and
  its piece lifts as for a capture. With none to lift (no last move, as in a position set
  up already won, or a flag while the last move is still showing) the lift and the wave
  are skipped and the celebration starts at the dim: dim from 0 s, card from 0.1 s,
  still from 0.8 s.
- **10 × 10**: the wave can reach a piece 12.7 squares away, passing it by 1.77 s; the
  still moment is computed at the win from the winner's farthest piece.
- **A turned board**: distances are in board squares, so the same pieces answer in the
  same order; the pieces' squares come from `board::hit`, which knows the turn.
- **Puzzles** don't use the celebration (their own solved state, `shell/puzzle.goose`);
  unchanged.
- **Leaving** for home or settings drops the card and the dim at once, as before (the
  celebration is drawn only on the game screen).

Checked:

- `test/game/win.goose` (new): the moments of a Russian win (the winning piece lifted,
  ringed, undimmed, and drawn last; the wave's pieces in order of distance with their
  squares lit; the dim; the card's tiles sliding and fading in; the crowned piece fading
  in), 103 frames at 60 Hz from the win, the last at 1.7 s, then none; International,
  still at 1.77 s; a position set up won, still at 0.82 s; a turned board.
  `test/expected/game.out` changed where it printed the sparks and the card at the
  win's first frame: the card now comes at 1.0 s. TinyCC and `--build`: 30 passed.
- Mac, 960 × 600 and 600 × 960 at 0.2, 0.6, 1.0, 1.4, 1.7, 2.5 s, beside the prototype's
  take a frames: the same lift, wave, dim, and card; also 10 × 10 and a turned board
  (screenshots local, in the session's scratchpad).
- Tablet (USB, `am start -S`, a tap from the prototype's position, `screenrecord`):
  landscape 194 frames over 2.13 s from the tap, frame time median 11.0 ms and max
  12.0 ms during the win (90 Hz, none over 20 ms); portrait median 11.0 ms, max 12.4 ms
  during the win. `scripts/idle_cpu.sh 60` on the still card in portrait: program
  thread 0.03 s (0.05%), process 1.07 s, 60 voluntary switches: one wakeup a second, no
  frames.

## Acceptance criteria

- [x] Takes prototyped (a, b, c above) and one picked by the user (a)
- [x] Built on the Mac and the tablet, in both orientations
- [x] Ends still: no frames once it has played (the tablet's `scripts/idle_cpu.sh`)
- [x] Headless test: the celebration ends and stops asking for frames
