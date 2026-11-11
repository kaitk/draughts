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
draws it. The root's layout per module is written at the top of each file, which
src/ngfx/render3d/render3d_gpu.goose fills to match.
"""
import re
import sys
import textwrap
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src/render3d/shaders.goose"


def strings():
    text = SRC.read_text(encoding="utf-8")
    out = {}
    for m in re.finditer(r'^let (\w+) = """\n(.*?)""";', text, re.S | re.M):
        out[m.group(1)] = m.group(2)
    for m in re.finditer(r'^let (\w+) = "(.*?)";', text, re.M):
        out[m.group(1)] = m.group(2).replace("\\n", "\n")
    return out


S = strings()

# The pipelines: name, vertex parts, fragment parts (shaders.goose's names, as
# render3d::setup puts them together).
FULL = ["FULL_VERT"]
LIT_VS = ["VS_SET", "FRAME", "LIT_VERT"]
QUAD_VS = ["VS_SET", "FRAME", "QUAD_VERT"]
MODULES = [
    ("r3d_lit", LIT_VS, ["FS_SET", "FRAME", "LIT_FRAG"]),
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

TYPES = {"float": 1, "vec2": 2, "vec3": 3, "vec4": 4}


def matching(s, i):
    """The index of the parenthesis closing the one at s[i]."""
    depth = 0
    for j in range(i, len(s)):
        if s[j] == "(":
            depth += 1
        elif s[j] == ")":
            depth -= 1
            if depth == 0:
                return j
    raise ValueError("unbalanced")


def arrays(s):
    """GLSL's array constructors, vec2[6](a, b) and int[](...), as { } lists."""
    while True:
        m = re.search(r"\b(?:vec[234]|ivec[234]|float|int)\[\d*\]\(", s)
        if not m:
            return s
        open_at = m.end() - 1
        close = matching(s, open_at)
        s = s[:m.start()] + "{" + s[open_at + 1:close] + "}" + s[close + 1:]


def preprocess(text, defined):
    """GLSL's #ifdef, #ifndef, #else, #endif over `defined`, done here so the stage's
    declarations are known."""
    out, stack = [], []      # stack: (whether the enclosing part is kept, this branch's)
    keep = True
    for line in text.split("\n"):
        t = line.strip()
        if t.startswith("#ifdef ") or t.startswith("#ifndef "):
            on = (t.split()[1] in defined) == t.startswith("#ifdef ")
            stack.append((keep, on))
            keep = keep and on
        elif t == "#else":
            outer, on = stack.pop()
            stack.append((outer, not on))
            keep = outer and not on
        elif t == "#endif":
            keep = stack.pop()[0]
        elif keep:
            out.append(line)
    return "\n".join(out)


