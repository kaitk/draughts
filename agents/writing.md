# Writing docs, tasks, and prose

- `README.md` and `docs/` are for people: what the app is, how it works, how to build
  it, and the decisions with their reasons. Rules for agents, Goose notes, and anything
  only an agent needs go in `AGENTS.md` and `agents/` (2026-11-07).
- User-facing docs reference no tasks and keep no history: say what is, not what used to
  be. Open work, causes not yet measured, and plans go in a task. Measurements a task
  took stay in its file (`tasks/README.md`).
- Lead with the decision, behavior, or action, then explain why. Use concrete facts and
  cut filler.
- Record a decision in `docs/architecture/` with its reason, and what was rejected when
  that matters. Keep each fact in one place and link to it elsewhere. Use absolute dates.
- Tasks follow `tasks/README.md`, with concrete acceptance criteria. Use sentence-case
  headings, backticks for identifiers and commands, and wrap prose at about 90
  characters.
- Docs and commits don't credit a decision or a request to a person; date it instead.
