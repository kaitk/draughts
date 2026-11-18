# 091: Small fixes

Status: in-progress (all four built 2026-11-17; the drag on Windows not yet checked)

Small bugs and follow-ups noted on 2026-11-16, none urgent.

1. **Mouse drag of the board is choppy.** Dragging the 3D board with a mouse on Windows
   wobbles or jumps instead of following the pointer, already on home (the drag in
   `src/shell/shell.goose`, home's and settings' 3D board), most visibly at the drag's
   limits. Maybe elsewhere too: check the Mac's mouse and trackpad and the game's board.
2. **Switching players with different board sizes.** Switching to a player whose
   draughts has another board size (10×10 to 8×8, `roster::switch_player`) briefly shows
   the pieces off the board during the transition.
3. **A game lost on time, in its replay.** The tablet showed "Watch replay" with "Lost"
   for a game of one move: the clock had run out.
4. **The row note on the tablet.** Home's "Vaata kordust" row in landscape left out
   "Kaotasid · raske".

## Done (2026-11-17)

1. **The drag.** Logged on the Mac, the pointer injected at 1500 px/s by wall-clock time
   (as a mouse moves) in a windowed run, and in a headless test at 60 Hz: the turn and
   the angle down follow the pointer evenly, frames 8.3 ms apart at 120 Hz (one of 479 at
   16.9 ms), no jump at the limits. What was off was the limits themselves: past one the
   pointer went on but the board stopped, and the first move back turned it at once, so
   the board slipped from under the pointer. A drag now keeps what it asked past a limit
   (`rig::Rig.asked`) and turns back only from where it reached it, on home, settings,
   and the game's showcase alike.

   Not explained: anything Windows-only (the mouse's event rate against the display's,
   its present mode). Also seen: the fit (`view3d::fit` in `shell::dragged_view`) shrinks
   the board as it turns, sharpest through the middle (k 2949 at 0° to 2775 at ±5°,
   2% a frame at this pace), which may read as a wobble; keeping the scale through a drag
   would let the turned board overrun its room, so it is left for the user to judge.
2. **Switching players.** The switch happened inside home's frame, after home had laid
   out the old player's 8×8 board, so that frame drew the new player's 10×10 pieces on
   it, and the 3D board kept that image for the ~28 frames it took to prepare the new
   size. The card's switch, new player, and removal now happen at the next frame's
   start (`shell::change_player`); `test/shell/switch_size` checks every frame's layout
   against its pieces (one frame out of step each way before).
3. **On time.** Home's note says "You lost on time · easy", "You won on time · easy", or
   "White wins on time" (Estonian *Kaotasid ajaga*, *Võitsid ajaga*, *Valged võitsid
   ajaga*) where a clock ran out. The history doesn't record how a game ended, so the
   replay and the results don't say it (`docs/decisions/rendering.md`).
4. **The row note.** "Vaata kordust" left only "Võitsid · raske" at its least size;
   "Kaotasid · raske" and every on-time note were left out, and English "Watch replay"
   left out "You lost on time · medium". The row is now "Replay" and "Kordus": every note
   fits, the longest "Kaotasid ajaga · keskmine", checked on the Mac at the tablet's
   1920 × 1200 with its 48 dp bar and 1200 × 1920, and a 20:9 phone's 2340 × 1080. The
   store texts that named the row follow; the release notes of 0.9.0 stay as shipped.
   On the tablet the new build runs; its profile has a game in progress, so the row
   wasn't shown there rather than writing a played game into it.

## Acceptance criteria

- [ ] A mouse drag on home's board follows the pointer smoothly on Windows and the Mac:
      the Mac logged even, the limits fixed; Windows to check
- [x] No piece shows off the board while switching between players of different board
      sizes
- [x] A game lost on time says so, or a recorded decision not to
- [x] The row note checked in Estonian landscape: on the Mac at the tablet's size and
      insets, the layout depending only on those (the tablet's own profile left alone)
