#!/usr/bin/env python3
"""Build a Goose program for the Mac with the patched goose_gfx, and optionally run it.

    scripts/mac.py src/main/draughts.goose                     build build/draughts
    scripts/mac.py src/main/draughts_ngfx.goose                build build/draughts_ngfx, holding
                                                              goose-ngfx too (scripts/ngfx.py)
    scripts/mac.py src/main/draughts.goose --run -- --board 3d build, and run it with those flags
    scripts/mac.py src/main/draughts.goose --release           Draughts.app, signed and notarized,
                                                              in a disk image for a GitHub release
    scripts/mac.py src/main/draughts.goose --release --no-notarize   the same, signed but not notarized

A release (docs/development.md, "Desktop releases") builds for MIN_MACOS, wraps the
executable in build/mac/release/Draughts.app (Info.plist, the launcher's name per
language, the icon from platform/ios/icon-1024.png compiled by actool), signs it with the
keychain's "Developer ID Application" identity and the hardened runtime, has Apple's
puts it beside a link to /Applications in build/mac/release/Draughts-VERSION-macos-arm64.dmg
(the window where the app is dragged onto Applications, laid out by Finder over
platform/mac/dmg-background.tiff, so the first build asks to let the terminal control Finder),
signs the image, has Apple's
notary service check it (notarytool's keychain profile NOTARY_PROFILE), and staples the
ticket to the image; the ticket covers the app inside. Without the identity it signs both
ad hoc and stops before notarizing, which is enough to try the image on this Mac;
--no-notarize stops there too with the identity. DRAUGHTS_MAC_IDENTITY names an identity,
DRAUGHTS_NOTARY_PROFILE a profile.

The release's own libgoose_gfx.a presents every frame, so the app at rest spins at the
display's rate. This builds goose_gfx's sources from the submodule (kaitk/goose_gfx's
main, with every change Draughts needs), as Android, iOS, and Windows (scripts/windows.py)
do, into a copy of the release (build/mac/goose/), and builds the program with that copy's
goose: its gfx can present only what was drawn and then wait for an event (WAIT_WHEN_IDLE,
which the app opens with),
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
import time
from pathlib import Path

import native
import ngfx

RELEASE = Path(os.environ.get("GOOSE_RELEASE", native.ROOT / "build/goose-v2026.4-macos-arm64"))
OUT = native.ROOT / "build/mac"


def patched_goose():
    """build/mac/goose/: the release with libgoose_gfx.a rebuilt from the patched sources."""
    return native.patched_goose(
        OUT, RELEASE, "goose", "libgoose_gfx.a",
        lambda c, o: ["clang", "-c", "-O2", "-DNDEBUG", "-I", native.SDL / "include", c, "-o", o],
        lambda lib, objs: ["ar", "rcs", lib, *objs])


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
    shutil.copy(native.ROOT / "platform/ios/icon-1024.png", icon / "Assets/icon.png")
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


DMG_WINDOW = (640, 427)                             # pt, platform/mac/dmg-background.tiff's size
TITLE_BAR = 28                                      # pt: Finder's bounds include it
DMG_ICONS = {"Draughts.app": (160, 185), "Applications": (480, 185)}  # on its card, the arrow between
DMG_LAYOUT = """
tell application "Finder"
  tell disk "{volume}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {{200, 120, {right}, {bottom}}}
    set o to the icon view options of container window
    set arrangement of o to not arranged
    set icon size of o to 96
    set text size of o to 13
    set background picture of o to file ".background:background.tiff"
    {positions}
    update without registering applications
    delay 1
    close
  end tell
