#!/usr/bin/env python3
"""The room's Surfaces block as GLSL constants (task 115): a Valhall Mali holds only 128
uniform components in registers, and the room's shaders read far more, each vec4 past them
a load a pixel. Constants cost none and fold into the math.

Reads the light tuner's `--dump-room-block PATH` (the block's raw bytes) and the block's
declaration in src/render3d/shaders.goose's ROOM_HEAD, and writes, for each member, a
constant and a #define that sends the shader's reads of the member to it. The part goes
after ROOM_HEAD, so the block keeps its layout and the CPU's side is unchanged.

    python scripts/room_fixed.py BLOCK.bin OUT.goose
"""
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src/render3d/shaders.goose"


def members():
    """Surfaces' members in order, each (name, count of vec4s, array length or 0)."""
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
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    data = Path(sys.argv[1]).read_bytes()
    ms = members()
    count = sum(max(n, 1) for _, n in ms)
    if len(data) != 16 * count:
        sys.exit(f"the dump is {len(data)} bytes, the block {16 * count}: rebuild the tuner")
    floats = struct.unpack(f"<{4 * count}f", data)
    lines = []
    at = 0
    for name, n in ms:
        if n:
            vals = [vec4(floats[at + 4 * i:at + 4 * i + 4]) for i in range(n)]
            lines.append(f"    const vec4 fixed_{name}[{n}] = vec4[{n}](" + ", ".join(vals) + ");")
            at += 4 * n
        else:
            lines.append(f"    const vec4 fixed_{name} = {vec4(floats[at:at + 4])};")
            at += 4
        lines.append(f"    #define {name} fixed_{name}")
    out = ("// Made by scripts/room_fixed.py from the light tuner's --dump-room-block: don't edit.\n"
           "// The room's Surfaces block as constants (shaders::ROOM_HEAD's), after ROOM_HEAD.\n"
           "namespace room_fixed;\n\n"
           'let ROOM_FIXED = """\n' + "\n".join(lines) + '\n""";\n')
    Path(sys.argv[2]).write_text(out, encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
