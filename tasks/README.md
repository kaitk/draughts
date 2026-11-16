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

- Release: 029 Google Play (closed test running), 046 the App Store (in review), 043 iOS
  (the icon left), 036 the announcement after the Play release, 075 the Linux build and
  076 Wayland, 064 Steam (low priority, scoped only).
- Sound: 089, a few quiet sounds, off at first on touch devices.
- Content and play: 026 how to play, 037 the puzzle set, 088 daily puzzles, 038 players,
  074 the games' history and a rating, 087 the replay's moves and the desktop's results.
- Menus and layout: 080 New game, settings as one list, and the board's material; 083 the
  layouts on devices; 072 keyboard and controller focus; 067 the board under the mouse.
- The 3D board: 041 carved looks, 042 the idle wakeup, 071 its memory.
- Frames: 055 the boards locked to the display's rate, 056 even pacing, 081 the A33 at
  60 fps.
- Renderer: 065 NoGraphicsAPI through goose-ngfx, 073 the renderer chosen at run time,
  074 ngfx against gfx on Windows, 077 ngfx's MSAA and older Apple GPUs.
- Later: 010 goose_gfx changes upstream, 013 season effects, 014 upscaled backgrounds,
  060 shared blocks for a second board game.

Not in the MVP (2026-11-08): sound, which may come soon after, kept from being bling. To
decide later: a puzzle rating and the computer's level shown as a rating.
