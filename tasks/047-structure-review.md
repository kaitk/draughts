# 047: Review the code's structure and clean up

Status: done (2026-11-09)

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

## Agreed and made (2026-11-09)

1. `scripts/native.py` holds what `scripts/android.py` and `scripts/ios.py` shared: the
   paths, `APP_ID` and `VERSION_NAME` (set once), `run`, `sidecar`, the Goose-to-C step,
   the patched goose_gfx and SDL copies (iOS's stamp, which works without git), and the
   launcher's names. Both still build (an APK and a simulator app, build only).
2. Declined: one CMake include for `android/` and `ios/`. Their drift shows at once, as a
   link error.
3. The app's flags in `src/app/flags.goose`: `Flags`, a comment per field, and
   `parse(argv)`; `--board` one value, `--reset-skill` read in the loop, no pre-scan.
4. One variant-name table, `rules::VARIANT_NAMES` with `rules::variant_named`, for the
   settings and puzzle files, the flag, the tools, and the tests; the files read and
   write the same names.
5. Stale paths in comments (`app/` before `src/`, `poc/3d/`'s mesh and shaders now
   `src/render3d/`), and the 3D board's sizes marked as kept in step in `view3d`,
   `mesh`, and `shaders`.
6. `scripts/ios.py`'s unused launch colour removed.
7. The unused `puzzles::nth` removed.
8. `src/render3d/` in the README's layout.
9. `--background`, `--summer`, `--spring`, and `--reset-skill` in `docs/development.md`.
10. `.DS_Store` ignored.
11. `tasks/README.md`'s order, open tasks, and next steps brought up to date.
12. 015 done and archived (its device numbers moved to `docs/architecture/rendering.md`,
    its open items to 041 and 042), 033 archived as cancelled, 042 in progress, 043's
    device build ticked, 044's device checks made criteria.
13. Deferred: task 010's upstream list, for later.
14. Task numbers in the README and the docs replaced with the facts or doc links.

**Shots:** a headless build (`agents/testing.md`) of twelve screens at 1280 × 800 and
one portrait, before and after: home, home's setup, a game, a clocked game, the
puzzles and a puzzle, settings, and the plain background on the flat board, and home,
a game, and settings on the 3D board. The flat ones are identical (`compare -metric
AE` 0); the 3D ones and settings differ by 1 to 68 pixels in the same boxes as two runs
of one build (the 3D board's edges, settings' preview), so unchanged. `scripts/test.sh`
passed after each code step.

## Acceptance criteria

- [x] A list of proposed changes, each with its reason, agreed with the user
- [x] The agreed changes made, tests passing, shots unchanged
- [x] Stale docs, flags, and tasks cleaned up
