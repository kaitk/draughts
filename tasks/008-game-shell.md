# 008: Game shell and HUD

Status: todo

Home screen and game flow, with the UI layer from `docs/architecture/rendering.md` (one vertex array,
one pipeline). Large touch targets with icons first, so a young child can use it
without reading.

## Acceptance criteria

- [ ] Home: the title menu (`prototypes/home-menu.html`): continue, a friend, the
      computer (level), puzzles, with the language and settings beside the wordmark
- [ ] Settings: the background (by the date or one season), the board (2D or 3D), move
      hints, the language; prototyped first
- [ ] Move hints: mistakes only by default, moves in the first lessons, a toggle on the
      game screen (`docs/product.md`)
- [ ] In game: undo, hint, restart, back; a celebration on a win or a solved puzzle
- [ ] Glass panels as task 003 chose them, sampling the pre-blurred background
- [ ] The app resumes where it was after Android kills it in the background
