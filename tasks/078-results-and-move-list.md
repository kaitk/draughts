# 078: The results screen, the move list on phones, and the marks explained

Status: in progress

The user's review of task 074's results screen at the Pixel 7a's landscape size
(2026-11-13):

1. The draughts' tiles at the head's right (International, Brazilian, Russian with their
   ratings) are hard to see: the unchosen ones are glass on a bright background.
2. The move list's setting (Off, Moves, Marks) is on the results screen and in settings:
   once is enough, in settings, and what Moves and Marks do is unclear there.
3. **A**: on phones the moves of the game in progress show nowhere (the Pixel 7a and the
   iPhone). In landscape at least, and in some form in portrait, there should be a line
   of the last move, opening the whole list (task 074's take d and open question 3).
4. **B**: a mark (?!, ?, ??, the star, the only move) explains itself when touched, or
   under the mouse.
5. **C**: a past game opens from the results screen with its whole move list, and beside
   it a board to replay it on; a game replayed counts neither as the game to resume nor in
   the results (task 074's open question 9, the prototype's `view=replay`).

Task 074 carries the rest of the history's work; this one these points.

## Steps

- [x] 1 and 2 fixed in the app: the tiles readable, the setting only in settings with a
      line saying what each choice shows
- [ ] A, B, and C prototyped in `prototypes/history.html`, for the user to choose
- [ ] The chosen takes built, checked on the Mac at the Pixel's and the iPhone's sizes,
      then on a phone

## Acceptance criteria

- [x] The results screen's head readable on every season's background
- [x] The move list's setting in one place, its choices explained
- [ ] A phone in landscape shows the last move and opens the list; portrait as chosen
- [ ] A mark explains itself on a touch and under the mouse
- [ ] A past game's moves listed and replayed on a board, touching neither resume nor the
      results

## Notes

- 1 and 2 (2026-11-13): the draughts' tiles on one glass as the puzzles' switch; the move
  list's line beside its tiles where the group's width leaves room. Under them always,
  the tablet's landscape preview went from 242 to 137 dp; beside, it keeps its size in
  every stacked landscape, and portrait's board gives up 24 to 36 dp (`test/shell/sizes`).
  The results panel's freed room shows the levels on a phone in landscape. Checked on
  the Mac at the Pixel 7a's landscape (four themes) and portrait, and the tablet's size.
