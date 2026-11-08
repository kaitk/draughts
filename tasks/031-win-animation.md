# 031: A better win

Status: todo

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

## Acceptance criteria

- [ ] Takes prototyped and one picked by the user
- [ ] Built on the Mac and the tablet, in both orientations
- [ ] Ends still: no frames once it has played (the tablet's `scripts/idle_cpu.sh`)
- [ ] Headless test: the celebration ends and stops asking for frames
