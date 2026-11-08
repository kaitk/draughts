# 031: A better win

Status: in-progress

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

## Acceptance criteria

- [x] Takes prototyped (a, b, c above) and one picked by the user (a)
- [ ] Built on the Mac and the tablet, in both orientations
- [ ] Ends still: no frames once it has played (the tablet's `scripts/idle_cpu.sh`)
- [ ] Headless test: the celebration ends and stops asking for frames
