#!/usr/bin/env python3
"""The ngfx build's 3D board shaders (r3d_*.slang) written from gfx's GLSL in
src/render3d/shaders.goose (task 065), so the two stay one source while both builds live.
scripts/ngfx.py calls sources() at every build; on its own it prints them into a folder to
read:

    python scripts/ngfx_3d_shaders.py <dir>

Each pipeline of render3d becomes one Slang module, its vertex and fragment stage each in
a namespace with its GLSL body as written: the GLSL names come from glsl.slang and
r3d.slang, the stage's inputs, outputs, uniform blocks, storage buffers and samplers
become statics filled from one root (r3d.slang's Root) at the entry points, and the
position's y is negated for NoGraphicsAPI's clip space, which leaves the picture as gfx
draws it (ngfx_glsl.py, which ngfx_2d_shaders.py shares). The root's layout per module is
written at the top of each file, which src/ngfx/render3d_ngfx.goose fills to
match.
"""
import re
import sys
import textwrap
from pathlib import Path

from ngfx_glsl import TYPES, Stage, source, strings, unique, write_entries, write_stage

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src/render3d/shaders.goose"


S = strings(SRC)

# The pipelines: name, vertex parts, fragment parts (shaders.goose's names, as
# render3d::setup puts them together).
FULL = ["FULL_VERT"]
LIT_VS = ["VS_SET", "FRAME", "LIT_VERT"]
QUAD_VS = ["VS_SET", "FRAME", "QUAD_VERT"]
TABLE_VS = ["VS_SET", "FRAME", "TABLE_VERT"]
# The room's pipelines, one a material group (render3d::room_group) and tier, as
# render3d_gpu.goose's make_room_tier puts them together: the defines, then ROOM_FS, the
# table's map (not the glass's), SSAO_FN, TONE_FN and ROOM_FRAG.
ROOM_VS = ["VS_SET", "FRAME", "ROOM_VERT"]
ROOM_FS = ["SHELL_WINDOWS", "FS_SET", "FRAME", "ROOM_HEAD", "LIGHT_FN"]
ROOMS = [
    ("r3d_room_floor", ["ROOM_FLOOR", "SHARP_BOX"]),
    ("r3d_room_planar", ["ROOM_FLOOR", "PLANAR_FLOOR"]),
    ("r3d_room_walls", ["ROOM_WALLS"]),
    ("r3d_room_metals", ["ROOM_METALS", "SHARP_BOX"]),
    ("r3d_room_glass", ["ROOM_GLASS"]),
    ("r3d_room_floor_phone", ["ROOM_FLOOR", "SHARP_BOX", "NO_SSAO"]),
    ("r3d_room_walls_phone", ["ROOM_WALLS", "NO_SSAO"]),
    ("r3d_room_metals_phone", ["ROOM_METALS", "SHARP_BOX", "NO_SSAO"]),
    ("r3d_room_glass_phone", ["ROOM_GLASS", "NO_SSAO"]),
    ("r3d_mirror_walls", ["ROOM_WALLS", "MIRROR_PASS"]),
    ("r3d_mirror_metals", ["ROOM_METALS", "MIRROR_PASS"]),
    ("r3d_mirror_glass", ["ROOM_GLASS", "MIRROR_PASS"]),
]
MODULES = [
    ("r3d_lit", LIT_VS, ["FS_SET", "FRAME", "LIT_HEAD", "SHADOW_FN", "LIGHT_FN", "LIT_FRAG"]),
    ("r3d_lit_few", LIT_VS, ["SHADOW_FEW", "FS_SET", "FRAME", "LIT_HEAD", "SHADOW_FN", "LIGHT_FN", "LIT_FRAG"]),
    ("r3d_lit_many", LIT_VS, ["SHADOW_MANY", "FS_SET", "FRAME", "LIT_HEAD", "SHADOW_FN", "LIGHT_FN", "LIT_FRAG"]),
    ("r3d_lit_wood", LIT_VS, ["PIECES_WOOD", "FS_SET", "FRAME", "LIT_HEAD", "SHADOW_FN", "LIGHT_FN", "LIT_FRAG"]),
    ("r3d_lit_few_wood", LIT_VS, ["PIECES_WOOD", "SHADOW_FEW", "FS_SET", "FRAME", "LIT_HEAD", "SHADOW_FN", "LIGHT_FN", "LIT_FRAG"]),
    ("r3d_lit_many_wood", LIT_VS, ["PIECES_WOOD", "SHADOW_MANY", "FS_SET", "FRAME", "LIT_HEAD", "SHADOW_FN", "LIGHT_FN", "LIT_FRAG"]),
    ("r3d_lit_winter", LIT_VS, ["PIECES_WINTER", "FS_SET", "FRAME", "LIT_HEAD", "SHADOW_FN", "LIGHT_FN", "LIT_FRAG"]),
    ("r3d_lit_few_winter", LIT_VS, ["PIECES_WINTER", "SHADOW_FEW", "FS_SET", "FRAME", "LIT_HEAD", "SHADOW_FN", "LIGHT_FN", "LIT_FRAG"]),
    ("r3d_lit_many_winter", LIT_VS, ["PIECES_WINTER", "SHADOW_MANY", "FS_SET", "FRAME", "LIT_HEAD", "SHADOW_FN", "LIGHT_FN", "LIT_FRAG"]),
    ("r3d_lit_mineral", LIT_VS, ["PIECES_MINERAL", "FS_SET", "FRAME", "LIT_HEAD", "SHADOW_FN", "LIGHT_FN", "LIT_FRAG"]),
    ("r3d_lit_few_mineral", LIT_VS, ["PIECES_MINERAL", "SHADOW_FEW", "FS_SET", "FRAME", "LIT_HEAD", "SHADOW_FN", "LIGHT_FN", "LIT_FRAG"]),
    ("r3d_lit_many_mineral", LIT_VS, ["PIECES_MINERAL", "SHADOW_MANY", "FS_SET", "FRAME", "LIT_HEAD", "SHADOW_FN", "LIGHT_FN", "LIT_FRAG"]),
    ("r3d_depth", LIT_VS, ["EMPTY_FRAG"]),
    ("r3d_table", TABLE_VS, ["FS_SET", "FRAME", "TABLE_HEAD", "SHADOW_FN", "LIGHT_FN", "TABLE_MAP_FN", "TABLE_FRAG"]),
    ("r3d_table_few", TABLE_VS, ["SHADOW_FEW", "FS_SET", "FRAME", "TABLE_HEAD", "SHADOW_FN", "LIGHT_FN", "TABLE_MAP_FN", "TABLE_FRAG"]),
    ("r3d_table_many", TABLE_VS, ["SHADOW_MANY", "FS_SET", "FRAME", "TABLE_HEAD", "SHADOW_FN", "LIGHT_FN", "TABLE_MAP_FN", "TABLE_FRAG"]),
    ("r3d_table_room", TABLE_VS, ["TABLE_ROOM", "FS_SET", "FRAME", "TABLE_HEAD", "SHADOW_FN", "LIGHT_FN", "TABLE_MAP_FN", "SSAO_FN", "TABLE_FRAG"]),
    ("r3d_table_room_phone", TABLE_VS, ["TABLE_ROOM", "NO_SSAO", "FS_SET", "FRAME", "TABLE_HEAD", "SHADOW_FN", "LIGHT_FN", "TABLE_MAP_FN", "SSAO_FN", "TABLE_FRAG"]),
    ("r3d_table_mirror", TABLE_VS, ["TABLE_ROOM", "MIRROR_PASS", "FS_SET", "FRAME", "TABLE_HEAD", "SHADOW_FN", "LIGHT_FN", "TABLE_MAP_FN", "SSAO_FN", "TABLE_FRAG"]),
    ("r3d_crown", FULL, ["CROWN_FN", "CROWN_FRAG"]),
    ("r3d_occ", FULL, ["FS_SET", "FRAME", "OCC_FRAG"]),
    ("r3d_backdrop", FULL, ["FS_SET", "FRAME", "FADE_FN", "BACKDROP_FRAG"]),
    ("r3d_catcher", QUAD_VS, ["FS_SET", "FRAME", "SHADOW_CATCHER_FRAG"]),
    ("r3d_marks", QUAD_VS, ["FS_SET", "FRAME", "MARKS_FRAG"]),
    ("r3d_pulse", QUAD_VS, ["MARKS_PULSE", "FS_SET", "FRAME", "MARKS_FRAG"]),
    ("r3d_bake", FULL, ["BAKE_FRAG"]),
    ("r3d_bake_slab", FULL, ["BAKE_SLAB", "BAKE_FRAG"]),
    ("r3d_bake_table", FULL, ["BAKE_TABLE", "BAKE_FRAG"]),
    ("r3d_bake_room", FULL, ["BAKE_ROOM", "BAKE_FRAG"]),
    ("r3d_shrink", FULL, ["SHRINK_FRAG"]),
    ("r3d_blur", FULL, ["BLUR_FRAG"]),
    ("r3d_copy", FULL, ["COPY_FRAG"]),
    ("r3d_kept", FULL, ["KEPT_FRAG"]),
    ("r3d_show", ["SHOW_VS", "SHOW_BLOCK", "SHOW_VERT"], ["SHOW_FS", "SHOW_BLOCK", "SHOW_FRAG"]),
    ("r3d_dust", ["VS_SET", "FRAME", "DUST_HEAD", "LIGHT_FN", "DUST_VERT"], ["DUST_FRAG"]),
    *[(name, ROOM_VS, defines + ROOM_FS + ([] if "ROOM_GLASS" in defines else ["TABLE_MAP_FN"]) + ["SSAO_FN", "TONE_FN", "ROOM_FRAG"])
      for name, defines in ROOMS],
    ("r3d_planar_resolve", FULL, ["PLANAR_RESOLVE_FRAG"]),
    ("r3d_planar_show", FULL, ["TONE_FN", "PLANAR_SHOW_FRAG"]),
    ("r3d_planar_mip", FULL, ["PLANAR_MIP_FRAG"]),
    ("r3d_outside", ["VS_SET", "FRAME", "OUTSIDE_VERT"], ["FS_SET", "FRAME", "TONE_FN", "OUTSIDE_FRAG"]),
    ("r3d_glow_pick", FULL, ["GLOW_PICK_FRAG"]),
    ("r3d_glow_blur", FULL, ["GLOW_BLUR_FRAG"]),
    ("r3d_glow_add", FULL, ["GLOW_ADD_FRAG"]),
    ("r3d_pre_room", ["VS_SET", "FRAME", "ROOM_VERT"], ["PRE_ROOM", "FS_SET", "FRAME", "PRE_FRAG"]),
    ("r3d_pre_table", TABLE_VS, ["FS_SET", "FRAME", "PRE_FRAG"]),
    ("r3d_pre_lit", LIT_VS, ["FS_SET", "FRAME", "PRE_FRAG"]),
    ("r3d_ssao", FULL, ["SSAO_FRAG"]),
    ("r3d_ssao_blur", FULL, ["SSAO_BLUR_FRAG"]),
]

