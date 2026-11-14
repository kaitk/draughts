#!/usr/bin/env python3
"""Build a Goose program for Windows with the patched goose_gfx, and optionally run it.

    python scripts/windows.py src/app/draughts.goose              build build/windows/draughts.exe
    python scripts/windows.py src/app/draughts.goose --run -- --board 3d
                                                                  build, and run it with those flags
    python scripts/windows.py src/app/draughts.goose --release    build/windows/release/
                                                                  Draughts-VERSION-windows-x64.zip

Every build puts windows/draughts.ico into the executable's resources afterwards
(embed_icon), as a .rc file linked in would, which Goose's build has no key for: Explorer
shows it, and SDL takes the first icon for the window and the taskbar.

A release (docs/development.md, "Desktop releases") is the executable alone, as
Draughts.exe, zipped: SDL and the C runtime are linked in, and Vulkan's loader is the
system's. It is not signed.

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
import struct
import sys
import zipfile
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


ICON = native.ROOT / "windows/draughts.ico"   # the iOS icon in a rounded square, 16 to 256 px


def embed_icon(exe, ico=ICON):
    """The .ico's images as the exe's RT_ICON resources 1..n and RT_GROUP_ICON 1 naming
    them, through the system's resource update calls."""
    import ctypes
    from ctypes import wintypes
    data = ico.read_bytes()
    _, kind, count = struct.unpack_from("<HHH", data, 0)
    if kind != 1:
        sys.exit(f"{ico}: not an icon")
    k32 = ctypes.WinDLL("kernel32", use_last_error=True)
    k32.BeginUpdateResourceW.restype = wintypes.HANDLE
    k32.BeginUpdateResourceW.argtypes = [wintypes.LPCWSTR, wintypes.BOOL]
    k32.UpdateResourceW.restype = wintypes.BOOL
    k32.UpdateResourceW.argtypes = [wintypes.HANDLE, ctypes.c_void_p, ctypes.c_void_p, wintypes.WORD,
                                    ctypes.c_void_p, wintypes.DWORD]
    k32.EndUpdateResourceW.restype = wintypes.BOOL
    k32.EndUpdateResourceW.argtypes = [wintypes.HANDLE, wintypes.BOOL]

    def update(h, kind, name, blob):
        buf = ctypes.create_string_buffer(blob, len(blob))
        if not k32.UpdateResourceW(h, kind, name, LANG, buf, len(blob)):
            raise ctypes.WinError(ctypes.get_last_error())

    RT_ICON, RT_GROUP_ICON, LANG = 3, 14, 0x0409
    h = k32.BeginUpdateResourceW(str(exe), False)
    if not h:
        raise ctypes.WinError(ctypes.get_last_error())
    group = struct.pack("<HHH", 0, 1, count)
    for i in range(count):
        w, ht, colors, _, planes, bits, size, offset = struct.unpack_from("<BBBBHHII", data, 6 + 16 * i)
        update(h, RT_ICON, i + 1, data[offset:offset + size])
        group += struct.pack("<BBBBHHIH", w, ht, colors, 0, planes, bits, size, i + 1)
    update(h, RT_GROUP_ICON, 1, group)
    if not k32.EndUpdateResourceW(h, False):
        raise ctypes.WinError(ctypes.get_last_error())


def gui_subsystem(exe):
    """Mark the exe a GUI program (IMAGE_SUBSYSTEM_WINDOWS_GUI), so that started from
    Explorer it opens no console window; Goose's build links a console one and has no key
    for this. The entry point stays main; its prints then go nowhere unless redirected, so
    only the release gets it."""
    data = bytearray(exe.read_bytes())
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    if data[pe:pe + 4] != b"PE\0\0":
        sys.exit(f"{exe}: not a PE file")
    at = pe + 24 + 68  # Subsystem, in the optional header after the COFF header
    if struct.unpack_from("<H", data, at)[0] not in (2, 3):
        sys.exit(f"{exe}: unexpected subsystem")
    struct.pack_into("<H", data, at, 2)
    exe.write_bytes(data)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("program", type=Path)
    ap.add_argument("--run", action="store_true", help="run it after building")
    ap.add_argument("--release", action="store_true", help="Draughts.exe, zipped for a GitHub release")
    ap.add_argument("args", nargs="*", help="the program's flags, after --")
    a = ap.parse_args()
    program = a.program.resolve()
    exe = OUT / f"{program.stem}.exe"
    native.run(patched_goose(), "build", "-o", exe, program.name, cwd=program.parent)
    embed_icon(exe)
    if a.release:
        gui_subsystem(exe)
        out = OUT / "release"
        out.mkdir(parents=True, exist_ok=True)
        zipped = out / f"Draughts-{native.VERSION_NAME}-windows-x64.zip"
        with zipfile.ZipFile(zipped, "w", zipfile.ZIP_DEFLATED) as z:
            z.write(exe, "Draughts.exe")
        print(zipped)
        return
    if a.run:
        sys.exit(subprocess.run([str(exe), *a.args]).returncode)


if __name__ == "__main__":
    main()
