#!/usr/bin/env python3
"""The room's Surfaces block as GLSL constants (task 115): a Valhall Mali holds only 128
uniform components in registers, and the room's shaders read far more, each vec4 past them
a load a pixel. Constants cost none and fold into the math.

Reads the light tuner's `--dump-room-block PATH` (the block's raw bytes, in the phone's
tier) and the block's declaration in src/render3d/shaders/room.goose's ROOM_HEAD, and writes,
for each fixed member, a constant and a #define that sends the shader's reads of the member
to it. The part goes after ROOM_HEAD, so the block keeps its layout and the CPU's side is
unchanged. The members in KEEP, which the app's state changes, stay uniforms. It writes
the fixed members' bytes too, so the renderer can check the constants are still the
block's and use the uniform shaders where they aren't (render3d_gpu's fixed_current).

    python scripts/room_fixed.py BLOCK.bin OUT.goose          # the fixed members (KEEP stay uniform)
    python scripts/room_fixed.py BLOCK.bin OUT.goose --all    # every member, the first trial's
"""
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src/render3d/shaders/room.goose"

# The members a season, the time of day, the room's state or its switches change: they stay
# uniforms (render3d::surfaces_block and room_block fill them from g.room, g.room_tint,
# room_sun and the switches), so one set of shaders serves every state. Keeping a few more
# costs little: malioc's loads stayed at 1 to 6 cycles with these.
KEEP = ["shade", "lace_light", "table", "shell_sun", "room_baked", "shell_ends", "corners", "books",
        "ssao", "planar", "planar_look", "contact", "sheen", "room_sun", "paint_quiet", "paint_steps",
        "sill_steps", "window_view", "lace_shade", "table_map", "tile", "shell_glass", "light_box", "light_grid"]


def members():
    """Surfaces' members in order, each (name, array length or 0)."""
    text = SRC.read_text(encoding="utf-8")
    m = re.search(r"uniform Surfaces \{(.*?)\};", text, re.S)
    body = re.sub(r"//.*", "", m.group(1))
    out = []
    for t, name, n in re.findall(r"(\w+)\s+(\w+)(?:\s*\[(\d+)\])?\s*;", body):
        if t != "vec4":
            sys.exit(f"Surfaces' {name} is a {t}: only vec4s are laid out here")
        out.append((name, int(n) if n else 0))
    return out


def vec4(v):
    return "vec4(" + ", ".join(f"{x:.9g}" for x in v) + ")"


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) != 2:
        sys.exit(__doc__)
    keep = [] if "--all" in sys.argv else KEEP
    data = Path(args[0]).read_bytes()
    ms = members()
    missing = [k for k in keep if k not in [m for m, _ in ms]]
    if missing:
        sys.exit(f"KEEP names members the block doesn't have: {missing}")
    count = sum(max(n, 1) for _, n in ms)
    if len(data) != 16 * count:
        sys.exit(f"the dump is {len(data)} bytes, the block {16 * count}: rebuild the tuner")
    floats = struct.unpack(f"<{4 * count}f", data)
    lines, spans, names = [], [], []
    at = 0
    for name, n in ms:
        size = max(n, 1)
        if name not in keep:
            if n:
                vals = [vec4(floats[at + 4 * i:at + 4 * i + 4]) for i in range(n)]
                lines.append(f"    const vec4 fixed_{name}[{n}] = vec4[{n}](" + ", ".join(vals) + ");")
            else:
                lines.append(f"    const vec4 fixed_{name} = {vec4(floats[at:at + 4])};")
            lines.append(f"    #define {name} fixed_{name}")
            spans += [4 * at, 16 * size]
            names.append(name)
        at += 4 * size
    fixed = b"".join(data[spans[i]:spans[i] + spans[i + 1]] for i in range(0, len(spans), 2))
    out = ("// Made by scripts/room_fixed.py from the light tuner's --dump-room-block: don't edit.\n"
           "// The room's Surfaces block as constants (shaders::ROOM_HEAD's), after ROOM_HEAD.\n"
           "namespace room_fixed;\n\n"
           'let ROOM_FIXED = """\n' + "\n".join(lines) + '\n""";\n\n'
           "// The constants' members, each as (start, length) in the block's bytes, and their bytes\n"
           "// as the dump had them (render3d_gpu's fixed_current).\n"
           f"let COUNT = {len(names)};\n"
           f"let SPANS: i64[{len(spans)}] = [" + ", ".join(map(str, spans)) + "];\n"
           f"let NAMES: const u8[:][{len(names)}] = [" + ", ".join(f'"{n}"' for n in names) + "];\n"
           f"let BYTES: u8[{len(fixed)}] = [" + ", ".join(map(str, fixed)) + "];\n")
    Path(args[1]).write_text(out, encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
