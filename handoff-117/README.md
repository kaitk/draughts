# Handoff: task 117, the maple (temporary)

A temporary folder so task 117 can go on on another machine. It holds the local material
that is normally kept out of git (`build/notes/`). Delete this folder when the task is
done, or move what is still needed back to `build/notes/` (local) and remove it from git.

To use it on the other machine: copy `notes/*` to `build/notes/` (so
`notes/tree/` becomes `build/notes/tree/`), because the task file, the decisions and the
scripts refer to those paths. The large tree dumps (`build/notes/tree/branches/dump/`, 104
MB) are left out: `tools/tree_dump` makes them again.

## Round two (2026-11-27)

Start at `notes/tree/round-2/index.html`: everything on from the chair behind the table,
then a page each for the skeleton and density (`branches.html`) and the bark's material
(`bark.html`), with the questions for the user. The user's bark specification is
`notes/bark-roots/norway_maple_bark_material.docx` (and `.txt`). The task file's sections
"Round two: the skeleton and density" and "Round two: the bark's material" hold the
switches, times and counts. Round two's new switches, all off by default:

- `--tree-elbow-plane`: elbows turned in the limb's upright plane and back.
- `--tree-limb-angle ON,DOWN,DOWN_V`: limbs off the trunk at Sapling's down angle.
- `--tree-hanging-twigs`: twigs hanging under level wood (negative AttractionUp).
- `--tree-detail`, `--tree-albedo`, `--tree-lichen`, `--tree-spec`: the bark's fine relief
  and small cracks, colour drift, lichen, and a weak broad highlight. Scattering showed
  nothing from the room and stays off.

Growth with round two's recommended settings is about 78 ms on the PC (the leaves' nudge
apart 28 ms of it), near the 100 ms budget: measure on the Mac first.

Warning for agents on Windows: `build/ngfx/goose-ngfx` is a junction to the goose-ngfx
checkout. Git 2.45's `git worktree remove` followed it out of an agent's worktree and
deleted the checkout twice (2026-11-26 and 11-27). Remove junctions in a worktree (`cmd /c
rmdir <junction>`) before removing the worktree, and never pass `--force`.

## Where to start (round one)

1. `tasks/117-maple-branches-and-leaves.md`: the criteria, the user's answers of
   2026-11-26, and a section for each built step with its switches, times and counts.
2. `notes/tree/choices.html`: round one's three studies side by side, the coordinator's
   reading of them, and all the questions (the user answered the starred ones).
3. `docs/decisions/rendering.md` (search "task 117") and `docs/architecture/rendering.md`.

## What is built (each part off by default, set in the light tuner)

All on `room-light`, checked on the Windows PC only (RTX 4090), not yet on the Mac or the
tablet. With every switch off, the tree is byte-identical to before.

| Step | Switches | Code |
|---|---|---|
| 1. Skeleton | `--tree-elbows FEWEST,MOST,TURN_LO,TURN_HI`, `--tree-gravity S`, `--tree-shed LIGHT,STUBS` | `src/model3d/tree_skeleton.goose`, `trees::grow_whole` |
| 2. Leaves | `--tree-plates ON,SPURS,NUDGE`, `--tree-tilt ON,SEASON,SAG`, `--tree-bend SHARE,TWIST`, `--tree-leaf-mesh tier\|card\|rows\|fan` | `src/model3d/tree_leaves.goose`, `tree_mesh.goose`, `shaders/tree.goose` |
| 3. Bark, junctions, roots | `--tree-bark on`, `--tree-relief K`, `--tree-scatter W`, `--tree-rough S`, `--tree-junctions on`, `--tree-roots on`, `--tree-wood-tier high\|standard\|phone` | `src/model3d/tree_bark.goose`, `tree_junctions.goose`, `shaders/tree.goose` |

`tools/tree_dump` takes the same settings without the `tree-` prefix, for CPU silhouettes.

Everything on, as tried (`notes/tree/all-on.png`), run from `tools/`:

```
light_tune --view table-window --tree-draw all --tree-elbows 1,2,30,50 --tree-gravity 1
  --tree-shed 0.45,0.5 --tree-plates 1,2,0 --tree-tilt 1,2,8 --tree-bend 1,25
  --tree-leaf-mesh tier --tree-bark on --tree-scatter 0.5 --tree-rough 0.8
  --tree-junctions on --tree-roots on
```

Times on the PC: growth 7 ms before; about 34 ms with steps one and two (the leaves'
nudge apart is 14 ms of it); step three's wood mesh 13 ms plain, 23 ms on the high tier;
the bark tile 35 ms once at startup. All under the 100 ms budget. Frame cost of the bent
leaves on the RTX 4090: +0.035 ms (fans), +0.01 ms (rows).

## Not done yet, and what still looks wrong

- **Elbows hardly show on the whole tree.** They read on a limb seen from its side
  (`notes/tree/branches/build/elbows.jpg`), but each turn goes a random way, so few read as
  the photos' zig-zags. Try turns kept in the limb's vertical plane. The user's count (0,
  1-2 or 3 a limb) waits on seeing this.
- **Limbs leave the trunk too steeply**; gravity above 1 adds little, as the bend reaches
  Stava's largest angle.
- **No hanging twig fans** in any method: needs a rule of its own.
- **Shedding takes the leaves with it** since step two fixed the leaves' segments: at 0.45
  the crown thins by a third; retune.
- **The plates look a little sparse and clumpy** from the room; `SPURS 3` fills them.
- **The season sets the tilt only**: the tint stays autumn's. All seasons come later.
- **Bent leaves hardly show from the room**; they read as light changing across a blade.
- **The ngfx build draws flat leaf cards only.**
- **Bark**: the plate edges are too even; scatter and roughness are subtle at the window's
  distance and need the user's eye (the user's note: bark looks like plastic: try
  scattering and less shine). A small step where a fork's thin branch meets its parent; a
  notch now and then beside a trunk junction.
- **Roots show only in the CPU renders**: the window pier hides the trunk's base.
- **Not built**: codominant stems (a later task), the hanging limb grown by gravity (open),
  Palubicki's full shadow grid as a high tier (open), the tropism criterion and the
  envelope criterion of the task as written, the checks on the Mac and the tablet, and the
  per-tier tuning for phones.

## Open questions for the user

From `notes/tree/choices.html`, not answered yet: how many elbows (after seeing them in the
vertical plane), the hanging limb, how much sag, Palubicki's grid as a high tier, the
measured tilts in place of the task's "within 15°", more sag inside the crown, whether the
tablet's bent leaves are worth it, the nudge apart or Weisse's ratios alone, which old bark
to match (park or lawn tree), moss and lichen, how much root shows, roots on all tiers, and
parallax later.

## What is here

- `notes/tree/photos/`: the photos of the maple (bare and leafy, Tartu plates).
- `notes/tree/choices.html`: the round-one summary and questions.
- `notes/tree/branches/`: the branch study (`compare.html`, `src/compare.py` remakes it),
  and step one's pictures in `build/`.
- `notes/tree/leaves/`: the leaf study (`index.html`, `src/`), step two's pictures in
  `build/`.
- `notes/tree/bark-roots/`: the bark, junction and root study (`index.html`, `src/`), step
  three's pictures in `build/`.
- `notes/tree-gravity/`: the gravity brief, Stava et al. 2014 (the PDF) and the photos.
- `notes/bark-roots/`: the bark and roots brief and its photos.
- `notes/leaves-earlier/`: an earlier leaf session's before and after pictures.
- `notes/tree/index.html`, `notes/tree/img/`: the first research page of 2026-11-24.
