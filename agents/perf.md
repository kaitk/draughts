# Measuring the 3D scene's speed

The standard way to measure and change the room's rendering speed on the Mac, so every
session and tool measures the same way. `agents/testing.md` ("Frame pacing", "GPU
profiling") holds the tools' details; `agents/goose.md` ("Speed") the code's rules.

## Builds

- Run from the repository root (or a worktree's). The ngfx build needs:
  `export NGFX=$HOME/projects/goose/goose-ngfx NGFX_SLANGC=$HOME/projects/goose/slang/bin/slangc`
- The light tuner, where all scene measuring happens: `python3 scripts/mac.py tools/light_tune.goose`
  writes `build/light_tune`. Run it from `tools/` with `--room-surfaces on --outside on`
  (as `build/stable/run-tuner.sh` does).
- The apps: `python3 scripts/mac.py src/main/draughts.goose` (gfx) and
  `python3 scripts/mac.py src/main/draughts_ngfx.goose` (both renderers). Both must build.
- Tests: `scripts/test.sh` with NGFX set (it also runs `goose check` on both apps). Must pass.
- No other build commands, flags or toolchains. ngfx compiles the same GLSL from
  `src/render3d/shaders.goose` (`scripts/ngfx_3d_shaders.py`) and stays at parity with gfx.
- At the end of a finished change, in the main checkout only: copy `build/light_tune` to
  `build/stable/light_tune-<short hash>`, point `build/stable/run-tuner.sh`'s `exec` line and
  header comment at it, and remove the previous stable binary if no process runs it
  (`pgrep -f`). The user tries changes with `build/stable/run-tuner.sh`.

## Views

Headless (`GOOSE_GFX_HEADLESS=1`), from `tools/`, `--room-surfaces on --outside on`, at
3840 × 2160 and 5120 × 2880 (the user's screens) unless a task says otherwise:

| View | Flags | Why |
|---|---|---|
| Straight down | `--plan-eye 6.0,3.0,1.7 --plan-at 6.0,3.05,0` | the floor fills the screen |
| Corner | `--plan-eye 8.4,0.6,1.6 --plan-at 2.0,5.0,0.5` | the walk's start: the worst case, nearly everything |
| Room | `--view room` | the room's own view |
| Menu | `--view table-window` | the main menu's view from the table |

`--shot FILE.png` saves a picture. `--fps-seconds S` prints `N ms a frame` each half second
(parse under `LC_ALL=C`; run a fresh binary once before timing it). `--view-nudge` does
nothing in headless shots: frame with `--plan-eye`/`--plan-at` (plan metres) instead.

## Measuring

- Only one job on the GPU at a time, across Claude, Codex and the user: hold
  `build/perf/quiet.lock` (in the main checkout) for every batch of renders, timing or shots.
  Take it atomically, never by plain creation: `L=/Users/kaitkasak/projects/personal/draughts/build/perf/quiet.lock;
  until (set -o noclobber; echo "$$ $(date +%s) <who>" > "$L") 2>/dev/null; do sleep 60; done`.
  `<who>` is a fixed tag of yours (a task name), since each shell call has its own `$$`.
  Holding it is the check. Remove it only if it is yours (`grep -q " <who>$" "$L" && rm "$L"`),
  right after the batch. Never overwrite or delete another's lock; one older than
  an hour with no live process of its pid may be stale: report it, don't take it. Never kill a `light_tune` process you didn't start (the user's tuner);
  if one runs, note it, its frames disturb yours.
- Before and after builds of the same views, two alternating rounds (A B A B), means of each.
  Measure at the start and after each finished step, not after every edit.
- Where the time goes: Metal System Trace (`agents/testing.md`, "Frame pacing"), split by the
  `Render Command N` index in each row's event label (the main pass was N = 11). Or a
  per-part split: scratch builds each without one part, against one whose shader returns a
  flat colour. Parts overlap: they don't add up.
- Delete every trace export (`build/perf/trace/`, XML) once read: the disk filled once.
- A branch around code that stays compiled saves little on the Mac (`agents/goose.md`,
  "Speed"): leave code out with a define or a separate pipeline, and measure both.

## Identical or not

- "No visible change" means the shots of all four views are byte-identical, or differ by at
  most a level or two in a few pixels, as two runs of one build do. Report the largest
  difference in levels and the number of pixels over 8.
- Anything more is a look change: don't make it the default. Put it behind a tuner flag,
  default off, with shots for the user, and ask.
- Check motion where it matters: two shots 1 cm apart (`--plan-eye`) or two `--wind-time`
  values.

## Results page

`build/notes/<topic>/index.html` (or a named page there): local HTML, opened as a
`file:///` link, never Markdown or a hosted artifact. Dark like
`build/notes/floor-perf/night.html` (copy its `<style>`). Pictures beside the page in
`img/` or inline. In order: what changed, a table of ms before and after for each view and
size, the pixel differences, full shots with 100% and 300% crops where something shows,
open questions with their numbers.

## Recording

- Commit each finished step with one lean sentence: no body, no trailers. Never push.
- A change that contradicts `docs/decisions/rendering.md` gets a dated entry there saying
  what it replaces, and `docs/architecture/rendering.md` updated, in the same commit.
- The numbers go into the task's file (`tasks/107-manor-scene.md` for the manor's speed).
- Nothing allocates in the frame loop; code lean and plain (`AGENTS.md`).