class Stage:
    def __init__(self, ns, text):
        self.ns = ns
        self.ins = []        # (location, type, name, flat)
        self.outs = []       # (location, type, name, flat)
        self.blocks = []     # (name, [(type, field, count)])
        self.buffers = []    # name of the vec4 array
        self.textures = []   # (name, shadow)
        self.body = self.parse(text)

    def parse(self, text):
        lines = []
        # Uniform blocks may span lines: take them whole first.
        def block(m):
            name = m.group(2)
            fields = []
            for f in re.finditer(r"(mat4|vec4|vec3|vec2|float)\s+(\w+)(?:\[(\d+)\])?\s*;", m.group(3)):
                fields.append((f.group(1), f.group(2), int(f.group(3) or 1)))
            self.blocks.append((name, fields))
            return ""
        text = re.sub(r"layout\(set = (\w+), binding = \d+\) uniform (\w+) \{(.*?)\};", block, text, flags=re.S)
        for line in text.split("\n"):
            m = re.match(r"\s*layout\(location = (\d+)\) (flat )?(in|out) (\w+) (\w+);", line)
            if m:
                entry = (int(m.group(1)), m.group(4), m.group(5), bool(m.group(2)))
                (self.ins if m.group(3) == "in" else self.outs).append(entry)
                continue
            m = re.match(r"\s*layout\(std430, set = \d+, binding = \d+\) readonly buffer \w+ \{ vec4 (\w+)\[\]; \};", line)
            if m:
                self.buffers.append(m.group(1))
                continue
            m = re.match(r"\s*layout\(set = \d+, binding = \d+\) uniform (sampler2D|sampler2DShadow) (\w+);", line)
            if m:
                self.textures.append((m.group(2), m.group(1) == "sampler2DShadow"))
                continue
            m = re.match(r"\s*#define FRAME_SET|\s*#define SHOW_SET", line)
            if m:
                continue
            lines.append(line)
        body = "\n".join(lines)
        body = arrays(body)
        body = re.sub(r"\bconst ((?:vec[234]|ivec[234]|float|int) \w+(?:\[\d*\])? =)", r"static const \1", body)
        body = re.sub(r"\bflat\b", "nointerpolation", body)
        body = re.sub(r"\bdFdx\(", "ddx(", body)
        body = re.sub(r"\bdFdy\(", "ddy(", body)
        body = re.sub(r"\binversesqrt\(", "rsqrt(", body)
        body = re.sub(r"\bnot\(", "glsl_not(", body)
        body = re.sub(r"\btexture\(", "glsl_texture(", body)
        body = re.sub(r"\btextureGrad\(", "glsl_texture_grad(", body)
        body = re.sub(r"\btextureSize\(", "glsl_texture_size(", body)
        body = re.sub(r"\btexelFetch\(", "glsl_texel_fetch(", body)
        # mat4 * v, as gfx's column-major matrices multiply.
        body = body.replace("(draw.y > 0.5 ? light_view_proj : view_proj) * vec4(world, 1.0)",
                            "xf(draw.y > 0.5 ? light_view_proj : view_proj, vec4(world, 1.0))")
        body = body.replace("light_view_proj * vec4(q, 1.0)", "xf(light_view_proj, vec4(q, 1.0))")
        body = body.replace("view_proj * vec4(pos, 1.0)", "xf(view_proj, vec4(pos, 1.0))")
        assert not re.search(r"_proj \*", body), "a matrix product left"
        body = re.sub(r"\bvoid main\(\)", "void glsl_main()", body)
        return body


def frame_fields():
    m = re.search(r"uniform Frame \{(.*?)\};", S["FRAME"], re.S)
    return [(f.group(1), f.group(2), int(f.group(3) or 1))
            for f in re.finditer(r"(mat4|vec4)\s+(\w+)(?:\[(\d+)\])?\s*;", m.group(1))]


def parts(names):
    return "\n".join(S[n] for n in names)


