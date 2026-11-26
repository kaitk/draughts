# The library room in Blender from tools/blender_export.goose's room.obj and scene.json,
# lit as the room's bake takes its light (the sun and the sky through the windows), and
# rendered with Cycles from one of the light tuner's named views. See README.md.
#
#   Blender -b --python-exit-code 1 --python tools/blender/scene.py -- [--scene build/blender]
#       [--view close] [--out build/blender/close] [--size 960x540] [--samples 512]
#       [--exposure 0] [--textures on|off] [--save-blend]
#
# Writes OUT.png (AgX), OUT.exr (multilayer: the combined light and the diffuse passes), and
# OUT-light.png: the diffuse light alone (direct + indirect, no albedo), the room's
# irradiance over pi seen from the view, through the same view transform.
import bpy
import json
import math
import os
import sys
import time

import numpy as np
from mathutils import Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def flags():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    f = {"scene": "build/blender", "view": "close", "out": None, "size": "960x540", "samples": "512",
         "exposure": "0", "textures": "on", "save-blend": None, "device": "gpu"}
    i = 0
    while i < len(argv):
        name = argv[i][2:]
        if name == "save-blend":
            f[name] = True
            i += 1
            continue
        f[name] = argv[i + 1]
        i += 2
    if f["out"] is None:
        f["out"] = os.path.join(f["scene"], f["view"])
    return f


F = flags()
scene_dir = os.path.join(REPO, F["scene"]) if not os.path.isabs(F["scene"]) else F["scene"]
S = json.load(open(os.path.join(scene_dir, "scene.json")))

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.wm.obj_import(filepath=os.path.join(scene_dir, "room.obj"), forward_axis="Y", up_axis="Z")


# ---- materials

def node_material(name):
    m = bpy.data.materials.new(name)
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    return m, nt, out


def diffuse(name, color, metallic=0.0, rough=1.0, spec=None):
    # spec: the Principled's Specular IOR Level, 0.5 a dielectric's f0 of 0.04 (the shaders').
    m, nt, out = node_material(name)
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metallic
    if spec is None:
        spec = 0.0 if metallic == 0.0 else 0.5
    b.inputs["Specular IOR Level"].default_value = spec
    nt.links.new(b.outputs[0], out.inputs["Surface"])
    return m, nt, b


def coated(m, b, weight, rough):
    # A clear coat over the albedo (the wax, the polish), f0 0.04; the base then matte, as
    # the shaders light the wood under it.
    b.inputs["Specular IOR Level"].default_value = 0.0
    b.inputs["Coat Weight"].default_value = weight
    b.inputs["Coat Roughness"].default_value = rough
    b.inputs["Coat IOR"].default_value = 1.5
    return m


def textured(name, image, scale, gain):
    # An albedo picture stored at a 2.2 gamma (design/materials/README.md), times gain, on
    # the mesh's uv over `scale` (the uv's units a tile).
    m, nt, b = diffuse(name, (0.5, 0.5, 0.5))
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(image)
    tex.image.colorspace_settings.name = "Non-Color"
    uv = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1.0 / scale, 1.0 / scale, 1.0)
    gamma = nt.nodes.new("ShaderNodeGamma")
    gamma.inputs["Gamma"].default_value = 2.2
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    mul.inputs["B"].default_value = (gain, gain, gain, 1.0)
    nt.links.new(uv.outputs["UV"], mp.inputs["Vector"])
    nt.links.new(mp.outputs[0], tex.inputs["Vector"])
    nt.links.new(tex.outputs["Color"], gamma.inputs["Color"])
    nt.links.new(gamma.outputs[0], mul.inputs["A"])
    nt.links.new(mul.outputs["Result"], b.inputs["Base Color"])
    return m


