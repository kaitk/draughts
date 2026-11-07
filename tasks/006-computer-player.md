# 006: Computer player

Status: todo

Alpha-beta search with a fixed transposition table allocated once. Three levels made
weaker by shallower depth and deliberate, plausible mistakes, never by obvious blunders.
It runs off the main thread or in small slices, so the UI never stalls.

## Acceptance criteria

- [ ] Levels easy, medium, hard; an older child beats easy, and hard beats a casual adult
- [ ] Hard replies in under 1 s on the tablet
- [ ] Works for both variants from task 002

## Notes (2026-11-07)

- The engine is `rules/`: `rules::generate` fills a fixed `rules::Moves` buffer and
  `rules::play` returns a new position, so a search keeps one buffer per ply and no
  undo. Perft runs at 12 to 16 million positions a second natively on an M-series Mac
  (`docs/architecture/rules.md`); the tablet's speed is not measured yet.
- An idle `gfx::frame()` waits up to 1 s for an event (`docs/architecture/rendering.md`,
  "Frames and battery"), so a reply from a worker thread is seen within that second
  unless the board animates while the computer thinks. Animate something while it does.
