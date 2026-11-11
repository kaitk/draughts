#!/usr/bin/env python3
"""Write src/render3d/smaa.glsl, SMAA's shader for the gfx build, from third_party/smaa/SMAA.hlsl.

    python3 tools/smaa_glsl.py

SMAA.hlsl stays as published. gfx's embed_shader compiles cute_spirv's GLSL, which lacks
two conversions the shader makes (docs/goose-findings.md): a float from a bool, and a
bool vector from a float one; and the Metal translation refuses a swizzle passed as an
inout argument (SMAAMovc's bool4 form). This copy rewrites those lines and nothing else; the
rest is the macros in src/render3d/smaa.goose (SMAA_CUSTOM_SL), as the ngfx build's
smaa.slang has. Run it again only if SMAA.hlsl changes.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "third_party/smaa/SMAA.hlsl"
OUT = ROOT / "src/render3d/smaa.glsl"

# What cute_spirv can't compile, and the same in what it can: each must match exactly as
# many times as given, so a changed SMAA.hlsl stops here rather than compiling wrong.
REWRITES = [
    (r"float\(end\.y > 0\.9\)", "(end.y > 0.9 ? 1.0 : 0.0)", 2),
    (r"bool2\(step\(0\.9, d\.zw\)\)", "greaterThanEqual(d.zw, float2(0.9, 0.9))", 2),
    # A swizzle passed as an inout argument, which the Metal translation refuses.
    (r"SMAAMovc\(cond\.xy, variable\.xy, value\.xy\);\n    SMAAMovc\(cond\.zw, variable\.zw, value\.zw\);",
     "SMAA_FLATTEN if (cond.x) variable.x = value.x;\n    SMAA_FLATTEN if (cond.y) variable.y = value.y;\n"
     "    SMAA_FLATTEN if (cond.z) variable.z = value.z;\n    SMAA_FLATTEN if (cond.w) variable.w = value.w;", 1),
    # The same for the corner patterns' weights, through a local.
    (r"(SMAADetect(?:Horizontal|Vertical)CornerPattern)\(SMAATexturePass2D\(edgesTex\), weights\.(rg|ba), (coords\.\w+), d\);",
     r"float2 w_\2 = weights.\2; \1(SMAATexturePass2D(edgesTex), w_\2, \3, d); weights.\2 = w_\2;", 2),
]


def main():
    # Latin-1: the file has a few such bytes in its comments; written back as UTF-8.
    s = SRC.read_text(encoding="latin-1")
    for pattern, to, count in REWRITES:
        s, n = re.subn(pattern, to, s)
        if n != count:
            sys.exit(f"{SRC}: {pattern} matched {n} times, not {count}")
    head = ("// Written by tools/smaa_glsl.py from third_party/smaa/SMAA.hlsl (MIT, its\n"
            "// LICENSE.txt) for gfx's GLSL; edit neither, run the tool again.\n")
    OUT.write_text(head + s, encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
