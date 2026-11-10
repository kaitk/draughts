# 062: Architecture for people, decisions for agents

Status: in-progress

After task 061. `docs/architecture/` mixes two things: how the app works now, and the
dated decisions with their reasons, what was rejected, and the measurements behind them.
At 2026-11-10 it is about 2,800 lines; `rendering.md` alone is 1,616, with about 50
task references, bench histories ("10.6 → 9.2 ms after task 059"), and decisions
credited to a person. That breaks `agents/writing.md`'s own rule (user-facing docs keep
no history and reference no tasks), and a reader who wants to know how the app works
has to dig through it.

Plod (`~/projects/goose/plod`, the user's Goose REST framework) splits them, and is the
model here:

- `docs/architecture.md`: how it works now, for users. It links to the decisions.
- `docs/decisions.md`: for contributors and agents. Each entry is dated, with its
  reason and what it rejected. A decision that replaces an earlier one says so, and both
  stay.
- `AGENTS.md`: a change that contradicts a decision records the new one in
  `decisions.md` and updates `architecture.md` in the same change.

## Steps

1. Split each of `docs/architecture/`'s files (README, rendering, rules, ai, puzzles):
   - What is, without dates, tasks, or history, stays in `docs/architecture/`, rewritten
     shorter for people.
   - Each decision with its date, reason, and what was rejected goes to `docs/decisions/`,
     one file per area as `docs/architecture/` has now (one `decisions.md` would run to
     thousands of lines).
   - Measurement histories go to the decisions or to the task that took them; current
     numbers per device stay in the architecture ("The release's frames").
2. Make task 061's overview page, "Draughts from above", the architecture's front page:
   `docs/architecture/index.html` beside the Markdown, linked from `README.md` and
   `docs/architecture/README.md`. This replaces 061's `docs/overview/`.
3. Publish it on GitHub Pages at `kaitk.github.io/draughts/architecture/`, copied to the
   `gh-pages` branch as `privacy/` is (task 029).
4. Update the rules to match: `AGENTS.md` (Project context, the rule on following
   decisions), `agents/writing.md` (where a decision is recorded), and every link into
   `docs/architecture/` from `docs/`, `agents/`, `tasks/`, `store/`, and the code's
   comments.

## Acceptance criteria

- [x] `docs/architecture/` names no task, keeps no history, and credits no person; each
      file reads as how the app works now
- [x] Every decision now in `docs/architecture/` is in `docs/decisions/`, dated, with its
      reason, and what it rejected where the source says so; nothing is lost (check by
      diffing the facts, not the lines)
- [ ] The overview page is `docs/architecture/index.html`, linked from both READMEs, and
      on Pages at `/draughts/architecture/`
- [x] `AGENTS.md` and `agents/writing.md` state the split as Plod's do
- [x] No link points at a heading that moved (grep for `architecture/` and `#` anchors)

## Outcome

Done on 2026-11-10 and 11, one commit per file, `rendering.md` in four section groups.

- `docs/decisions/`: `README.md` (the stack, the code's layout and the renderer seam, with
  task 061's stage verdicts, players, the app's lifecycle), `rules.md`, `ai.md` (the
  self-play histories), `puzzles.md`, and `rendering.md`, whose headings follow the
  architecture's. The old "The 3D board on devices" is kept there whole as its history.
- `docs/architecture/rendering.md` stays one file with its headings, as 92 links and
  about 50 quoted section names point into it; 1,638 lines became 1,462, the decisions
  467. The architecture is 2,515 lines in all, from 2,860.
- Checked by facts: every number, colour, code span, and URL of the five originals (at
  `57298d4`, and `56ad433` for `rendering.md`) is in the new files. A script resolved every
  Markdown link and anchor into both folders from the repo's text and code, and each
  quoted section name.
- `puzzles.md` said a game plays a capture whole once one goes on; the code and
  `rendering.md` make it stop by stop in a game too, so that line was corrected.
- Pages: the page is committed on the local `gh-pages` branch as
  `architecture/index.html`, not pushed (2026-11-11).
