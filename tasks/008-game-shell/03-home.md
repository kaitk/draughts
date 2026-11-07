# 008-03: Home

Status: done (awaiting review)

The title menu (`prototypes/home.html`, rendering.md "Home"): the sharp season
scene, and one glass column with the wordmark, then continue, a friend, the computer
with its level, puzzles with stars, and settings, each an icon and a word; in portrait
settings is a button beside the wordmark instead. The language is chosen in settings
(04), not on home. In portrait the column is a sheet below the board. The 3D board is
task 015; until then the 2D board stands beside the menu.

## Work

- Text: Libertinus Sans (rendering.md, "Fonts") baked into an atlas at start (Latin-1,
  Latin Extended-A, punctuation), drawn as a text quad kind by the same pipeline, sizes
  in dp. Strings from the table (task 009).
- The home tiles' filled icons: two figures, a robot head, a jigsaw piece.
- Screens: home and game, switched by the shell; back on the game panel returns home.
- The computer and puzzles open their screens once tasks 006 and 007 exist; until then
  they are drawn but dimmed.

## Acceptance criteria

- [x] The title menu in both orientations, next to the design boards' home
- [x] Text crisp at both sizes on the tablet; Estonian letters drawn
- [x] Continue and a friend start or resume a game; back returns home

## Outcome (2026-11-07)

- Text: `assets/fonts/LibertinusSans-Regular.ttf` (v7.051, OFL) baked by `app/text.goose`
  into three faces (64, 30, 17 dp) at the screen's pixel size, at 1.14 times the em so
  sizes match the prototype's CSS. `gui/` keeps the glyph tables and lays text out
  (`text`, `text_width`, UTF-8), so tests run it with `gui::test_faces`; a glyph is a
  `TEXT` quad sampling the atlas texture. The atlas is destroyed once copied.
- `gui/`: `glass` with a radius; `row` (icon, label, note; dimmed rows take the press
  but do nothing); tile looks `QUIET`, `ROW`, `ROW_PRIMARY`; icons next, friend,
  computer, puzzle, gear as distance shapes. Quads per frame up to 512.
- `shell/` (new): `Shell` holds the screen and the game, and says where the board goes
  and whether the photograph is sharp. `shell/home.goose` declares home from the
  prototype's values: a 440 dp column with its left corners off the screen (in
  portrait a sheet with its lower corners off), the wordmark (a crowned piece drawn
  over the UI, the name with 0.06 em spacing), and 80 dp rows. Continue opens the game
  as it stands, a friend starts a new one, back returns home with the game kept. The
  board stands beside the menu at up to 70% of the height (in portrait above the
  sheet), showing the game.
- Settings: in landscape the menu's last row, in portrait a quiet 48 dp button beside
  the wordmark (chosen 2026-11-07), so the sheet leaves the board its room. The gear
  does nothing until 04. `home.language` left the string table.
- The photograph: `app/background.c` decodes it once for both sizes; the sharp 2048 px
  texture shows behind home (16 MB of graphics memory), the blurred copy behind the game.
- The app opens at home; `--fen`, `--tap`, or `--screen game` open the game.
- `test/shell/shell.goose`: home at start, continue, a move, back keeping it, the dimmed
  rows and settings doing nothing, a friend starting over, the portrait sheet clear of
  the board.

### Compared

Mac screenshots at 1920 × 1200 and 1200 × 1920 for all four seasons, in English and
Estonian, beside `prototypes/home.html` at the same pixel size: column, wordmark,
rows, icons, and text sizes match. The prototype's wordmark and gear overflowed its
440 px column; with settings a row in landscape the wordmark fits.

### On the tablet

Home in landscape and in portrait in Estonian (õ, ä, Ü drawn, crisp at 96, 45, and
25 px). By taps over adb: continue, a move, back (home shows the move), a held row
lighting, and a friend starting over. Idle at home, untouched, 60 s: the program thread
0.02 s of CPU (0.03% of a core) with 60 voluntary switches, the process 1.14 s. Over 20
cycles of home, resume, and rotation: one process, no errors, PSS 259 to 263 MB (255 to
259 before), native heap 27 MB, graphics 211 to 215 MB with the same two 2 MB steps.
The first sample, before any pause, reads PSS 286 MB and graphics 235 MB; the extra
goes at the first pause, likely the upload buffer that carried the 16 MB photograph.
Before giving the load's pages back with `trim_memory()` and destroying the atlas,
PSS was 293 to 297 MB and the native heap 36 MB.
