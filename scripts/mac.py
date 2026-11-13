#!/usr/bin/env python3
"""Build a Goose program for the Mac with the patched goose_gfx, and optionally run it.

    scripts/mac.py src/app/draughts.goose                     build build/draughts
    scripts/mac.py src/app/draughts.goose --run -- --board 3d build, and run it with those flags
    scripts/mac.py src/app/draughts.goose --release           Draughts.app, signed and notarized,
                                                              zipped for a GitHub release

A release (docs/development.md, "Desktop releases") builds for MIN_MACOS, wraps the
executable in build/mac/release/Draughts.app (Info.plist, the launcher's name per
language, the icon from ios/icon-1024.png compiled by actool), signs it with the
keychain's "Developer ID Application" identity and the hardened runtime, has Apple's
notary service check it (notarytool's keychain profile NOTARY_PROFILE), staples the
ticket, and zips it as build/mac/release/Draughts-VERSION-macos-arm64.zip. Without the
identity it signs ad hoc and stops before notarizing, which is enough to try the bundle
on this Mac; DRAUGHTS_MAC_IDENTITY names an identity, DRAUGHTS_NOTARY_PROFILE a profile.

The release's own libgoose_gfx.a presents every frame, so the app at rest spins at the
display's rate. This builds goose_gfx's sources from the submodule (kaitk/goose_gfx's
main, with every change Draughts needs), as Android, iOS, and Windows (scripts/windows.py)
do, into a copy of the release (build/mac/goose/), and builds the program with that copy's
goose: its gfx presents only what was drawn and then waits for an event (draw-on-demand),
and samples ASTC where the GPU takes it (compressed-textures). SDL is the release's own libSDL3.a, which is goose_gfx's SDL submodule's commit.

The copy is made once; delete build/mac/goose/ after the release changes. The release is
build/goose-v2026.4-macos-arm64/, or GOOSE_RELEASE.
"""
import argparse
import json
import os
import plistlib
import re
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


MIN_MACOS = "13.3"            # a release's LSMinimumSystemVersion and deployment target: the
                              # Goose release's libSDL3.a and runtime are built for 13.3
NOTARY_PROFILE = os.environ.get("DRAUGHTS_NOTARY_PROFILE", "draughts-notary")
CATEGORY = "public.app-category.board-games"


def identity():
    """The Developer ID Application identity to sign with, or None."""
    if os.environ.get("DRAUGHTS_MAC_IDENTITY"):
        return os.environ["DRAUGHTS_MAC_IDENTITY"]
    found = native.run("security", "find-identity", "-v", "-p", "codesigning", capture=True)
    m = re.search(r'"(Developer ID Application: [^"]+)"', found)
    return m.group(1) if m else None


def app_icon(out):
    """Assets.car and AppIcon.icns from the iOS icon, compiled by actool from an Icon
    Composer .icon. macOS 26 masks Assets.car's full-bleed icon to its squircle itself; an
    .icns alone, though drawn in the old rounded square, it sets on a grey plate. actool's
    AppIcon.icns is the squircle for macOS 13 to 15."""
    work = out / "icon"
    shutil.rmtree(work, ignore_errors=True)
    icon = work / "AppIcon.icon"
    (icon / "Assets").mkdir(parents=True)
    shutil.copy(native.ROOT / "ios/icon-1024.png", icon / "Assets/icon.png")
    (icon / "icon.json").write_text(json.dumps({
        "fill": "automatic",
        "groups": [{
            "layers": [{"glass": False, "image-name": "icon.png", "name": "icon"}],
            "shadow": {"kind": "neutral", "opacity": 0.5},
            "translucency": {"enabled": False, "value": 0.5},
        }],
        "supported-platforms": {"squares": "shared"},
    }, indent=2))
    compiled = work / "compiled"
    compiled.mkdir()
    native.run("xcrun", "actool", icon, "--compile", compiled, "--app-icon", "AppIcon",
               "--platform", "macosx", "--target-device", "mac",
               "--minimum-deployment-target", MIN_MACOS,
               "--output-partial-info-plist", work / "partial.plist")
    return compiled / "Assets.car", compiled / "AppIcon.icns"


