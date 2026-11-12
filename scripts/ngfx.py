#!/usr/bin/env python3
"""Build Draughts holding both renderers, gfx and goose-ngfx (NoGraphicsAPI), one chosen
when it starts (task 073), and optionally run it.

    python scripts/ngfx.py src/app/draughts.goose              build build/ngfx/draughts(.exe)
    python scripts/ngfx.py src/app/draughts.goose --run -- --renderer gfx --screen game
                                                               build, and run it with those flags

The gfx-only build (Android's) is untouched. This copies the program (src/, strings/,
assets/, the backgrounds' JPEG and ASTC masters, and SMAA's tables) into build/ngfx/tree/
and lays src/ngfx/ over it. Each recorder twin then has three parts: gfx's, compiled under
a name of its own (GFX_RECORDERS: src/app/draw_gpu.goose as draw_gfx, and so on, its
namespace line rewritten), goose-ngfx's (src/ngfx/app/draw_ngfx.goose, ...), and in the
gfx recorder's place a facade of the same name that calls one or the other as
nx::ngfx_on says (src/ngfx/app/draw_gpu.goose, ...; render3d_gpu.goose and photo_gpu.h
alike). The drawers are shared and hold gfx's handle types; nx gives goose-ngfx's calls
those types. The root file gets the package's import and the halves', the sidecar the
package's C headers, and the Slang shaders are compiled ahead into ngfx's blobs, which the
app embeds, so it runs no shader compiler: the 2D shaders and the 3D board's, written from
gfx's GLSL by ngfx_2d_shaders.py and ngfx_3d_shaders.py, and src/ngfx/shaders/, what they
include and the shaders ngfx alone has. SMAA (third_party/smaa) comes with them: its
shader, which smaa.slang includes, and its tables, which render3d embeds.

Needs a goose-ngfx checkout (NGFX, else ../goose/goose-ngfx beside this repository),
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
import re
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
    the same path, that one instead, and over/'s files with none in src/ too. src/ngfx/
    itself is left out."""
    for f in src.rglob("*"):
        r = f.relative_to(src)
        if f.is_dir() or r.parts[0] == "ngfx":
            continue
        o = over / r if over else None
        (dst / r).parent.mkdir(parents=True, exist_ok=True)
        copy_if_changed(o if o and o.exists() else f, dst / r)
    for o in over.rglob("*") if over else []:
        r = o.relative_to(over)
        if o.is_file() and not (src / r).exists():
            (dst / r).parent.mkdir(parents=True, exist_ok=True)
            copy_if_changed(o, dst / r)


# gfx's recorders, compiled again beside goose-ngfx's under a name of their own, as the
# overlay's recorders of the same name are facades that call one or the other: each file,
# its copy's name, and its namespace's line before and after. A recorder never names its
# own namespace, so the copy is the same code.
GFX_RECORDERS = [
    ("app/gpu.goose", "app/gpu_gfx.goose", "namespace gpu;", "namespace gpu_gfx;"),
    ("app/host_gpu.goose", "app/host_gfx.goose", "namespace host_gpu;", "namespace host_gfx;"),
    ("app/scene_gpu.goose", "app/scene_gfx.goose", "namespace scene_gpu;", "namespace scene_gfx;"),
    ("app/draw_gpu.goose", "app/draw_gfx.goose", "namespace draw_gpu;", "namespace draw_gfx;"),
    ("app/widgets_gpu.goose", "app/widgets_gfx.goose", "namespace widgets_gpu;", "namespace widgets_gfx;"),
    ("render3d/render3d_gpu.goose", "render3d/render3d_gfx.goose", "namespace render3d;", "namespace render3d_gfx;"),
    ("app/photo_gpu.h", "app/photo_gfx.h", None, None),
]
# The app's recorders' two halves, which the root file imports as it does every app file.
HALVES = ["gpu_gfx", "gpu_ngfx", "host_gfx", "host_ngfx", "scene_gfx", "scene_ngfx", "draw_gfx", "draw_ngfx",
          "widgets_gfx", "widgets_ngfx"]


def gfx_recorders(tree):
    for src, dst, before, after in GFX_RECORDERS:
        text = (ROOT / "src" / src).read_text(encoding="utf-8")
        if before:
            assert text.count(before) == 1, f"{src}: not one '{before}'"
            text = text.replace(before, after)
        write_if_changed(tree / "src" / dst, text)


def rel(frm, to):
    return os.path.relpath(to, frm).replace("\\", "/")


