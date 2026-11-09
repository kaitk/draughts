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

## Next (updated 2026-11-09, at the night session's end)

Done on 2026-11-08 and 9: 029's package (the AAB and APK signed with the upload key,
version 0.1.0, app id `io.github.kaitk.draughts`, the listing drafts in English and
Estonian, the privacy page, the Play Console answers drafted; nothing submitted); 037's
set by theme with the picker on glass rows, a first Russian set of 46, and stars per
variant; 038's players, with the chip (the badge bare, the name on a glass pill) at the
board's side, the first-run pick on a fresh install only, and the traced animal badges;
the public repo `kaitk/draughts` under MIT OR Apache-2.0. Idle CPU on the release build,
untouched: 0.05%.

What needs the user:

1. Back up the upload key (`~/.config/draughts/upload-key.jks` and its properties).
2. 029: the developer name (likely "Gideonic") and the contact email in `store/`'s
   placeholders; publish `store/privacy/` on GitHub Pages; open the personal Play
   account and find the 12 testers for the 14-day closed test; review the listing
   drafts, the Estonian especially. Nothing goes to Play until the user says so.
3. 037: play the set and its levels' order on the tablet; the Russian set's open terms
   (the sieve, free tempo); Brazilian's own set.
4. 038: the final badge silhouettes, if the traced ones are to be replaced.
5. On the Pixel 7a: a drop about 0.6 of a square off a target in puzzle 4 lands on it
   (`board::snap`, not yet seen on a device).

Then: 015's 3D prototype (`poc/3d/`), the user's next session; 036, the announcement,
after the release.

Not in the MVP (the user, 2026-11-08): sound; the visual feedback is clear, and sound
may come soon after, kept from being bling. To decide later: a puzzle rating like
GoDraughts' and the computer's level shown as a rating (per player), 026's first start.

After the MVP: 026 (first start and tutorial; its prototype awaits the user's review),
more Russian puzzles and Brazilian's, 015, 013, 014, 033's seasonal icons, and 010
alongside.
