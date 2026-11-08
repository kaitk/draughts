# Tasks

Markdown-based task tracking. One file per task, or one folder for a task with several
subtasks or its own supporting files.

## Naming

`NNN-short-slug.md`: a zero-padded sequential number plus a kebab-case slug. A task with
subtasks is a folder `NNN-short-slug/` holding the task as `README.md` and one file per
subtask as `NN-short-slug.md`, numbered within the folder.

## Format

```markdown
# NNN: Title

Status: todo | in-progress | done | cancelled

Short description of what and why.

## Acceptance criteria

- [ ] Concrete, verifiable outcome
```

Update the status line as work progresses, and tick criteria as they are met. A cancelled
task says who cancelled it, when, and why. A task that measures something records the
numbers in its own file.

## Archive

When a task is done and nothing still builds on its file, move what a current doc needs
from it into that doc, delete the file, and add one line to `000-archive/README.md`: its
number, title, outcome, file name, and the commit that last has it. Numbers stay unique:
pick the next number after the highest in the folder or the archive. Refer to tasks by
number ("task 004"), not by path.

## Order

001 confirmed the stack (Goose runs on the tablet), 002 built the rules engine, 003
settled the look in HTML prototypes, 004 drew the board natively, 005 made the idle app
draw nothing, 006 added the computer player, 007 the puzzles, 008 the shell (a folder of
subtasks), 009 the string table, 011 stopped SDL's accelerometer, 012 brought the
prototypes to the seasonal design boards, 017 brought the board to the settled look, 018
finished the pieces' shape, 019 prototyped the game screen's controls, a clock, and the
first start, 020 reviewed the code's layout, 021 built the game screen, clocks, and setup,
022 the transitions between screens, 023 added Brazilian draughts, 024 reviewed the
Estonian, 025 regrouped the settings, 027 had the computer spend its clock as a player of
its level would, 028 made the icon and launch screen, 030 fitted the layouts to phones and
other screen sizes, 031 made the win calmer, 032 brought memory down, 034 made the setup's
board show the game, and 035 added home's X; 016 (tabletop pictures) was cancelled. All
are archived. Together they make the MVP in `docs/product.md`.

Open: 010 runs alongside: goose_gfx changes to propose upstream. 013 adds season effects
later. 014 upscales the backgrounds on the desktop; placeholders do until then. 015 (the
3D board) comes after the MVP, and so does 033 (an icon per season; until then one icon,
switched by hand). 026 (the first start and tutorial) comes after the MVP's menus. 029
(release on Google Play) makes the release, 036 announces it, 037 builds the puzzle set by
theme, and 038 adds players.

## Next (agreed 2026-11-08, updated at the session's end)

The MVP's features are in, and on 2026-11-08 also: 030 (phones and other sizes), 035
(home's X), 032 (memory: the tablet's PSS at home 216 → 130 MB, the Pixel 7a's 291 →
146) and 011 (idle 1.2 → 0.05 s a minute), all archived; puzzles' multi-captures by hand
(a capture left partway and next pressed is a miss), drops that snap to the nearest
legal square within 0.9 of one, home's gear as a bare icon in portrait, the date-based
season tile after the four seasons, and the second Estonian review taken (Võta, Päästa
nupp, Proovi veel, Tänane, Tammid).

The goal for the morning (2026-11-09): a working, good build on the tablet, which the
user reconnects. Turn its stay-awake on first and leave it on until the session is done.
Screenshots: keep them to a minimum, no portrait-and-landscape sweeps of every screen;
shoot only at the very end, or where something concrete is or may be off.

Ask first, build after (the user, 2026-11-08): at the session's start, while the user is
there, put every open question and prototype to them in one go: 037's themes, counts,
label, and picker take (prototype it early); 038's take and its open questions; and
029's decisions only the user can make (the final application id, the developer name,
where the privacy policy is hosted, the listing's wording, the version). Then the work
that follows from the answers (037, 038, 029) can run while the user is away or asleep.

The next session is lean: the main session delegates to subagents (the default model for
judgment, Sonnet for mechanical work), one device agent at a time, stay-awake turned on
first. The order:

1. 029, the Play release: everything that needs neither the user nor the Play account,
   so the package is ready for upload: the AAB, release signing with an upload key kept
   outside the repo (the user backs it up), a version below 1 (0.x), the target SDK
   and 16 KB alignment, the listing's text in English and Estonian, the privacy policy,
   the Data safety and content rating answers drafted. Switch the icon back to winter
   before it ships. The user starts the developer account (a new personal account needs
   a 14-day closed test with 12 testers).
2. 037, the puzzle set by theme: the user decides the themes and their counts, what
   replaces "Capture 2", and which picker take to prototype; then build the set and the
   picker. Black to move in about a third.
3. 038, players (one per child): the user picks a take in `prototypes/profiles.html`
   (a proposed) and answers the task's open questions.
4. Small checks: on the Pixel 7a, a drop about 0.6 of a square off a target in puzzle 4
   lands on it (`board::snap`, not yet seen on a device); the tablet's stay-awake was
   left on when it was unplugged, turn it off when it is next attached.
5. Done (2026-11-08): the done tasks 006, 007, 008, 019, 020, 021, 023, 024, 025, 027, and
   028, and the cancelled 016, are archived.
6. 036, the announcement, after the release.

Not in the MVP (the user, 2026-11-08): sound; the visual feedback is clear, and sound
may come soon after, kept from being bling. To decide later: a puzzle rating like GoDraughts' and the computer's level
shown as a rating (both per player, after 037 and 038), 026's first start.

Alongside, when the user wants it: 015's 3D prototype (`poc/3d/`, its plan and sources in
the task; the user has more to add first).

After the MVP: 026 (first start and tutorial; its prototype awaits the user's review), 038
(players, a take to choose),
Russian puzzles the way 037 says, each level's adapted skill shown as a
rating (a number or stars on the computer's tile, like a chess rating; the user,
2026-11-08), 015, 013, 014, 033's seasonal icons, and
010 alongside.