end tell
"""


def disk_image(app, dmg):
    """dmg: a compressed, read-only image holding app and a link to /Applications, laid
    out by Finder over platform/mac/dmg-background.tiff, with the app's icon as the volume's."""
    volume = "Draughts"
    mount = Path("/Volumes") / volume
    if mount.exists():
        sys.exit(f"{mount} is mounted already: eject it first")
    stage = dmg.parent / "dmg"
    shutil.rmtree(stage, ignore_errors=True)
    (stage / ".background").mkdir(parents=True)
    native.run("ditto", app, stage / app.name)
    (stage / "Applications").symlink_to("/Applications")
    shutil.copy(native.ROOT / "platform/mac/dmg-background.tiff", stage / ".background/background.tiff")
    shutil.copy(app / "Contents/Resources/AppIcon.icns", stage / ".VolumeIcon.icns")
    writable = dmg.with_suffix(".rw.dmg")
    writable.unlink(missing_ok=True)
    native.run("hdiutil", "create", "-volname", volume, "-srcfolder", stage, "-fs", "HFS+",
               "-format", "UDRW", "-size", "200m", writable)
    shutil.rmtree(stage)
    native.run("hdiutil", "attach", "-readwrite", "-noverify", "-noautoopen", writable)
    try:
        positions = "\n    ".join(f'set position of item "{n}" of container window to {{{x}, {y}}}'
                                   for n, (x, y) in DMG_ICONS.items())
        w, h = DMG_WINDOW
        layout = DMG_LAYOUT.format(volume=volume, right=200 + w, bottom=120 + h + TITLE_BAR,
                                   positions=positions)
        # Finder can take a few seconds to see a volume just attached (-1728).
        for attempt in range(10):
            if subprocess.run(["osascript", "-e", layout]).returncode == 0:
                break
            time.sleep(1)
        else:
            sys.exit("Finder never saw the disk image's volume")
        native.run("xcrun", "SetFile", "-a", "C", mount)     # use .VolumeIcon.icns; after
                                                             # Finder, which clears it
        native.run("sync")
    finally:
        native.run("hdiutil", "detach", mount)
    dmg.unlink(missing_ok=True)
    native.run("hdiutil", "convert", writable, "-format", "UDZO", "-imagekey", "zlib-level=9",
               "-o", dmg)
    writable.unlink()


def release(program, notarize):
    """The signed, notarized Draughts.app in a disk image (the module's docstring)."""
    os.environ["MACOSX_DEPLOYMENT_TARGET"] = MIN_MACOS
    out = OUT / "release"
    out.mkdir(parents=True, exist_ok=True)
    exe = out / "draughts"
    native.run(patched_goose(), "build", "-o", exe, program.name, cwd=program.parent)
    app = bundle(exe, out)
    who = identity()
    dmg = out / f"Draughts-{native.VERSION_NAME}-macos-arm64.dmg"
    if not who:
        native.run("codesign", "--force", "--sign", "-", app)
        disk_image(app, dmg)
        print(f"\nno Developer ID Application identity: {dmg} is signed ad hoc and not notarized"
              " (docs/development.md, \"Desktop releases\")")
        return
    native.run("codesign", "--force", "--options", "runtime", "--timestamp", "--sign", who, app)
    native.run("codesign", "--verify", "--strict", "--verbose=2", app)
    disk_image(app, dmg)
    native.run("codesign", "--force", "--timestamp", "--sign", who, dmg)
    if not notarize:
        print(f"\n{dmg} is signed, not notarized")
        return
    native.run("xcrun", "notarytool", "submit", dmg, "--keychain-profile", NOTARY_PROFILE, "--wait")
    native.run("xcrun", "stapler", "staple", dmg)
    native.run("spctl", "--assess", "--type", "open", "--context", "context:primary-signature",
               "--verbose", dmg)
    print(f"\n{dmg}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("program", type=Path)
    ap.add_argument("-o", type=Path, help="the executable (build/<program> by default)")
    ap.add_argument("--run", action="store_true", help="run it after building")
    ap.add_argument("--release", action="store_true", help="Draughts.app, signed and notarized, in a disk image")
    ap.add_argument("--no-notarize", action="store_true", help="with --release: sign, but don't notarize")
    ap.add_argument("args", nargs="*", help="the program's flags, after --")
    a = ap.parse_args()
    program = a.program.resolve()
    if a.release:
        if ngfx.uses_ngfx(program):
            sys.exit("the build holding goose-ngfx isn't released")
        return release(program, not a.no_notarize)
    ngfx.prepare(program)
    exe = (a.o or native.ROOT / "build" / program.stem).resolve()
    native.run(patched_goose(), "build", "-o", exe, program.name, cwd=program.parent)
    if a.run:
        sys.exit(subprocess.run([str(exe), *a.args]).returncode)


if __name__ == "__main__":
    main()
