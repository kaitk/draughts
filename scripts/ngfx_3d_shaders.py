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
written at the top of each file, which src/ngfx/render3d/render3d_gpu.goose fills to
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
MODULES = [
    ("r3d_lit", LIT_VS, ["FS_SET", "FRAME", "LIT_FRAG"]),
    ("r3d_lit_few", LIT_VS, ["SHADOW_FEW", "FS_SET", "FRAME", "LIT_FRAG"]),
    ("r3d_lit_many", LIT_VS, ["SHADOW_MANY", "FS_SET", "FRAME", "LIT_FRAG"]),
    ("r3d_depth", LIT_VS, ["EMPTY_FRAG"]),
    ("r3d_crown", FULL, ["CROWN_FN", "CROWN_FRAG"]),
    ("r3d_occ", FULL, ["FS_SET", "FRAME", "OCC_FRAG"]),
    ("r3d_backdrop", FULL, ["FS_SET", "FRAME", "FADE_FN", "BACKDROP_FRAG"]),
    ("r3d_catcher", QUAD_VS, ["FS_SET", "FRAME", "SHADOW_CATCHER_FRAG"]),
    ("r3d_marks", QUAD_VS, ["FS_SET", "FRAME", "MARKS_FRAG"]),
    ("r3d_pulse", QUAD_VS, ["MARKS_PULSE", "FS_SET", "FRAME", "MARKS_FRAG"]),
    ("r3d_bake", FULL, ["BAKE_FRAG"]),
    ("r3d_shrink", FULL, ["SHRINK_FRAG"]),
    ("r3d_blur", FULL, ["BLUR_FRAG"]),
    ("r3d_copy", FULL, ["COPY_FRAG"]),
    ("r3d_kept", FULL, ["KEPT_FRAG"]),
    ("r3d_show", ["SHOW_VS", "SHOW_BLOCK", "SHOW_VERT"], ["SHOW_FS", "SHOW_BLOCK", "SHOW_FRAG"]),
]

def products(body):
    """mat4 * v, as gfx's column-major matrices multiply."""
    body = body.replace("(draw.y > 0.5 ? light_view_proj : view_proj) * vec4(world, 1.0)",
                        "xf(draw.y > 0.5 ? light_view_proj : view_proj, vec4(world, 1.0))")
    body = body.replace("light_view_proj * vec4(q, 1.0)", "xf(light_view_proj, vec4(q, 1.0))")
    body = body.replace("view_proj * vec4(pos, 1.0)", "xf(view_proj, vec4(pos, 1.0))")
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
    assert len(buffers) <= 3 and len(textures) <= 8

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
    for t, n, k in fields:
        lines.append(f"static {'Mat' if t == 'mat4' else t} {n}{f'[{k}]' if k > 1 else ''};")
    lines.append("void load_frame() {")
    for t, n, k in fields:
        if k > 1:
            lines.append(f"    for (int i = 0; i < {k}; i++) {n}[i] = root.frame->{n}[i];")
        else:
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
