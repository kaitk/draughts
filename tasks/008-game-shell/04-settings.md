# 008-04: Settings

Status: todo

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

- [ ] Each setting changes the app at once and survives a restart
- [ ] Checked on the Mac and the tablet in both orientations
