# 008-02: The game panel

Status: done (awaiting review)

The panel from 01 working, as rendering.md ("Controls", "Game screen") and
`prototypes/game.html` show it.

## Work

- The side to move on top: a piece of its color with a glow ring, no text.
- The move-hints toggle beside it (`docs/product.md`): mistakes only or moves, one tap.
- Undo (a stack of positions, as `docs/architecture/README.md` says), restart, and back
  (to home once 03 exists; until then it does nothing). Hint shows one good move: the
  computer player's (task 006) when it exists; until then a capture that must be made,
  or else nothing.
- A celebration on a win: a few drifting sparks and the winner's piece, from the solved
  screen's style (`prototypes/solved.html`), then restart or back.
- Buttons can't be confused with the board: a press that starts on the panel never
  moves a piece, and the reverse.

## Acceptance criteria

- [x] Side to move and the hints toggle, in both orientations
- [x] Undo, hint, restart, and back working; tested headless where they change the game
- [x] A celebration on a win
- [x] Checked on the Mac and the tablet; idle still draws nothing

## Outcome (2026-11-07)

- `board/`: the undo stack is in the `Board`, 512 steps of position and last move
  (the oldest go first when full), pushed as each move starts; `undo` (also mid-move,
  bringing back the last move's marks), `restart` (to where the game began, a FEN start
  too), `hint` (the capture taking the most; its piece selected and its target marked
  whatever the hints are, until the next press), and `winner`.
- `game/` (new, no graphics): the game screen. `game::frame` advances the board,
  declares the panel (moved here from `app/panel.goose`) and the celebration, does what
  their buttons ask, and gives the pointer to the board only when the press didn't land
  on the UI. Back returns `game::HOME`, which the app ignores until 03.
- `gui/`: `tile` with four looks (plain, primary, toggle on and off) and a corner radius;
  the dots icon; sparks. Icons are half a tile's shorter side.
- The side to move and the winner are drawn after the UI by the piece pipeline from a
  second storage buffer of four, with a ring right round the disc as the prototype's
  box-shadow draws it; the piece shader now takes the side's depth in radii, so a piece
  of any size has the board's proportions.
- The celebration: the board dimmed to 55%, a glass card with the winner crowned
  popping in, back and restart (primary), and 14 sparks that drift twice each and stop
  after at most 7.2 s, so idle still draws nothing. The panel's piece shows the winner.
- `test/game/game.goose`: undo twice and at the start, undo mid-move, hint with and
  without a capture due and cleared by a press elsewhere, the hinted capture played,
  restart to a FEN start, the toggle, a press from undo released on a target and a
  press from a piece released on undo, the celebration's start, sparks, end, restart,
  and back.

### Compared

Mac screenshots at 1920 × 1200 and 1200 × 1920 for all four seasons, with hints on and
off and a celebration in each orientation, beside `prototypes/game.html` and
`prototypes/solved.html` at the same pixel size. The top row (turn piece, ring, toggle
on and off) matches the prototype in both orientations. The card is the solved screen's,
with the winner's crowned piece in place of the stars. The icons keep the prototypes'
stroke; the design boards' heavier icons and filled bulb were set aside, since the
current ones look right on the tablet.

### On the tablet

All checked by taps over adb in landscape and portrait: moves, the turn piece changing
side, the toggle, hint marking a due capture with hints off, undo, restart held (its
press shows) and released, and the celebration in portrait. Idle, untouched, 60 s: the
program thread 0.01 s of CPU (0.02% of a core) with 60 voluntary switches, the process
1.21 s (the accelerometer, task 011); 30 s starting 12 s after a win's celebration
began: the program thread 0.00 s, 31 switches, so the sparks stop. Over 20 cycles of
home, resume, and rotation (`scripts/lifecycle_memory.sh 20`), one process throughout,
no errors: PSS 255 to 259 MB, native heap 26 MB (30 MB at the first sample), graphics
210 to 215 MB, with the same two 2 MB steps as before.
