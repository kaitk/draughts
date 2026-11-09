#!/usr/bin/env python3
"""Build a Goose program into an iOS app, without an Xcode project, and optionally run it.

    scripts/ios.py poc/poc.goose                 build build/ios/<name>/sim/<Name>.app
    scripts/ios.py src/app/draughts.goose --run  build, install in the simulator, and start it
    scripts/ios.py src/app/draughts.goose --run --args "--screen game"
                                                 the same, with development flags
    scripts/ios.py src/app/draughts.goose --shot out.png --wait 4
                                                 run, wait, and save the simulator's screen
    scripts/ios.py src/app/draughts.goose --device --run
                                                 build for the attached iPhone, sign, install, start

Steps, as scripts/android.py's: Goose writes the program's C and the runtime's C;
goose_gfx's sources are copied and patches/goose_gfx applied, and SDL is copied and
patches/SDL applied; CMake with Ninja and Xcode's clang builds ios/CMakeLists.txt, one
executable with SDL linked statically; the bundle is the executable, an Info.plist written
here (the id, the version, full screen, the launch screen's colour), the launcher's name
per language (<lang>.lproj/InfoPlist.strings from strings/<lang>.txt's app.name); no icon
yet (task 043). A simulator build is signed ad hoc; a device build with the Mac's development
identity and a provisioning profile for the app's id (docs/development.md, "Run on
iOS"), made once through Xcode when missing; no team, identity, or device id is ever
written into the repo.

The simulator is one this script creates once, named SIM_NAME, of SIM_TYPE, and boots
headless: no Simulator.app window opens. Tools come from Xcode (xcrun) and the
environment: GOOSE, DRAUGHTS_IOS_SIM (another simulator's name or UDID),
DRAUGHTS_IOS_DEVICE (a device's name, identifier, or UDID).
"""
import argparse
import hashlib
import json
import os
import plistlib
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GOOSE = Path(os.environ.get("GOOSE", ROOT / "build/goose-v2026.4-macos-arm64/goose"))
SDL = ROOT / "third_party/goose_gfx/third_party/SDL"
# The bundle id, as Android's application id (scripts/android.py's APP_ID).
APP_ID = "io.github.kaitk.draughts"
VERSION_NAME = "0.1.0"    # CFBundleShortVersionString, as Android's versionName
BUILD_NUMBER = "1"        # CFBundleVersion, raised for every upload
MIN_IOS = "16.0"
# Each data stack's address space. Goose reserves 2 GB a stack by default, and the app
# has 26 (goose build --stacks): 52 GB, more than an iOS process may map. 128 MB each is
# 3.3 GB, and the largest stack holds a few MB.
STACK_RESERVE = "128M"
# The simulator this script makes and uses: the size of the iPhone the app is tried on.
SIM_NAME = "Draughts iPhone 13 mini"
SIM_TYPE = "com.apple.CoreSimulator.SimDeviceType.iPhone-13-mini"
LAUNCH_COLOR = (0x06 / 255, 0x17 / 255, 0x2b / 255)   # the icon's background (android/res)


def run(*cmd, cwd=None, capture=False, check=True):
    print("+", " ".join(str(c) for c in cmd), flush=True)
    r = subprocess.run([str(c) for c in cmd], cwd=cwd, check=check, text=True,
                       capture_output=capture)
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


def copy_sources(out):
    """goose_gfx's src/ under out with patches/goose_gfx applied, and SDL in build/ios/SDL_src
    with patches/SDL applied, remade only when its commit or a patch changes."""
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
    sdl_src = ROOT / "build/ios/SDL_src"
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
    return gfx_src / "src", sdl_src


def app_names():
    """Each strings/<lang>.txt's app.name, by language."""
    names = {}
    for path in sorted((ROOT / "strings").glob("*.txt")):
        m = re.search(r"^app\.name\s*=\s*(.+?)\s*$", path.read_text(encoding="utf-8"), re.M)
        if not m:
            sys.exit(f"{path}: no app.name")
        names[path.stem] = m.group(1)
    return names