def bundle(exe, out):
    """build/mac/release/Draughts.app around exe."""
    app = out / "Draughts.app"
    shutil.rmtree(app, ignore_errors=True)
    (app / "Contents/MacOS").mkdir(parents=True)
    res = app / "Contents/Resources"
    res.mkdir()
    shutil.copy(exe, app / "Contents/MacOS/Draughts")
    for f in app_icon(out):
        shutil.copy(f, res / f.name)
    names = native.app_names()
    for lang, name in names.items():
        (res / f"{lang}.lproj").mkdir()
        (res / f"{lang}.lproj/InfoPlist.strings").write_text(
            f'CFBundleName = "{name}";\nCFBundleDisplayName = "{name}";\n', encoding="utf-8")
    info = {
        "CFBundleDevelopmentRegion": "en",
        "CFBundleExecutable": "Draughts",
        "CFBundleIdentifier": native.APP_ID,
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleName": names["en"],
        "CFBundleDisplayName": names["en"],
        "CFBundleLocalizations": sorted(names),
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": native.VERSION_NAME,
        "CFBundleVersion": native.VERSION_NAME,
        "CFBundleIconFile": "AppIcon",
        "CFBundleIconName": "AppIcon",
        "LSMinimumSystemVersion": MIN_MACOS,
        "LSApplicationCategoryType": CATEGORY,
        "NSHighResolutionCapable": True,
        "NSSupportsAutomaticGraphicsSwitching": True,
    }
    with open(app / "Contents/Info.plist", "wb") as f:
        plistlib.dump(info, f)
    return app


def release(program):
    """The signed, notarized Draughts.app, zipped (the module's docstring)."""
    os.environ["MACOSX_DEPLOYMENT_TARGET"] = MIN_MACOS
    out = OUT / "release"
    out.mkdir(parents=True, exist_ok=True)
    exe = out / "draughts"
    native.run(patched_goose(), "build", "-o", exe, program.name, cwd=program.parent)
    app = bundle(exe, out)
    who = identity()
    zipped = out / f"Draughts-{native.VERSION_NAME}-macos-arm64.zip"
    zipped.unlink(missing_ok=True)
    if not who:
        native.run("codesign", "--force", "--sign", "-", app)
        print(f"\nno Developer ID Application identity: {app} is signed ad hoc, not notarized,"
              " and not zipped (docs/development.md, \"Desktop releases\")")
        return
    native.run("codesign", "--force", "--options", "runtime", "--timestamp", "--sign", who, app)
    native.run("codesign", "--verify", "--strict", "--verbose=2", app)
    native.run("ditto", "-c", "-k", "--keepParent", app, zipped)
    native.run("xcrun", "notarytool", "submit", zipped, "--keychain-profile", NOTARY_PROFILE, "--wait")
    native.run("xcrun", "stapler", "staple", app)
    zipped.unlink()
    native.run("ditto", "-c", "-k", "--keepParent", app, zipped)
    native.run("spctl", "--assess", "--type", "execute", "--verbose", app)
    print(f"\n{zipped}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("program", type=Path)
    ap.add_argument("-o", type=Path, help="the executable (build/<program> by default)")
    ap.add_argument("--run", action="store_true", help="run it after building")
    ap.add_argument("--release", action="store_true", help="Draughts.app, signed, notarized, and zipped")
    ap.add_argument("args", nargs="*", help="the program's flags, after --")
    a = ap.parse_args()
    program = a.program.resolve()
    if a.release:
        return release(program)
    exe = (a.o or native.ROOT / "build" / program.stem).resolve()
    native.run(patched_goose(), "build", "-o", exe, program.name, cwd=program.parent)
    if a.run:
        sys.exit(subprocess.run([str(exe), *a.args]).returncode)


if __name__ == "__main__":
    main()
