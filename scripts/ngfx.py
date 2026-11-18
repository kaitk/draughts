"""What a build of src/main/draughts_ngfx.goose needs from outside the repository, made in
build/ngfx/ before the build (task 073). scripts/mac.py, windows.py, linux.py, and ios.py
call prepare() with the program they are given, which does nothing for any other
program.

The root holds both renderers, gfx and goose-ngfx (NoGraphicsAPI), one chosen when it
starts (src/ngfx/backend.goose). It needs a link to the goose-ngfx checkout
(build/ngfx/goose-ngfx, which the root declares its package from), and the Slang shaders
compiled ahead into ngfx's blobs (build/ngfx/blobs/), which the app embeds, so it runs no
shader compiler: the 2D shaders and the 3D board's, written from gfx's GLSL into
build/ngfx/shaders/ by ngfx_2d_shaders.py and ngfx_3d_shaders.py, and src/ngfx/shaders/,
what they include and the shaders ngfx alone has, with SMAA's (third_party/smaa), which
smaa.slang includes.

Needs a goose-ngfx checkout (NGFX, else ../goose-ngfx or ../goose/goose-ngfx beside this
repository), slangc 2026.18.2 or later (NGFX_SLANGC), and what ngfx's own build needs
(its docs/development.md: on Windows the Vulkan SDK and Visual Studio's Build Tools; on
the Mac Xcode with its Metal toolchain; on Linux the Vulkan SDK and CMake). The desktop
scripts build it with their patched gfx, for gfx's WINDOW_ONLY: gfx's window, input, and
events, with ngfx drawing into the window, on Linux a Wayland surface or an X11 window,
whichever SDL opened. Android has no ngfx build.
"""
import os
import shutil
import sys
from pathlib import Path

import native
import ngfx_2d_shaders
import ngfx_3d_shaders

ROOT = native.ROOT
OUT = ROOT / "build/ngfx"
ROOTFILE = ROOT / "src/main/draughts_ngfx.goose"
BLOBS = OUT / "blobs"
# The checkout NGFX names, else one beside this repository (../goose-ngfx, or ../goose/goose-ngfx).
NGFX = Path(os.environ.get("NGFX") or next(
    (p for p in (ROOT.parent / "goose-ngfx", ROOT.parent / "goose/goose-ngfx") if p.exists()),
    ROOT.parent / "goose-ngfx")).resolve()
LINK = OUT / "goose-ngfx"


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


def make_link():
    """build/ngfx/'s link to the checkout (a junction on Windows, which needs no rights), and
    a check that the root's sidecar has all of the app's C."""
    OUT.mkdir(parents=True, exist_ok=True)
    if not LINK.exists() or LINK.resolve() != NGFX:
        if LINK.is_symlink() or LINK.exists():
            LINK.unlink() if LINK.is_symlink() else os.rmdir(LINK)
        if native.WINDOWS:
            import _winapi
            _winapi.CreateJunction(str(NGFX), str(LINK))
        else:
            LINK.symlink_to(NGFX, target_is_directory=True)
    app = {p.name for p in native.sidecar(ROOT / "src/main/draughts.goose", "c_sources")}
    ours = {p.name for p in native.sidecar(ROOTFILE, "c_sources")}
    assert app <= ours, f"src/main/draughts_ngfx.build lacks the app's {sorted(app - ours)}"


def write_sources():
    """build/ngfx/shaders/: src/ngfx/shaders/, those written from gfx's GLSL
    (ngfx_2d_shaders.py, ngfx_3d_shaders.py), and SMAA's. Returns the Slang files, and the
    ones of them that are modules, each compiled into a blob, not parts others include."""
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
    copy_if_changed(ROOT / "third_party/smaa/SMAA.hlsl", gen / "SMAA.hlsl")
    for name, text in written.items():
        write_if_changed(gen / name, text)
    src = sorted(gen.glob("*.slang"))
    parts = ["common.slang", "glsl.slang", "r3d.slang", "r3d_frame.slang"]
    return src, [f for f in src if f.name not in parts]


def shaders(sdk=None):
    """The blobs in build/ngfx/blobs/, compiled where stale. sdk names the SDK the
    metallibs are for (NGFX_METAL_SDK, iphoneos for iOS and iPadOS), else the Mac's; the
    blobs of another SDK's are all made again."""
    src, modules = write_sources()
    out = BLOBS
    out.mkdir(parents=True, exist_ok=True)
    made_for = out / "sdk.txt"
    if not made_for.exists() or made_for.read_text() != (sdk or ""):
        for f in out.glob("*.blob"):
            f.unlink()
        made_for.write_text(sdk or "")
    newest = max(f.stat().st_mtime for f in [*src, OUT / "shaders/SMAA.hlsl"])
    stale = [f for f in modules
             if not (out / (f.stem + ".blob")).exists() or (out / (f.stem + ".blob")).stat().st_mtime < newest]
    if not stale:
        return
    tools = OUT / "tools"
    tools.mkdir(parents=True, exist_ok=True)
    tool = tools / "ngfx_shaders.goose"
    write_if_changed(tool, (ROOT / "scripts/ngfx_shaders.goose.in").read_text(encoding="utf-8")
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


def uses_ngfx(program):
    """Whether the program declares goose-ngfx from build/ngfx/, as draughts_ngfx.goose does."""
    return "build/ngfx/goose-ngfx" in Path(program).read_text(encoding="utf-8")


def prepare(program, sdk=None):
    """build/ngfx/ for the program if it uses goose-ngfx: the link, the version header, and
    the blobs, their metallibs for sdk (iphoneos for iOS and iPadOS) or the Mac. Returns
    whether it does."""
    if not uses_ngfx(program):
        return False
    check_setup()
    make_link()
    native.write_version()
    shaders(sdk)
    return True