def write_bundle(app, exe, app_id, title, device):
    """The .app: the executable, Info.plist, and the launcher's name per language."""
    if app.exists():
        shutil.rmtree(app)
    app.mkdir(parents=True)
    shutil.copy(exe, app / title)
    names = app_names()
    platform = "iPhoneOS" if device else "iPhoneSimulator"
    sdk = "iphoneos" if device else "iphonesimulator"
    sdk_version = run("xcrun", "--sdk", sdk, "--show-sdk-version", capture=True).strip()
    info = {
        "CFBundleDevelopmentRegion": "en",
        "CFBundleExecutable": title,
        "CFBundleIdentifier": app_id,
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleName": names["en"] if title == "Draughts" else title,
        "CFBundleDisplayName": names["en"] if title == "Draughts" else title,
        "CFBundleLocalizations": sorted(names),
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": VERSION_NAME,
        "CFBundleVersion": BUILD_NUMBER,
        "CFBundleSupportedPlatforms": [platform],
        "DTPlatformName": sdk,
        "DTSDKName": f"{sdk}{sdk_version}",
        "DTPlatformVersion": sdk_version,
        "LSRequiresIPhoneOS": True,
        "MinimumOSVersion": MIN_IOS,
        "UIDeviceFamily": [1, 2],
        "UIRequiredDeviceCapabilities": ["arm64", "metal"],
        # A launch screen makes iOS give the app the whole screen at its own size; without
        # one it runs letterboxed at an old iPhone's. Its colour is the icon's background.
        "UILaunchScreen": {},
        "UIStatusBarHidden": True,
        # SDL asks for it to take a pointer (an iPad's trackpad, the simulator's mouse).
        "UIApplicationSupportsIndirectInputEvents": True,
        "UIViewControllerBasedStatusBarAppearance": True,
        "UIRequiresFullScreen": True,
        "UISupportedInterfaceOrientations": [
            "UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft",
            "UIInterfaceOrientationLandscapeRight"],
        "UISupportedInterfaceOrientations~ipad": [
            "UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown",
            "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"],
        "ITSAppUsesNonExemptEncryption": False,
    }
    with open(app / "Info.plist", "wb") as f:
        plistlib.dump(info, f, fmt=plistlib.FMT_BINARY)
    (app / "PkgInfo").write_text("APPL????")
    if title == "Draughts":
        for lang, name in names.items():
            folder = app / f"{lang}.lproj"
            folder.mkdir()
            with open(folder / "InfoPlist.strings", "wb") as f:
                plistlib.dump({"CFBundleDisplayName": name, "CFBundleName": name}, f,
                              fmt=plistlib.FMT_BINARY)


def simulator():
    """The UDID of the simulator to run on, created once and booted headless."""
    want = os.environ.get("DRAUGHTS_IOS_SIM", SIM_NAME)
    listing = json.loads(run("xcrun", "simctl", "list", "-j", "devices", "available",
                             capture=True))
    found = None
    for runtime, devices in listing["devices"].items():
        for d in devices:
            if want in (d["name"], d["udid"]):
                found = d
    if not found:
        if want != SIM_NAME:
            sys.exit(f"no simulator named {want}")
        runtimes = json.loads(run("xcrun", "simctl", "list", "-j", "runtimes", "available",
                                  capture=True))["runtimes"]
        ios = [r for r in runtimes if r.get("platform") == "iOS"]
        if not ios:
            sys.exit("no iOS simulator runtime: Xcode → Settings → Components")
        udid = run("xcrun", "simctl", "create", SIM_NAME, SIM_TYPE, ios[-1]["identifier"],
                   capture=True).strip()
        found = {"udid": udid, "state": "Shutdown"}
    if found["state"] != "Booted":
        # simctl boots it without a window; Simulator.app is never opened.
        run("xcrun", "simctl", "boot", found["udid"])
        run("xcrun", "simctl", "bootstatus", found["udid"], "-b")
    return found["udid"]


def device():
    """The attached iPhone or iPad to install on: devicectl's identifier and the device's
    UDID, the first paired one in Developer Mode, or the one DRAUGHTS_IOS_DEVICE names."""
    listing = ROOT / "build/ios/devices.json"
    listing.parent.mkdir(parents=True, exist_ok=True)
    run("xcrun", "devicectl", "list", "devices", "--quiet", "--json-output", listing)
    want = os.environ.get("DRAUGHTS_IOS_DEVICE")
    for d in json.loads(listing.read_text())["result"]["devices"]:
        hw, conn = d["hardwareProperties"], d["connectionProperties"]
        if want and want not in (d["identifier"], hw.get("udid"), d["deviceProperties"].get("name")):
            continue
        if hw.get("platform") != "iOS" or hw.get("reality") != "physical":
            continue
        if conn.get("pairingState") != "paired":
            sys.exit("the device isn't paired: unlock it and trust this Mac")
        if d["deviceProperties"].get("developerModeStatus") != "enabled":
            sys.exit("the device's Developer Mode is off: Settings → Privacy & Security")
        return d["identifier"], hw["udid"]
    sys.exit("no iPhone or iPad attached")


