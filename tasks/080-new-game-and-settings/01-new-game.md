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

The user picked take c, New game as the row's word, and the last opponent noted at its
end (2026-11-13).

## Acceptance criteria

- [x] The takes at the tablet's and the phones' sizes, both orientations; the user's pick
- [x] Home's one row and the setup built; the turning gone from settings, kept in the
      player's file as before
- [x] Strings in `strings/en.txt` and `strings/et.txt`; the unused ones removed
- [x] Checked on the Mac (tablet, Pixel 7a, iPhone 13 mini sizes)
- [ ] Checked on the tablet

## Measured (2026-11-13, headless, `test/shell/setup` and shots)

The setup is 732 dp tall unscrolled (head 88 + 18, the choices 26 + 3 × 34 + 3 × 88 +
128, play 18 + 88), the same for both opponents; the landscape column is 400 dp, whom to
play's four tiles 93 dp each.

| Size | Play | The choices | The four tiles | Board |
| --- | --- | --- | --- | --- |
| Tablet 1280 × 800 | under them | fit, 18 dp above play | 93 dp | 560 dp |
| Tablet 800 × 1280 | under them | fit | 177 dp | 404 dp |
| Pixel 7a 1200 × 540 dp, insets 59, 42 | in the head row | scroll 102 dp in a 436 dp view | 93 dp | 349 dp |
| Pixel 7a 540 × 1200 dp, insets 59, 42 | under them | fit | 112 dp | 223 dp |
| iPhone 13 mini 1083 × 500 dp, insets 67, 30 | in the head row | scroll 142 dp in a 396 dp view | 93 dp | 328 dp |
| iPhone 13 mini 500 × 1083 dp, insets 67, 45 | under them | fit | 102 dp | none |
| iPad's smallest window 499 × 645 dp | under them | scroll 111 dp | | none |

Home's menu, a row shorter, gives the board more room in portrait: the tablet's 592 to
640 dp, a 4:3 tablet's 451 to 541. Every tile is 88 dp at least at every size
`test/shell/sizes` checks. Settings' Board row without Turns puts both groups on one page
on a 20:9 phone in portrait at 540 dp (the preview 228 dp), where it had needed the tabs.

