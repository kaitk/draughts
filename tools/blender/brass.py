# The antique brass (task 129) as a Cycles material, for scene.py and brass_check.py; the
# model and its levels in brass_model.py. Wear shifts the mottling's rank: up on the grip's
# touched convex parts, down in the recesses (the occlusion within 4 mm).
import os

import bpy

from brass_model import (DEPOSIT, EDGE, EXPOSED, EXPOSED_POWER, LEVELS, METAL, MOTTLE, ROUGH, SPECKLE_DARK,
                         SPECKLE_ROUGH, TARNISH, TILE_M)

# The grip's place in the export's frame (the inner and outer leaves' grips stand 15-40 mm
# before their housings at y 1.536 and 1.736): a stand-in for the wear the port will put in
# the vertices.
GRIP_Y = ((1.490, 1.526), (1.690, 1.726))
GRIP_Z = (1.50, 1.78)


class Nodes:
    def __init__(self, nt):
        self.nt = nt

    def new(self, kind, **kw):
        n = self.nt.nodes.new(kind)
        for k, v in kw.items():
            setattr(n, k, v)
        return n

    def link(self, a, b):
        self.nt.links.new(a, b)

    def math(self, op, a, b=None, clamp=False):
        n = self.new("ShaderNodeMath", operation=op, use_clamp=clamp)
        for i, x in enumerate((a, b)):
            if x is None:
                continue
            if isinstance(x, (int, float)):
                n.inputs[i].default_value = x
            else:
                self.link(x, n.inputs[i])
        return n.outputs[0]

    def smooth(self, x, lo, hi):
        n = self.new("ShaderNodeMapRange", interpolation_type="SMOOTHSTEP")
        self.link(x, n.inputs["Value"])
        n.inputs["From Min"].default_value = lo
        n.inputs["From Max"].default_value = hi
        return n.outputs["Result"]

    def rgb(self, c):
        n = self.new("ShaderNodeRGB")
        n.outputs[0].default_value = (*c, 1.0)
        return n.outputs[0]

    def mix(self, blend, a, b):
        n = self.new("ShaderNodeMix", data_type="RGBA", blend_type=blend)
        pin = {s.identifier: s for s in n.inputs}
        pin["Factor_Float"].default_value = 1.0
        self.link(a, pin["A_Color"])
        if isinstance(b, (int, float)):
            pin["B_Color"].default_value = (b, b, b, 1.0)
        else:
            self.link(b, pin["B_Color"])
        return {s.identifier: s for s in n.outputs}["Result_Color"]

    def scale(self, c, k):
        return self.mix("MULTIPLY", c, k)

    def add(self, a, b):
        return self.mix("ADD", a, b)

    def weighted(self, w, values):
        # sum of w[i] * values[i]: floats
        s = None
        for wi, v in zip(w, values):
            t = self.math("MULTIPLY", wi, v)
            s = t if s is None else self.math("ADD", s, t)
        return s

    def tile(self, path, coords, colour=False):
        img = bpy.data.images.load(path, check_existing=True)
        img.colorspace_settings.name = "sRGB" if colour else "Non-Color"
        n = self.new("ShaderNodeTexImage", projection="BOX", projection_blend=0.3, interpolation="Cubic")
        n.image = img
        self.link(coords, n.inputs["Vector"])
        return n


def coords(N):
    # Object space in metres (the room's object sits at the origin unscaled), a tile 64 mm.
    tc = N.new("ShaderNodeTexCoord")
    m = N.new("ShaderNodeVectorMath", operation="SCALE")
    N.link(tc.outputs["Object"], m.inputs[0])
    m.inputs["Scale"].default_value = 1.0 / TILE_M
    return tc, m.outputs["Vector"]


def micro_bump(N, tile_dir, uv, strength=0.5):
    h = N.tile(os.path.join(tile_dir, "brass_height.png"), uv)
    b = N.new("ShaderNodeBump")
    b.inputs["Strength"].default_value = strength
    b.inputs["Distance"].default_value = 0.000008   # 8 µm peak to valley over the height's range
    N.link(h.outputs["Color"], b.inputs["Height"])
    return b.outputs["Normal"]


def principled(name):
    m = bpy.data.materials.new(name)
    nt = m.node_tree
    nt.nodes.clear()
    N = Nodes(nt)
    out = N.new("ShaderNodeOutputMaterial")
    b = N.new("ShaderNodeBsdfPrincipled")
    b.inputs["Specular IOR Level"].default_value = 0.5
    N.link(b.outputs[0], out.inputs["Surface"])
    return m, N, b


