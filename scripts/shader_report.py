#!/usr/bin/env python3
"""The 3D renderer's shaders as standalone GLSL, and the Mali Offline Compiler's report
for each (task 059).

Pulls each shader's parts out of src/render3d/shaders.goose, joined as embed_shader
joins them (render3d::setup's calls, repeated in SHADERS below: keep them in step),
writes them to build/shaders/<name>.<stage>, checks each with glslangValidator (the
Vulkan SDK's) into SPIR-V, and, when malioc is on PATH (Arm Performance Studio), prints
its report for the given cores.

    python scripts/shader_report.py                     # extract and check only
    python scripts/shader_report.py --core Mali-G615    # and malioc's report (the tablet)
    python scripts/shader_report.py --core Mali-G710 --core Mali-G68
"""
import argparse
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "src", "render3d", "shaders.goose")
OUT = os.path.join(ROOT, "build", "shaders")

# name, stage, parts in embed_shader's order (render3d::setup).
SHADERS = [
    ("lit", "vert", ["VS_SET", "FRAME", "LIT_VERT"]),
    ("lit", "frag", ["FS_SET", "FRAME", "LIT_FRAG"]),
    ("quad", "vert", ["VS_SET", "FRAME", "QUAD_VERT"]),
    ("empty", "frag", ["EMPTY_FRAG"]),
    ("full", "vert", ["FULL_VERT"]),
    ("backdrop", "frag", ["FS_SET", "FRAME", "FADE_FN", "BACKDROP_FRAG"]),
    ("catcher", "frag", ["FS_SET", "FRAME", "SHADOW_CATCHER_FRAG"]),
    ("marks", "frag", ["FS_SET", "FRAME", "MARKS_FRAG"]),
    ("marks_pulse", "frag", ["MARKS_PULSE", "FS_SET", "FRAME", "MARKS_FRAG"]),
    ("show", "vert", ["SHOW_VS", "SHOW_BLOCK", "SHOW_VERT"]),
    ("show", "frag", ["SHOW_FS", "SHOW_BLOCK", "SHOW_FRAG"]),
    ("bake", "frag", ["BAKE_FRAG"]),
]


def constants(text):
    """Each top-level `let NAME = "...";` or `let NAME = \"\"\"...\"\"\";` as its string."""
    out = {}
    for m in re.finditer(r'^let ([A-Z_0-9]+) = """\n(.*?)\n\s*""";', text, re.S | re.M):
        out[m.group(1)] = m.group(2)
    for m in re.finditer(r'^let ([A-Z_0-9]+) = "((?:[^"\\]|\\.)*)";', text, re.M):
        out[m.group(1)] = m.group(2).encode().decode("unicode_escape")
    return out


def glslang():
    exe = shutil.which("glslangValidator")
    if exe:
        return exe
    sdk = os.environ.get("VULKAN_SDK")
    if sdk:
        p = os.path.join(sdk, "Bin", "glslangValidator.exe")
        if os.path.exists(p):
            return p
    return None


def find_malioc():
    """malioc on PATH, or in Arm Performance Studio's newest install (its installer
    doesn't add it to PATH on Windows)."""
    exe = shutil.which("malioc")
    if exe:
        return exe
    base = os.path.join(os.environ.get("ProgramFiles", r"C:\Program Files"), "Arm")
    if os.path.isdir(base):
        for d in sorted(os.listdir(base), reverse=True):
            p = os.path.join(base, d, "mali_offline_compiler", "malioc.exe")
            if os.path.exists(p):
                return p
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--core", action="append", default=[], help="a Mali core for malioc, e.g. Mali-G615")
    args = ap.parse_args()

    with open(SOURCE, encoding="utf-8") as f:
        consts = constants(f.read())
    os.makedirs(OUT, exist_ok=True)
    validator = glslang()
    malioc = find_malioc()
    if args.core and not malioc:
        sys.exit("malioc isn't on PATH or in Program Files/Arm: install Arm Performance Studio (its Mali Offline Compiler)")

    failed = False
    for name, stage, parts in SHADERS:
        body = "\n".join(consts[p] for p in parts)
        # `patch` is a keyword to glslang's 450 (tessellation), not to the compiler goose
        # uses: BAKE_FRAG names a local so.
        body = re.sub(r"\bpatch\b", "patch_", body)
        src = "#version 450\n" + body + "\n"
        path = os.path.join(OUT, f"{name}.{stage}")
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(src)
        spv = path + ".spv"
        if validator:
            r = subprocess.run([validator, "-V", "-S", stage, path, "-o", spv], capture_output=True, text=True)
            if r.returncode != 0:
                failed = True
                print(f"{name}.{stage}: glslang failed\n{r.stdout}{r.stderr}")
                continue
        for core in args.core:
            r = subprocess.run([malioc, "--vulkan", "--core", core, f"--{stage}ment" if stage == "frag" else "--vertex", path],
                               capture_output=True, text=True)
            print(f"===== {name}.{stage} on {core} =====")
            print(r.stdout + r.stderr)
    if not validator:
        print("glslangValidator not found (the Vulkan SDK): extracted only, into", OUT)
    elif not failed:
        print("extracted and compiled", len(SHADERS), "shaders into", OUT)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
