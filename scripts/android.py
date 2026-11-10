#!/usr/bin/env python3
"""Build a Goose program into an Android APK, without Gradle, and optionally install it.

    scripts/android.py poc/poc.goose             build build/android/<name>/<name>.apk
    scripts/android.py poc/poc.goose --run       build, install over adb, and start it
    scripts/android.py src/app/draughts.goose --release
                                                 <name>-release.apk and <name>-release.aab
                                                 beside it, signed with the upload key, for Play

Steps: Goose writes the program's C and the runtime's C; goose_gfx's sources are copied
and patches/goose_gfx applied, and SDL is copied and patches/SDL applied; CMake with the
NDK builds
libSDL3.so and libmain.so (android/CMakeLists.txt); javac and d8 compile SDL's Java
glue from the patched copy and DraughtsActivity; aapt2 compiles android/res (the icon and the theme) and the
launcher's name per language (res/values*/strings.xml, written from strings/<lang>.txt's
app.name) and links them with the manifest, giving it APP_ID and the version; zip adds the dex and
the stripped libraries, the libraries stored uncompressed; zipalign aligns them to 16 KB;
apksigner signs with the debug key, or with --release the upload key. A release also links
the resources in protobuf form and packs them, the dex, and the libraries into the bundle's
base module; bundletool builds the AAB, its libraries stored uncompressed and aligned to
16 KB, and validates it; jarsigner signs it with the upload key. Every library's ELF
segments, the APK, and the APKs bundletool makes from the AAB for an arm64 device are
checked for 16 KB pages.

The upload key is read from ~/.config/draughts/upload-key.properties (DRAUGHTS_UPLOAD_KEY
overrides the path), which names the keystore, its alias, and its password;
docs/development.md says how it was made and how to back it up. bundletool is
build/bundletool-VERSION/, downloaded from its GitHub release and checked against its
SHA-256 when missing.

Tools come from the environment or the defaults below: GOOSE, ANDROID_HOME, ANDROID_NDK,
ANDROID_BUILD_TOOLS, ANDROID_PLATFORM. docs/development.md lists the versions.
"""
import argparse
import hashlib
import os
import shutil
import subprocess
import struct
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

from native import (APP_ID, ROOT, VERSION_NAME, WINDOWS, app_names, copy_sources, goose_to_c,
                    run, sidecar)

SDK = Path(os.environ.get("ANDROID_HOME", Path(os.environ.get("LOCALAPPDATA", "")) / "Android/Sdk"
                          if WINDOWS else Path.home() / "Library/Android/sdk"))
NDK = Path(os.environ.get("ANDROID_NDK", SDK / "ndk/29.0.14206865"))
BUILD_TOOLS = Path(os.environ.get("ANDROID_BUILD_TOOLS", SDK / "build-tools/36.0.0"))
PLATFORM = Path(os.environ.get("ANDROID_PLATFORM", SDK / "platforms/android-36"))
# The application id is native.APP_ID. aapt2's --rename-manifest-package gives it to the
# app, so that line alone sets it; the Java code's package (android/java/) is the same name,
# which lets `adb shell am start -n ID/.DraughtsActivity` work, and needs no change if the
# id ever does before the first upload. The versionName is native.VERSION_NAME.
ACTIVITY = "io.github.kaitk.draughts.DraughtsActivity"
VERSION_CODE = 1          # raised for every upload to Play
MIN_SDK = "29"
TARGET_SDK = "36"         # what Play requires of new apps and updates from 2026-08-31
UPLOAD_KEY = Path(os.environ.get("DRAUGHTS_UPLOAD_KEY",
                                 Path.home() / ".config/draughts/upload-key.properties"))
BUNDLETOOL_VERSION = "1.18.3"
BUNDLETOOL_SHA256 = "a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29"
PAGE = 16384              # the page size Play requires native libraries to be aligned to
# The SDK's Java tools are batch files on Windows.
D8 = BUILD_TOOLS / ("d8.bat" if WINDOWS else "d8")
APKSIGNER = BUILD_TOOLS / ("apksigner.bat" if WINDOWS else "apksigner")
ADB = shutil.which("adb") or SDK / "platform-tools/adb"


