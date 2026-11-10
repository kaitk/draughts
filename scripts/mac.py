#!/usr/bin/env python3
"""Build a Goose program for the Mac with the patched goose_gfx, and optionally run it.

    scripts/mac.py src/app/draughts.goose                     build build/draughts
    scripts/mac.py src/app/draughts.goose --run -- --board 3d build, and run it with those flags

The release's own libgoose_gfx.a is unpatched: it presents every frame, so the app at rest
spins at the display's rate. This builds goose_gfx's sources with patches/goose_gfx
applied, as Android, iOS, and Windows (scripts/windows.py) do, into a copy of the release
(build/mac/goose/), and builds the program with that copy's goose: its gfx presents only
what was drawn and then waits for an event (0002), and samples ASTC where the GPU takes it
(0004). SDL is the release's own libSDL3.a, which is goose_gfx's SDL submodule's commit.

The copy is made once; delete build/mac/goose/ after the release changes. The release is
build/goose-v2026.4-macos-arm64/, or GOOSE_RELEASE.
"""
import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

import native

RELEASE = Path(os.environ.get("GOOSE_RELEASE", native.ROOT / "build/goose-v2026.4-macos-arm64"))
OUT = native.ROOT / "build/mac"
# The release's libgoose_gfx.a holds these four.
GFX_SOURCES = ["gfx_device", "gfx_resources", "gfx_pipeline", "gfx_draw"]


def patched_goose():
    """build/mac/goose/: the release with libgoose_gfx.a rebuilt from the patched sources."""
    goose = OUT / "goose"
    if not goose.exists():
        if not (RELEASE / "goose").exists():
            sys.exit(f"no Goose release at {RELEASE} (docs/development.md, Toolchain)")
        shutil.copytree(RELEASE, goose, symlinks=True)
    src = native.copy_gfx(OUT)
    shutil.copytree(src / "gfx", goose / "pkg/gfx/src/gfx", dirs_exist_ok=True)
    objs = OUT / "obj"
    objs.mkdir(exist_ok=True)
    for name in GFX_SOURCES:
        native.run("clang", "-c", "-O2", "-DNDEBUG", "-I", native.SDL / "include",
                   src / "gfx" / f"{name}.c", "-o", objs / f"{name}.o")
    lib = goose / "pkg/gfx/lib/libgoose_gfx.a"
    lib.unlink(missing_ok=True)
    native.run("ar", "rcs", lib, *[objs / f"{name}.o" for name in GFX_SOURCES])
    return goose / "goose"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("program", type=Path)
    ap.add_argument("-o", type=Path, help="the executable (build/<program> by default)")
    ap.add_argument("--run", action="store_true", help="run it after building")
    ap.add_argument("args", nargs="*", help="the program's flags, after --")
    a = ap.parse_args()
    program = a.program.resolve()
    exe = (a.o or native.ROOT / "build" / program.stem).resolve()
    native.run(patched_goose(), "build", "-o", exe, program.name, cwd=program.parent)
    if a.run:
        sys.exit(subprocess.run([str(exe), *a.args]).returncode)


if __name__ == "__main__":
    main()
