#!/usr/bin/env python3
"""Build Draughts holding both renderers, gfx and goose-ngfx (NoGraphicsAPI), one chosen
when it starts (task 073), and optionally run it.

    python scripts/ngfx.py src/app/draughts.goose              build build/ngfx/draughts(.exe)
    python scripts/ngfx.py src/app/draughts.goose --run -- --renderer gfx --screen game
                                                               build, and run it with those flags

The program is src/ngfx/draughts_ngfx.goose, the second root beside the gfx build's
src/app/draughts.goose: the same app (src/app/app.goose), gfx's backend and goose-ngfx's,
and src/ngfx/backend.goose, which chooses one at start. The gfx-only build is untouched.
This makes what that root needs from outside the repository, all in build/ngfx/: a link
to the goose-ngfx checkout (goose-ngfx, which the root declares its package from), the
app's version and commit for the crash marker (draughts_version.h), and the Slang shaders
compiled ahead into ngfx's blobs (blobs/), which the app embeds, so it runs no shader
compiler: the 2D shaders and the 3D board's, written from gfx's GLSL into shaders/ by
ngfx_2d_shaders.py and ngfx_3d_shaders.py, and src/ngfx/shaders/, what they include and
the shaders ngfx alone has, with SMAA's (third_party/smaa), which smaa.slang includes.

Needs a goose-ngfx checkout (NGFX, else ../goose-ngfx or ../goose/goose-ngfx beside this repository),
slangc 2026.18.2 or later (NGFX_SLANGC), and what ngfx's own build needs (its
docs/development.md: on Windows the Vulkan SDK and Visual Studio's Build Tools; on the
Mac Xcode with its Metal toolchain; on Linux the Vulkan SDK and CMake, so in the goose
distrobox on Bazzite). The program is built with the Goose release's copy whose gfx is
built from the submodule (scripts/mac.py, windows.py, linux.py), for gfx's WINDOW_ONLY:
gfx's window, input, and events, with ngfx drawing into the window, on Linux a Wayland
surface or an X11 window, whichever SDL opened.
"""
import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

import native
import ngfx_2d_shaders
import ngfx_3d_shaders

if native.WINDOWS:
    import windows as platform_build
elif sys.platform.startswith("linux"):
    import linux as platform_build
else:
    import mac as platform_build

ROOT = native.ROOT
OUT = ROOT / "build/ngfx"
ROOTFILE = ROOT / "src/ngfx/draughts_ngfx.goose"
BLOBS = OUT / "blobs"
# The checkout NGFX names, else one beside this repository (../goose-ngfx, or ../goose/goose-ngfx).
NGFX = Path(os.environ.get("NGFX") or next(
    (p for p in (ROOT.parent / "goose-ngfx", ROOT.parent / "goose/goose-ngfx") if p.exists()),
    ROOT.parent / "goose-ngfx")).resolve()
LINK = OUT / "goose-ngfx"
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


def write_if_changed(path, text):
    if not path.exists() or path.read_text(encoding="utf-8") != text:
        path.write_bytes(text.encode())


def rel(frm, to):
    return os.path.relpath(to, frm).replace("\\", "/")


def prepare():
    """build/ngfx/'s link to the checkout (a junction on Windows, which needs no rights) and
    draughts_version.h; and a check that the root's sidecar has all of the app's C."""
    OUT.mkdir(parents=True, exist_ok=True)
    if not LINK.exists() or LINK.resolve() != NGFX:
        if LINK.is_symlink() or LINK.exists():
            LINK.unlink() if LINK.is_symlink() else os.rmdir(LINK)
        if native.WINDOWS:
            import _winapi
            _winapi.CreateJunction(str(NGFX), str(LINK))
        else:
            LINK.symlink_to(NGFX, target_is_directory=True)
    commit = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout.strip()
    write_if_changed(OUT / "draughts_version.h", f'#define DRAUGHTS_VERSION "{native.VERSION_NAME} {commit}"\n')
    app = {p.name for p in native.sidecar(ROOT / "src/app/draughts.goose", "c_sources")}
    ours = {p.name for p in native.sidecar(ROOTFILE, "c_sources")}
    assert app <= ours, f"src/ngfx/draughts_ngfx.build lacks the app's {sorted(app - ours)}"