def products(body):
    """mat4 * v, as gfx's column-major matrices multiply."""
    body = body.replace("(draw.y > 0.5 ? light_view_proj : view_proj) * vec4(world, 1.0)",
                        "xf(draw.y > 0.5 ? light_view_proj : view_proj, vec4(world, 1.0))")
    body = body.replace("light_view_proj * vec4(q, 1.0)", "xf(light_view_proj, vec4(q, 1.0))")
    body = body.replace("view_proj * vec4(pos, 1.0)", "xf(view_proj, vec4(pos, 1.0))")
    body = body.replace("view_proj * vec4(under, 1.0)", "xf(view_proj, vec4(under, 1.0))")
    body = body.replace("view_proj * vec4(q, 1.0)", "xf(view_proj, vec4(q, 1.0))")
    assert not re.search(r"_proj \*", body), "a matrix product left"
    return body


def frame_fields():
    m = re.search(r"uniform Frame \{(.*?)\};", S["FRAME"], re.S)
    return [(f.group(1), f.group(2), int(f.group(3) or 1))
            for f in re.finditer(r"(mat4|vec4)\s+(\w+)(?:\[(\d+)\])?\s*;", m.group(1))]


def module(name, vs_parts, fs_parts):
    uses_frame = "FRAME" in vs_parts or "FRAME" in fs_parts
    # FRAME's text (constants, srgb) goes once at the top; the stages get the rest.
    def strip(ps):
        return [S[p] for p in ps if p != "FRAME"]
    vs = Stage("vs", source(strip(vs_parts)), products)
    fs = Stage("fs", source(strip(fs_parts)), products)
    # Uniform blocks by name, in order, into root.u's float4s.
    blocks = {}
    offset = 0
    for bname, fields in unique((vs, fs), "blocks"):
        blocks[bname] = offset
        offset += sum(n for _, _, n in fields)
    buffers = unique((vs, fs), "buffers")
    textures = unique((vs, fs), "textures")
    assert len(buffers) <= 3 and len(textures) <= 16

    out = []
    w = out.append
    w(f"// Written by scripts/ngfx_3d_shaders.py from src/render3d/shaders.goose ({' + '.join(vs_parts)};")
    w(f"// {' + '.join(fs_parts)}).")
    w("//")
    w("// Root (r3d.slang): frame, u, buf, verts, tex/smp slots.")
    for bname, at in blocks.items():
        w(f"//   u[{at}..]: {bname}")
    for i, b in enumerate(buffers):
        w(f"//   buf{i}: {b}")
    for i, (t, shadow) in enumerate(textures):
        w(f"//   tex{i}: {t}{' (compare sampler)' if shadow else ''}")
    w('#include "r3d.slang"')
    w("")
    if uses_frame:
        w(textwrap.dedent(re.sub(r" *layout\(set = FRAME_SET.*?\};\n", "", S["FRAME"], flags=re.S))
          .replace("const ", "static const "))

    def load(st, kind):
        lines = []
        for bname, fields in st.blocks:
            at = blocks[bname]
            for t, f, n in fields:
                if n > 1:
                    lines.append(f"for (int i = 0; i < {n}; i++) {f}[i] = root.u[{at} + i];")
                else:
                    lines.append(f"{f} = root.u[{at}];")
                at += n
        for b in st.buffers:
            lines.append(f"{b} = root.buf{buffers.index(b)};")
        for t, shadow in st.textures:
            i = [x[0] for x in textures].index(t)
            lines.append(f"{t} = {'ShadowTex' if shadow else 'Tex'}(root.tex{i // 4}[{i % 4}], root.smp{i // 4}[{i % 4}]);")
        if kind == "vs" and st.ins:
            # The vertex's attributes, pulled from root.verts: mesh::Vertex, packed floats.
            stride = sum(TYPES[t] for _, t, _, _ in st.ins)
            at = 0
            lines.append(f"float* v = root.verts + gl_VertexIndex * {stride};")
            for _, t, n, _ in sorted(st.ins):
                k = TYPES[t]
                comps = ", ".join(f"v[{at + j}]" for j in range(k))
                lines.append(f"{n} = {t}({comps});")
                at += k
        return lines

    write_stage(w, vs, "vs", load(vs, "vs"))
    write_stage(w, fs, "fs", load(fs, "fs"))
    # The varyings: the vertex stage's outputs by location.
    write_entries(w, vs, fs, ["load_frame();"] if uses_frame else [])
    return "\n".join(out) + "\n"


