"""What the build scripts share: the paths and the app's id and version, the steps from a
Goose program to C, the patched copies of goose_gfx and SDL (android.py, ios.py), the
release's copy with gfx rebuilt (mac.py, linux.py, windows.py), and the launcher's name
per language. Not run by itself.
"""
import hashlib
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WINDOWS = sys.platform == "win32"
GOOSE = Path(os.environ.get("GOOSE", ROOT / ("build/goose-v2026.4-windows-x64/goose.exe" if WINDOWS
                                             else "build/goose-v2026.4-linux-x64/goose"
                                             if sys.platform.startswith("linux")
                                             else "build/goose-v2026.4-macos-arm64/goose")))
SDL = ROOT / "third_party/goose_gfx/third_party/SDL"
# The application id on Android (2026-11-08): Play fixes it for good at the first upload.
# iOS has its own, scripts/ios.py's BUNDLE_ID. Another program (tools/pace.goose) gets
# APP_ID.<name> (app_id_of).
APP_ID = "io.github.kaitk.draughts"
# The version people see: Android's versionName and iOS's CFBundleShortVersionString.
# Each platform's build number is its own script's (VERSION_CODE, BUILD_NUMBER).
VERSION_NAME = "0.9.0"
# The shipped season's 1024 px icon, in git, for the iOS bundle: tools/assets/icon.py
# writes it when the shipped season changes.
IOS_ICON = ROOT / "platform/ios/icon-1024.png"


def write_version():
    """build/draughts_version.h: the version, the commit it is built from (-dirty when the
    tree has changes), and the commit's date, which settings' About shows and the build
    holding both renderers keys its crash marker by (src/native/about.c, src/native/renderer.c).
    Written only when it changes, so a build that changes nothing compiles nothing again.
    Without git (a copy of the sources) the commit is "unknown"."""
    def git(*a):
        r = subprocess.run(["git", *a], cwd=ROOT, capture_output=True, text=True)
        return r.stdout.strip() if r.returncode == 0 else ""
    commit = git("rev-parse", "--short", "HEAD") or "unknown"
    if commit != "unknown" and git("status", "--porcelain", "--untracked-files=no"):
        commit += "-dirty"
    date = git("log", "-1", "--format=%cs")
    text = (f'#define DRAUGHTS_VERSION_NAME "{VERSION_NAME}"\n'
            f'#define DRAUGHTS_COMMIT "{commit}"\n'
            f'#define DRAUGHTS_COMMIT_DATE "{date}"\n'
            f'#define DRAUGHTS_VERSION "{VERSION_NAME} {commit}"\n')
    path = ROOT / "build/draughts_version.h"
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists() or path.read_text(encoding="utf-8") != text:
        path.write_bytes(text.encode())


def run(*cmd, cwd=None, env=None, capture=False, check=True):
    """Runs a command, echoed; its output when capture, else the completed process."""
    print("+", " ".join(str(c) for c in cmd), flush=True)
    r = subprocess.run([str(c) for c in cmd], cwd=cwd, check=check, text=True,
                       capture_output=capture,
                       env=None if env is None else dict(os.environ, **env))
    return r.stdout if capture else r


def sidecar_text(program):
    """The program's .build sidecar without its comments, or "" if it has none."""
    build = program.with_suffix(".build")
    return re.sub(r"//[^\n]*", "", build.read_text()) if build.exists() else ""


def sidecar(program, key):
    """The paths a list in the program's .build sidecar names, made absolute."""
    m = re.search(rf"\b{key}\s*=\s*\[([^\]]*)\]", sidecar_text(program))
    names = re.findall(r'"([^"]*)"', m.group(1)) if m else []
    return [(program.parent / n).resolve() for n in names]


def program_name(program):
    """The sidecar's output, else the file's name. Both roots in src/main/ set
    output = "draughts". Build folders are named after the file instead, so the two
    roots get one each."""
    m = re.search(r'\boutput\s*=\s*"([^"]*)"', sidecar_text(program))
    return m.group(1) if m else program.stem


