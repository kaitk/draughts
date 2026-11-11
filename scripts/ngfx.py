#!/usr/bin/env python3
"""Build Draughts on goose-ngfx (NoGraphicsAPI) instead of gfx, and optionally run it
(task 065, a prototype on the ngfx branch).

    python scripts/ngfx.py src/app/draughts.goose              build build/ngfx/draughts(.exe)
    python scripts/ngfx.py src/app/draughts.goose --run -- --screen game
                                                               build, and run it with those flags

The gfx build is untouched. This copies the program (src/, strings/, assets/, and the
backgrounds' JPEG and ASTC masters) into build/ngfx/tree/ and lays src/ngfx/ over it: the ngfx
versions of the files that draw (src/ngfx/app/ over src/app/, src/ngfx/render3d/ over
src/render3d/). The root file gets the package's import, the sidecar the package's C
headers, and the Slang shaders are compiled ahead into ngfx's blobs, which the app embeds,
so it runs no shader compiler: src/ngfx/shaders/, and the 3D board's, written from gfx's
GLSL by ngfx_3d_shaders.py. SMAA (third_party/smaa) comes with them: its shader, which
smaa.slang includes, and its tables, which render3d embeds.

Needs a goose-ngfx checkout (NGFX, else ../goose/goose-ngfx beside this repository),
slangc 2026.18.2 or later (NGFX_SLANGC), and what ngfx's own build needs (its
docs/development.md: on Windows the Vulkan SDK and Visual Studio's Build Tools; on the
Mac Xcode with its Metal toolchain). The program is built with the Goose release's copy
whose gfx has patches/goose_gfx applied (scripts/mac.py, scripts/windows.py), for gfx's
WINDOW_ONLY: gfx's window, input, and events, with ngfx drawing into the window.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

import native
import ngfx_3d_shaders

if native.WINDOWS:
    import windows as platform_build
else:
    import mac as platform_build

ROOT = native.ROOT
OUT = ROOT / "build/ngfx"
TREE = OUT / "tree"
NGFX = Path(os.environ.get("NGFX", ROOT.parent / "goose/goose-ngfx")).resolve()
EXE = ".exe" if native.WINDOWS else ""


def copy_if_changed(src, dst):
    """Copies a file unless dst has its size and time already, so Goose sees no change."""
    s = os.stat(src)
    try:
        d = os.stat(dst)
        if d.st_size == s.st_size and int(d.st_mtime) == int(s.st_mtime):
            return dst
    except FileNotFoundError:
        pass
    return shutil.copy2(src, dst)


def sync(src, dst, over=None):
    """dst/ as a copy of src/, each file copied if it changed; where over/ has a file of
    the same path, that one instead. src/ngfx/ itself is left out."""
    for f in src.rglob("*"):
        r = f.relative_to(src)
        if f.is_dir() or r.parts[0] == "ngfx":
            continue
        o = over / r if over else None
        (dst / r).parent.mkdir(parents=True, exist_ok=True)
        copy_if_changed(o if o and o.exists() else f, dst / r)


def rel(frm, to):
    return os.path.relpath(to, frm).replace("\\", "/")


def tree(program):
    """build/ngfx/tree/: the program with src/ngfx/ laid over it; the root file's path."""
    sync(ROOT / "src", TREE / "src", ROOT / "src/ngfx")
    for part in ["strings", "assets"]:
        sync(ROOT / part, TREE / part)
    masters = ROOT / "design/backgrounds/masters"
    if masters.exists():
        (TREE / "design/backgrounds/masters").mkdir(parents=True, exist_ok=True)
        for f in [*masters.glob("*-2048.jpg"), *masters.glob("*-2048-6x6.astc")]:
            copy_if_changed(f, TREE / "design/backgrounds/masters" / f.name)
    app = TREE / "src/app"
    root = app / program.name
    text = (ROOT / "src/app" / program.name).read_text(encoding="utf-8")
    text = text.replace("import os;\n", f'import os;\nimport ngfx from "{rel(app, NGFX)}";\n', 1)
    write_if_changed(root, text)
    build = (ROOT / "src/app/draughts.build").read_text(encoding="utf-8")
    includes = [rel(app, ROOT / "third_party/goose_gfx/third_party/nuklear/demo/common/filebrowser"),
                rel(app, NGFX / "native")]
    build = re.sub(r"c_include\s*=\s*\[[^\]]*\];",
                   "c_include = [" + ", ".join(f'"{p}"' for p in includes) + "];", build)
    write_if_changed(app / "draughts.build", build)
    return root


def write_if_changed(path, text):
    if not path.exists() or path.read_text(encoding="utf-8") != text:
        path.write_bytes(text.encode())


def shaders():
    """The Slang modules compiled into blobs in the tree's src/app/shaders/, where stale:
    src/ngfx/shaders/ and the 3D board's, written from gfx's GLSL (ngfx_3d_shaders.py),
    side by side in build/ngfx/shaders/."""
    gen = OUT / "shaders"
    gen.mkdir(parents=True, exist_ok=True)
    for f in (ROOT / "src/ngfx/shaders").glob("*.slang"):
        copy_if_changed(f, gen / f.name)
    smaa = ROOT / "third_party/smaa"
    copy_if_changed(smaa / "SMAA.hlsl", gen / "SMAA.hlsl")
    for name, text in ngfx_3d_shaders.sources().items():
        write_if_changed(gen / name, text)
    src = sorted(gen.glob("*.slang"))
    out = TREE / "src/app/shaders"
    out.mkdir(parents=True, exist_ok=True)
    # SMAA's tables, which render3d embeds beside the blobs.
    for name in ["area", "search"]:
        copy_if_changed(smaa / f"{name}.bin", out / f"smaa_{name}.bin")
    newest = max(f.stat().st_mtime for f in [*src, gen / "SMAA.hlsl"])
    parts = ["common.slang", "ui.slang", "glsl.slang", "r3d.slang", "r3d_frame.slang"]
    stale = [f for f in src if f.name not in parts
             and (not (out / (f.stem + ".blob")).exists() or (out / (f.stem + ".blob")).stat().st_mtime < newest)]
    if not stale:
        return
    tools = OUT / "tools"
    tools.mkdir(parents=True, exist_ok=True)
    tool = tools / "ngfx_shaders.goose"
    write_if_changed(tool, (ROOT / "tools/ngfx_shaders.goose.in").read_text(encoding="utf-8")
                     .replace("@NGFX@", rel(tools, NGFX)))
    native.run(native.GOOSE, "run", tool.name, "--", out, *stale, cwd=tools)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("program", type=Path)
    ap.add_argument("--run", action="store_true", help="run it after building")
    ap.add_argument("args", nargs="*", help="the program's flags, after --")
    a = ap.parse_args()
    if not (NGFX / "ngfx.goose").exists():
        sys.exit(f"no goose-ngfx checkout at {NGFX}: set NGFX")
    if not os.environ.get("NGFX_SLANGC"):
        sys.exit("set NGFX_SLANGC to slangc 2026.18.2 or later (goose-ngfx's docs/development.md)")
    root = tree(a.program.resolve())
    shaders()
    exe = OUT / f"{root.stem}{EXE}"
    # gfx from the patched sources, as the gfx build's: the window comes from gfx opened
    # WINDOW_ONLY (patches/goose_gfx/0008), and ngfx draws into it.
    native.run(platform_build.patched_goose(), "build", "-o", exe, root.name, cwd=root.parent)
    if a.run:
        sys.exit(subprocess.run([str(exe), *a.args]).returncode)


if __name__ == "__main__":
    main()
