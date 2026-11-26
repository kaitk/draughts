# 125: The look tuned in Blender, carried to the app

Status: todo (a plan; starts after task 122)

The user's plan (2026-11-26): settle the look in Blender first, where the light, the window's
beam and the dust can be tuned quickly, then carry it to the app. There is no automatic way
from a Cycles scene to 30 fps on a Mali: every effect is still approximated by hand. Blender
sets the target; the app is measured against it, as task 122 does for the light.

How, as agreed:

- Values, not node graphs. Each of our shader models (wood, cloth, stone, plaster, brass)
  gets one Blender node group built to match ours, once. Their parameters (albedo,
  roughness, grain and so on) live in one file that both the app and Blender read, so a
  value tuned in Blender reaches the app without porting. Materials first: they must stay
  ones the app can draw, never a Blender-only node.
- The geometry stays in code (`mesh::`). Blender doesn't reshape the room; new props come
  in through task 123's import.
- EEVEE for the feel of the beam and the dust (closer to what the app can draw), Cycles for
  the truth. Tuning in Blender kept to a minimum.
- One tone mapper in both, derived from AgX: Blender's AgX view, and in the app a short fit
  of it (a matrix, a log curve, a polynomial, a matrix back), not Blender's lookup table.
  The user judges it on full materials first; it stays if it costs no more than today's.

## Acceptance criteria

- [ ] The materials' parameter file read by the app and by the Blender scene
- [ ] One node group per shader model, matching the app within a stated error on a test card
- [ ] The app's AgX fit against Blender's AgX on the same linear picture, and its cost
- [ ] The beam and the dust tuned in Blender, then carried over with their error stated
