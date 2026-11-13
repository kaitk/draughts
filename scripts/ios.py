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
    scripts/ios.py src/app/draughts.goose --device --run --ngfx
                                                 the same holding both renderers (task 073), in its place
    scripts/ios.py src/app/draughts.goose --release [--upload]
                                                 build/ios/draughts/Draughts.ipa, signed for the
                                                 App Store, and uploaded to App Store Connect

Steps, as scripts/android.py's: Goose writes the program's C and the runtime's C;
goose_gfx's sources are copied from the submodule, and SDL is copied and
patches/SDL applied; CMake with Ninja and Xcode's clang builds ios/CMakeLists.txt, one
executable with SDL linked statically; the bundle is the executable, an Info.plist written
here (the id, the version, full screen, the launch screen in the icon's background),
the launcher's name per language (<lang>.lproj/InfoPlist.strings from strings/<lang>.txt's
app.name), the icon and the launch screen's colour in an asset catalog compiled by
actool into Assets.car (the shipped season's icon, ios/icon-1024.png, made by
scripts/icon.py), and the privacy manifest, PrivacyInfo.xcprivacy. A simulator build is
signed ad hoc; a device build with the Mac's development
identity and a provisioning profile for the app's id (docs/development.md, "Run on
iOS"), made once through Xcode when missing; no team, identity, or device id is ever
written into the repo.

