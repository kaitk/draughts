#!/usr/bin/env python3
"""Build a Goose program for Windows with the patched goose_gfx, and optionally run it.

    python scripts/windows.py src/app/draughts.goose              build build/windows/draughts.exe
    python scripts/windows.py src/app/draughts.goose --run -- --board 3d
                                                                  build, and run it with those flags

The release's own goose_gfx.lib lacks Draughts' changes. This builds goose_gfx's sources
from the submodule (kaitk/goose_gfx's main), as Android and iOS do, into a copy of the
release (build/windows/goose/), and builds the program with that copy's goose: its gfx
draws only when something changed (draw-on-demand), and so on. SDL is the release's own, linked
statically; patches/SDL are for Android and iOS. The app draws through Vulkan there, as on
Android (src/app/display.c).

The copy is made once; delete build/windows/goose/ after the release changes. clang-cl is
the one in Visual Studio (found with vswhere), or CLANG_CL; the release is
build/goose-v2026.4-windows-x64/, or GOOSE_RELEASE.
"""
import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

import native

RELEASE = Path(os.environ.get("GOOSE_RELEASE", native.ROOT / "build/goose-v2026.4-windows-x64"))
OUT = native.ROOT / "build/windows"
# The release's goose_gfx.lib holds these four, built against the static CRT (/MT).
GFX_SOURCES = ["gfx_device", "gfx_resources", "gfx_pipeline", "gfx_draw"]


def llvm_bin():
    """The folder with clang-cl and llvm-lib."""
    if os.environ.get("CLANG_CL"):
        return Path(os.environ["CLANG_CL"]).parent
    vswhere = Path(os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)"),
                   "Microsoft Visual Studio/Installer/vswhere.exe")
    found = subprocess.run([str(vswhere), "-latest", "-products", "*", "-find",
                            r"VC\Tools\Llvm\x64\bin\clang-cl.exe"],
                           capture_output=True, text=True).stdout.splitlines()
    if not found:
        sys.exit("no clang-cl: install Visual Studio's C++ Clang tools, or set CLANG_CL")
    return Path(found[0]).parent


def patched_goose():
    """build/windows/goose/: the release with goose_gfx.lib rebuilt from the patched sources."""
    goose = OUT / "goose"
    if not goose.exists():
        if not (RELEASE / "goose.exe").exists():
            sys.exit(f"no Goose release at {RELEASE} (docs/development.md, Run on Windows)")
        shutil.copytree(RELEASE, goose)
    src = native.copy_gfx(OUT)
    shutil.copytree(src / "gfx", goose / "pkg/gfx/src/gfx", dirs_exist_ok=True)
    llvm, objs = llvm_bin(), OUT / "obj"
    objs.mkdir(exist_ok=True)
    sdl_include = native.SDL / "include"
    for name in GFX_SOURCES:
        native.run(llvm / "clang-cl.exe", "/nologo", "/O2", "/MT", "/DNDEBUG",
                   "/D_CRT_SECURE_NO_WARNINGS", "/utf-8", "/W3", f"/I{sdl_include}", "/c",
                   src / "gfx" / f"{name}.c", f"/Fo{objs / name}.obj")
    native.run(llvm / "llvm-lib.exe", "/nologo", f"/out:{goose / 'pkg/gfx/lib/goose_gfx.lib'}",
               *[objs / f"{name}.obj" for name in GFX_SOURCES])
    return goose / "goose.exe"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("program", type=Path)
    ap.add_argument("--run", action="store_true", help="run it after building")
    ap.add_argument("args", nargs="*", help="the program's flags, after --")
    a = ap.parse_args()
    program = a.program.resolve()
    exe = OUT / f"{program.stem}.exe"
    native.run(patched_goose(), "build", "-o", exe, program.name, cwd=program.parent)
    if a.run:
        sys.exit(subprocess.run([str(exe), *a.args]).returncode)


if __name__ == "__main__":
    main()
