"""What scripts/android.py and scripts/ios.py share: the paths and the app's id and
version, the steps from a Goose program to C, the patched copies of goose_gfx and SDL,
and the launcher's name per language. Not run by itself.
"""
import hashlib
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GOOSE = Path(os.environ.get("GOOSE", ROOT / "build/goose-v2026.4-macos-arm64/goose"))
SDL = ROOT / "third_party/goose_gfx/third_party/SDL"
# The application id on Android and the bundle id on iOS (2026-11-08): Play fixes it for
# good at the first upload. Another program (a prototype in poc/) gets APP_ID.<name>, so
# it installs beside the app.
APP_ID = "io.github.kaitk.draughts"
# The version people see: Android's versionName and iOS's CFBundleShortVersionString.
# Each platform's build number is its own script's (VERSION_CODE, BUILD_NUMBER).
VERSION_NAME = "0.1.0"


def run(*cmd, cwd=None, env=None, capture=False, check=True):
    """Runs a command, echoed; its output when capture, else the completed process."""
    print("+", " ".join(str(c) for c in cmd), flush=True)
    r = subprocess.run([str(c) for c in cmd], cwd=cwd, check=check, text=True,
                       capture_output=capture,
                       env=None if env is None else dict(os.environ, **env))
    return r.stdout if capture else r


def sidecar(program, key):
    """The paths a list in the program's .build sidecar names, made absolute."""
    build = program.with_suffix(".build")
    if not build.exists():
        return []
    text = re.sub(r"//[^\n]*", "", build.read_text())
    m = re.search(rf"\b{key}\s*=\s*\[([^\]]*)\]", text)
    names = re.findall(r'"([^"]*)"', m.group(1)) if m else []
    return [(program.parent / n).resolve() for n in names]


def goose_to_c(program, gen, *flags):
    """The program's C (gen/program.c) and the runtime's (gen/goose_runtime.c)."""
    gen.mkdir(parents=True, exist_ok=True)
    run(GOOSE, "-o", gen / "program.c", *flags, program, cwd=program.parent)
    run(GOOSE, "--emit-runtime", gen / "goose_runtime.c")


def sdl_stamp():
    """What SDL's patched copy is made from: the submodule's commit (or, in a copy without
    git, its version and CMakeLists) and every patch."""
    stamp = hashlib.sha256()
    r = subprocess.run(["git", "rev-parse", "HEAD"], cwd=SDL, capture_output=True)
    if r.returncode == 0 and (SDL / ".git").exists():
        stamp.update(r.stdout)
    else:
        stamp.update((SDL / "include/SDL3/SDL_version.h").read_bytes())
        stamp.update((SDL / "CMakeLists.txt").read_bytes())
    for patch in sorted((ROOT / "patches/SDL").glob("*.patch")):
        stamp.update(patch.read_bytes())
    return stamp.hexdigest()


def copy_gfx(out):
    """goose_gfx's src/ under out with patches/goose_gfx applied; returns that src/."""
    gfx_src, fresh = out / "goose_gfx_src", out / "goose_gfx_src.new"
    if fresh.exists():
        shutil.rmtree(fresh)
    # Fresh timestamps (shutil.copy), so ninja rebuilds what a removed patch restores.
    shutil.copytree(ROOT / "third_party/goose_gfx/src", fresh / "src", copy_function=shutil.copy)
    for patch in sorted((ROOT / "patches/goose_gfx").glob("*.patch")):
        run("patch", "-s", "-p1", "-i", patch, cwd=fresh)
    if gfx_src.exists():
        shutil.rmtree(gfx_src)
    fresh.rename(gfx_src)
    return gfx_src / "src"


def copy_sources(out, sdl_src):
    """goose_gfx's src/ under out with patches/goose_gfx applied, and SDL in sdl_src with
    patches/SDL applied; SDL is large, so its copy is remade only when its commit or a
    patch changes. Returns the two folders the CMake build takes."""
    gfx_src = copy_gfx(out)
    stamp, stamp_file = sdl_stamp(), sdl_src / ".draughts-stamp"
    if not stamp_file.exists() or stamp_file.read_text() != stamp:
        fresh = sdl_src.with_name("SDL_src.new")
        if fresh.exists():
            shutil.rmtree(fresh)
        shutil.copytree(SDL, fresh, ignore=shutil.ignore_patterns(".git"),
                        copy_function=shutil.copy)
        for patch in sorted((ROOT / "patches/SDL").glob("*.patch")):
            run("patch", "-s", "-p1", "-i", patch, cwd=fresh)
        (fresh / ".draughts-stamp").write_text(stamp)
        if sdl_src.exists():
            shutil.rmtree(sdl_src)
        fresh.rename(sdl_src)
    return gfx_src, sdl_src


def app_names():
    """Each strings/<lang>.txt's app.name, by language."""
    names = {}
    for path in sorted((ROOT / "strings").glob("*.txt")):
        m = re.search(r"^app\.name\s*=\s*(.+?)\s*$", path.read_text(encoding="utf-8"), re.M)
        if not m:
            sys.exit(f"{path}: no app.name")
        names[path.stem] = m.group(1)
    return names
