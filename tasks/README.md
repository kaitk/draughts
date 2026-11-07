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

001 confirmed the stack (Goose runs on the tablet) and 002 built the rules engine; both
are archived. 003 (HTML prototypes) is next. Then 004 and 005, then 006 to 009. Together
they make the MVP in `docs/product.md`. 010 runs alongside: goose_gfx changes to propose
upstream.
