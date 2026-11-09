# 047: Review the code's structure and clean up

Status: todo

The first thing for the next session (2026-11-09), run as a subagent: a look at the
whole project's directories, files, and code composition, now that it builds for
Android, iOS, and the Mac and has a 3D board. Task 020 reviewed the layout once, before
these.

- **Platforms:** are Android's and iOS's parts well separated and encapsulated
  (`android/`, `ios/`, `scripts/android.py` and `scripts/ios.py`, `src/app/`'s platform
  C, `platform.h`, the patches), with what they share in one place?
- **Readability:** where something obvious would read better moved or extracted, do it:
  a file grown past what one screen of it says, a function doing two jobs, a table
  repeated. Not files for their own sake, and nothing that only feels tidy: no layers,
  interfaces, or indirection without a measured reason (AGENTS.md's code rules).
- **No cost:** nothing that slows the frame loop or allocates in it, and nothing that
  closes doors the product needs: more puzzles and puzzle sets, more board styles
  (task 045), a renderer without goose_gfx later.
- **Clean up:** dead code, flags no longer used, stale docs and comments, leftovers from
  the 3D branch, old prototypes' leftovers that no prototype uses, task files done and
  ready for the archive (`tasks/README.md`, "Archive").

Propose the changes first as a short list with the reason for each; make them after the
user agrees, one step a commit, `scripts/test.sh` passing and the app looking the same
(headless shots before and after).

## Acceptance criteria

- [ ] A list of proposed changes, each with its reason, agreed with the user
- [ ] The agreed changes made, tests passing, shots unchanged
- [ ] Stale docs, flags, and tasks cleaned up
