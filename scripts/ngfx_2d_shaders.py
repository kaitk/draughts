#!/usr/bin/env python3
"""The ngfx build's 2D shaders, the flat board's, the scene's, and the UI's, written from
gfx's GLSL in src/app/draw_gpu.goose, scene_gpu.goose, and widgets_gpu.goose (task 073),
as ngfx_3d_shaders.py writes the 3D board's, so each shader has one source. scripts/ngfx.py
calls sources() at every build; on its own it prints them into a folder to read:

    python scripts/ngfx_2d_shaders.py <dir>

Each pipeline becomes one Slang module (ngfx_glsl.py), its stages' GLSL put together as
the gfx recorder's embed_shader calls put it. Its root is its own, written at the top of
the file, which the module's recorder in src/ngfx/app/ fills to match: the storage
buffers' addresses, the textures' heap indices and their one sampler's, padded to 16
bytes, then the uniform blocks' fields, each block once, the vertex stage's first.
"""
import sys
from pathlib import Path

from ngfx_glsl import Stage, source, strings, unique, write_entries, write_stage

ROOT = Path(__file__).resolve().parent.parent
SOURCES = {
    "shaders": ROOT / "src/render3d/shaders.goose",
    "draw_gpu": ROOT / "src/app/draw_gpu.goose",
    "scene_gpu": ROOT / "src/app/scene_gpu.goose",
    "widgets_gpu": ROOT / "src/app/widgets_gpu.goose",
}
S = {f"{ns}::{name}": text for ns, path in SOURCES.items() for name, text in strings(path).items()}

# The pipelines: name, vertex parts, fragment parts (as the gfx recorders' embed_shader
# calls name them), and whether the root carries the run's first instance.
FULL = ["shaders::FULL_VERT"]
THEMED = ["shaders::FADE_FN", "draw_gpu::THEME_BLOCK", "draw_gpu::SHARED_BLOCK"]
UI_VS = ["draw_gpu::SHARED_BLOCK", "widgets_gpu::VERT"]
UI_FS = [*THEMED, "draw_gpu::MAN_BLOCK", "widgets_gpu::FRAG"]
MODULES = [
    ("compose", FULL, ["widgets_gpu::COMPOSE_FRAG"], False),
    ("fade", FULL, ["shaders::FADE_FN", "scene_gpu::FADE_FRAG"], False),
    ("blur", FULL, ["scene_gpu::BLUR_FRAG"], False),
    ("shrink", FULL, ["scene_gpu::SHRINK_FRAG"], False),
    ("board", FULL, [*THEMED, "draw_gpu::BOARD_FRAG"], False),
]

# Hand-written, beside what is generated: SV_InstanceID counts from 0 whatever the draw's
# first instance (goose-ngfx's docs/design.md), where gl_InstanceIndex counts from it, so
# a run of quads from `first` (widgets_gpu::run) takes it from the root.
FIRST = "int(instance + root.first)"

VEC4S = {"vec4", "uvec4", "ivec4"}


def module(name, vs_parts, fs_parts, first):
    vs = Stage("vs", source([S[p] for p in vs_parts]))
    fs = Stage("fs", source([S[p] for p in fs_parts]))
    blocks = unique((vs, fs), "blocks")
    buffers = unique((vs, fs), "buffers")
    textures = unique((vs, fs), "textures")
    assert not any(shadow for _, shadow in textures), "a compare sampler in a 2D shader"
    for bname, fields in blocks:
        assert all(t in VEC4S and n == 1 for t, _, n in fields), f"{bname}: only vec4s are laid out here"
    uints = [t for t, _ in textures] + (["smp"] if textures else []) + (["first"] if first else [])
    pad = (-(8 * len(buffers) + 4 * len(uints)) % 16) // 4

    out = []
    w = out.append
    w(f"// Written by scripts/ngfx_2d_shaders.py from {' + '.join(vs_parts)};")
    w(f"// {' + '.join(fs_parts)}.")
    w("//")
    w("// Root, which the recorder fills in this order: the storage buffers' addresses (u64),")
    w("// the textures' heap indices and their sampler's (u32), padding to 16 bytes, and the")
    w("// uniform blocks' fields (float4).")
    w(f"//   {', '.join([*buffers, *uints, *[f'pad{i}' for i in range(pad)]]) or '(none)'}")
    for bname, fields in blocks:
        w(f"//   {bname}: {', '.join(f for _, f, _ in fields)}")
    w('#include "glsl.slang"')
    w("")
    w("struct Root {")
    for b in buffers:
        w(f"    vec4* {b};")
    for u in uints:
        w(f"    uint {u};{'  // hand-written: FIRST' if u == 'first' else ''}")
    for i in range(pad):
        w(f"    uint pad{i};")
    for _, fields in blocks:
        for t, f, _ in fields:
            w(f"    {t} {f};")
    w("};")
    w("GPU_ROOT(Root, root);")
    w("")

    def load(st):
        lines = [f"{f} = root.{f};" for _, fields in st.blocks for _, f, _ in fields]
        lines += [f"{b} = root.{b};" for b in st.buffers]
        lines += [f"{t} = Tex(root.{t}, root.smp);" for t, _ in st.textures]
        return lines

    write_stage(w, vs, "vs", load(vs))
    write_stage(w, fs, "fs", load(fs))
    write_entries(w, vs, fs, instance=FIRST if first else "int(instance)")
    return "\n".join(out) + "\n"


def sources():
    """Each file's name and text: a module per pipeline."""
    return {f"{name}.slang": module(name, vs, fs, first) for name, vs, fs, first in MODULES}


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for name, text in sources().items():
        (out / name).write_bytes(text.encode())
    print(f"wrote {len(MODULES)} modules to {out}")


if __name__ == "__main__":
    main()
