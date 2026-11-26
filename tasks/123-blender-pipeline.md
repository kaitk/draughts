# 123: The scene to Blender and back

Status: todo

Task 120 added an export of the library room to Blender (`tools/blender_export.goose`: OBJ
in metres, z up, one object per part; `scene.json` with the sun, the sky, the albedos, the
windows and the tuner's named views) and a Cycles script that renders a view
(`tools/blender/scene.py`). It was the reference for task 122's light. The first plan for the
room was to build it in Blender (task 107), so the pipeline is worth keeping in shape in
both directions (the user, 2026-11-26): our scene out, for reference renders; meshes in,
from Blender's ecosystem, for shape only, with our own procedural materials (task 107's rule).

## Acceptance criteria

- [ ] The export covers every part the room draws (the lace as task 124's model, the maple
      when task 117 settles it), and stays in step with `model3d` through a check in
      `scripts/test.sh`
- [ ] Our materials' look in Cycles close enough to judge a picture: the procedural woods,
      the cloth, the gloss
- [ ] Import: a mesh from Blender (a glTF or OBJ) into `model3d` as fixed data, shape and
      UVs only, assigned one of our materials; one prop brought in as the example
- [ ] `tools/blender/README.md` says how to run each direction
