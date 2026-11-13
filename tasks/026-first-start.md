# 026: How to play, and a new player's way to it

Status: in progress (built 2026-11-13; to check on the tablet)

How to play is the rules one at a time, each a step played on the board in a puzzle's
layout with the moves shown, in the player's draughts. A new player (and a fresh
install's first) is asked "Do you know how to play?" on the card right after their
sheet's done; Show me opens the tutorial. It lives on as How to play in continue's place
on home while a new player hasn't learned it, and always as the first row of the puzzles'
library. The end hands over to the puzzles' Learn theme or a new game. This replaces task
019's first start, pages of its own before home (`first-start.html`, in git history at
086f47d), and settings' tutorial row, which doesn't come back.

## The takes (2026-11-13)

`prototypes/tutorial.html`, from `?view=players` (+, the sheet, done) on. The question
(`&ask=a` the two answers, teaching the player's draughts; `b` with the setup's draughts
row on the card; `c` a card of the draughts after Show me); where it lives later
(`&entry=a` a row on home always; `b` in continue's place for a new player, then the
library's first row; `c` the library only); the icon (`&icon=tap|path|step|cap|ask`). The
first step was given the other side's answer and a second move of the child's after the
first look, so the turns show. Chosen: ask a, entry b, the tap icon (the finger).

## Built

- `src/shell/tutorial.goose`: the steps as data (a FEN on the board's lower left each,
  the crowning step's a row from either size's far side), the step's play, the right
  panel (dots, name, line, next), and the end's card. International and Brazilian 9 steps,
  Russian 10 (any capture; crowned on the way).
- `who.goose`'s question (`ASKING`), home's row in continue's place (`home::Resume.learn`),
  the library's row (`picker::learn_row`, declared after the themes so their tiles keep
  their order), the shell's screen (`shell::TUTORIAL`, `shell::learn`).
- The player's file: `learned.<draughts> = n` (steps played), `how_to_play = known`;
  `first_start = done` now means the player was asked.
- `gui::HOW`, the finger, in the widgets' shader; `gui::wrapped`, text broken into lines.
- 44 strings in English and Estonian (capture as *lööma*, as the app's Estonian has it).
- `--screen tutorial --step N|end`, `--screen ask` for screenshots.

## Measured (2026-11-13, headless and Mac shots)

The library's How to play row is 104 dp on the tablet, a tap on a phone. On the tablet's
landscape the themes' columns narrow from 600 to 531 dp to clear back's column; on a
20:9 phone's landscape at 480 dp the list now scrolls to its last two rows. Checked on the
Mac (gfx, flat and 3D, English and Estonian; the ngfx build's question card): the
tablet's landscape, a phone's landscape and portrait.

## Acceptance criteria

- [x] A new player, and a fresh install's first, is asked; Show me opens how to play,
      I know how is kept
- [x] Each step is played on the board and goes on; the end leads to the Learn puzzles,
      a new game's setup, or home
- [x] Home's How to play row for a player asked and not done; the library's row always
- [x] Headless tests: every step's legal moves per draughts, the whole tutorial played
      by taps (`test/shell/tutorial`), the question (`test/shell/who`)
- [ ] Checked on the tablet
- [ ] The Estonian lines reviewed (`agents/writing.md`, "Reviewing a translation")

## References

- GoDraughts (https://godraughts.com/en, its Android app `net.devdad.internationaldraughts`;
  2026-11-08): a good modern draughts app with an interactive rules tutorial, training
  courses, and coaching from the player's own mistakes. For adults, but worth studying
  for how it teaches.
