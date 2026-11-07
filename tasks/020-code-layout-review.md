# 020: Review the code's layout as a whole

Status: todo

Once the MVP's flows work in their basic form (task 008, then 006 and 007), look at the
code as a whole: is it readable and neatly packaged, as a game's code would be, and does
it fit what comes next: more screens and flows (task 019), other screen sizes, a Mac
version, and perhaps a NoGraphicsAPI port (`docs/product.md`), reusing most of it. Not
before then: the flows should exist first, so the review is of real code (asked
2026-11-07).

## Work

- Read the packages (`rules/`, `board/`, `gui/`, `game/`, `shell/`, `strings/`) and
  `app/`, and note where game logic, layout, and drawing mix, where state hides in the
  app's main loop, and what a second renderer would have to rewrite.
- Propose changes with their reasons; no abstractions ahead of need, only what removes
  tangles or real duplication. Record the layout in `docs/architecture/`.

## Acceptance criteria

- [ ] A written review with the changes proposed, agreed with the user
- [ ] The agreed changes made, tests passing, the app unchanged on the Mac and tablet
