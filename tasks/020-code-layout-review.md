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

## Settled (2026-11-08)

Once tasks 021, 025, and the computer's wiring are in, review the code with subagents and
make the clear-cut fixes without waiting for agreement: tangles and real duplication
whose fix is obvious, no abstractions ahead of need. Anything larger or arguable goes in
the written review for the user to agree.

The review also reads the code as Goose: whether each part is written the way the
release's `docs/`, `samples/`, and `stdlib/` write it, and where writing it more
idiomatically would simplify it meaningfully. The user's other Goose projects,
`~/projects/goose/goose-http` and `~/projects/goose/plod`, are models to compare with.
Change only what gains clearly; finding nothing of real value is a fine answer.
