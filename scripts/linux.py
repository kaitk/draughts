#!/usr/bin/env python3
"""Build a Goose program for Linux (x64) with the patched goose_gfx, and optionally run it.

    scripts/linux.py src/app/draughts.goose               build build/linux/draughts
    scripts/linux.py src/app/draughts.goose --run -- --board 3d
                                                          build, and run it with those flags
    scripts/linux.py src/app/draughts.goose --release     build/linux/release/
                                                          Draughts-VERSION-linux-x64.tar.gz

As scripts/windows.py does on Windows: goose_gfx's sources from the submodule
(kaitk/goose_gfx's main) are built into a copy of the Goose release (build/linux/goose/),
whose goose then builds the program. SDL is built here, statically, from the submodule
with patches/SDL applied, in place of the release's libSDL3.a, which has no Wayland: it
opens Wayland, or X11 where there is none, and Vulkan's loader, all at run time. The C
library and libm are the system's, so the executable runs on a glibc as new as the one it
was built against, or newer: build a release on the oldest system it should run on.

Building SDL takes CMake and the Wayland and X11 development headers, which the
draughts-jammy distrobox has (docs/development.md, "Desktop releases") and an immutable
host such as Bazzite doesn't: run this once in the box, and the host's builds then link
the SDL it made, until SDL's commit or a patch changes.

A release (docs/development.md, "Desktop releases") is a folder, Draughts/, holding the
executable, a .desktop file, the icon, and install.sh, which puts the three in ~/.local
for the desktop's menu, tarred. It is not signed.

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
# The Goose release's own SDL options (its pkg/gfx/CMakeLists.txt), with Wayland and X11
# both required. SDL loads every library it uses at run time, the X11 and Wayland ones too.
SDL_OPTIONS = ["-DSDL_SHARED=OFF", "-DSDL_STATIC=ON", "-DSDL_TEST_LIBRARY=OFF", "-DSDL_CAMERA=OFF",
               "-DSDL_RENDER=OFF", "-DSDL_OPENGL=OFF", "-DSDL_OPENGLES=OFF", "-DSDL_KMSDRM=OFF",
               "-DSDL_WAYLAND=ON", "-DSDL_X11=ON"]
APP_ID = "io.github.kaitk.draughts"    # SDL's app id too (src/app/display.c)
ICON = native.ROOT / f"linux/{APP_ID}.png"    # windows/draughts.ico's 256 px


def sdl():
    """build/linux/SDL/libSDL3.a, made again when SDL's commit or a patch changes."""
    out = OUT / "SDL"
    lib, stamp_file, stamp = out / "libSDL3.a", out / ".draughts-stamp", native.sdl_stamp()
    if lib.exists() and stamp_file.exists() and stamp_file.read_text() == stamp:
        return lib
    if not shutil.which("cmake"):
        sys.exit("SDL needs building, with CMake and the Wayland and X11 headers: run this once "
                 "in the draughts-jammy distrobox (docs/development.md, \"Run on Linux\")")
    src, build = native.copy_sdl(OUT / "SDL_src"), out / "build"
    if build.exists():
        shutil.rmtree(build)
    generator = ["-G", "Ninja"] if shutil.which("ninja") else []
    native.run("cmake", "-S", src, "-B", build, *generator, "-DCMAKE_BUILD_TYPE=Release", *SDL_OPTIONS)
    # SDL's configure leaves out a video driver whose headers are missing, without failing.
    config = next(build.glob("include-config-*/build_config/SDL_build_config.h")).read_text()
    for driver in ["WAYLAND", "X11"]:
        if f"#define SDL_VIDEO_DRIVER_{driver} 1" not in config:
            sys.exit(f"SDL's configure found no {driver.title()} headers (docs/development.md)")
    native.run("cmake", "--build", build)
    shutil.copy2(build / "libSDL3.a", lib)
    stamp_file.write_text(stamp)
    return lib


def patched_goose():
    """build/linux/goose/: the release with libgoose_gfx.a rebuilt from the patched sources,
    and SDL built here (sdl())."""
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
    shutil.copy2(sdl(), goose / "pkg/gfx/lib/libSDL3.a")
    return goose / "goose"


DESKTOP = f"""[Desktop Entry]
Type=Application
Name=Draughts
Exec=draughts
Icon={APP_ID}
StartupWMClass={APP_ID}
Categories=Game;BoardGame;
"""

# The executable to ~/.local/bin, and the .desktop file, its Exec made the full path, and
# the icon where the desktop's menu finds them; run again to update, or with --remove.
INSTALL = f"""#!/bin/sh
set -e
cd "$(dirname "$0")"
data="${{XDG_DATA_HOME:-$HOME/.local/share}}"
bin="$HOME/.local/bin/draughts"
app="$data/applications/{APP_ID}.desktop"
icon="$data/icons/hicolor/256x256/apps/{APP_ID}.png"
if [ "$1" = --remove ]; then
    rm -f "$bin" "$app" "$icon"
    echo "Removed Draughts. Its settings and saved game stay in $data/kaitk/draughts/."
    exit 0
fi
mkdir -p "$(dirname "$bin")" "$(dirname "$app")" "$(dirname "$icon")"
cp draughts "$bin"
sed "s|^Exec=.*|Exec=$bin|" {APP_ID}.desktop > "$app"
cp {APP_ID}.png "$icon"
echo "Installed Draughts in $bin, with the menu's entry and icon."
"""


def release(exe):
    """build/linux/release/Draughts-VERSION-linux-x64.tar.gz: Draughts/ with the executable,
    the .desktop file, the icon, and install.sh."""
    out = OUT / "release"
    folder = out / "Draughts"
    if folder.exists():
        shutil.rmtree(folder)
    folder.mkdir(parents=True)
    shutil.copy2(exe, folder / "draughts")
    native.run("strip", folder / "draughts")
    (folder / f"{APP_ID}.desktop").write_text(DESKTOP)
    shutil.copy2(ICON, folder / ICON.name)
    (folder / "install.sh").write_text(INSTALL)
    tarred = out / f"Draughts-{native.VERSION_NAME}-linux-x64.tar.gz"
    def owned(info):    # root's, 755 or 644, whatever the folder's own say (a Windows mount's 777)
        info.uid = info.gid = 0
        info.uname = info.gname = "root"
        info.mode = 0o755 if info.isdir() or info.name.endswith(("/draughts", ".sh")) else 0o644
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
