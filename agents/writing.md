# Writing docs, tasks, and prose

- `README.md` and `docs/` are for people: what the app is, how it works, how to build
  it, and the decisions with their reasons. Rules for agents, Goose notes, and anything
  only an agent needs go in `AGENTS.md` and `agents/` (2026-11-07).
- User-facing docs, all of `docs/` but `docs/decisions/`, reference no tasks and keep no
  history: say what is, not what used to be. The decisions are dated and may name the
  task that made them. Open work, causes not yet measured, and plans go in a task. Measurements a task
  took stay in its file (`tasks/README.md`).
- Lead with the decision, behavior, or action, then explain why. Use concrete facts and
  cut filler.
- For a new or rewritten doc section, and for text that goes upstream (a pull request's
  description, another project's docs), run the `google-style` skill's editing pass
  (`.claude/skills/google-style/`, from Snowtime). An upstream text is about that
  project: Draughts appears only as where the change was tested (2026-11-18).
- `docs/architecture/` says how the app works now: no dates, tasks, history, or people.
  Its current per-device numbers stay there; how they came to be does not.
- Record a decision in `docs/decisions/`, in the area's file, with its date, its reason,
  and what was rejected when that matters; measurement histories go there or to the task
  that took them. A decision that replaces an earlier one says so, and both stay. Keep
  each fact in one place and link to it elsewhere. Use absolute dates.
- Tasks follow `tasks/README.md`, with concrete acceptance criteria. Use sentence-case
  headings, backticks for identifiers and commands, and wrap prose at about 90
  characters.
- Docs and commits don't credit a decision or a request to a person; date it instead.

## Reviewing a translation

Repeat this for new strings or another language.

- A Gemini agent proposes, a Claude session checks. Run it headless and without tools:
  `agy --sandbox -p "<prompt>"` (the prompt only as the argument; a run takes 1 to 15
  minutes). Gemini writes the best Estonian of the models, given the right context.
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
  Mustad). The app itself says *nupp* for a piece and *tamm* for a king. The Estonian
  is plain spoken prose a second-grader reads at once, not rulebook language: capture is
  *võtma* (*Pead võtma*, *Võta nii palju, kui saad*), not the official *lööma*, which
  reads as kantseliit to a child; *viltu* for diagonal, *teise serva* for the far side.
  Never a bare "Tamm!" nor a king with a crown beside it: *tamm* is also an oak, which
  has a crown. A saying is used as people say it (*Kaks on parem kui üks!*). How to play
  follows this (2026-11-19); the theme names, draw lines, and replay still say *lööma*.
  A brief for Gemini says all of this, or it keeps the stiff wording as correct.
  English "either" is *ükskõik kumb* or *mõlemad*: bare *kumbki* reads as "neither"
  (2026-11-13). The tightest labels are "Rahvusvaheline" (the setups' tiles size to their
  words, `home::draughts_tile`) and "Kuupäev"/"Tänane" on settings' background tile.
- Measure a candidate against the row as laid out, not a fixed budget: a title can also
  decide whether tiles stand beside it (`picker::today_beside`). A scratch Goose program
  printing the rows' rects at the layout tests' sizes, with a Python reader of the font's
  `hmtx`, gives every case. Gemini chooses wording by the room in dp it is given, so
  check its arithmetic against the real layout.
