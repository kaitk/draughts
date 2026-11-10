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
board show the game, 035 added home's X, 015 the 3D board (in main 2026-11-09), 047
reviewed the structure, 049 added the draws, 051 polished what preparing the stores found,
053 made the computer's mistakes follow how tense the position is, 050 fitted small iPad
windows, 048 found no forced capture behind a report (covered by tests), 039 baked the 3D
board's wood, 040 added the lookout and the hint, 054 gave the flat game screen the 3D one's
controls, 052 showed what each side has taken, 044 added the plain background, 057 made the app
rest on every platform, 059 profiled and reworked the 3D renderer, and 060 made the UI's shader fast in itself; 016 (tabletop pictures) and 033 (an icon per season) were
cancelled. All are archived. The MVP in `docs/product.md` is built.

Open:

- Release: 029 Google Play, 046 the App Store (after 043, iOS), 036 the announcement
  after the Play release.
- Content and play: 037 the puzzle set by theme, 038 players.
- The 3D board: 041 a carved spring board, 042 its frame cost (the idle wakeup left),
  045 board styles to choose from.
- Frames: 055 both boards locked to the display's rate on every device, 056 even pacing
  where the frame fits but still drops (the iPhone).
- Code: 061 the code review's refactors (2026-11-10), five stages, one per session.
- Docs: 062 the docs split as Plod's are, decisions for agents and architecture for
  people, after 061.
- Later: 010 goose_gfx changes to propose upstream (alongside), 013 season effects, 014
  upscaled backgrounds, 026 the first start and tutorial, 060 shared blocks for a second
  board game (chess).

## Next (updated 2026-11-10)

Done on 2026-11-10: task 059's four 3D speedups (the field's occlusion and the crown
into maps, the backdrop and the UI kept while they stand still): the tablet's moving 3D
board holds 90 Hz with no frame dropped, the Pixel 7a a third fewer GPU cycles a frame;
044 (the plain background) and 057 (at rest everywhere) closed.

Done later on 2026-11-10: 060, the UI drawn live at half its GPU cycles on the Pixel
(three shaders at 32 registers, quads only as large as their shadows, glass and tiles
shaded in parts); 042 brought up to date after 059.

Next for the agent:

1. 042: the 3D board's idle wakeup on the tablet (about 2.7 ms CPU against the flat
   board's 0.3), when the tablet is attached.
2. 055: a screen transition counted as the boards' frames are; 056: the iPhone's flat
   board's drops and the Pixel's one 3D drop over a longer run.

What needs the user:

1. Back up the upload key (`~/.config/draughts/upload-key.jks` and its properties).
2. 029: the developer name and the contact email in `store/`'s placeholders; publish
   `store/privacy/` on GitHub Pages; open the personal Play account and find the 12
   testers for the 14-day closed test. Nothing goes to Play until the user says so.
3. 037: play the sets and their levels' order on the tablet, Brazilian's too; the
   Russian set's open terms; approve the store's text and the 2026-11-10 screenshots
   (`store/README.md`).
4. 038: the final badge silhouettes, if the traced ones are to be replaced.
5. 041: the carved spring board's look.
6. The child's next games: whether easy at skill 0 feels right (`docs/architecture/ai.md`'s
   tuning notes), and whether multi-jump captures are clear with the capture count.

Then: 036 after the release.

Not in the MVP (the user, 2026-11-08): sound; the visual feedback is clear, and sound
may come soon after, kept from being bling. To decide later: a puzzle rating like
GoDraughts' and the computer's level shown as a rating (per player), 026's first start.
