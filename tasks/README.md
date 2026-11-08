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
desktop; placeholders do until then. 024 reviews the Estonian translation once the MVP's text is in. 015 (the 3D board) and 022 (transitions between screens, optional) come after the MVP, and so does 033 (an icon per season; shipping autumn instead of winter is a smaller call before it); 016
(tabletop pictures) was cancelled. 031 makes the win calmer, and 032 brings memory down last. 027 has the computer spend its clock as a player of its level would. 028 (the icon and launch screen), 030 (phones and other screen sizes), and 029 (release on Google Play) make the release.

## Next (agreed 2026-11-08)

The MVP's features are in (puzzles, the computer with its clock, three variants, the
icon and launch). The order for what is left:

1. Done (2026-11-08): `--tap` seemed to stall on the tablet; the cause was `am start`
   bringing back a running app with its old flags, so tablet runs start with `-S`
   (task 007).
2. 031, the win: take a, the pieces answer.
3. Done (2026-11-08): the launcher's name follows the phone's language ("Kabe" in Estonian):
   `scripts/android.py` writes `res/values*/strings.xml` from `strings/<lang>.txt`, and
   the manifest takes `@string/app_name`. The icon stays winter (task 033).
4. 034, the setup's board shows the game being set up.
5. 022, transitions: continue and a new game with the sharp-to-blurred crossfade, the
   game back to home, and a puzzle opened from the picker if it stays as cheap; not the
   setups.
6. 030, phones and other screen sizes, before memory, so memory is sized and measured on
   the final layouts.
7. 032, memory: measure first, then the blur against its alternatives, ASTC with a
   fallback, sizing to each screen; and the idle CPU rise.
8. 011 before release, then 029, the Play release (start the developer account early:
   a new personal account needs a 14-day closed test with 12 testers).
9. Children play it (task 006's last criterion; medium's strength, the
   computer's time on the clock).

After the MVP: 026 (first start and tutorial; its prototype awaits the user's review),
Russian puzzles from the International ones, 015, 013, 014, 033's seasonal icons, and
010 alongside.
