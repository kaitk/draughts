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
settled the look in HTML prototypes, 005 made the idle app draw nothing, 012 brought the
prototypes to the seasonal design boards, 004 drew the board natively, 017 brought it to
the settled look, 018 finished the pieces' shape, and 009 added the string table;
all nine are archived. 008 (a folder of subtasks) builds the shell, and 006 and 007
follow. Together they make the MVP in `docs/product.md`. 019 prototypes the game screen's controls, a clock, and the first start, alongside them, and
021 builds the screen, clocks, and setup it settled, 025 the regrouped settings, and 023 adds Brazilian draughts; 026 (the first start and tutorial) comes after the MVP's menus; 020 reviews the code's
layout once the MVP's flows work. 010 runs alongside: goose_gfx changes
to propose upstream. 011, the last idle CPU (SDL's accelerometer), can come any time
before release. 013 adds season effects later. 014 upscales the backgrounds on the
desktop; placeholders do until then. 024 reviews the Estonian translation once the MVP's text is in. 015 (the 3D board) and 022 (transitions between screens, optional) come after the MVP, and so does 033 (an icon per season; until then one icon, switched by hand); 016
(tabletop pictures) was cancelled. 031 makes the win calmer, and 032 brings memory down last. 027 has the computer spend its clock as a player of its level would. 028 (the icon and launch screen), 030 (phones and other screen sizes), and 029 (release on Google Play) make the release.

## Next (agreed 2026-11-08, updated at the session's end)

The MVP's features are in: puzzles, the computer with its clock, three variants, the
icon and launch, the win (031), the setup's board (034), the transitions (022), and
home's X (035, all but its phone check). Done on 2026-11-08 and archived or recorded in
their tasks: the `--tap` stall (tablet runs start with `am start -S`), the launcher's
name per language ("Kabe" in Estonian), the autumn icon (winter again for the winter
months and the release, task 033), a multi-capture tapped stop by stop and puzzles with
no targets (task 007), medium starting at skill 40 and never under 25 (task 006), and
settings' Board row hidden until the 3D board exists (`--3d`, task 015).

The order for what is left:

1. 030, phones and other screen sizes: the survey, the fixes (home's portrait menu runs
   off phones; home's portrait settings button is 48 dp, under the 88 dp floor), insets,
   then the user's Pixel 7a. It closes 035's last criterion. Before memory, so memory is
   sized and measured on the final layouts.
2. 032, memory: measure first, then the blur against its alternatives, ASTC with a
   fallback, sizing by each screen's size and density; the idle CPU rise; PSS was 277 to
   278 MB on puzzle 21 after the lifecycle cycles (task 007 had 268 to 272).
3. 011 before release, then 029, the Play release (start the developer account early:
   a new personal account needs a 14-day closed test with 12 testers). Switch the icon
   back to winter before it ships.
4. Children play it (task 006's last criterion; medium's strength, the
   computer's time on the clock).
5. 036, the announcement (a tweet, the Goose Discord, a video, a thread on the methods),
   after the release, its numbers measured after 032 and 030.

Alongside, when the user wants it: 015's 3D prototype (`poc/3d/`, its plan and sources in
the task; the user has more to add first).

After the MVP: 026 (first start and tutorial; its prototype awaits the user's review),
Russian puzzles from the International ones, each level's adapted skill shown as a
rating (a number or stars on the computer's tile, like a chess rating; the user,
2026-11-08), 015, 013, 014, 033's seasonal icons, and
010 alongside.