def glass(name, lets):
    # A pane: what it lets through straight on, no refraction, so the sun's shadow rays pass;
    # ROOM_FRAG's reflection over it, 0.6 of Fresnel's (a glass's, 0.04 straight on), sharp.
    m, nt, out = node_material(name)
    t = nt.nodes.new("ShaderNodeBsdfTransparent")
    t.inputs["Color"].default_value = (lets, lets, lets, 1.0)
    g = nt.nodes.new("ShaderNodeBsdfGlossy")
    g.inputs["Roughness"].default_value = 0.0
    fres = nt.nodes.new("ShaderNodeFresnel")
    fres.inputs["IOR"].default_value = 1.5
    k = nt.nodes.new("ShaderNodeMath")
    k.operation = "MULTIPLY"
    k.inputs[1].default_value = 0.6
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(fres.outputs[0], k.inputs[0])
    nt.links.new(k.outputs[0], mix.inputs["Fac"])
    nt.links.new(t.outputs[0], mix.inputs[1])
    nt.links.new(g.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    return m


def lace(name, lets, scatter):
    # The lace as a sheet: `lets` passes straight through its holes; the thread (near white,
    # 0.8) throws `scatter` of what it stops on forward and as much back.
    m, nt, out = node_material(name)
    hole = nt.nodes.new("ShaderNodeBsdfTransparent")
    fwd = nt.nodes.new("ShaderNodeBsdfTranslucent")
    fwd.inputs["Color"].default_value = (scatter, scatter, scatter, 1.0)
    back = nt.nodes.new("ShaderNodeBsdfDiffuse")
    back.inputs["Color"].default_value = (scatter, scatter, scatter, 1.0)
    add = nt.nodes.new("ShaderNodeAddShader")
    mix = nt.nodes.new("ShaderNodeMixShader")
    mix.inputs["Fac"].default_value = 1.0 - lets
    nt.links.new(fwd.outputs[0], add.inputs[0])
    nt.links.new(back.outputs[0], add.inputs[1])
    nt.links.new(hole.outputs[0], mix.inputs[1])
    nt.links.new(add.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    return m


def srgb_to_linear(c):
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]


LUM = (0.2126, 0.7152, 0.0722)


def map_mean(path):
    # The albedo map's mean luminance in linear light: TABLE_FRAG's last mip.
    img = bpy.data.images.load(path, check_existing=True)
    px = np.asarray(img.pixels[:], np.float32).reshape(-1, 4)[:, :3]
    lin = np.where(px <= 0.04045, px / 12.92, ((px + 0.055) / 1.055) ** 2.4)
    return float((lin.mean(0) * np.array(LUM)).sum())


def table_wood(name, part):
    # The table's wood as TABLE_FRAG draws it from the maps (tools/blender_export.goose
    # --maps), on the uv the export gives (where the shader reads the maps). part: "top"
    # (the top and its edge), "base" (its own wood: base_wood, base_look), "chair" (the
    # base's map darker and less red, CHAIR_WOOD). Under the polish: a coat of strength
    # coat.y, its roughness the map's alpha on the top, coat.x elsewhere.
    m, nt, b = diffuse(name, (0.5, 0.5, 0.5))
    L = nt.links
    alb = nt.nodes.new("ShaderNodeTexImage")
    alb.image = bpy.data.images.load(ALBEDO_MAP, check_existing=True)
    alb.image.colorspace_settings.name = "sRGB"
    alb.image.alpha_mode = "CHANNEL_PACKED"
    alb.interpolation = "Cubic"

    def math(op, a, bb=None):
        n = nt.nodes.new("ShaderNodeMath")
        n.operation = op
        for i, x in enumerate((a, bb)):
            if x is None:
                continue
            if isinstance(x, (int, float)):
                n.inputs[i].default_value = x
            else:
                L.new(x, n.inputs[i])
        return n.outputs[0]

    def mix_rgb(fac, a, c):
        n = nt.nodes.new("ShaderNodeMix")
        n.data_type = "RGBA"
        n.inputs["Factor"].default_value = fac
        L.new(a, n.inputs["A"])
        L.new(c, n.inputs["B"])
        return n.outputs["Result"]

    def scale_rgb(c, k):
        n = nt.nodes.new("ShaderNodeVectorMath")
        n.operation = "SCALE"
        L.new(c, n.inputs[0])
        if isinstance(k, (int, float)):
            n.inputs["Scale"].default_value = k
        else:
            L.new(k, n.inputs["Scale"])
        return n.outputs[0]

    lum = nt.nodes.new("ShaderNodeRGBToBW")   # the scene's luminance, Rec. 709's
    L.new(alb.outputs["Color"], lum.inputs[0])
    l = lum.outputs[0]
    grey = nt.nodes.new("ShaderNodeCombineColor")
    for i in range(3):
        L.new(l, grey.inputs[i])
    color = alb.outputs["Color"]
    if part == "chair":
        # TABLE_FRAG: mix(vec3(l), albedo, 0.75) * CHAIR_WOOD (0.6).
        color = scale_rgb(mix_rgb(0.75, grey.outputs[0], color), 0.6)
    elif part == "base":
        # TABLE_FRAG's own base: mix(vec3(l), albedo, base_look.w)
        #     * (mean * base_wood.y + (l - mean) * base_wood.z) / l
        bw, bl = G["base_wood"], G["base_look"]
        mean = map_mean(ALBEDO_MAP)
        k = math("DIVIDE", math("ADD", math("MULTIPLY", math("SUBTRACT", l, mean), bw[2]), mean * bw[1]),
                 math("MAXIMUM", l, 1e-4))
        color = scale_rgb(mix_rgb(bl[3], grey.outputs[0], color), k)
    L.new(color, b.inputs["Base Color"])
    coat = G["table_coat"]
    coated(m, b, coat[1], coat[0])       # tables::Table.coat: x the edge's roughness, y strength
    if part != "top":
        return m
    # The top's faces (facing straight up) take the baked normal and the map's roughness
    # (BAKE_FRAG's polish, alpha); the edge keeps the mesh's normal and coat.x.
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep_n = nt.nodes.new("ShaderNodeSeparateXYZ")
    L.new(geo.outputs["True Normal"], sep_n.inputs[0])
    on_top = math("GREATER_THAN", sep_n.outputs["Z"], 0.999)
    rough = nt.nodes.new("ShaderNodeMix")
    rough.data_type = "FLOAT"
    L.new(on_top, rough.inputs["Factor"])
    rough.inputs["A"].default_value = coat[0]
    L.new(alb.outputs["Alpha"], rough.inputs["B"])
    L.new(rough.outputs["Result"], b.inputs["Coat Roughness"])
    # The normal map: r and g the normal's x and z over the top seen from above (0.5 flat),
    # along the uv's u and the app's v (the export flips v, so g flips back); its height
    # worked out, as TABLE_FRAG's sqrt(1 - t.t). b holds the wear's patches, not a normal.
    nm = nt.nodes.new("ShaderNodeTexImage")
    nm.image = bpy.data.images.load(NORMAL_MAP, check_existing=True)
    nm.image.colorspace_settings.name = "Non-Color"
    nm.image.alpha_mode = "CHANNEL_PACKED"
    nm.interpolation = "Cubic"
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    L.new(nm.outputs["Color"], sep.inputs[0])
    tx = math("SUBTRACT", math("MULTIPLY", sep.outputs[0], 2.0), 1.0)
    ty = math("SUBTRACT", 1.0, math("MULTIPLY", sep.outputs[1], 2.0))
    tz = math("SQRT", math("MAXIMUM", math("SUBTRACT", 1.0, math("ADD", math("MULTIPLY", tx, tx), math("MULTIPLY", ty, ty))), 0.0))
    enc = nt.nodes.new("ShaderNodeCombineColor")
    for i, t in enumerate((tx, ty, tz)):
        L.new(math("ADD", math("MULTIPLY", t, 0.5), 0.5), enc.inputs[i])

    def normal(strength):
        n = nt.nodes.new("ShaderNodeNormalMap")
        n.inputs["Strength"].default_value = strength
        L.new(enc.outputs[0], n.inputs["Color"])
        pick = nt.nodes.new("ShaderNodeMix")
        pick.data_type = "VECTOR"
        L.new(on_top, pick.inputs["Factor"])
        L.new(geo.outputs["Normal"], pick.inputs["A"])
        L.new(n.outputs[0], pick.inputs["B"])
        return pick.outputs["Result"]

    L.new(normal(1.0), b.inputs["Normal"])
    L.new(normal(coat[2]), b.inputs["Coat Normal"])   # the polish follows the relief coat.z
    return m


A = S["albedo"]
G = S["gloss"]
table = A["table"]
lum = 0.2126 * table[0] + 0.7152 * table[1] + 0.0722 * table[2]
# TABLE_FRAG's chairs' wood: the base's albedo a quarter toward grey, times CHAIR_WOOD.
chair_wood = [0.6 * (0.25 * lum + 0.75 * c) for c in table]
BRAID = [0.38, 0.29, 0.15]
# The pictures' means in linear light (tapestry 0.8 × its mean, TABLE_FRAG's CHAIR_CLOTH).
TAPESTRY_MEAN = [0.8 * c for c in (0.5159, 0.3405, 0.2105)]
RUG_MEAN = [0.1573, 0.0754, 0.0495]
ALBEDO_MAP = os.path.join(scene_dir, "table_albedo.png")
NORMAL_MAP = os.path.join(scene_dir, "table_normal.png")
textures = F["textures"] == "on"
maps = textures and os.path.exists(ALBEDO_MAP) and os.path.exists(NORMAL_MAP)
if textures and not maps:
    print("no table maps in", scene_dir, "(blender_export --maps on): the table flat")


def wood(name, color, part):
    # The table's wood: its maps, or with --textures off (or no maps) its mean albedo,
    # matte, for the light alone.
    if maps:
        return table_wood(name, part)
    if not textures:
        return diffuse(name, color)[0]
    m, nt, b = diffuse(name, color)
    return coated(m, b, G["table_coat"][1], G["table_coat"][0])


def gloss(name, color, rough, spec=0.5):
    # A dielectric at f0 0.04 and the shader's roughness; matte with --textures off.
    if not textures:
        return diffuse(name, color)[0]
    return diffuse(name, color, rough=rough, spec=spec)[0]


def floor_wax(name, color):
    # The floor's wax: ROOM_FRAG's mirror over it (rooms::Room.planar: x its strength, its
    # roughness the oak's times y), one layer; the oak's own sheen (FLOOR_OAK.base.w) left out.
    m, nt, b = diffuse(name, color, rough=G["floor_rough"])
    return coated(m, b, G["floor_wax"], G["floor_wax_rough"]) if textures else m


brass = G["brass"]
mats = {
    "floor": floor_wax("floor", A["floor"]),
    "oak": gloss("oak", A["oak"], G["oak_rough"]),                    # WALL_OAK.base.w
    "paper": gloss("paper", A["paper"], G["paper_rough"]),            # surfaces::LOOK.paper.w
    "stone": gloss("stone", A["stone"], G["stone_rough"]),            # LOOK.stone.w
    "plaster": gloss("plaster", A["plaster"], G["plaster_rough"]),    # LOOK.plaster_shade.w, _light.w
    "ceiling": gloss("ceiling", A["ceiling"], G["ceiling_rough"]),    # LOOK.ceiling_shade.w, _light.w
    "paint": gloss("paint", A["paint"], G["paint_rough"]),            # LOOK.paint_quiet.x, the doors'
    # CASE_ALBEDO is the cases' fronts with the shelves' shadows in; the books alone a guess
    # half again lighter. Their cloth 0.65 rough (ROOM_FRAG's books, roughly).
    "books": gloss("books", [1.5 * c for c in A["books"]], 0.65),
    "stove_tile": gloss("stove_tile", A["stove_tile"], 0.08),          # ROOM_FRAG's STOVE_ROUGH, the glaze
    # LOOK.brass: its colour at normal incidence (sRGB) and roughness.
    "brass": diffuse("brass", srgb_to_linear(brass[:3]), metallic=1.0, rough=brass[3])[0],
    "cord": diffuse("cord", (0.30, 0.16, 0.07))[0],
    "glass": glass("glass", 0.92),
    "lace": lace("lace", S["lace_lets"], 0.4),
    "table_top": wood("table_top", table, "top"),
    "table_base": wood("table_base", table, "base"),
    "chair_wood": wood("chair_wood", chair_wood, "chair"),
    "chair_seat": (textured("chair_seat", os.path.join(REPO, "design/materials/tapestry.png"), 7.3152, 0.8)
                   if textures else diffuse("chair_seat", TAPESTRY_MEAN)[0]),
    "chair_trim": diffuse("chair_trim", [0.85 * c for c in BRAID])[0],
    "rug": (textured("rug", os.path.join(REPO, "design/materials/rug.png"), 1.0, 1.0)
            if textures else diffuse("rug", RUG_MEAN)[0]),
}
for ob in scene.objects:
    if ob.type != "MESH":
        continue
    name = ob.name.split(".")[0]
    m = mats.get(name)
    if m is None:
        print("no material for", ob.name)
        m = diffuse(name, (0.5, 0.5, 0.5))[0]
    ob.data.materials.clear()
    ob.data.materials.append(m)
    # The lace sheets hang in thin layers; let the panes and lace through for shadows.
    if name in ("glass", "lace"):
        ob.visible_shadow = True


# ---- the box: the shell is made for rasterising and has gaps the sun and sky would leak
# through; a closed box round it, black, open only at the windows' outer openings.

def blocker():
    import bmesh
    lo = Vector((min(o.bound_box[i][0] + o.location.x for o in scene.objects for i in range(8)) - 1.0,
                 min(o.bound_box[i][1] + o.location.y for o in scene.objects for i in range(8)) - 1.0, -0.5))
    hi = Vector((max(o.bound_box[i][0] + o.location.x for o in scene.objects for i in range(8)) + 1.0,
                 S["window_wall_outer_y"] + 0.01, S["ceiling"] + 1.0))
    W = S["windows"]
    holes = sorted((x - 0.5 * W["width"], x + 0.5 * W["width"]) for x in W["x"])
    quads = []

    def quad(a, b, c, d):
        quads.append((Vector(a), Vector(b), Vector(c), Vector(d)))

    x0, y0, z0 = lo
    x1, y1, z1 = hi
    quad((x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0))   # under
    quad((x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1))   # over
    quad((x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1))   # the hall's side
    quad((x0, y0, z0), (x0, y1, z0), (x0, y1, z1), (x0, y0, z1))
    quad((x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1))
    # The window wall's outer face with its three openings.
    sill, top = W["sill"], W["top"]
    quad((x0, y1, z0), (x1, y1, z0), (x1, y1, sill), (x0, y1, sill))
    quad((x0, y1, top), (x1, y1, top), (x1, y1, z1), (x0, y1, z1))
    edges = [x0] + [e for h in holes for e in h] + [x1]
    for i in range(0, len(edges), 2):
        quad((edges[i], y1, sill), (edges[i + 1], y1, sill), (edges[i + 1], y1, top), (edges[i], y1, top))
    me = bpy.data.meshes.new("box")
    bm = bmesh.new()
    for q in quads:
        bm.faces.new([bm.verts.new(v) for v in q])
    bm.to_mesh(me)
    ob = bpy.data.objects.new("box", me)
    scene.collection.objects.link(ob)
    ob.data.materials.append(diffuse("box", (0.0, 0.0, 0.0))[0])
    ob.visible_camera = False


blocker()


# ---- light

sun_dir = Vector(S["sun_toward"]).normalized()
E = S["sun_irradiance"]
peak = max(E)
sun = bpy.data.lights.new("sun", "SUN")
sun.energy = peak               # W/m², irradiance on a plane facing it, as the shaders' sun.light
sun.color = [c / peak for c in E]
sun.angle = math.radians(0.53)
sun_ob = bpy.data.objects.new("sun", sun)
scene.collection.objects.link(sun_ob)
sun_ob.rotation_euler = sun_dir.to_track_quat("Z", "Y").to_euler()   # its -Z along the light

world = bpy.data.worlds.new("sky")
bg = world.node_tree.nodes["Background"]
sky = [c * S["sky_gain"] for c in S["sky_radiance"]]
bg.inputs["Color"].default_value = (*sky, 1.0)
bg.inputs["Strength"].default_value = 1.0
scene.world = world


# ---- camera

v = S["views"][F["view"]]
eye, at = Vector(v["eye"]), Vector(v["at"])
cam = bpy.data.cameras.new("cam")
cam.sensor_fit = "VERTICAL"
cam.angle_y = math.radians(v["fov"])
cam.clip_start = 0.02
cam.clip_end = 100.0
cam_ob = bpy.data.objects.new("cam", cam)
scene.collection.objects.link(cam_ob)
cam_ob.location = eye
cam_ob.rotation_euler = (eye - at).to_track_quat("Z", "Y").to_euler()
scene.camera = cam_ob


# ---- render

w, h = (int(x) for x in F["size"].split("x"))
r = scene.render
r.engine = "CYCLES"
r.resolution_x, r.resolution_y = w, h
r.resolution_percentage = 100
c = scene.cycles
c.samples = int(F["samples"])
c.use_denoising = True
c.max_bounces = 16
c.diffuse_bounces = 12
c.glossy_bounces = 4
c.transmission_bounces = 12
c.transparent_max_bounces = 32
c.caustics_reflective = False
c.caustics_refractive = False
c.sample_clamp_indirect = 0.0
if F["device"] == "gpu":
    prefs = bpy.context.preferences.addons["cycles"].preferences
    try:
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        c.device = "GPU"
        print("devices:", [(d.name, d.type) for d in prefs.devices])
    except Exception as e:
        print("no GPU:", e)
        c.device = "CPU"
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "None"
scene.view_settings.exposure = float(F["exposure"])
layer = scene.view_layers[0]
layer.use_pass_diffuse_direct = True
layer.use_pass_diffuse_indirect = True
layer.use_pass_diffuse_color = True
layer.use_pass_glossy_direct = True
layer.use_pass_glossy_indirect = True
layer.use_pass_normal = True
layer.use_pass_object_index = True
# The props' parts numbered for the statistics of their light by facing.
STAT_PARTS = ["table_top", "table_base", "chair_wood", "chair_seat"]
for ob in scene.objects:
    if ob.name.split(".")[0] in STAT_PARTS:
        ob.pass_index = 1 + STAT_PARTS.index(ob.name.split(".")[0])

out = os.path.join(REPO, F["out"]) if not os.path.isabs(F["out"]) else F["out"]
os.makedirs(os.path.dirname(out), exist_ok=True)
if F["save-blend"]:
    bpy.ops.wm.save_as_mainfile(filepath=out + ".blend")

t0 = time.time()
r.image_settings.media_type = "MULTI_LAYER_IMAGE"
r.image_settings.file_format = "OPEN_EXR_MULTILAYER"
r.image_settings.color_depth = "32"
r.filepath = out + ".exr"
bpy.ops.render.render(write_still=True)
seconds = time.time() - t0
print(f"render {F['view']} {w}x{h} {c.samples} samples: {seconds:.1f} s")

# The PNG and the light alone from the EXR's passes, through the scene's view transform.
import OpenImageIO as oiio


# A multilayer EXR is multipart: a pass a part.
passes = {}
inp = oiio.ImageInput.open(out + ".exr")
part = 0
while inp.seek_subimage(part, 0):
    spec = inp.spec()
    names = list(spec.channelnames)
    px = np.asarray(inp.read_image(oiio.FLOAT)).reshape(spec.height, spec.width, spec.nchannels)
    for n in names:
        if n.endswith(".X") or n.endswith(".V"):
            k = names.index(n)
            passes[n.split(".")[1]] = px[:, :, k:k + 3] if n.endswith(".X") else px[:, :, k:k + 1]
        if n.endswith(".R"):
            k = names.index(n)
            passes[n.split(".")[1]] = px[:, :, k:k + 3]
    part += 1
inp.close()
combined = passes["Combined"]
# The light alone: the denoised image less the gloss (noisy) over the albedo where there is
# one, else the noisy diffuse passes (the lace, the brass).
color = passes["Diffuse Color"]
raw = passes["Diffuse Direct"] + passes["Diffuse Indirect"]
glossy = passes["Glossy Direct"] + passes["Glossy Indirect"]
light = np.where(color > 0.01, np.maximum(combined - glossy, 0.0) / np.maximum(color, 1e-4), raw)


def save(rgb, path):
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=False, float_buffer=True)
    rgba = np.ones((h, w, 4), np.float32)
    rgba[:, :, :3] = rgb
    img.pixels.foreach_set(rgba[::-1].ravel())   # Blender's rows bottom up; OIIO's top down
    img.save_render(path, scene=scene)
    bpy.data.images.remove(img)


