# 006: Computer player

Status: todo

Alpha-beta search with a fixed transposition table allocated once. Three levels made
weaker by shallower depth and deliberate, plausible mistakes, never by obvious blunders.
It runs off the main thread or in small slices, so the UI never stalls.

## Acceptance criteria

- [ ] Levels easy, medium, hard; an older child beats easy, and hard beats a casual adult
- [ ] Hard replies in under 1 s on the tablet
- [ ] Works for both variants from task 002
