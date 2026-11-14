# 074: Games' history, marked moves, and a rating

Status: in progress (built and merged into main 2026-11-12, checked on the Mac's desktop
app by the user; the phone layouts and the replay built in task 078; left: the tablet's
and the A33's checks)

A family asked for a history of the games played and moves rated as GoDraughts rates them
(2026-11-11): the moves of the game in progress marked by how good each was, hidden by a
per-player setting; the games played kept per player on a results screen; and an Elo
rating per player and draughts from games against the computer, whose levels get ratings
of their own.

How it works is in `docs/architecture/ai.md` ("Judging a move", "Ratings"),
`rendering.md` ("The moves panel", "The results screen"), and `README.md` ("Players"); the
reasons in `docs/decisions/ai.md` and `rendering.md`, 2026-11-11. Marks follow lichess's
win-chance thresholds; the prototype is in git history at `086f47d`
(`prototypes/history.html`).

## Numbers

The computer's ratings come from `build/aimatch international A B 200` between
neighbouring skills (2026-11-11): gaps of 87 (0 – 8), 775 for 8 – 25 (the chain's 849
scaled toward the direct match's 700), 260 for 25 – 40, 589 for 60 – 90, and 5 for
90 – 100, so hard's ratings are 2716 to 2721. A score near 0 or 1 over 200 games is
±60 or more.

Judging's cost (`build/judgebench`, the Mac): 25 ms a move on average, 43 at most, 300,000
nodes; about 50 ms a move on the tablet's big cores. The A33 to measure.

## Open questions

1. The setting's default: marks (built), or off for a new player, so a young child sees
   nothing unless a parent turns it on?
2. Too many stars? Most moves come out best; a star only for a move that stood out would
   be quieter.
3. Ratings per draughts (built) or one for all; show the computer's rating beside its
   level in the setup ("Medium · 1644")?
4. Dates are UTC; the local date needs the system's time zone (a small C call).

## Left

- [ ] A summary at the moves panel's foot (each side's accuracy and marks counted), as
      the prototype has
- [ ] The results screen in `test/shell/sizes`' sizes, with insets

## Acceptance criteria

- [x] The prototype's takes compared and one chosen
- [x] Every move of a game judged on the worker without slowing the computer's reply
- [x] A finished game written to the player's history, its rating updated, start again
      clearing both
- [x] The moves panel and the results screen built, every tap 88 dp, strings in English
      and Estonian
- [x] Headless tests: judging known blunders and best moves, the rating's update, the
      history file read and written back and capped
- [ ] Checked on the Mac at the tablet's and a phone's sizes (done), then on the tablet;
      the judging's CPU on the A33