The simulator is one this script creates once, named SIM_NAME, of SIM_TYPE, and boots
headless: no Simulator.app window opens. Tools come from Xcode (xcrun) and the
environment: GOOSE, DRAUGHTS_IOS_SIM (another simulator's name or UDID),
DRAUGHTS_IOS_DEVICE (a device's name, identifier, or UDID), DRAUGHTS_IOS_TEAM (the
signing team's id or Apple ID, when the Mac has several development identities).
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

import icon
from native import ROOT, VERSION_NAME, app_names, copy_sources, goose_to_c, run, sidecar

# The bundle id, not Android's native.APP_ID: a free team on a locked Apple ID holds that
# one, and this one is kept for good (2026-11-12, tasks/046-app-store-release.md). Another
# program gets BUNDLE_ID.<name>. CFBundleShortVersionString is native.VERSION_NAME.
BUNDLE_ID = "io.github.kaitk.draughts.app"
BUILD_NUMBER = "2"        # CFBundleVersion, raised for every upload
# A release build's App Store profile and the upload's API key ids, outside the repo
# (docs/development.md, "Release builds"); DRAUGHTS_IOS_PROFILE, DRAUGHTS_ASC_PROPERTIES.
RELEASE_PROFILE = "~/.config/draughts/draughts-app-store.mobileprovision"
UPLOAD_PROPERTIES = "~/.config/draughts/app-store-connect.properties"
MIN_IOS = "16.0"
# Each data stack's address space. Goose reserves 2 GB a stack by default, and the app
# has 26 (goose build --stacks): 52 GB, more than an iOS process may map. 128 MB each is
# 3.3 GB, and the largest stack holds a few MB.
STACK_RESERVE = "128M"
# The simulator this script makes and uses: the size of the iPhone the app is tried on.
SIM_NAME = "Draughts iPhone 13 mini"
SIM_TYPE = "com.apple.CoreSimulator.SimDeviceType.iPhone-13-mini"
# The asset catalog's names: the icon, and the launch screen's colour.
APP_ICON = "AppIcon"
LAUNCH_COLOR = "LaunchBackground"
# The privacy manifest (store/app-store.md, "Privacy manifest"): the "required reason"
# APIs the binary imports, each with Apple's reason code; `nm -u` on a build lists them
# (docs/development.md). No tracking, no tracking domains, no data collected.
PRIVACY_APIS = {
    # stat, fstat: the metadata of files in the app's container (the players' files).
    "NSPrivacyAccessedAPICategoryFileTimestamp": ["C617.1"],
    # mach_absolute_time: time between events in the app (frames, animations, clocks).
    "NSPrivacyAccessedAPICategorySystemBootTime": ["35F9.1"],
}


def icon_background():
    """The shipped icon's background, the colour Android's window and splash take
    (android/res/values/colors.xml), as #rrggbb."""
    xml = (ROOT / "android/res/values/colors.xml").read_text()
    return "#" + re.search(r'name="icon_background">#([0-9a-fA-F]{6})<', xml).group(1).lower()


def apple_icon():
    """The shipped season's 1024 px icon, in git (ios/icon-1024.png), as scripts/icon.py
    writes it with android/res's foregrounds when the shipped season changes."""
    return icon.IOS_ICON


def asset_catalog(work, app, device):
    """The icon and the launch screen's colour as an asset catalog under work, compiled
    by actool into the bundle's Assets.car and its icon PNGs; returns the Info.plist keys
    actool says the bundle needs (CFBundleIcons and their iPad twin)."""
    catalog = work / "Assets.xcassets"
    if catalog.exists():
        shutil.rmtree(catalog)
    info = {"info": {"author": "xcode", "version": 1}}
    icons = catalog / f"{APP_ICON}.appiconset"
    icons.mkdir(parents=True)
    shutil.copy(apple_icon(), icons / "icon-1024.png")
    (icons / "Contents.json").write_text(json.dumps(dict(info, images=[
        {"filename": "icon-1024.png", "idiom": "universal", "platform": "ios",
         "size": "1024x1024"}]), indent=2))
    color = catalog / f"{LAUNCH_COLOR}.colorset"
    color.mkdir()
    rgb = icon_background()
    (color / "Contents.json").write_text(json.dumps(dict(info, colors=[
        {"idiom": "universal", "color": {"color-space": "srgb", "components": {
            "red": f"0x{rgb[1:3]}", "green": f"0x{rgb[3:5]}", "blue": f"0x{rgb[5:7]}",
            "alpha": "1.000"}}}]), indent=2))
    (catalog / "Contents.json").write_text(json.dumps(info, indent=2))
    partial = work / "assets-info.plist"
    run("xcrun", "actool", "--compile", app,
        "--platform", "iphoneos" if device else "iphonesimulator",
        "--minimum-deployment-target", MIN_IOS, "--target-device", "iphone",
        "--target-device", "ipad", "--app-icon", APP_ICON,
        "--output-partial-info-plist", partial, "--errors", "--warnings",
        "--output-format", "human-readable-text", catalog)
    with open(partial, "rb") as f:
        return plistlib.load(f)


def privacy_manifest(app):
    """PrivacyInfo.xcprivacy at the bundle's root: Apple refuses an upload without it."""
    manifest = {
        "NSPrivacyTracking": False,
        "NSPrivacyTrackingDomains": [],
        "NSPrivacyCollectedDataTypes": [],
        "NSPrivacyAccessedAPITypes": [
            {"NSPrivacyAccessedAPIType": api, "NSPrivacyAccessedAPITypeReasons": reasons}
            for api, reasons in PRIVACY_APIS.items()],
    }
    with open(app / "PrivacyInfo.xcprivacy", "wb") as f:
        plistlib.dump(manifest, f)


def write_bundle(app, exe, app_id, title, device, min_ios=MIN_IOS, label=""):
    """The .app: the executable, Info.plist, the launcher's name per language, the icon
    and the launch screen's colour (Assets.car), and the privacy manifest."""
    if app.exists():
        shutil.rmtree(app)
    app.mkdir(parents=True)
    shutil.copy(exe, app / title)
    assets = asset_catalog(app.parent, app, device)
    privacy_manifest(app)
    names = {lang: name + label for lang, name in app_names().items()}
    platform = "iPhoneOS" if device else "iPhoneSimulator"
    sdk = "iphoneos" if device else "iphonesimulator"
    sdk_version = run("xcrun", "--sdk", sdk, "--show-sdk-version", capture=True).strip()
    sdk_build = run("xcrun", "--sdk", sdk, "--show-sdk-build-version", capture=True).strip()
    # Xcode's version and build, as Xcode writes them ("2640", "17E192"): App Store
    # Connect reads them to hold uploads to its minimum Xcode and SDK.
    xcode = run("xcodebuild", "-version", capture=True).split()
    major, minor = (xcode[1].split(".") + ["0", "0"])[:2]
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
        "DTPlatformBuild": sdk_build,
        "DTSDKBuild": sdk_build,
        "DTXcode": f"{int(major):02d}{minor}0",
        "DTXcodeBuild": xcode[-1],
        "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
        "BuildMachineOSBuild": run("sw_vers", "-buildVersion", capture=True).strip(),
        "LSRequiresIPhoneOS": True,
        "MinimumOSVersion": min_ios,
        "UIDeviceFamily": [1, 2],
        "UIRequiredDeviceCapabilities": ["arm64", "metal"],
        # A launch screen makes iOS give the app the whole screen at its own size; without
        # one it runs letterboxed at an old iPhone's. Its colour is the icon's background,
        # as Android's splash.
        "UILaunchScreen": {"UIColorName": LAUNCH_COLOR},
        "CFBundleIconName": APP_ICON,
        "UIStatusBarHidden": True,
        # SDL asks for it to take a pointer (an iPad's trackpad, the simulator's mouse).
        "UIApplicationSupportsIndirectInputEvents": True,
        "UIViewControllerBasedStatusBarAppearance": True,
        "UISupportedInterfaceOrientations": [
            "UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft",
            "UIInterfaceOrientationLandscapeRight"],
        "UISupportedInterfaceOrientations~ipad": [
            "UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown",
            "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"],
        "ITSAppUsesNonExemptEncryption": False,
        **assets,
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


def goose_h(ngfx_dir):
    """The folder of the goose.h the compiler wrote for goose-ngfx's build on the Mac,
    which the ngfx build's C includes: Goose writes it only for the native parts it builds
    itself, so ngfx's Mac build (its blob compiler's, scripts/ngfx.py) comes first."""
    home = Path(os.environ.get("GOOSE_HOME", Path.home() / ".goose"))
    found = []
    for jit in home.glob("build/pkg/local/*/*/goose_jit_ngfx.dylib"):
        cache = jit.parent / "cmake/CMakeCache.txt"
        header = jit.parent / "include/goose.h"
        if header.exists() and cache.exists() and str(ngfx_dir) in cache.read_text(errors="replace"):
            found.append(header)
    if not found:
        sys.exit(f"no goose.h from a Mac build of {ngfx_dir}: run scripts/ngfx.py first")
    return max(found, key=lambda h: h.stat().st_mtime).parent


def identity():
    """The Mac's Apple Development signing identity: its SHA-1 and its team, the
    certificate's organizational unit. With several identities, as when an Apple ID of a
    company's team is in Xcode too, DRAUGHTS_IOS_TEAM picks one by its team id or its
    Apple ID, so the app is never signed into a team by chance. Neither is ever written
    into the repo."""
    out = run("security", "find-identity", "-v", "-p", "codesigning", capture=True)
    found = []
    for sha1, name in sorted(set(re.findall(r'([0-9A-F]{40}) "(Apple Development: [^"]+)"', out))):
        pem = run("security", "find-certificate", "-a", "-Z", "-p", "-c", name, capture=True)
        # The certificate whose SHA-1 is the identity's.
        block = pem[pem.index(f"SHA-1 hash: {sha1}"):]
        cert = block[block.index("-----BEGIN"):block.index("-----END CERTIFICATE-----") + 25]
        subject = subprocess.run(["openssl", "x509", "-noout", "-subject", "-nameopt",
                                  "sep_multiline"], input=cert, text=True,
                                 capture_output=True, check=True).stdout
        team = re.search(r"OU=(\w+)", subject)
        org = re.search(r"O=(.+)", subject)
        if team:
            found.append((sha1, team.group(1), name, org.group(1).strip() if org else ""))
    if not found:
        sys.exit("no Apple Development identity: sign in to Xcode with an Apple ID "
                 "(Settings → Accounts) and make one under Manage Certificates")
    want = os.environ.get("DRAUGHTS_IOS_TEAM")
    if want:
        found = [f for f in found if want == f[1] or want in f[2]]
    if len(found) != 1:
        listed = "\n".join(f"  {t}  {o}  {n}" for _, t, n, o in found)
        sys.exit(("no identity of DRAUGHTS_IOS_TEAM" if want and not found else
                  "several Apple Development identities: set DRAUGHTS_IOS_TEAM to the team "
                  "id or Apple ID of a personal one, never a company's") + "\n" + listed)
    return found[0][0], found[0][1]


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


def release_signing(app, out, app_id):
    """Signs the bundle for the App Store: the App Store profile (RELEASE_PROFILE, or
    DRAUGHTS_IOS_PROFILE), embedded, and the Apple Distribution identity whose certificate
    the profile names; the entitlements the app needs from the profile's, without its
    keychain wildcard. Neither file is in the repo."""
    path = Path(os.environ.get("DRAUGHTS_IOS_PROFILE", RELEASE_PROFILE)).expanduser()
    if not path.exists():
        sys.exit(f"no App Store profile at {path} (docs/development.md, \"Release builds\")")
    prof = plistlib.loads(run("security", "cms", "-D", "-i", path, capture=True).encode())
    ents = prof["Entitlements"]
    team = ents["com.apple.developer.team-identifier"]
    if ents["application-identifier"] != f"{team}.{app_id}" or prof.get("ProvisionedDevices") \
            or ents.get("get-task-allow"):
        sys.exit(f"{path} isn't an App Store profile for {app_id}")
    if prof["ExpirationDate"].timestamp() < time.time():
        sys.exit(f"{path} expired: make another (Certificates, Identifiers & Profiles)")
    # The profile's certificates' SHA-1s; the keychain's identity that is one of them.
    certs = {hashlib.sha1(c).hexdigest().upper() for c in prof["DeveloperCertificates"]}
    out_ids = run("security", "find-identity", "-v", "-p", "codesigning", capture=True)
    sha1 = next((h for h in re.findall(r"([0-9A-F]{40}) \"Apple Distribution", out_ids)
                 if h in certs), None)
    if not sha1:
        sys.exit(f"no Apple Distribution identity in the keychain for {path}'s certificate")
    shutil.copy(path, app / "embedded.mobileprovision")
    entitlements = out / "release-entitlements.plist"
    with open(entitlements, "wb") as f:
        plistlib.dump({k: ents[k] for k in ("application-identifier",
                      "com.apple.developer.team-identifier", "get-task-allow",
                      "beta-reports-active") if k in ents}, f)
    run("codesign", "--force", "--sign", sha1, "--entitlements", entitlements, app)
    run("codesign", "--verify", "--deep", "--strict", app)


def ipa(app, out):
    """The .ipa App Store Connect takes: the bundle in Payload/, zipped."""
    work = out / "ipa"
    if work.exists():
        shutil.rmtree(work)
    (work / "Payload").mkdir(parents=True)
    run("ditto", app, work / "Payload" / app.name)
    dest = out / app.with_suffix(".ipa").name
    dest.unlink(missing_ok=True)
    run("ditto", "-c", "-k", "--norsrc", "--keepParent", work / "Payload", dest)
    return dest


def upload(ipa_path):
    """Uploads the .ipa to App Store Connect with the API key whose ids
    UPLOAD_PROPERTIES holds; altool finds the key itself in ~/.private_keys/."""
    props = Path(os.environ.get("DRAUGHTS_ASC_PROPERTIES", UPLOAD_PROPERTIES)).expanduser()
    if not props.exists():
        sys.exit(f"no {props}: key_id= and issuer_id= of an App Store Connect API key")
    conf = dict(line.split("=", 1) for line in props.read_text().split() if "=" in line)
    run("xcrun", "altool", "--upload-app", "-t", "ios", "-f", ipa_path,
        "--apiKey", conf["key_id"], "--apiIssuer", conf["issuer_id"])


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
    ap.add_argument("--ngfx", action="store_true",
                    help="hold both renderers, gfx and goose-ngfx (NGFX, NGFX_SLANGC; scripts/ngfx.py), "
                         "one chosen at start, in place of the gfx build, under its id")
    ap.add_argument("--release", action="store_true",
                    help="build for the App Store: signed with the App Store profile, as an .ipa")
    ap.add_argument("--upload", action="store_true",
                    help="with --release, upload the .ipa to App Store Connect")
    args = ap.parse_args()
    if args.release:
        if args.run or args.shot or args.console or args.ngfx:
            sys.exit("a release build can't be run here: TestFlight installs it")
        args.device = True
    elif args.upload:
        sys.exit("--upload needs --release")
    program = args.program.resolve()
    name = program.stem
    app_id = BUNDLE_ID if name == "draughts" else f"{BUNDLE_ID}.{name}"
    title = "Draughts" if name == "draughts" else name
    out = ROOT / "build/ios" / name
    min_ios, label, ngfx_cmake = MIN_IOS, "", []
    if args.ngfx:
        # The tree holding both renderers (scripts/ngfx.py), its blobs made for iphoneos.
        import ngfx
        program = ngfx.ios_tree(program)
        # The gfx build's id: the iPhone wouldn't verify a new id of the team (2026-11-11),
        # so this replaces the gfx build, keeping its data, and the gfx build goes back on
        # to compare.
        out, label = out.with_name(name + "-ngfx"), " ngfx"
        # From MIN_IOS too: NoGraphicsAPI links Metal 4 weakly and fails at run time before
        # iOS 26, where gfx draws (docs/decisions/README.md, the stack).
        ngfx_cmake = [f"-DGOOSE_NGFX={ngfx.NGFX}", f"-DGOOSE_H_DIR={goose_h(ngfx.NGFX)}"]
    plat = "release" if args.release else "device" if args.device else "sim"
    gen, native = out / "gen", out / plat / "native"

    # 1. Goose to C.
    goose_to_c(program, gen, "--stack-reserve", STACK_RESERVE)

    # 2. goose_gfx's C layers and SDL, patched copies (native.py), then the executable.
    gfx_src, sdl_src = copy_sources(out, ROOT / "build/ios/SDL_src")
    run("cmake", "-S", ROOT / "ios", "-B", native, "-G", "Ninja",
        "-DCMAKE_SYSTEM_NAME=iOS",
        f"-DCMAKE_OSX_SYSROOT={'iphoneos' if args.device else 'iphonesimulator'}",
        "-DCMAKE_OSX_ARCHITECTURES=arm64",
        f"-DCMAKE_OSX_DEPLOYMENT_TARGET={min_ios}",
        "-DCMAKE_BUILD_TYPE=Release", *ngfx_cmake,
        f"-DGOOSE_PROGRAM_C={gen / 'program.c'}",
        f"-DGOOSE_RUNTIME_C={gen / 'goose_runtime.c'}",
        f"-DGOOSE_GFX_SRC={gfx_src}",
        f"-DSDL_SRC={sdl_src}",
        "-DGOOSE_PROGRAM_SOURCES=" + ";".join(map(str, sidecar(program, "c_sources"))),
        "-DGOOSE_PROGRAM_INCLUDE=" + ";".join(map(str, sidecar(program, "c_include"))))
    run("cmake", "--build", native, "--target", "main")

    # 3. The bundle, signed.
    app = out / plat / f"{title}.app"
    write_bundle(app, native / "main", app_id, title, args.device, min_ios, label)
    if args.release:
        release_signing(app, out / plat, app_id)
    elif args.device:
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
    # The commit it was built from, beside it, for the measurements that name their build
    # (scripts/ios_perf.py): "dirty" when the sources differed from it.
    head = subprocess.run(["git", "log", "-1", "--format=%h %cs"], cwd=ROOT, capture_output=True,
                          text=True).stdout.strip()
    dirty = subprocess.run(["git", "diff", "--quiet", "HEAD", "--", "src", "strings", "assets", "ios"],
                           cwd=ROOT).returncode != 0
    app.with_suffix(".commit").write_text(head + (" dirty" if dirty else "") + "\n")
    print(f"{app} ({sum(f.stat().st_size for f in app.rglob('*') if f.is_file()) // 1024} KB)")
    if args.release:
        dest = ipa(app, out)
        print(f"{dest} ({dest.stat().st_size // 1024} KB), {VERSION_NAME} ({BUILD_NUMBER})")
        if args.upload:
            upload(dest)
        return

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
