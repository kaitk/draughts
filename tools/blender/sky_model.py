# The sun and the sky from Blender's sky model (the Sky Texture's multiple scattering) for one
# air: renders the sky all round with and without the sun's disc and integrates them, so
# scene.py's --sky takes the sun's irradiance and colour and the sky from one input.
#
#   Blender -b --python-exit-code 1 --python tools/blender/sky_model.py -- --elevation 15
#       [--aerosol 1] [--air 1] [--ozone 1] [--size 2048] [--out build/blender/sky.json]
#
# Writes JSON: sun (irradiance on a plane facing it, linear Rec.709, the model's units), sky
# (irradiance on a level plane from the sky alone), the sky's mean radiance toward the
# horizon round the sun (±45° in azimuth, 0 to 30° up: what the windows see), the clear air's
# sun (aerosol 1) for the units, and the sun's direction found in the picture (the check that
# scene.py's --sky turns the model to the export's sun: rotation 0 is along +y, positive toward +x).
import bpy
import json
import math
import sys

import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
F = {"elevation": "15", "aerosol": "1", "air": "1", "ozone": "1", "size": "2048", "rotation": "0",
     "out": "build/blender/sky.json"}
for i in range(0, len(argv), 2):
    F[argv[i][2:]] = argv[i + 1]
W = int(F["size"])
H = W // 2

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 16
scene.cycles.use_denoising = False
scene.render.resolution_x, scene.render.resolution_y = W, H
scene.render.film_transparent = False
scene.view_settings.view_transform = "Standard"

world = bpy.data.worlds.new("sky")
scene.world = world
nt = world.node_tree
bg = nt.nodes["Background"]
sky = nt.nodes.new("ShaderNodeTexSky")
sky.sky_type = "MULTIPLE_SCATTERING"
sky.sun_elevation = math.radians(float(F["elevation"]))
sky.sun_rotation = math.radians(float(F["rotation"]))
sky.air_density = float(F["air"])
sky.aerosol_density = float(F["aerosol"])
sky.ozone_density = float(F["ozone"])
sky.altitude = 100.0
nt.links.new(sky.outputs["Color"], bg.inputs["Color"])

cam = bpy.data.cameras.new("pano")
cam.type = "PANO"
cam.panorama_type = "EQUIRECTANGULAR"
ob = bpy.data.objects.new("pano", cam)
scene.collection.objects.link(ob)
ob.rotation_euler = (math.pi / 2, 0, 0)   # looking along +y, z up
scene.camera = ob


def render(disc):
    sky.sun_disc = disc
    bpy.ops.render.render()
    img = bpy.data.images["Render Result"]
    path = bpy.app.tempdir + "sky.exr"
    scene.render.image_settings.file_format = "OPEN_EXR"
    scene.render.image_settings.color_depth = "32"
    img.save_render(path)
    im = bpy.data.images.load(path)
    a = np.array(im.pixels[:], dtype=np.float64).reshape(H, W, 4)[::-1, :, :3]   # rows top down
    bpy.data.images.remove(im)
    return a


with_disc = render(True)
without = render(False)
# The clear air's sun (aerosol 1), for the units: scene.py puts it at the app's clear sun.
aerosol = sky.aerosol_density
sky.aerosol_density = 1.0
clear = render(True) - render(False)
sky.aerosol_density = aerosol
# Each pixel's direction: rows from +90 to -90 degrees up, columns from 180 left to 180 right
# of the camera's forward (+y).
lat = np.radians(90 - (np.arange(H) + 0.5) * 180 / H)
lon = np.radians((np.arange(W) + 0.5) * 360 / W - 180)
dw = (2 * math.pi / W) * (math.pi / H) * np.cos(lat)[:, None]          # solid angle a pixel
up = np.sin(lat)[:, None]
sun_px = np.clip(with_disc - without, 0, None)
sun = (sun_px * dw[..., None]).sum((0, 1))
lum = sun_px @ [0.2126, 0.7152, 0.0722]
i, j = np.unravel_index(np.argmax(lum), lum.shape)
d = [math.cos(lat[i]) * math.sin(lon[j]), math.cos(lat[i]) * math.cos(lon[j]), math.sin(lat[i])]
level = (without * (dw * np.clip(up, 0, None))[..., None]).sum((0, 1))
# The sky the windows see: within 45 degrees of the sun's azimuth, 0 to 30 up.
near = (np.abs(((lon[None, :] - lon[j] + math.pi) % (2 * math.pi)) - math.pi) < math.radians(45)) & \
       (lat[:, None] >= 0) & (lat[:, None] <= math.radians(30))
near_rad = (without * (dw * near)[..., None]).sum((0, 1)) / (dw * near).sum()
out = {"elevation": float(F["elevation"]), "aerosol": float(F["aerosol"]), "air": float(F["air"]),
       "ozone": float(F["ozone"]), "sun": sun.tolist(), "clear_sun": (np.clip(clear, 0, None) * dw[..., None]).sum((0, 1)).tolist(), "sky_level": level.tolist(),
       "sky_toward_sun": near_rad.tolist(), "sun_dir_seen": d}
json.dump(out, open(F["out"], "w"), indent=1)
print("sky_model", json.dumps(out))
