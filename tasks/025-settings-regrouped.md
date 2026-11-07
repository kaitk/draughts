# 025: Build the regrouped settings with the board beside them

Status: in-progress (built and checked on the Mac; tablet check pending, locked)

Bring settings to `prototypes/settings.html` (rendering.md "Settings", 2026-11-07): the
choices as words in two groups, game (the draughts for a new game, move hints, the
tutorial) and look (background, board, kings), the language in the title row, and home's
board beside them showing what the choices make.

## Work

- `shell/settings.goose`: the groups and rows; the draughts for a new game (international
  dimmed until task 002's 10×10 is on screen, Brazilian until task 023), kings (auto,
  crown, stack; the crown and stack tiles draw their king), the tutorial's tile (task
  026), the language at the title row's right end.
- The board beside them is home's board, drawn with the choices: 10×10 or 8×8, the move
  hints' look on a fixed position (all moves: a capture shown; mistakes only: a wrong
  move's ring and the piece that must capture pulsing). In landscape the choices take
  the width they need at the left and the board the rest; in portrait the board is on
  top and the groups side by side under it.
- Stacked kings are two plain discs, no crown, in the piece shader (rendering.md "Kings").
- `settings.txt` keeps the new values; strings for every new word.

## Acceptance criteria

- [ ] Settings match the prototype in both orientations, on the Mac and the tablet (Mac
  done; tablet check pending, locked)
- [x] Each choice changes the board beside them at once and survives a restart
- [x] Headless tests for the new settings and their file

## Settled while scoping (2026-11-08)

- International is the default draughts for a new game once 10×10 is on screen (task
  021); settings' draughts row and the setup's are one setting in `settings.txt`.

## What was built (2026-11-08)

- `shell/settings.goose`: the title row (back, the title, the language's glass with a
  globe and a tile per language named in itself) and two groups, game (draughts, move
  hints, tutorial) and look (background, board, kings), each setting a dim 17 dp name and
  its tiles (`gui::pick`, the seasons `gui::choice`). The rows are a small table (`ROW_*`,
  `word`, `note`, `tile_width`), laid out by `lay`, which wraps tiles at the width it is
  given and measures with the same code it declares with. Landscape: the side as wide
  as its words want, at most 55% of the page, the board 94% of the rest; portrait: the
  board between the title row and the groups, which stand side by side as tall as the
  taller.
- The kings setting (`kings = auto|crown|stack` in `settings.txt`): `board::CROWN`,
  `board::STACK` as a piece's `look.y`, set from `Board.king_look`, which the shell keeps
  in step with the settings every frame. The piece shader draws a stack as two plain
  discs, the upper 1.3% of the board above the lower (`STACK_BLOCK`); the crown and stack
  tiles draw their king over the UI (`game::put` takes the king's look).
- The preview is `Shell.preview`, a board of its own staged by `settings::stage` on
  opening and after each change; the app draws it instead of the game's board on
  settings. `Board.still`/`held`: once a wrong move's ring has flashed and the pieces that
  must capture have pulsed, both stay lit and still (`ring.x` 2 in the shader).
- Every screen has a board now, so `Shell.board` and the board pass's "no board" path
  are gone.
- Strings: game, look, tutorial, kings, flat/raised with 2D/3D notes, auto with its note,
  crown, stack, learn the moves; `settings.language` is gone with the language's group.

## Measurements (Mac, 2026-11-08)

- From the screenshots (`--size 960x600`, 1920 × 1200, so 1280 × 800 dp): in landscape
  the choices take 621 dp and the board 553 dp at x 677; the prototype's are 563 and 589
  at x 639. Home's board is 560 at x 580, so opening settings moves it right by about
  100 dp at the same size. In portrait (800 × 1280 dp) the board is 542 dp (the
  prototype's 560) and the groups start at y 723.
- Opening settings with mistakes only animates the preview for 2.8 s (the flash for
  1.2 s, the pulse for 2.8 s), then nothing animates (`test/shell/settings.goose`).
- The APK is 5.6 MB.

## Open for the user

- The tutorial's tile is dimmed and takes no tap until task 026 builds the tutorial.
- Notes and the thumbnails' labels use the 17 dp face the setup uses, not the
  prototype's 13 px, so the choices are wider and the landscape board about 6% smaller
  than the prototype's. A 13 or 14 dp face would match it, at the cost of one more baked
  size. The title is in the 30 dp face (the prototype's 34 px).
- The preview's position leaves out the prototype's black man on f8: with it the king
  takes three on 10 × 10, majority capture leaves the man on d4 no move, and all moves
  would show d4 selected with nothing marked. Without it the man and the king both take
  two on every board. On 10 × 10 the position sits a square in from the corner, not in
  it as in the prototype.
- With mistakes only, the preview plays the wrong move's flash and both capturing pieces'
  pulse once, on opening and after each tap, then holds them lit and still, rather than
  pulsing for as long as settings show (a frame every vsync while idle).
- The winner's piece on the win card follows the kings setting; home's wordmark keeps its
  crown.
- The choices' side may take up to 55% of the page in landscape; beyond that its tiles
  wrap. Estonian's auto note was shortened to "2D kroon, 3D virn" to fit. Estonian
  drafts for task 024's review: Mäng, Välimus, Õpetus, Õpi käike, Tammid, Kroon, Virn,
  Automaatne, Lame, Ruumiline.
- Tablet check pending (locked): both orientations, a tap on each choice, and that a
  season's photograph reloads after its tile shows lit.
