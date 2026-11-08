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

## Reviewing a translation

How the Estonian review ran (2026-11-08); repeat it for new strings or another language.

- A Gemini agent proposes, a Claude session checks. Run it headless and without tools:
  `agy --sandbox -p "<prompt>"`, the answer as text on stdout (`agy` takes the prompt only
  as the argument, not on stdin; a run takes from 1 to 15 minutes by model). Gemini writes
  the best Estonian of the models, given the right context.
- The brief is one file: what the app is and who uses it (`docs/product.md`), every key
  with its English, current text, where it shows, its face, and its room in dp, the
  language's draughts terms, and the answer's format. Proposals go to a file, never into
  `strings/<lang>.txt`.
- Take a change only with a reason: wrong, unnatural, or too long for its tile. Check each
  against the English (no meaning lost, nothing added) and measure its width the way
  `gui::text_width` sums the face's advances. A second model or pass is a second opinion,
  not a vote.
- Keep every key in every language file (`test/strings/` fails otherwise), and check the
  longer labels on the Mac in both orientations with `--lang <code>`.
- The Estonian terms: Eesti Kabeliit's rules write *lööma* for capture, *kabend* for a
  piece, *kivi* for a man and *kabe* for a king; sides are named in the plural (Valged,
  Mustad). The tightest labels are "Rahvusvaheline" (the setups' tiles size to their
  words, `home::draughts_tile`) and "Kuupäev"/"Tänane" on settings' background tile.