def identity():
    """The Mac's Apple Development signing identity: its SHA-1 and its team, the
    certificate's organizational unit. Neither is ever written into the repo."""
    out = run("security", "find-identity", "-v", "-p", "codesigning", capture=True)
    m = re.search(r'([0-9A-F]{40}) "(Apple Development: [^"]+)"', out)
    if not m:
        sys.exit("no Apple Development identity: sign in to Xcode with an Apple ID "
                 "(Settings → Accounts) and make one under Manage Certificates")
    pem = run("security", "find-certificate", "-a", "-Z", "-p", "-c", m.group(2), capture=True)
    # The certificate whose SHA-1 is the identity's.
    block = pem[pem.index(f"SHA-1 hash: {m.group(1)}"):]
    cert = block[block.index("-----BEGIN"):block.index("-----END CERTIFICATE-----") + 25]
    subject = subprocess.run(["openssl", "x509", "-noout", "-subject", "-nameopt",
                              "sep_multiline"], input=cert, text=True, capture_output=True,
                             check=True).stdout
    team = re.search(r"OU=(\w+)", subject)
    if not team:
        sys.exit("the identity's certificate names no team")
    return m.group(1), team.group(1)


PROFILES = [Path.home() / "Library/Developer/Xcode/UserData/Provisioning Profiles",
            Path.home() / "Library/MobileDevice/Provisioning Profiles"]


def profile(team, app_id, udid):
    """The newest provisioning profile that signs app_id for the team on the device, still
    valid, decoded: (path, plist), or None."""
    best = None
    for folder in PROFILES:
        for path in sorted(folder.glob("*.mobileprovision")) if folder.exists() else []:
            r = subprocess.run(["security", "cms", "-D", "-i", path], capture_output=True)
            if r.returncode != 0:
                continue
            p = plistlib.loads(r.stdout)
            ident = p.get("Entitlements", {}).get("application-identifier", "")
            if ident not in (f"{team}.{app_id}", f"{team}.*"):
                continue
            if udid not in p.get("ProvisionedDevices", []) and not p.get("ProvisionsAllDevices"):
                continue
            if p["ExpirationDate"].timestamp() < time.time():
                continue
            if not best or p["CreationDate"] > best[1]["CreationDate"]:
                best = (path, p)
    return best


