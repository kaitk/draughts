# 01: One New game row, the opponent chosen in the setup

Status: in-progress

Home's menu: Continue, New game, Puzzles, Results, Settings (Quit on a desktop). New game
opens the setup in the same column, as A friend and The computer do now, and the setup
starts with whom to play: the computer (its level and the child's color) or a friend
(whether the board turns to the side to move, prefs' `turns`, today the Board row's third
tile in settings). The choices are kept, so a child who always plays the computer taps
New game and Play.

The user picked take c of `prototypes/new-game.html` (2026-11-13): one row for whom and
how strong (A friend, Easy, Medium, Hard), under it Your pieces for the computer or the
Turning row for a friend, so both setups have the same rows; New game as the row's word,
the last opponent noted at its end.

## Acceptance criteria

- [x] The takes at the tablet's and the phones' sizes, both orientations; the user's pick
- [x] Home's one row and the setup built; the turning gone from settings, kept in the
      player's file as before
- [x] Strings in `strings/en.txt` and `strings/et.txt`; the unused ones removed
- [x] Checked on the Mac (tablet, Pixel 7a, iPhone 13 mini sizes)
- [ ] Checked on the tablet

## Measured (2026-11-13, headless, `test/shell/setup` and shots)

The setup is 732 dp tall unscrolled, the same for both opponents. It fits on the tablet
both ways and on phones in portrait; in a phone's landscape it scrolls (Pixel 7a 102 dp in
a 436 dp view, iPhone 13 mini 142 in 396) with Play in the head row. Every tile is 88 dp at
least at every size `test/shell/sizes` checks; home's shorter menu gives a portrait
tablet's board 592 to 640 dp.
