#!/usr/bin/env python3
"""Build a Goose program for Linux (x64) with the patched goose_gfx, and optionally run it.

    scripts/linux.py src/app/draughts.goose               build build/linux/draughts
    scripts/linux.py src/app/draughts.goose --run -- --board 3d
                                                          build, and run it with those flags
    scripts/linux.py src/app/draughts.goose --release     build/linux/release/
                                                          Draughts-VERSION-linux-x64.tar.gz

As scripts/windows.py does on Windows: goose_gfx's sources from the submodule
(kaitk/goose_gfx's main) are built into a copy of the Goose release (build/linux/goose/),
whose goose then builds the program. SDL is the release's own libSDL3.a, linked
statically; it opens X11 or Wayland and Vulkan's loader at run time. The C library and
libm are the system's, so the executable runs on a glibc as new as the one it was built
against, or newer: build a release on the oldest system it should run on.

A release (docs/development.md, "Desktop releases") is a folder, Draughts/, holding the
executable, a .desktop file, and the icon, tarred. It is not signed.

The copy is made once; delete build/linux/goose/ after the release changes. The compiler
is cc, or CC; the release is build/goose-v2026.4-linux-x64/, or GOOSE_RELEASE.
"""
import argparse
import os
import shutil
import subprocess
import sys
import tarfile
from pathlib import Path

import native

RELEASE = Path(os.environ.get("GOOSE_RELEASE", native.ROOT / "build/goose-v2026.4-linux-x64"))
OUT = native.ROOT / "build/linux"
# The release's libgoose_gfx.a holds these four.
GFX_SOURCES = ["gfx_device", "gfx_resources", "gfx_pipeline", "gfx_draw"]
ICON = native.ROOT / "ios/icon-1024.png"


def patched_goose():
    """build/linux/goose/: the release with libgoose_gfx.a rebuilt from the patched sources."""
    goose = OUT / "goose"
    if not goose.exists():
        if not (RELEASE / "goose").exists():
            sys.exit(f"no Goose release at {RELEASE} (docs/development.md, Run on Linux)")
        shutil.copytree(RELEASE, goose, symlinks=True)
    src = native.copy_gfx(OUT)
    shutil.copytree(src / "gfx", goose / "pkg/gfx/src/gfx", dirs_exist_ok=True)
    cc, objs = os.environ.get("CC", "cc"), OUT / "obj"
    objs.mkdir(exist_ok=True)
    for name in GFX_SOURCES:
        native.run(cc, "-O2", "-DNDEBUG", "-fPIC", "-Wall", "-Wno-missing-field-initializers",
                   f"-I{native.SDL / 'include'}", "-c", src / "gfx" / f"{name}.c",
                   "-o", objs / f"{name}.o")
    lib = goose / "pkg/gfx/lib/libgoose_gfx.a"
    lib.unlink(missing_ok=True)
    native.run("ar", "rcs", lib, *[objs / f"{name}.o" for name in GFX_SOURCES])
    return goose / "goose"


DESKTOP = """[Desktop Entry]
Type=Application
Name=Draughts
Exec=draughts
Icon=draughts
Categories=Game;BoardGame;
"""


def release(exe):
    """build/linux/release/Draughts-VERSION-linux-x64.tar.gz: Draughts/ with the executable,
    the .desktop file, and the icon."""
    out = OUT / "release"
    folder = out / "Draughts"
    if folder.exists():
        shutil.rmtree(folder)
    folder.mkdir(parents=True)
    shutil.copy2(exe, folder / "draughts")
    native.run("strip", folder / "draughts")
    (folder / "draughts.desktop").write_text(DESKTOP)
    shutil.copy2(ICON, folder / "draughts.png")
    tarred = out / f"Draughts-{native.VERSION_NAME}-linux-x64.tar.gz"
    def owned(info):    # root's, 755 or 644, whatever the folder's own say (a Windows mount's 777)
        info.uid = info.gid = 0
        info.uname = info.gname = "root"
        info.mode = 0o755 if info.isdir() or info.name.endswith("/draughts") else 0o644
        return info

    with tarfile.open(tarred, "w:gz") as t:
        t.add(folder, "Draughts", filter=owned)
    print(tarred)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("program", type=Path)
    ap.add_argument("--run", action="store_true", help="run it after building")
    ap.add_argument("--release", action="store_true", help="Draughts/, tarred for a GitHub release")
    ap.add_argument("args", nargs="*", help="the program's flags, after --")
    a = ap.parse_args()
    program = a.program.resolve()
    exe = OUT / program.stem
    # Goose takes a compiler by path, or by the names clang, gcc, and cc only.
    cc = {"GOOSE_CC": shutil.which(os.environ["CC"])} if os.environ.get("CC") else None
    native.run(patched_goose(), "build", "-o", exe, program.name, cwd=program.parent, env=cc)
    if a.release:
        release(exe)
        return
    if a.run:
        sys.exit(subprocess.run([str(exe), *a.args]).returncode)


if __name__ == "__main__":
    main()
