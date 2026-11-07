# 008: Game shell

Status: in-progress

The screens around the board: the game screen's panel, home, and settings, built on the
UI layer from `docs/architecture/rendering.md` ("UI layer": rect-cut layout, one quad
array, one pipeline) and its glass ("Scene and glass"). Large touch targets with icons
first, so a young child can use it without reading; words come from the string table
(task 009). The 3D board on the home screen is task 015; until then home shows the 2D
board.

## Subtasks

In order; each is checked on the Mac and the tablet before the next.

1. [01-ui-layer.md](01-ui-layer.md): the immediate-mode UI layer, glass, and the game
   screen's panel beside the board with its four buttons drawn
2. [02-game-panel.md](02-game-panel.md): the panel working: side to move, the move-hints
   toggle, undo, hint, restart, back, and a celebration on a win
3. [03-home.md](03-home.md): text from the font atlas, and the title menu
4. [04-settings.md](04-settings.md): background, board, move hints, language, kept
   across runs
5. [05-resume.md](05-resume.md): the app resumes where it was after Android kills it

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
- [ ] Nothing allocated per frame; idle CPU and memory on the tablet as before
