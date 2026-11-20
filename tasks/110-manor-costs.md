# 110: The manor scene's costs, made affordable

Status: todo (planned 2026-11-20; after the look of the epic 107 is settled)

The manor scene's work (the epic 107) goes for the look first and leaves its costs here,
to pay them down once the look is chosen (the user, 2026-11-20). They are fine on the
branch for now. Ways to pay them, as the user sees it: bake beforehand and store the
results, or keep baking at run time behind a loader when the room or a look is chosen
(task 101's progress bar), and per render tier (`AGENTS.md`).

## The costs so far (the Mac, 2026-11-20)

- The room's oak (task 104's note): the wood bake's two fields, floor and wainscot, four
  2048² RGBA8 textures with mips, 85 MiB, baked in 45 to 48 ms (about 120 ms the first
  time after a shader change), only with the room on. At 1024², 21 MiB.
- The tree's map (task 105): 512² RGBA8 with mips.
- The `branches` wind (task 105): six value noises and 4 texture taps a pixel where the
  window's pattern is on; not measured on a device.
- Dust in the sunbeam (task 104's follow-ups): not measured.
- ngfx's 5 ms more on shadow-map frames with the pattern on (task 107): not reproduced.
- No frustum culling: every object is drawn whenever a frame is, only back faces culled.
  Cheap while the room is a few draws; as the room and the outside fill up, test each
  object's bounds against the view, at least for the frames that redraw the kept backdrop
  and the home screen's pans.

Add each new cost here as it lands, with its numbers.

## Acceptance criteria

- [ ] Each cost above measured on the Mac and the A33 (task 071's way for memory)
- [ ] For each, a choice recorded: baked offline and stored, baked at run time behind a
      loader, cut per tier, or kept as it is
- [ ] The 3D standard tier's memory and startup no worse than before the epic 107, or the
      difference agreed with the user