def module(name, vs_parts, fs_parts):
    uses_frame = "FRAME" in vs_parts or "FRAME" in fs_parts
    # FRAME's text (constants, srgb) goes once at the top; the stages get the rest.
    def strip(ps):
        return [p for p in ps if p not in ("FRAME", "VS_SET", "FS_SET", "MARKS_PULSE", "SHOW_VS", "SHOW_FS")]
    pulse = "MARKS_PULSE" in fs_parts
    defined = {"PULSE"} if pulse else set()
    vs = Stage("vs", preprocess(parts(strip(vs_parts)), defined))
    fs = Stage("fs", preprocess(parts(strip(fs_parts)), defined))
    # Uniform blocks by name, in order, into root.u's float4s.
    blocks = {}
    offset = 0
    for st in (vs, fs):
        for bname, fields in st.blocks:
            if bname in blocks:
                continue
            blocks[bname] = offset
            offset += sum(n for _, _, n in fields)
    buffers = []
    for st in (vs, fs):
        for b in st.buffers:
            if b not in buffers:
                buffers.append(b)
    textures = []
    for st in (vs, fs):
        for t in st.textures:
            if t not in textures:
                textures.append(t)
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

    def stage_text(st, kind):
        w(f"namespace {st.ns} {{")
        if kind == "vs":
            w("static int gl_VertexIndex;")
            w("static int gl_InstanceIndex;")
            w("static vec4 gl_Position;")
        else:
            w("static vec4 gl_FragCoord;")
        for _, t, n, _ in st.ins + st.outs:
            w(f"static {t} {n};")
        for bname, fields in st.blocks:
            for t, f, n in fields:
                w(f"static {t} {f}{f'[{n}]' if n > 1 else ''};")
        for b in st.buffers:
            w(f"static vec4* {b};")
        for t, shadow in st.textures:
            w(f"static {'ShadowTex' if shadow else 'Tex'} {t};")
        w("void load() {")
        for bname, fields in st.blocks:
            at = blocks[bname]
            for t, f, n in fields:
                if n > 1:
                    w(f"    for (int i = 0; i < {n}; i++) {f}[i] = root.u[{at} + i];")
                else:
                    w(f"    {f} = root.u[{at}];")
                at += n
        for b in st.buffers:
            w(f"    {b} = root.buf{buffers.index(b)};")
        for t, shadow in st.textures:
            i = [x[0] for x in textures].index(t)
            w(f"    {t} = {'ShadowTex' if shadow else 'Tex'}(root.tex{i // 4}[{i % 4}], root.smp{i // 4}[{i % 4}]);")
        if kind == "vs" and st.ins:
            # The vertex's attributes, pulled from root.verts: mesh::Vertex, packed floats.
            stride = sum(TYPES[t] for _, t, _, _ in st.ins)
            at = 0
            w(f"    float* v = root.verts + gl_VertexIndex * {stride};")
            for _, t, n, _ in sorted(st.ins):
                k = TYPES[t]
                comps = ", ".join(f"v[{at + j}]" for j in range(k))
                w(f"    {n} = {t}({comps});")
                at += k
        w("}")
        w(st.body)
        w(f"}} // {st.ns}")
        w("")

    stage_text(vs, "vs")
    stage_text(fs, "fs")

    # The varyings: the vertex stage's outputs by location.
    w("struct Varyings {")
    w("    float4 position : SV_Position;")
    for loc, t, n, flat in sorted(vs.outs):
        w(f"    {'nointerpolation ' if flat else ''}{t} {n} : TEXCOORD{loc};")
    w("};")
    w("")
    w("[shader(\"vertex\")]")
    w("Varyings vertex_main(uint vertex : SV_VertexID, uint instance : SV_InstanceID) {")
    if uses_frame:
        w("    load_frame();")
    w("    vs::gl_VertexIndex = int(vertex);")
    w("    vs::gl_InstanceIndex = int(instance);")
    w("    vs::load();")
    w("    vs::glsl_main();")
    w("    Varyings o;")
    w("    o.position = vs::gl_Position;")
    w("    o.position.y = -o.position.y;")
    for loc, t, n, flat in sorted(vs.outs):
        w(f"    o.{n} = vs::{n};")
    w("    return o;")
    w("}")
    w("")
    outs = sorted(fs.outs)
    if outs:
        w("struct Targets {")
        for loc, t, n, _ in outs:
            w(f"    vec4 {n} : SV_Target{loc};")
        w("};")
    w("[shader(\"fragment\")]")
    w(f"{'Targets' if outs else 'void'} fragment_main(Varyings i) {{")
    if uses_frame:
        w("    load_frame();")
    w("    fs::gl_FragCoord = i.position;")
    by_loc = {loc: n for loc, _, n, _ in vs.outs}
    for loc, t, n, _ in fs.ins:
        w(f"    fs::{n} = i.{by_loc[loc]};")
    w("    fs::load();")
    w("    fs::glsl_main();")
    if outs:
        w("    Targets o;")
        for loc, t, n, _ in outs:
            w(f"    o.{n} = fs::{n};")
        w("    return o;")
    w("}")
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
