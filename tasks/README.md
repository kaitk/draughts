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
021 builds the screen, clocks, and setup it settled, and 023 adds Brazilian draughts; 020 reviews the code's
layout once the MVP's flows work. 010 runs alongside: goose_gfx changes
to propose upstream. 011, the last idle CPU (SDL's accelerometer), can come any time
before release. 013 adds season effects later. 014 upscales the backgrounds on the
desktop; placeholders do until then. 024 reviews the Estonian translation once the MVP's text is in. 015 (the 3D board) and 022 (transitions between screens, optional) come after the MVP; 016
(tabletop pictures) was cancelled.