def tree(program, tree=TREE):
    """build/ngfx/tree/ (or another): the program with src/ngfx/ laid over it; the root
    file's path."""
    sync(ROOT / "src", tree / "src", ROOT / "src/ngfx")
    gfx_recorders(tree)
    for part in ["strings", "assets"]:
        sync(ROOT / part, tree / part)
    # SMAA's tables, which gfx's 3D recorder embeds from there.
    (tree / "third_party/smaa").mkdir(parents=True, exist_ok=True)
    for name in ["area.bin", "search.bin"]:
        copy_if_changed(ROOT / "third_party/smaa" / name, tree / "third_party/smaa" / name)
    masters = ROOT / "design/backgrounds/masters"
    if masters.exists():
        (tree / "design/backgrounds/masters").mkdir(parents=True, exist_ok=True)
        for f in [*masters.glob("*-2048.jpg"), *masters.glob("*-2048-6x6.astc")]:
            copy_if_changed(f, tree / "design/backgrounds/masters" / f.name)
    app = tree / "src/app"
    root = app / program.name
    text = (ROOT / "src/app" / program.name).read_text(encoding="utf-8")
    text = text.replace("import os;\n", f'import os;\nimport ngfx from "{rel(app, NGFX)}";\n', 1)
    # Before the facades, whose globals may take the halves' (draw_gpu's shader blocks).
    text = text.replace("import .draw_gpu;\n", "".join(f"import .{h};\n" for h in HALVES) + "import .draw_gpu;\n", 1)
    write_if_changed(root, text)
    build = (ROOT / "src/app/draughts.build").read_text(encoding="utf-8")
    includes = [rel(app, ROOT / "third_party/goose_gfx/third_party/nuklear/demo/common/filebrowser"),
                rel(app, NGFX / "native"), rel(app, ROOT / "third_party/goose_gfx/src/gfx"),
                rel(app, ROOT / "third_party/goose_gfx/third_party/SDL/src/video/khronos")]
    build = re.sub(r"c_include\s*=\s*\[[^\]]*\];",
                   "c_include = [" + ", ".join(f'"{p}"' for p in includes) + "];", build)
    # renderer.c, the check before a window and the window shown (src/ngfx/app/), with the
    # app's version and commit, which key the crash marker.
    build = build.replace('c_sources = ["', 'c_sources = ["renderer.c", "', 1)
    commit = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout.strip()
    renderer = (ROOT / "src/ngfx/app/renderer.c").read_text(encoding="utf-8")
    write_if_changed(app / "renderer.c", renderer.replace("@VERSION@", f"{native.VERSION_NAME} {commit}"))
    write_if_changed(app / "draughts.build", build)
    return root


def write_if_changed(path, text):
    if not path.exists() or path.read_text(encoding="utf-8") != text:
        path.write_bytes(text.encode())


def shaders(tree=TREE, sdk=None):
    """The Slang modules compiled into blobs in the tree's src/app/shaders/, where stale:
    src/ngfx/shaders/ and those written from gfx's GLSL (ngfx_2d_shaders.py,
    ngfx_3d_shaders.py), side by side in build/ngfx/shaders/. sdk names the SDK the
    metallibs are for (NGFX_METAL_SDK, iphoneos for iOS and iPadOS), else the Mac's."""
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
    out = tree / "src/app/shaders"
    out.mkdir(parents=True, exist_ok=True)
    # SMAA's tables, which render3d embeds beside the blobs.
    for name in ["area", "search"]:
        copy_if_changed(smaa / f"{name}.bin", out / f"smaa_{name}.bin")
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
        sys.exit(f"no goose-ngfx checkout at {NGFX}: set NGFX")
    if not os.environ.get("NGFX_SLANGC"):
        sys.exit("set NGFX_SLANGC to slangc 2026.18.2 or later (goose-ngfx's docs/development.md)")


def ios_tree(program):
    """The tree for iOS and iPadOS (scripts/ios.py --ngfx): build/ngfx/ios/tree/, its
    blobs' metallibs compiled for iphoneos, as a Mac's don't load there. Its root file."""
    check_setup()
    tree_dir = OUT / "ios/tree"
    root = tree(program.resolve(), tree_dir)
    shaders(tree_dir, "iphoneos")
    return root


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("program", type=Path)
    ap.add_argument("--run", action="store_true", help="run it after building")
    ap.add_argument("args", nargs="*", help="the program's flags, after --")
    a = ap.parse_args()
    check_setup()
    root = tree(a.program.resolve())
    shaders()
    exe = OUT / f"{root.stem}{EXE}"
    # gfx from the patched sources, as the gfx build's: the window comes from gfx opened
    # WINDOW_ONLY (kaitk/goose_gfx's window-only), and ngfx draws into it.
    native.run(platform_build.patched_goose(), "build", "-o", exe, root.name, cwd=root.parent)
    if a.run:
        sys.exit(subprocess.run([str(exe), *a.args]).returncode)


if __name__ == "__main__":
    main()
