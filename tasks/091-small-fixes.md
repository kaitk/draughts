# 091: Small fixes

Status: todo

Small bugs and follow-ups noted on 2026-11-16, none urgent.

1. **Mouse drag of the board is choppy.** Dragging the 3D board with a mouse on Windows
   wobbles or jumps instead of following the pointer, already on home (the drag in
   `src/shell/shell.goose`, home's and settings' 3D board). Maybe elsewhere too: check
   the Mac's mouse and trackpad and the game's board. Log the pointer and the turn per
   frame first to see whether the input, the frame pacing, or the smoothing is uneven.
2. **Switching players with different board sizes.** Switching to a player whose
   draughts has another board size (10×10 to 8×8, `roster::switch_player`) briefly shows
   the buttons off screen during the transition. Hide them until the new layout is in
   place.
3. **A game lost on time, in its replay.** The tablet showed "Watch replay" with "Lost"
   for a game of one move: the clock had run out. Consider saying so, in the home row's
   note or in the replay ("Lost on time"), if the game records how it ended.
4. **The row note on the tablet.** Since 2026-11-16 a menu row's note shrinks to fit or
   is left out (`gui::row`). Check home's "Vaata kordust" row in landscape on the tablet
   and on the Mac. If "Kaotasid · raske" is left out, shorten the Estonian (for example
   `home.replay = Kordus`).

## Acceptance criteria

- [ ] A mouse drag on home's board follows the pointer smoothly on Windows and the Mac
- [ ] No button shows off screen while switching between players of different board sizes
- [ ] A game lost on time says so, or a recorded decision not to
- [ ] The row note checked on the tablet and the Mac in Estonian landscape
