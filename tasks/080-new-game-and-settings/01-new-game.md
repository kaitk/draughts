# 01: One New game row, the opponent chosen in the setup

Status: in-progress

Home's menu: Continue, New game, Puzzles, Games, Settings (Quit on a desktop). New game
opens the setup in the same column, as A friend and The computer do now, and the setup
starts with whom to play: the computer (its level and the child's color) or a friend
(whether the board turns to the side to move, prefs' `turns`, today the Board row's third
tile in settings). The choices are kept, so a child who always plays the computer taps
New game and Play.

Takes in `prototypes/new-game.html`:

- **a**: an Opponent row (The computer, A friend) first; the computer's Level and Your
  pieces under it, or a friend's Turning row; the column scrolls where it runs past the
  foot, Play pinned under it.
- **b**: the opponent in the head row, a two-part switch beside back in place of the
  title, saving a row.
- **c**: one row for whom and how strong: A friend, Easy, Medium, Hard. Under it Your
  pieces for the computer, or the Turning row for a friend, so both setups have the same
  rows and the column never jumps.

Also: the row's word (New game or Play), and whether it notes the last opponent at its
end as The computer notes its level today.

## Acceptance criteria

- [ ] The takes at the tablet's and the phones' sizes, both orientations; the user's pick
- [ ] Home's one row and the setup built; the turning gone from settings, kept in the
      player's file as before
- [ ] Strings in `strings/en.txt` and `strings/et.txt`; the unused ones removed
- [ ] Checked on the Mac (tablet, Pixel 7a, iPhone 13 mini sizes), then on the tablet
