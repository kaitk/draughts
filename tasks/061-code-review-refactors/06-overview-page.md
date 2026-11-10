# 06: The overview page, brought up to date

Status: todo

After stage 4, once the code has its new shape. "Draughts from above" is a plain-words
HTML page about the app:

- the start-up;
- the frame loop, step by step;
- the packages as floors;
- the structs as an ownership tree;
- the threads, and the Ask/Thought queues between them;
- one tap followed to the computer's reply;
- the house rules;
- a glossary of the code's odd names.

It is written for a smart teenager: short sentences, no jargon left unexplained. It was
made on 2026-11-10, at `abfcb5c`, before this task. It is kept locally, outside git, at
`build/notes/overview.html`. If that file is gone, rebuild the page from the sections
above.

## Steps

1. Update it to the code as stages 0 to 4 left it:
   - start-up and the loop through `host` and `render`;
   - `dev.goose` out of the loop;
   - `shell::Frame`, the screen table, and the game's events;
   - the panel's regions;
   - the new files in the floors and the tree.

   Check every function name it cites against the code.
2. Put it in the repo as a page for people, not agents: `docs/overview/index.html`,
   linked from `README.md` and `docs/architecture/README.md`. It must stand alone, with
   its own `<!doctype html>`, head, and body, and Google Fonts with fallbacks. It must
   read in light and dark, and at phone width.
3. Later, publish it on GitHub Pages, together with `store/privacy/` (task 029). Decide
   then whether Pages serves `docs/` or its own folder.

## Acceptance criteria

- [ ] The page matches the code after stage 4: every cited name exists
- [ ] It is in the repo, linked from both READMEs, and opens from `file:///` with no
      broken parts
- [ ] It is on GitHub Pages (may wait for task 029's Pages setup)
