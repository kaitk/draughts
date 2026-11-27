# The antique brass's controlled check (task 129): a sphere (40 mm), a bevelled plate (the
# housing's 28 x 140 x 5 mm) and the box window's real crémone handle (from room.obj's
# window_metal, the room-side leaf's) under neutral light: a grey world and two large white
# cards, fixed exposure, AgX. Writes OUT.png.
#
#   Blender -b --python-exit-code 1 --python tools/blender/brass_check.py -- \
#       --level LEVEL|clean|flat [--scene build/blender] [--micro build/scratch/brass] \
#       [--out build/notes/antique-brass/img/check-1] [--size 1600x900] [--samples 256] \
#       [--turn on] [--mottle 0.5]
#
# --turn on mirrors the light (the highlights move, the mottling stays); flat is task 127's
# bronze B. The tile is the game's (the export's brass_tile.ppm, `--box-window on`); the handle
# keeps its vertices' wear, the sphere and plate none; --micro adds the concept's micro-finish
# (brass_tile.py's brass_height.png), which the game hasn't.
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
import brass  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def flags():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    f = {"level": "4", "scene": "build/blender", "out": None, "micro": None, "mottle": "0.5",
         "size": "1600x900", "samples": "256", "turn": "off"}
    for i in range(0, len(argv), 2):
        f[argv[i][2:]] = argv[i + 1]
    if f["out"] is None:
        f["out"] = "build/notes/antique-brass/img/check-" + f["level"]
    return f


def at_repo(p):
    return p if os.path.isabs(p) else os.path.join(REPO, p)


F = flags()
tile = os.path.join(at_repo(F["scene"]), "brass_tile.ppm")
micro = at_repo(F["micro"]) if F["micro"] else None
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# The handle: the room-side leaf's crémone of the middle window, cut from window_metal.
bpy.ops.wm.obj_import(filepath=os.path.join(at_repo(F["scene"]), "room.obj"), forward_axis="Y", up_axis="Z")
for ob in list(scene.objects):
    if not ob.name.startswith("window_metal"):
        bpy.data.objects.remove(ob)
handle = next(o for o in scene.objects)
handle.name = "handle"
LO, HI = Vector((-0.140, 1.48, 1.56)), Vector((-0.090, 1.56, 1.73))
import bmesh  # noqa: E402
bm = bmesh.new()
bm.from_mesh(handle.data)
gone = [f for f in bm.faces if not all(LO[i] <= f.calc_center_median()[i] <= HI[i] for i in range(3))]
bmesh.ops.delete(bm, geom=gone, context="FACES")
bm.to_mesh(handle.data)
bm.free()
mid = Vector((-0.116, 1.52, 1.643))

# The sphere and the plate beside it, in the same object-space metres (their own origins).
bpy.ops.mesh.primitive_uv_sphere_add(segments=96, ring_count=48, radius=0.020, location=(mid.x - 0.062, 1.515, mid.z))
sphere = bpy.context.object
bpy.ops.object.shade_smooth()
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(mid.x + 0.060, 1.535, mid.z))
plate = bpy.context.object
plate.scale = (0.028, 0.005, 0.140)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
bev = plate.modifiers.new("bevel", "BEVEL")
bev.width = 0.0012
bev.segments = 4
plate.rotation_euler = (0, 0, math.radians(-20))

# The material on all three.
lv = F["level"]
if lv == "clean":
    mat = brass.clean_brass("brass", micro)
elif lv == "flat":
    lin = [((c + 0.055) / 1.055) ** 2.4 for c in (0.34, 0.25, 0.17)]
    mat = brass.flat_metal("brass", lin, 0.5)
else:
    mat = brass.antique_brass("brass", float(lv), tile, mottle=float(F["mottle"]), micro_dir=micro)
for ob in (handle, sphere, plate):
    ob.data.materials.clear()
    ob.data.materials.append(mat)
# No wear on the sphere and plate: the vertex colour's g at a half, in sRGB as the OBJ's.
for ob in (sphere, plate):
    attr = ob.data.color_attributes.new("Color", "FLOAT_COLOR", "POINT")
    for d in attr.data:
        d.color_srgb = (1.0, 0.5, 0.0, 1.0)

# A grey backdrop behind, a grey world, and two white cards.
bpy.ops.mesh.primitive_plane_add(size=2.0, location=(mid.x, 1.62, mid.z), rotation=(math.radians(90), 0, 0))
back = bpy.context.object
bm_ = bpy.data.materials.new("backdrop")
bm_.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.18, 0.18, 0.18, 1.0)
bm_.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
back.data.materials.append(bm_)
world = bpy.data.worlds.new("grey")
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.05, 0.05, 0.05, 1.0)
scene.world = world
side = -1.0 if F["turn"] == "on" else 1.0
for name, at, size, power in (("key", (-0.55 * side, 0.85, 2.15), 0.9, 40.0),
                              ("fill", (0.6 * side, 1.0, 1.45), 0.7, 12.0)):
    li = bpy.data.lights.new(name, "AREA")
    li.shape = "SQUARE"
    li.size = size
    li.energy = power
    ob = bpy.data.objects.new(name, li)
    scene.collection.objects.link(ob)
    ob.location = (mid.x + at[0], at[1], at[2])
    ob.rotation_euler = (ob.location - mid).to_track_quat("Z", "Y").to_euler()

cam = bpy.data.cameras.new("cam")
cam.sensor_fit = "VERTICAL"
cam.angle_y = math.radians(11.0)
cam_ob = bpy.data.objects.new("cam", cam)
scene.collection.objects.link(cam_ob)
eye = mid + Vector((0.20, -0.82, 0.08))
cam_ob.location = eye
cam_ob.rotation_euler = (eye - mid).to_track_quat("Z", "Y").to_euler()
scene.camera = cam_ob

w, h = (int(x) for x in F["size"].split("x"))
r = scene.render
r.engine = "CYCLES"
r.resolution_x, r.resolution_y, r.resolution_percentage = w, h, 100
c = scene.cycles
c.samples = int(F["samples"])
c.use_denoising = True
c.glossy_bounces = 6
prefs = bpy.context.preferences.addons["cycles"].preferences
try:
    prefs.compute_device_type = "METAL"
    prefs.get_devices()
    for d in prefs.devices:
        d.use = True
    c.device = "GPU"
except Exception as e:
    print("no GPU:", e)
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "None"
scene.view_settings.exposure = 0.0
out = at_repo(F["out"])
os.makedirs(os.path.dirname(out), exist_ok=True)
r.image_settings.file_format = "PNG"
r.filepath = out + ".png"
bpy.ops.render.render(write_still=True)
print("wrote", out + ".png")