def app_id_of(program, base=APP_ID):
    """base for the app, base.<name> for another program, so it installs beside the app."""
    name = program_name(program)
    return base if name == "draughts" else f"{base}.{name}"


def goose_to_c(program, gen, *flags):
    """The program's C (gen/program.c) and the runtime's (gen/goose_runtime.c)."""
    write_version()
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
    """goose_gfx's src/ under out, from the submodule (kaitk/goose_gfx's main, which holds
    every change Draughts needs); returns that src/."""
    gfx_src, fresh = out / "goose_gfx_src", out / "goose_gfx_src.new"
    if fresh.exists():
        shutil.rmtree(fresh)
    # Fresh timestamps (shutil.copy), so ninja rebuilds what a new submodule commit changes.
    shutil.copytree(ROOT / "third_party/goose_gfx/src", fresh / "src", copy_function=shutil.copy)
    if gfx_src.exists():
        shutil.rmtree(gfx_src)
    fresh.rename(gfx_src)
    return gfx_src / "src"


# The Goose release's gfx library (libgoose_gfx.a, goose_gfx.lib) holds these four.
GFX_SOURCES = ["gfx_device", "gfx_resources", "gfx_pipeline", "gfx_draw"]


def patched_goose(out, release, exe, lib, compile, archive, obj=".o", section="Toolchain"):
    """out/goose/: a copy of the Goose release whose gfx library (pkg/gfx/lib/<lib>) is
    rebuilt from the submodule's sources, as the desktop scripts (mac.py, linux.py,
    windows.py) build with. compile(c, o) and archive(lib, objs) give the platform's
    commands. The library is rebuilt only when the sources (gfx's and SDL's version) or the
    commands change: a stamp beside it holds their hash. Returns the copy's goose."""
    write_version()
    goose = out / "goose"
    if not goose.exists():
        if not (release / exe).exists():
            sys.exit(f"no Goose release at {release} (docs/development.md, {section})")
        shutil.copytree(release, goose, symlinks=not WINDOWS)
    src = copy_gfx(out)
    shutil.copytree(src / "gfx", goose / "pkg/gfx/src/gfx", dirs_exist_ok=True)
    objs, target = out / "obj", goose / "pkg/gfx/lib" / lib
    stamp = hashlib.sha256(repr([compile(Path("c"), Path("o")), archive(Path("lib"), [])]).encode())
    for f in sorted(p for p in src.rglob("*") if p.is_file()):
        stamp.update(f.relative_to(src).as_posix().encode() + f.read_bytes())
    stamp.update((SDL / "include/SDL3/SDL_version.h").read_bytes())
    stamp_file = target.with_name(lib + ".draughts-stamp")
    if target.exists() and stamp_file.exists() and stamp_file.read_text() == stamp.hexdigest():
        return goose / exe
    objs.mkdir(exist_ok=True)
    for name in GFX_SOURCES:
        run(*compile(src / "gfx" / f"{name}.c", objs / f"{name}{obj}"))
    target.unlink(missing_ok=True)
    run(*archive(target, [objs / f"{name}{obj}" for name in GFX_SOURCES]))
    stamp_file.write_text(stamp.hexdigest())
    return goose / exe


def copy_sdl(sdl_src):
    """SDL in sdl_src with patches/SDL applied; SDL is large, so its copy is remade only
    when its commit or a patch changes. Returns sdl_src."""
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
    return sdl_src


def copy_sources(out, sdl_src):
    """goose_gfx's src/ under out, and SDL's patched copy in sdl_src (copy_sdl). Returns
    the two folders the CMake build takes."""
    return copy_gfx(out), copy_sdl(sdl_src)


def app_names():
    """Each strings/<lang>.txt's app.name, by language."""
    names = {}
    for path in sorted((ROOT / "strings").glob("*.txt")):
        m = re.search(r"^app\.name\s*=\s*(.+?)\s*$", path.read_text(encoding="utf-8"), re.M)
        if not m:
            sys.exit(f"{path}: no app.name")
        names[path.stem] = m.group(1)
    return names
