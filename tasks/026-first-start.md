# 026: How to play, and a new player's way to it

Status: in progress (built 2026-11-13; to check on the tablet)

How to play teaches the rules one step at a time, each played on the board in the
player's draughts (`src/shell/tutorial.goose`: International and Brazilian 9 steps,
Russian 10). A new player is asked "Do you know how to play?" after their sheet; Show me
opens it. It stands in continue's place on home until learned, and always as the first
row of the puzzles' library; the end leads to the Learn puzzles or a new game. It replaces
task 019's first start (`first-start.html`, in git history at 086f47d). The takes chosen
2026-11-13 from `prototypes/tutorial.html`: ask a, entry b, the tap icon.

Built, tested headless (`test/shell/tutorial`, `test/shell/who`), checked on the Mac in
both orientations and languages, the Estonian reviewed. `--screen tutorial --step N|end`
and `--screen ask` shoot it.

## Acceptance criteria

- [x] A new player is asked; each step played on the board; home's and the library's rows
- [x] Headless tests and the Estonian review
- [ ] Checked on the tablet

## References

- GoDraughts (https://godraughts.com/en, Android `net.devdad.internationaldraughts`): an
  interactive rules tutorial and courses worth studying for how it teaches.
