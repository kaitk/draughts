# 040: A hint in the game

Status: todo

A hint button in a game against the computer or a friend, for the best move (the user,
2026-11-09, after a young player tried the game; later, not a priority). Help shouldn't do the
thinking (`docs/product.md`), so it gives as little as helps:

- The first press lights the piece to move; a second press shows where it goes.
- A few hints a game, shown on the button, so it stays help and not autopilot.
- It looks like the puzzles' hint, which already exists.
- The move comes from the computer's search at a strength above the opponent's
  (`docs/architecture/ai.md`), on its worker thread, so the frame never waits.

## Acceptance criteria

- [ ] A hint button on the game screen in every layout, its strings in `strings/`
- [ ] First press shows the piece, second the move; the count of hints left shows
- [ ] The search runs off the drawing thread; tested headless
