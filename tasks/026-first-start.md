# 026: Build the first start and the tutorial

Status: todo (after the MVP's menus, 2026-11-07: not in the MVP's scope)

Bring the first start to `prototypes/first-start.html` (task 019; removed 2026-11-13, in git history at 086f47d): which draughts (two
cards with the starting position: international, the default once it exists, and
Russian), learn the moves or just play, the tutorial, and what to play first. Settings'
tutorial row comes back with it (taken out 2026-11-09 so the tablet's landscape fits both
groups; the game group has room for it there only if the look's rows stay as they are),
and its tile opens the tutorial again.

## The take (2026-11-13)

`prototypes/tutorial.html`, from `?view=players` (+, the sheet, done) on: a new player
(and a fresh install's first) is asked "do you know how to play?" before home (`&ask=a`
the two answers, teaching the player's draughts; `b` with the setup's draughts row on
the card; `c` a card of the draughts after Show me). The steps, one rule each, are
played on the board with the moves shown and any legal move taken (International and
Brazilian 9: move, jump to take, must take, keep jumping, take the most, king, kings fly,
kings take from afar, win; Russian 10, choose any capture in place of take the most, and
crowned on the way). The end hands over to Puzzles (the Learn theme's first) or New game,
the draughts kept. Where it lives later, `&entry=`: `a` a How to play row on home; `b`
How to play in Continue's place while a new player has nothing to continue, then the
puzzles' library's first row; `c` that row only. Proposed: ask a, entry b. Settings'
tutorial row isn't drawn: the library's row, switched by draughts, replaces it.

The user liked the steps (2026-11-13) and asked for the other side's move in the first
step: now your move, the other side's after a pause with its squares lit, and yours
again before next lights. How to play's icon, which the app doesn't have yet, has takes
(`&icon=tap|path|step|cap|ask`); proposed: tap, a finger tapping, which is what the
steps ask.

## Work

- The pages as a shell screen, shown on the first launch only (a flag in `settings.txt`).
- The tutorial's steps as data: a position, the move it shows, a title and a line, per
  variant (Russian 7 steps, International 8: majority capture, and how each crowns
  mid-capture). Move hints show the moves here, and go back to the setting after.
- Each step's move is played on the board by tapping, with the hints on; next is lit once
  it is played. Positions checked with `test/perft.py moves`.
- Strings for every title and line.

## References

- GoDraughts (https://godraughts.com/en, its Android app `net.devdad.internationaldraughts`;
  the user, 2026-11-08): a good modern draughts app with an interactive rules tutorial,
  training courses, and coaching from the player's own mistakes. For adults, but worth
  studying for how it teaches.

## Acceptance criteria

- [ ] A fresh install opens on the variant cards; later launches open home
- [ ] Each step can be played on the board and goes on; done leads to a new game's setup
- [ ] Headless tests for the step positions' moves and the flow
