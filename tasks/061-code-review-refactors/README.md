# 061: The code review's refactors

Status: in-progress

On 2026-11-10 a high-level review, at commit `abfcb5c`, read the code for readability,
how it is split into files, how easy its flow is to follow, the layout code, and how
separate the drawing is. Its findings:

- **The packages below the shell are sound.** `rules`, `ai`, `puzzles`, `board`, and
  `badges` are clean. Nothing outside `app/` and `render3d/` uses gfx, and nothing
  allocates per frame. About 9.9k lines of headless tests make refactoring safe.
- **The cost is in `shell`, `game`, `panel`, and `main()`:**
  - Grab-bag files.
  - The same screen dispatch written in eight places.
  - Flags one package sets and another clears.
  - Layout worked out by hand per screen, with about 400 bare `N.0 * u` numbers.
  - No seam between the app and the renderer.

This task turns those findings into five stages, each a subtask, and then updates the
overview page. Do one stage per session and clear the context between them. A stage's
file holds what its session needs. Line numbers are as of `abfcb5c`, so look a name up again before editing.

| Stage | Subtask | Changes what the app shows |
| --- | --- | --- |
| 0 | `01-sizes-failures.md`: the failures saved in `sizes`' expected output | maybe (real overlaps fixed) |
| 1 | `02-moves.md`: files split, leftovers, dev flags out of `main`, shared constants | no |
| 2 | `03-structure.md`: one screen table, events instead of flags, the shell's `Frame` | no |
| 3 | `04-layout.md`: the panel's regions and modes, `gui::stack`, pure screen layouts | no |
| 4 | `05-renderer-seam.md`: `app/host` and `app/render`, pixels from C, `render3d` split | no |
| after | `06-overview-page.md`: "Draughts from above" updated and put in `docs/`, later on Pages | no |

The order matters:

- Stage 0 makes `sizes` a safety net that fails on a regression.
- Stages 1 to 3 are checked by identical expected output.
- Stage 4 is the seam that task 060 (shared blocks for a second game) and a later
  goose-ngfx renderer build on.

Rules for every stage:

- **No frame cost.** Each item is a move or a reshaping of code that runs once a frame
  or less. Where an item could cost time, its stage says what to measure.
- **Identical tests.** After each item, `scripts/test.sh` passes with every expected
  output byte-identical. Stage 0 is the exception: it may change `sizes.out` on purpose.
- **Measure once, at the end of the task** (after stage 4), not per stage (the user,
  2026-11-10). Run the idle CPU script and `--bench` on the 2D and 3D boards on the Mac,
  then on the A33 (`docs/development.md`), with the season photograph's load time (stage
  4). Compare with a build of `6bf54c8`, from before the task, and record both here. A
  stage may run a quick `--bench` on the Mac where it reshapes something that runs each
  frame, but no devices.
- **One commit per finished item**, one lean sentence each.
- **Docs in the same change.** Update `docs/architecture/` wherever a stage moves
  something it names.

Left out on purpose:

- A Clay-like layout engine. `gui::stack` in stage 3 covers what it would give here.
- The goose-ngfx renderer itself (`docs/product.md`, task 060).
- A wrapper over single gfx calls: gfx's and ngfx's APIs differ too much for one.

## Acceptance criteria

- [x] Stage 0: `sizes` fails on any listed failure not on its allow-list
- [x] Stage 1: the moves made, tests identical
- [x] Stage 2: one screen table; the game returns events; the app reads the shell's frame
      output only
- [ ] Stage 3: the panel's layout as regions with a mode; `gui::stack` in use; home and
      settings with pure layout functions
- [ ] Stage 4: `main` calls no gfx drawing; one `render::frame`; C decoders return pixels
- [ ] The overview page updated to the new code and in the repo
- [ ] Idle CPU, frame times, and the photograph's load on the Mac and the A33, measured
      once at the end against `6bf54c8`, none noticeably worse