def shaders(sdk=None):
    """The Slang modules compiled into blobs in build/ngfx/blobs/, where stale:
    src/ngfx/shaders/ and those written from gfx's GLSL (ngfx_2d_shaders.py,
    ngfx_3d_shaders.py), side by side in build/ngfx/shaders/. sdk names the SDK the
    metallibs are for (NGFX_METAL_SDK, iphoneos for iOS and iPadOS), else the Mac's; the
    blobs of another SDK's are all made again."""
    gen = OUT / "shaders"
    gen.mkdir(parents=True, exist_ok=True)
    hand = {f.name: f for f in (ROOT / "src/ngfx/shaders").glob("*.slang")}
    written = {**ngfx_2d_shaders.sources(), **ngfx_3d_shaders.sources()}
    assert not hand.keys() & written.keys(), f"written and in src/ngfx/shaders/: {hand.keys() & written.keys()}"
    for f in gen.glob("*.slang"):     # a module since deleted or renamed
        if f.name not in hand and f.name not in written:
            f.unlink()
    for name, f in hand.items():
        copy_if_changed(f, gen / name)
    smaa = ROOT / "third_party/smaa"
    copy_if_changed(smaa / "SMAA.hlsl", gen / "SMAA.hlsl")
    for name, text in written.items():
        write_if_changed(gen / name, text)
    src = sorted(gen.glob("*.slang"))
    out = BLOBS
    out.mkdir(parents=True, exist_ok=True)
    made_for = out / "sdk.txt"
    if not made_for.exists() or made_for.read_text() != (sdk or ""):
        for f in out.glob("*.blob"):
            f.unlink()
        made_for.write_text(sdk or "")
    newest = max(f.stat().st_mtime for f in [*src, gen / "SMAA.hlsl"])
    parts = ["common.slang", "glsl.slang", "r3d.slang", "r3d_frame.slang"]
    stale = [f for f in src if f.name not in parts
             and (not (out / (f.stem + ".blob")).exists() or (out / (f.stem + ".blob")).stat().st_mtime < newest)]
    if not stale:
        return
    tools = OUT / "tools"
    tools.mkdir(parents=True, exist_ok=True)
    tool = tools / "ngfx_shaders.goose"
    write_if_changed(tool, (ROOT / "tools/ngfx_shaders.goose.in").read_text(encoding="utf-8")
                     .replace("@NGFX@", rel(tools, NGFX)))
    env = {"NGFX_METAL_SDK": sdk} if sdk else None
    if sys.platform.startswith("linux"):    # TinyCC can't run under SELinux (Fedora's, Bazzite's)
        native.run(native.GOOSE, "build", "-o", tools / "ngfx_shaders", tool.name, cwd=tools)
        native.run(tools / "ngfx_shaders", out, *stale, env=env)
    else:
        native.run(native.GOOSE, "run", tool.name, "--", out, *stale, cwd=tools, env=env)


def check_setup():
    if not (NGFX / "ngfx.goose").exists():
        sys.exit(f"no goose-ngfx checkout at {NGFX}: clone it beside this repository or set NGFX")
    if not os.environ.get("NGFX_SLANGC"):
        sys.exit("set NGFX_SLANGC to slangc 2026.18.2 or later (goose-ngfx's docs/development.md)")


def ios_root():
    """The root for iOS and iPadOS (scripts/ios.py --ngfx), its blobs' metallibs compiled
    for iphoneos, as a Mac's don't load there (the next Mac build compiles them again)."""
    check_setup()
    prepare()
    shaders("iphoneos")
    return ROOTFILE


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("program", type=Path, help="the gfx build's root, src/app/draughts.goose")
    ap.add_argument("--run", action="store_true", help="run it after building")
    ap.add_argument("args", nargs="*", help="the program's flags, after --")
    a = ap.parse_args()
    check_setup()
    if a.program.resolve() != ROOT / "src/app/draughts.goose":
        sys.exit(f"{a.program}: only src/app/draughts.goose has a twin holding both renderers")
    prepare()
    shaders()
    exe = OUT / f"draughts{EXE}"
    # gfx from the patched sources, as the gfx build's: the window comes from gfx opened
    # WINDOW_ONLY (kaitk/goose_gfx's window-only), and ngfx draws into it.
    native.run(platform_build.patched_goose(), "build", "-o", exe, ROOTFILE.name, cwd=ROOTFILE.parent)
    if a.run:
        sys.exit(subprocess.run([str(exe), *a.args]).returncode)


if __name__ == "__main__":
    main()
