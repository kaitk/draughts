# 034: The setup's board shows the game being set up

Status: done

Found by the user on 2026-11-08. In home's setups (a friend, the computer), the board
beside the choices is the game in progress or the last one played
(`shell::home_screen` passes `sh.game.b`), so picking International, Brazilian, or
Russian changes nothing on it, and neither does picking black against the computer. It
should show the game the setup will start: the chosen variant's starting position, 8 × 8
or 10 × 10, turned when the child plays black against the computer, and change as the
choices change. Back to the menu shows the game in progress again, as now.

## Notes

- A board of the setup's own, like settings' preview (`sh.preview`), set to
  `rules::start` of the chosen variant when the setup opens and on each change; the
  game's board stays untouched until play.
- A change of variant between 8 × 8 and 10 × 10 can crossfade the pieces with
  `board::under`, as home to settings does (task 022), or switch at once; opening the
  setup from the menu likewise. Pick whichever reads calmer on the tablet.
- Play starts the game from what the board shows, so nothing jumps on play.
- The app still draws only on change.

## What was built (2026-11-08)

- `Shell.next`, the setup's own board. `shell::home_screen` resets it to `rules::start`
  of `prefs.variant` whenever a setup is open and its draughts differ, and shows it
  (`board_of(HOME)` while `Shell.staged`); on the menu the game's board shows as before.
  `shell::turned` turns home's board: in the computer's setup when black is chosen,
  never in a friend's, and on the menu when the game in progress has the child on black.
- A tap's frame still shows what it declared (the layout's squares and the board agree);
  the next frame shows the board and the column changed together, drawn through
  `g.acted` as any tile's change is. Play leaves `staged` off, so home, come back to,
  shows the new game.
- Switch, not crossfade. The board stays in place, so a crossfade with `board::under`
  would switch the squares between 10 × 10 and 8 × 8 halfway under half-faded pieces (the
  board pass draws one layout's squares), a two-step change where home to settings hides
  it in the slide. The column beside it switches in one frame too, opening the setup and
  lighting a tile, so a board fading for 0.25 s would lag the tap it answers. Switching
  also needs no frames after the tap's.
- `--variant`, `--computer`, and `--level` with `--screen friend|computer` set the
  setup's choices for a screenshot without touching `settings.txt`.
- `test/shell/setup.goose`: every draughts tile in both setups, in landscape and
  portrait, shows its start whole on squares of its size; black turns the board and
  white turns it back; back shows the Russian game in progress, a move in; play starts
  the Brazilian game turned as shown; and half a second after each tap the shell asks
  for no frame and nothing animates (but on the game screen after play, where the
  computer's turn ring runs).

## Checks (2026-11-08)

- `python3 test/run_tests.py` and `--build`: 33 tests pass. New: `setup.out`; no other
  output changed.
- The Mac, 960 × 600 and 600 × 960: both setups with each draughts, and black against
  the computer on International and Russian, the board as chosen; the menu with a
  Russian game a move in. `settings.txt` unchanged after the runs.
- The tablet (2026-11-08), with the APK built from `6b20e66`, in 1920 × 1200 and
  1200 × 1920. The setups were opened with `--screen friend|computer --variant V`, and
  `--computer white` put the child on black. Each draughts showed its own start, on
  10 × 10 or 8 × 8, and black turned the board on International and Russian.
  - Matching the Mac's shots (`magick compare`, 6% fuzz): every landscape shot and every
    computer portrait shot differs only in about 880 px (landscape) or 575 px
    (portrait), which is the X. The Mac's shots were made before the X.
  - The friend's setup in portrait differs by about 10%. Its board sits lower and
    smaller, 16 dp under the X, as task 035 lays it out. The same two shots from a Mac
    build of HEAD at 600 × 960 match the tablet's exactly (0 px).
- The app starts and runs as before with four boards in the shell.
  - Freshly started on home: PSS 267 MB, native heap 40.8 MB, graphics 189 MB.
  - `scripts/lifecycle_memory.sh 3` on puzzle 21: 314 MB before the first cycle, then
    277 to 278 MB, with native heap 28.0 to 28.6 MB and graphics 211 MB. That is one
    process, flat, with no errors; task 007 had 268 to 272, 27.6 to 28, and 211 to 215.
  - `scripts/idle_cpu.sh 60` on home in landscape: the program thread used 0.03 s
    (0.05% of a core) with 60 voluntary switches, and the process 1.17 s.

Screenshots, out of git:
`/private/tmp/claude-501/-Users-kaitkasak-projects-personal-draughts/d9f11ac9-ef2c-4a62-bf58-8c3587116c29/scratchpad/tabletround/setup/`.

## Acceptance criteria

- [x] Each variant tile shows its starting position on the board, in both setups, both
      orientations
- [x] Black against the computer turns the board; white turns it back
- [x] Back to the menu shows the game in progress; play starts the game shown
- [x] Headless test of the above; checked on the Mac and the tablet
