#!/usr/bin/env python3
"""gfx's GLSL as Slang for the ngfx build (task 065, 073): what ngfx_3d_shaders.py (the 3D
board's modules) and ngfx_2d_shaders.py (the flat board's, the scene's, and the UI's)
share. Not run on its own.

A stage's GLSL becomes a namespace holding its body as written: the GLSL names come from
src/ngfx/shaders/glsl.slang, the stage's inputs, outputs, uniform blocks, storage buffers
and samplers become statics, which the caller's load() fills from its root at the entry
points, and the position's y is negated for NoGraphicsAPI's clip space, which leaves the
picture as gfx draws it.
"""
import re

TYPES = {"float": 1, "vec2": 2, "vec3": 3, "vec4": 4}


def strings(path):
    """A Goose file's top-level strings by name: its multi-line `let NAME = \"\"\"...` ones
    and its one-line `let NAME = "...";` ones."""
    text = path.read_text(encoding="utf-8")
    out = {}
    for m in re.finditer(r'^let (\w+) = """\n(.*?)""";', text, re.S | re.M):
        out[m.group(1)] = m.group(2)
    for m in re.finditer(r'^let (\w+) = "(.*?)";', text, re.M):
        out[m.group(1)] = m.group(2).replace("\\n", "\n")
    return out


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


def source(texts):
    """A stage's strings as embed_shader takes them, put together and preprocessed: a
    string of #defines alone (VS_SET, MARKS_PULSE, widgets_gpu's BASE) defines its names
    and adds no lines."""
    defines = r"(?:#define \w+(?: \w+)?\n)+"
    defined = {m for t in texts if re.fullmatch(defines, t) for m in re.findall(r"#define (\w+)", t)}
    return preprocess("\n".join(t for t in texts if not re.fullmatch(defines, t)), defined)


def statics(body):
    """A global with an initializer, `vec4 acc = vec4(0.0);`, as a static: Slang takes a
    plain global for a uniform."""
    out, depth = [], 0
    for line in body.split("\n"):
        if depth == 0:
            line = re.sub(r"^(\s*)((?:vec[234]|ivec[234]|float|int|bool) \w+ = )", r"\1static \2", line)
        depth += line.count("{") - line.count("}")
        out.append(line)
    return "\n".join(out)


class Stage:
    def __init__(self, ns, text, fix=None):
        self.ns = ns
        self.ins = []        # (location, type, name, flat)
        self.outs = []       # (location, type, name, flat)
        self.blocks = []     # (name, [(type, field, count)])
        self.buffers = []    # name of the vec4 array
        self.textures = []   # (name, shadow)
        self.body = self.parse(text, fix)

    def parse(self, text, fix):
        lines = []
        # Uniform blocks may span lines: take them whole first.
        def block(m):
            name = m.group(2)
            fields = []
            for f in re.finditer(r"(mat4|[iu]?vec4|vec3|vec2|float)\s+(\w+)(?:\[(\d+)\])?\s*;", m.group(3)):
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
            lines.append(line)
        body = "\n".join(lines)
        body = arrays(body)
        body = statics(body)
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
        if fix:
            body = fix(body)
        body = re.sub(r"\bvoid main\(\)", "void glsl_main()", body)
        return body


def unique(stages, field):
    """The stages' blocks, buffers, or textures, each once, the vertex stage's first."""
    out, seen = [], set()
    for st in stages:
        for x in getattr(st, field):
            key = x[0] if field == "blocks" else x
            if key not in seen:
                seen.add(key)
                out.append(x)
    return out


def write_stage(w, st, kind, load):
    """The stage's namespace: its statics, load() with the caller's lines, and its body."""
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
    for line in load:
        w(f"    {line}")
    w("}")
    w(st.body)
    w(f"}} // {st.ns}")
    w("")


def write_entries(w, vs, fs, pre=(), instance="int(instance)"):
    """The varyings and the two entry points: `pre` lines first in each, the instance's
    index as `instance` reads it."""
    w("struct Varyings {")
    w("    float4 position : SV_Position;")
    for loc, t, n, flat in sorted(vs.outs):
        w(f"    {'nointerpolation ' if flat else ''}{t} {n} : TEXCOORD{loc};")
    w("};")
    w("")
    w("[shader(\"vertex\")]")
    w("Varyings vertex_main(uint vertex : SV_VertexID, uint instance : SV_InstanceID) {")
    for line in pre:
        w(f"    {line}")
    w("    vs::gl_VertexIndex = int(vertex);")
    w(f"    vs::gl_InstanceIndex = {instance};")
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
    for line in pre:
        w(f"    {line}")
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
