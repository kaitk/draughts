# 113: The park's trees as baked impostors, and no baked blur outside

Status: todo

The view out's trees are pictures today: the oak card (task 109's ChatGPT cut-out, put in
place seven times by the park look test, `--park ground`) and the tree-line band. They are
front-lit, flat, and blurred before they reach the screen, so they read as pasted in, and
the blur looks strange now that the lawn is sharp (the user, 2026-11-22). The plan (task
109, Outside, 2026-11-22): the trees out to about 100 m become impostors baked from our own
grown trees and lit live; the tree line beyond is made sharp too; all blur outside then
comes from the lens (task 111), so it follows the focus.

How the impostors work is shown live in `build/notes/outside-impostors/index.html` (local);
the user chose its "Views over the room's angles" mode.

## Plan

1. **Trees to bake.** Task 105's grower (`trees.goose`, `tree_whole.goose`, branch
   `tree-prep`) grows the near maple; give it a few habits for the park (Norway maple,
   oak, small-leaved lime, a spruce or two) and a couple of seeds each.
2. **The bake** (task 105's T5 card, grown): each tree rendered on the GPU from 4 × 3
   views over the angles the room sees it from (±25° across, from 5° above its crown's
   middle to 30° below), into two atlases: colour with occlusion and coverage, and normal
   with depth. 8 bits and mips, compressed where the tier has it. When to bake (at room-on,
   or offline into the build) is decided by its time.
3. **The draw** in the outside pass: a box round each tree; each pixel blends the 4
   nearest views, each marching its ray through that view's depth. The depth is read
   unfiltered and as a thin shell, so a ray stops only on a surface the bake saw, never on
   the step between a near leaf and what lies behind it (the comparison page's two bugs).
   It writes its depth, so trunks stand on the lawn. Lit by the key's sun and sky, the
   leaves backlit, hazed with distance; no baked light.
4. **The park's layout**: the look test's places (the oak at 70 m 22° right, the tree 6°
   left at 50 m whose shadow crosses the middle window's lawn) and 20-40 trees between
   15 and 100 m, after Alatskivi's open lawns between masses (task 109).
5. **Their shadows on the lawn** from the impostors, in place of the cards' ray test:
   the same test against the colour atlas's coverage, or a small shadow map made when the
   sun or the layout changes.
6. **The tree line past 100 m**, sharp: a picture made at 2-3 times today's resolution
   with no blur baked in, or more rows of impostors to the horizon in the haze. A look test
   of both, the user picks.
7. **The baked blur removed**: `render3d::soften` of the oak (`view_out::OAK_SOFT`),
   `tools/materials/outside.py`'s `OAK_BLUR` and `BAND_BLUR`, and the band's foot fix
   (`park_band_foot`) if the new tree line no longer needs it. This replaces the
   2026-11-21 decision in `docs/decisions/rendering.md` (the oak blurred once when
   uploaded); update it and `docs/architecture/rendering.md` in the same change.
8. **Costs** measured at the end, on a quiet Mac, then the A33; each tier's version
   chosen then (phones perhaps one view a tree).

Depends on task 105's grower (step T1) for the trees and on task 111's B3 (the view out's
discs) for the blur the pictures stop carrying.

## Acceptance criteria

- [ ] The park's trees from 15 to about 100 m are baked from grown trees, stand on the
      lawn, hold their perspective from every window and pan, and follow the sun
- [ ] No branch floats when the eye moves within the room's angles
- [ ] The tree line past 100 m is sharp, its foot on the lawn with no smear
- [ ] No blur is baked into anything outside; the lens alone blurs it
- [ ] The decisions and architecture docs say so, the 2026-11-21 blur decision replaced
- [ ] Bake time, memory and the outside pass's cost recorded per tier