def upload_key():
    """The upload keystore, its alias, and its password, from UPLOAD_KEY's properties."""
    if not UPLOAD_KEY.exists():
        sys.exit(f"{UPLOAD_KEY} is missing: docs/development.md says how the upload key is made")
    props = dict(line.split("=", 1) for line in UPLOAD_KEY.read_text().splitlines()
                 if "=" in line and not line.startswith("#"))
    if props.get("keyPassword", props["storePassword"]) != props["storePassword"]:
        sys.exit(f"{UPLOAD_KEY}: the key's password must be the store's (PKCS12)")
    return Path(props["storeFile"]).expanduser(), props["keyAlias"], props["storePassword"]


def bundletool():
    """build/bundletool-VERSION/bundletool-all-VERSION.jar, downloaded and checked if missing."""
    jar = ROOT / f"build/bundletool-{BUNDLETOOL_VERSION}/bundletool-all-{BUNDLETOOL_VERSION}.jar"
    if not jar.exists():
        url = (f"https://github.com/google/bundletool/releases/download/{BUNDLETOOL_VERSION}/"
               f"bundletool-all-{BUNDLETOOL_VERSION}.jar")
        print(f"+ download {url}", flush=True)
        data = urllib.request.urlopen(url).read()
        if hashlib.sha256(data).hexdigest() != BUNDLETOOL_SHA256:
            sys.exit(f"{url}: not the SHA-256 pinned in scripts/android.py")
        jar.parent.mkdir(parents=True, exist_ok=True)
        jar.write_bytes(data)
    return jar


def check_elf_pages(so):
    """Exit unless every LOAD segment of a 64-bit ELF library is aligned to 16 KB pages."""
    data = so.read_bytes()
    if data[:5] != b"\x7fELF\x02":
        sys.exit(f"{so}: not a 64-bit ELF")
    phoff, = struct.unpack_from("<Q", data, 0x20)
    phentsize, phnum = struct.unpack_from("<HH", data, 0x36)
    for i in range(phnum):
        p_type, = struct.unpack_from("<I", data, phoff + i * phentsize)
        p_align, = struct.unpack_from("<Q", data, phoff + i * phentsize + 0x30)
        if p_type == 1 and p_align < PAGE:  # PT_LOAD
            sys.exit(f"{so}: a LOAD segment aligned to {p_align}, not {PAGE}")


