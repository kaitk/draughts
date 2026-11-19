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

## Open

Done and cancelled tasks are listed in `000-archive/README.md`; the MVP in
`docs/product.md` is built.

- Release: 096 ngfx shipped on Mac, iOS and Windows as 0.9.1, 029 Google Play (closed test running), 046 the App Store (in review), 036 the
  announcement after the Play release, 075 the Linux build, 064 Steam (low priority,
  scoped only; the board under the mouse first).
- Content and play: 038 the badges' final silhouettes; 097 testers' puzzle feedback (kings in
  the solver, take puzzles, refilling the libraries).
- Menus and layout: 072 keyboard and controller focus; 098 How to play within reach while learning.
- Small fixes: 091, built; the mouse drag on Windows left to check.
- Settings: 092 About and the battery saver's cap, built; the devices left to check.
- The 3D board: 042 the idle wakeup, 071 its memory, 094 the pieces' materials (parked on its branch), 095 a
  table under it.
- Frames: 055 the boards locked to the display's rate, with even pacing and the A33 at
  60 fps.
- Renderer: 065 NoGraphicsAPI through goose-ngfx, with the renderer chosen at run time,
  the uncapped Windows runs, and MSAA and older Apple GPUs.
- Upstream: 010 goose_gfx changes in order, Wayland's branches among them, then SDL's;
  cute_spirv's Direct3D 12 fix for cute_framework and Goose, and the first instance.
- The manor room: 093, a whole room around the 3D board; exploratory, concept art only.
- Later: 013 season effects, 060 shared blocks for a second board game.

To decide later: a puzzle rating and the computer's level shown as a rating.