def clean_brass(name, tile_dir):
    # The control: bare C260 brass, the micro-finish only.
    m, N, b = principled(name)
    _, uv = coords(N)
    b.inputs["Base Color"].default_value = (*EXPOSED, 1.0)
    b.inputs["Metallic"].default_value = 1.0
    b.inputs["Roughness"].default_value = ROUGH[0]
    N.link(micro_bump(N, tile_dir, uv), b.inputs["Normal"])
    return m


def flat_metal(name, colour, rough):
    # Task 127's metal: one colour (linear), no mottling.
    m, N, b = principled(name)
    b.inputs["Base Color"].default_value = (*colour, 1.0)
    b.inputs["Metallic"].default_value = 1.0
    b.inputs["Roughness"].default_value = rough
    return m


def antique_brass(name, level, tile_dir, wear=True):
    exposed_cover, deposit_cover, gain, tint, mean = LEVELS[level]
    m, N, b = principled(name)
    tc, uv = coords(N)
    t = N.tile(os.path.join(tile_dir, "brass_tile.png"), uv)
    sep = N.new("ShaderNodeSeparateColor")
    N.link(t.outputs["Color"], sep.inputs[0])
    rank, speckle = sep.outputs[0], sep.outputs[1]
    if wear:
        # touch: the grip's band; the convex parts by the vertices' pointiness (0.5 flat).
        xyz = N.new("ShaderNodeSeparateXYZ")
        N.link(tc.outputs["Object"], xyz.inputs[0])
        y, z = xyz.outputs["Y"], xyz.outputs["Z"]
        band = None
        for lo, hi in GRIP_Y:
            inside = N.math("MULTIPLY", N.math("GREATER_THAN", y, lo), N.math("LESS_THAN", y, hi))
            band = inside if band is None else N.math("MAXIMUM", band, inside)
        touch = N.math("MULTIPLY", band, N.math("MULTIPLY", N.math("GREATER_THAN", z, GRIP_Z[0]),
                                                N.math("LESS_THAN", z, GRIP_Z[1])))
        geo = N.new("ShaderNodeNewGeometry")
        convex = N.math("MULTIPLY", N.math("SUBTRACT", geo.outputs["Pointiness"], 0.5), 4.0, clamp=True)
        lift = N.math("MULTIPLY", touch, N.math("ADD", 0.05, N.math("MULTIPLY", convex, 0.3)))
        ao = N.new("ShaderNodeAmbientOcclusion", only_local=True, samples=8)
        ao.inputs["Distance"].default_value = 0.004
        sink = N.math("MULTIPLY", N.math("SUBTRACT", 1.0, ao.outputs["AO"]), 0.5)
        rank = N.math("ADD", rank, N.math("SUBTRACT", lift, sink), clamp=True)
    else:
        touch = 0.0
    deposit = N.math("SUBTRACT", 1.0, N.smooth(rank, deposit_cover - EDGE, deposit_cover + EDGE))
    exposed = N.smooth(rank, 1.0 - exposed_cover - EDGE, 1.0 - exposed_cover + EDGE)
    tarnish = N.math("SUBTRACT", N.math("SUBTRACT", 1.0, deposit), exposed, clamp=True)
    k_exposed = gain ** EXPOSED_POWER
    c = N.add(N.add(N.scale(N.rgb([k_exposed * v for v in EXPOSED]), exposed),
                    N.scale(N.rgb([gain * v * w for v, w in zip(TARNISH, tint)]), tarnish)),
              N.scale(N.rgb([gain * v * w for v, w in zip(DEPOSIT, tint)]), deposit))
    # The speckles: small pits, darker and rougher.
    c = N.scale(c, N.math("SUBTRACT", 1.0, N.math("MULTIPLY", speckle, SPECKLE_DARK)))
    # Halfway to the level's mean: a mix of the mean (A) and the mottled colour (B).
    mix = N.new("ShaderNodeMix", data_type="RGBA", blend_type="MIX")
    pin = {s.identifier: s for s in mix.inputs}
    pin["Factor_Float"].default_value = MOTTLE
    pin["A_Color"].default_value = (*mean, 1.0)
    N.link(c, pin["B_Color"])
    N.link({s.identifier: s for s in mix.outputs}["Result_Color"], b.inputs["Base Color"])
    N.link(N.weighted((exposed, tarnish, deposit), METAL), b.inputs["Metallic"])
    rough = N.math("ADD", N.weighted((exposed, tarnish, deposit), ROUGH), N.math("MULTIPLY", speckle, SPECKLE_ROUGH))
    if wear:
        rough = N.math("SUBTRACT", rough, N.math("MULTIPLY", touch, 0.05))
    N.link(rough, b.inputs["Roughness"])
    N.link(micro_bump(N, tile_dir, uv), b.inputs["Normal"])
    return m