def check_zip_pages(apk):
    """Exit unless the APK's libraries are stored uncompressed at 16 KB page offsets."""
    run(BUILD_TOOLS / "zipalign", "-c", "-P", str(PAGE // 1024), "4", apk)
    with zipfile.ZipFile(apk) as z:
        for info in z.infolist():
            if info.filename.endswith(".so") and info.compress_type != zipfile.ZIP_STORED:
                sys.exit(f"{apk}: {info.filename} is compressed")


def llvm_bin(name):
    hosts = sorted((NDK / "toolchains/llvm/prebuilt").iterdir())
    return hosts[0] / "bin" / name


def android_text(text):
    """A string for strings.xml: XML escaped, and Android's own escapes for \\, quotes, and
    a leading @ or ?."""
    text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    text = text.replace("\\", "\\\\").replace("'", "\\'").replace('"', '\\"')
    if text[:1] in ("@", "?"):
        text = "\\" + text
    return text


def write_app_names(res_dir):
    """res/values/strings.xml from strings/en.txt and res/values-<lang>/strings.xml from
    every other strings/<lang>.txt, each holding app_name, the file's app.name."""
    if res_dir.exists():
        shutil.rmtree(res_dir)
    for lang, name in app_names().items():
        folder = res_dir / ("values" if lang == "en" else f"values-{lang}")
        folder.mkdir(parents=True)
        (folder / "strings.xml").write_text(
            '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
            f'    <string name="app_name">{android_text(name)}</string>\n'
            '</resources>\n', encoding="utf-8")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("program", type=Path)
    ap.add_argument("--run", action="store_true", help="install over adb and start it")
    ap.add_argument("--id-suffix", default="",
                    help="append .SUFFIX to the application id, to install a test build beside the app")
    ap.add_argument("--release", action="store_true",
                    help="sign with the upload key and build the AAB beside the APK")
    args = ap.parse_args()
    program = args.program.resolve()
    name = program.stem
    # Another program (a prototype in poc/) gets its own id, so it installs beside the app.
    app_id = APP_ID if name == "draughts" else f"{APP_ID}.{name}"
    if args.id_suffix: app_id += "." + args.id_suffix
    out = ROOT / "build/android" / name
    gen, native, apk_dir = out / "gen", out / "native", out / "apk"

    # 1. Goose to C.
    goose_to_c(program, gen)

    # 2. goose_gfx's C layers and SDL, patched copies (native.py), then libSDL3.so and
    # libmain.so.
    gfx_src, sdl_src = copy_sources(out, ROOT / "build/android/SDL_src")
    # Configured every time, so a change to the sidecar is seen; it is quick once done.
    run("cmake", "-S", ROOT / "android", "-B", native, "-G", "Ninja",
        f"-DCMAKE_TOOLCHAIN_FILE={NDK / 'build/cmake/android.toolchain.cmake'}",
        "-DANDROID_ABI=arm64-v8a", f"-DANDROID_PLATFORM=android-{MIN_SDK}",
        "-DCMAKE_BUILD_TYPE=Release",
        f"-DGOOSE_PROGRAM_C={gen / 'program.c'}",
        f"-DGOOSE_RUNTIME_C={gen / 'goose_runtime.c'}",
        f"-DGOOSE_GFX_SRC={gfx_src}",
        f"-DSDL_SRC={sdl_src}",
        "-DGOOSE_PROGRAM_SOURCES=" + ";".join(map(str, sidecar(program, "c_sources"))),
        "-DGOOSE_PROGRAM_INCLUDE=" + ";".join(map(str, sidecar(program, "c_include"))))
    run("cmake", "--build", native, "--target", "main")

    # 3. The APK's tree: stripped libraries and SDL's Java as dex.
    if apk_dir.exists():
        shutil.rmtree(apk_dir)
    libs = apk_dir / "lib/arm64-v8a"
    libs.mkdir(parents=True)
    for so in (native / "libmain.so", native / "SDL/libSDL3.so"):
        run(llvm_bin("llvm-strip"), "--strip-unneeded", so, "-o", libs / so.name)
        check_elf_pages(libs / so.name)

    android_jar = PLATFORM / "android.jar"
    classes = out / "classes"
    if classes.exists():
        shutil.rmtree(classes)
    classes.mkdir()
    # SDL's Java from the patched copy, as its C is (patches/SDL).
    java = sorted(str(p) for p in (sdl_src / "android-project/app/src/main/java").rglob("*.java"))
    java += sorted(str(p) for p in (ROOT / "android/java").rglob("*.java"))
    run("javac", "-nowarn", "-Xlint:-options", "-source", "8", "-target", "8",
        "-bootclasspath", android_jar, "-d", classes, *java)
    run(D8, "--release", "--min-api", MIN_SDK, "--lib", android_jar,
        "--output", apk_dir, *sorted(str(p) for p in classes.rglob("*.class")))

    # 4. Link, add, align, sign.
    suffix = "-release" if args.release else ""
    unaligned = out / f"{name}-unaligned.apk"
    aligned = out / f"{name}{suffix}.apk"
    res = out / "res.zip"
    names_dir, names = out / "res_strings", out / "res_strings.zip"
    write_app_names(names_dir)
    run(BUILD_TOOLS / "aapt2", "compile", "--dir", ROOT / "android/res", "-o", res)
    run(BUILD_TOOLS / "aapt2", "compile", "--dir", names_dir, "-o", names)
    link = [BUILD_TOOLS / "aapt2", "link", "--manifest", ROOT / "android/AndroidManifest.xml",
            "-I", android_jar, res, names, "--rename-manifest-package", app_id,
            "--version-code", VERSION_CODE, "--version-name", VERSION_NAME,
            "--min-sdk-version", MIN_SDK, "--target-sdk-version", TARGET_SDK]
    run(*link, "-o", unaligned)
    with zipfile.ZipFile(unaligned, "a", zipfile.ZIP_DEFLATED) as z:
        z.write(apk_dir / "classes.dex", "classes.dex")
        for so in sorted(libs.iterdir()):
            z.write(so, f"lib/arm64-v8a/{so.name}", zipfile.ZIP_STORED)
    run(BUILD_TOOLS / "zipalign", "-f", "-P", PAGE // 1024, "4", unaligned, aligned)
    if args.release:
        # The password reaches the tools through the environment, never the command line.
        keystore, alias, password = upload_key()
        key_env = {"DRAUGHTS_UPLOAD_PASS": password}
        run(APKSIGNER, "sign", "--ks", keystore, "--ks-key-alias", alias,
            "--ks-pass", "env:DRAUGHTS_UPLOAD_PASS", aligned, env=key_env)
    else:
        keystore = Path.home() / ".android/debug.keystore"
        if not keystore.exists():
            keystore.parent.mkdir(exist_ok=True)
            run("keytool", "-genkeypair", "-keystore", keystore, "-storepass", "android",
                "-alias", "androiddebugkey", "-keypass", "android", "-keyalg", "RSA",
                "-validity", "10000", "-dname", "CN=Android Debug,O=Android,C=US")
        run(APKSIGNER, "sign", "--ks", keystore, "--ks-pass", "pass:android",
            aligned)
    unaligned.unlink()
    check_zip_pages(aligned)
    print(f"{aligned} ({aligned.stat().st_size // 1024} KB)")

    # 5. A release's bundle: the base module in the bundle's layout (manifest/, dex/, lib/,
    # res/, resources.pb, the resources in protobuf form), built, validated, and signed.
    if args.release:
        proto, module = out / "proto.apk", out / "base.zip"
        aab = out / f"{name}-release.aab"
        run(*link, "--proto-format", "-o", proto)
        with zipfile.ZipFile(proto) as src, \
                zipfile.ZipFile(module, "w", zipfile.ZIP_DEFLATED) as z:
            for info in src.infolist():
                path = ("manifest/AndroidManifest.xml" if info.filename == "AndroidManifest.xml"
                        else info.filename)
                z.writestr(path, src.read(info))
            z.write(apk_dir / "classes.dex", "dex/classes.dex")
            for so in sorted(libs.iterdir()):
                z.write(so, f"lib/arm64-v8a/{so.name}")
        config = out / "bundle-config.json"
        config.write_text('{"optimizations": {"uncompressNativeLibraries": '
                          '{"enabled": true, "alignment": "PAGE_ALIGNMENT_16K"}}}\n')
        tool = bundletool()
        run("java", "-jar", tool, "build-bundle", f"--modules={module}", f"--config={config}",
            f"--output={aab}", "--overwrite")
        run("jarsigner", "-sigalg", "SHA256withRSA", "-digestalg", "SHA-256", "-keystore",
            keystore, "-storepass:env", "DRAUGHTS_UPLOAD_PASS", aab, alias, env=key_env)
        run("java", "-jar", tool, "validate", f"--bundle={aab}")
        # The APKs Play would serve from it to an arm64 device: their libraries stored and
        # on 16 KB pages. Signed with the debug key, if any; they are only looked at.
        with tempfile.TemporaryDirectory() as tmp:
            apks, splits = Path(tmp) / "app.apks", Path(tmp) / "splits"
            spec = Path(tmp) / "device.json"
            spec.write_text('{"supportedAbis": ["arm64-v8a"], "supportedLocales": ["en"], '
                            '"screenDensity": 240, "sdkVersion": 36}\n')
            run("java", "-jar", tool, "build-apks", f"--bundle={aab}", f"--output={apks}",
                f"--device-spec={spec}")
            with zipfile.ZipFile(apks) as z:
                z.extractall(splits)
            with_libs = [a for a in sorted(splits.rglob("*.apk"))
                         if any(n.endswith(".so") for n in zipfile.ZipFile(a).namelist())]
            if not with_libs:
                sys.exit(f"{aab}: no APK bundletool made from it has the libraries")
            for a in with_libs:
                check_zip_pages(a)
        print(f"{aab} ({aab.stat().st_size // 1024} KB)")

    if args.run:
        # Never uninstalls: that deletes the app's data. A build signed with another key
        # (another machine's debug key, or the upload key's release) can't install over it.
        r = run(ADB, "install", "-r", aligned, capture=True, check=False)
        print(r, flush=True)
        if "INSTALL_FAILED_UPDATE_INCOMPATIBLE" in r or "Success" not in r:
            sys.exit(f"not installed. If the installed {app_id} is signed with another key, "
                     "install beside it with --id-suffix; uninstalling it deletes its data")
        run(ADB, "shell", "am", "start", "-n", f"{app_id}/{ACTIVITY}")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as e:
        sys.exit(e.returncode)
