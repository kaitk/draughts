# 008-04: Settings

Status: done (awaiting review)

Settings (`prototypes/settings.html`): the background (by the date, or one season), the
board (2D now; 3D once task 015 exists), move hints, and the language. A tap applies at
once; there is no save button.

## Work

- Glass groups with a title and tiles; the season tiles show the scene's thumbnail.
- Kept across runs in a small file in the app's storage (`SDL_GetPrefPath` through the
  program's C, as `app/locale.c` reaches SDL), read at start.
- Changing the season reloads the scene and its glass copy; changing the language
  re-reads the string table.

## Acceptance criteria

- [x] Each setting changes the app at once and survives a restart
- [x] Checked on the Mac and the tablet in both orientations

## Outcome (2026-11-07)

- `shell/settings.goose`: the `Settings` value (season or by the date, board, move
  hints, language or the system's), its file (`season = winter`, one per line; what a
  file lacks or doesn't know stays at the default), and the screen from the prototype's
  values. The shell holds the settings, opens them from home, and marks them changed;
  the game's hints toggle is the same setting.
- The app reads `settings.txt` from the storage folder (`app/storage.c`, SDL's pref
  path) at start and writes it whole with `write_file_atomic` after a tap: a new season
  reloads the photograph, its blurred copies, and the theme (`draw::reload`); a new
  language takes effect on the next frame. `--theme`, `--hints`, `--lang` still override
  for a run. `--screen settings` opens settings.
- Thumbnails: `app/background.c` crops any shape from the photograph
  (`draughts_background_crop`); the four seasons' 160 × 98 thumbnails are made into one
  texture when settings first opens, since each decodes a photograph. The UI shader
  draws them as a `PICTURE` quad.
- `gui/`: `choice` tiles (a picture with a label, or a word; on, off, or dimmed), faces
  of 24 and 20 dp, the sun, target, and globe icons. Strings: `board.flat`,
  `board.raised`, and `strings::name_of` for each language's own name.
- Fixed on the way: a screen switched to was drawn only if something else kept frames
  coming; the first frame of a new screen is now always drawn (`shell::frame`).
- `test/shell/settings.goose`: the file read back, defaults for unknown values, taps on a
  season, 3D (nothing), all moves (the board takes it), Eesti, by the date, and the
  game's toggle changing the setting. `test/shell/shell.goose` checks the first frame
  of a new screen is drawn and the next isn't.

### Compared

Mac screenshots at 1920 × 1200 and 1200 × 1920 beside the prototype at the same pixel
size, in English and Estonian: groups, titles, tiles, thumbnails, and the lit choice
match. "Kuupäeva järgi" is wider than a picture, so a tile grows to its label with the
picture centered. A hand-written `settings.txt` (winter, Estonian) opened the app in
winter in Estonian.

### On the tablet

By taps over adb: settings from home, summer (the photograph, theme, and glass changed),
Eesti (applied at once), then a force-stop and start: summer and Estonian were kept.
Then back to by the date and English the same way. Opening settings the first time took
0.21 s (the four thumbnails); a season's reload 0.16 s. Idle at home after that, 60 s:
the program thread 0.03 s of CPU (0.05% of a core) with 60 voluntary switches, the
process 1.19 s. Over 20 cycles of home, resume, and rotation: one process, no errors,
PSS 263 to 265 MB (259 to 263 before), native heap 27 MB, graphics 213 to 215 MB.

Fixed after review (2026-11-07): on the tablet a season's tile sometimes showed the old
choice lit, or none, until the next touch. A tile is declared before the tap changes the
setting, and the reload ran in that frame and outlasted the press animation, so no later
frame was drawn. Now a click draws one more frame (`gui::Gui.acted`), and the reload
waits for the frame showing the lit tile. Decoding with stb_image's NEON loops, to RGBA,
and scaling without a divide per pixel (a 1:1 crop is a row copy) took a reload from
0.15 to 0.16 s down to 0.075 to 0.095 s, and opening settings from 0.21 to 0.15 s; on
the Mac the decode and scale of one photograph went from 46 to 16 ms.