def provision(team, app_id, target):
    """Has Xcode make a development profile for app_id on the device, as automatic signing
    does: an empty app of that id, generated by CMake as an Xcode project under
    build/ios/provision/ and built once with -allowProvisioningUpdates, which also
    registers the device with the team."""
    work = ROOT / "build/ios/provision"
    if work.exists():
        shutil.rmtree(work)
    work.mkdir(parents=True)
    (work / "stub.c").write_text("int main(void) { return 0; }\n")
    (work / "CMakeLists.txt").write_text(
        "cmake_minimum_required(VERSION 3.20)\nproject(stub C)\n"
        "add_executable(stub MACOSX_BUNDLE stub.c)\n")
    run("cmake", "-S", work, "-B", work / "xcode", "-G", "Xcode", "-DCMAKE_SYSTEM_NAME=iOS",
        f"-DCMAKE_OSX_DEPLOYMENT_TARGET={MIN_IOS}", "-DCMAKE_XCODE_GENERATE_SCHEME=ON",
        f"-DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM={team}",
        "-DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_STYLE=Automatic",
        "-DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY=Apple Development",
        f"-DCMAKE_XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER={app_id}",
        f"-DMACOSX_BUNDLE_GUI_IDENTIFIER={app_id}")
    run("xcodebuild", "-project", work / "xcode/stub.xcodeproj", "-scheme", "stub",
        "-destination", f"id={target}", "-allowProvisioningUpdates",
        "-allowProvisioningDeviceRegistration", "-derivedDataPath", work / "derived",
        "-quiet", "build")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("program", type=Path)
    ap.add_argument("--device", action="store_true", help="build for an iPhone, not the simulator")
    ap.add_argument("--run", action="store_true", help="install and start it")
    ap.add_argument("--args", default="", help="the program's flags, as one string")
    ap.add_argument("--shot", type=Path,
                    help="run in the simulator, wait --wait seconds, save the screen there")
    ap.add_argument("--wait", type=float, default=3.0)
    ap.add_argument("--console", action="store_true",
                    help="run, and stay attached to the program's output until it ends")
    args = ap.parse_args()
    program = args.program.resolve()
    name = program.stem
    app_id = APP_ID if name == "draughts" else f"{APP_ID}.{name}"
    title = "Draughts" if name == "draughts" else name
    out = ROOT / "build/ios" / name
    plat = "device" if args.device else "sim"
    gen, native = out / "gen", out / plat / "native"
    gen.mkdir(parents=True, exist_ok=True)

    # 1. Goose to C.
    run(GOOSE, "-o", gen / "program.c", "--stack-reserve", STACK_RESERVE, program,
        cwd=program.parent)
    run(GOOSE, "--emit-runtime", gen / "goose_runtime.c")

    # 2. goose_gfx's C layers and SDL, patched copies, then the executable.
    gfx_src, sdl_src = copy_sources(out)
    run("cmake", "-S", ROOT / "ios", "-B", native, "-G", "Ninja",
        "-DCMAKE_SYSTEM_NAME=iOS",
        f"-DCMAKE_OSX_SYSROOT={'iphoneos' if args.device else 'iphonesimulator'}",
        "-DCMAKE_OSX_ARCHITECTURES=arm64",
        f"-DCMAKE_OSX_DEPLOYMENT_TARGET={MIN_IOS}",
        "-DCMAKE_BUILD_TYPE=Release",
        f"-DGOOSE_PROGRAM_C={gen / 'program.c'}",
        f"-DGOOSE_RUNTIME_C={gen / 'goose_runtime.c'}",
        f"-DGOOSE_GFX_SRC={gfx_src}",
        f"-DSDL_SRC={sdl_src}",
        "-DGOOSE_PROGRAM_SOURCES=" + ";".join(map(str, sidecar(program, "c_sources"))),
        "-DGOOSE_PROGRAM_INCLUDE=" + ";".join(map(str, sidecar(program, "c_include"))))
    run("cmake", "--build", native, "--target", "main")

    # 3. The bundle, signed.
    app = out / plat / f"{title}.app"
    write_bundle(app, native / "main", app_id, title, args.device)
    if args.device:
        # The development identity, its team's profile for the app on this device (made
        # once through Xcode if missing), embedded, and its entitlements signed in.
        sha1, team = identity()
        target, udid = device()
        found = profile(team, app_id, udid)
        if not found:
            provision(team, app_id, udid)
            found = profile(team, app_id, udid)
            if not found:
                sys.exit(f"Xcode made no profile for {app_id} on the device")
        path, prof = found
        shutil.copy(path, app / "embedded.mobileprovision")
        entitlements = out / plat / "entitlements.plist"
        with open(entitlements, "wb") as f:
            plistlib.dump(prof["Entitlements"], f)
        run("codesign", "--force", "--sign", sha1, "--entitlements", entitlements,
            "--timestamp=none", app)
    else:
        run("codesign", "--force", "--sign", "-", "--timestamp=none", app)
    print(f"{app} ({sum(f.stat().st_size for f in app.rglob('*') if f.is_file()) // 1024} KB)")

    # 4. Install and start it on the device.
    flags = args.args.split()
    if args.device and (args.run or args.console):
        run("xcrun", "devicectl", "device", "install", "app", "--device", target, app)
        run("xcrun", "devicectl", "device", "process", "launch", "--device", target,
            "--terminate-existing", *(["--console"] if args.console else []), app_id, *flags,
            check=not args.console)
        return

    # 4. Install and start it in the simulator.
    if args.run or args.shot or args.console:
        udid = simulator()
        run("xcrun", "simctl", "install", udid, app)
        if args.console:
            run("xcrun", "simctl", "launch", "--console-pty", "--terminate-running-process",
                udid, app_id, *flags, check=False)
        else:
            run("xcrun", "simctl", "launch", "--terminate-running-process", udid, app_id, *flags)
        if args.shot:
            time.sleep(args.wait)
            run("xcrun", "simctl", "io", udid, "screenshot", args.shot.resolve())


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as e:
        sys.exit(e.returncode)