r.image_settings.media_type = "IMAGE"
r.image_settings.file_format = "PNG"
r.image_settings.color_depth = "8"
save(combined, out + ".png")
save(light, out + "-light.png")
# The light on the props by which way their surface faces (the normal's largest axis):
# toward the window (+y), away (-y), up, down, along the wall (+-x); mean of the light's
# luminance over the pixels, and how many.
stats = {}
if "Normal" in passes and "Object Index" in passes:
    nrm = passes["Normal"]
    idx = np.rint(passes["Object Index"][:, :, 0]).astype(int)
    Y = 0.2126 * light[:, :, 0] + 0.7152 * light[:, :, 1] + 0.0722 * light[:, :, 2]
    ways = {"window": (1, 1), "away": (1, -1), "up": (2, 1), "down": (2, -1), "x+": (0, 1), "x-": (0, -1)}
    axis = np.argmax(np.abs(nrm), axis=2)
    sign = np.sign(np.take_along_axis(nrm, axis[:, :, None], 2)[:, :, 0])
    for k, part_name in enumerate(STAT_PARTS):
        here = idx == k + 1
        row = {}
        for way, (a, sg) in ways.items():
            m = here & (axis == a) & (sign == sg)
            if m.sum() > 30:
                row[way] = [round(float(Y[m].mean()), 4), int(m.sum())]
        stats[part_name] = row
meta = {"view": F["view"], "size": [w, h], "samples": c.samples, "seconds": round(seconds, 1),
        "device": c.device, "exposure": scene.view_settings.exposure,
        "mean_combined": [float(x) for x in combined.reshape(-1, 3).mean(0)],
        "mean_light": [float(x) for x in light.reshape(-1, 3).mean(0)], "light_by_facing": stats}
json.dump(meta, open(out + ".json", "w"), indent=1)
print(json.dumps(meta))