def frame_slang():
    """r3d.slang's Frame and load_frame(), from FRAME's block."""
    fields = frame_fields()
    lines = ["// Written by scripts/ngfx_3d_shaders.py from shaders::FRAME.", "struct Frame {"]
    for t, n, k in fields:
        lines.append(f"    {'Mat' if t == 'mat4' else t} {n}{f'[{k}]' if k > 1 else ''};")
    lines.append("};")
    # An array is read where it is used: copied into the stage's globals, as a field is,
    # every pixel would hold all of it, and its indexing spills (the table's 48 discs
    # cost a 3D frame about 30 ms at 2560x1440 on an M1 Pro).
    for t, n, k in fields:
        if k > 1:
            lines.append(f"#define {n} (root.frame->{n})")
        else:
            lines.append(f"static {'Mat' if t == 'mat4' else t} {n};")
    lines.append("void load_frame() {")
    for t, n, k in fields:
        if k == 1:
            lines.append(f"    {n} = root.frame->{n};")
    lines.append("}")
    return "\n".join(lines) + "\n"


def sources():
    """Each file's name and text: r3d_frame.slang and a module per pipeline."""
    out = {"r3d_frame.slang": frame_slang()}
    for name, vs, fs in MODULES:
        out[f"{name}.slang"] = module(name, vs, fs)
    return out


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for name, text in sources().items():
        (out / name).write_bytes(text.encode())
    print(f"wrote {len(MODULES)} modules to {out}")


if __name__ == "__main__":
    main()
