#!/usr/bin/env python3
"""Build a Goose program into an Android APK, without Gradle, and optionally install it.

    scripts/android.py poc/poc.goose             build build/android/<name>.apk
    scripts/android.py poc/poc.goose --run       build, install over adb, and start it

Steps: Goose writes the program's C and the runtime's C; goose_gfx's sources are copied
and patches/goose_gfx applied; CMake with the NDK builds
libSDL3.so and libmain.so (android/CMakeLists.txt); javac and d8 compile SDL's stock Java
glue; aapt2 links the manifest; zip adds the dex and the stripped libraries, the libraries
stored uncompressed; zipalign aligns them to 16 KB; apksigner signs with the debug key.

Tools come from the environment or the defaults below: GOOSE, ANDROID_HOME, ANDROID_NDK,
ANDROID_BUILD_TOOLS, ANDROID_PLATFORM. docs/development.md lists the versions.
"""
import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SDK = Path(os.environ.get("ANDROID_HOME", Path.home() / "Library/Android/sdk"))
NDK = Path(os.environ.get("ANDROID_NDK", SDK / "ndk/29.0.14206865"))
BUILD_TOOLS = Path(os.environ.get("ANDROID_BUILD_TOOLS", SDK / "build-tools/36.0.0"))
PLATFORM = Path(os.environ.get("ANDROID_PLATFORM", SDK / "platforms/android-36"))
GOOSE = Path(os.environ.get("GOOSE", ROOT / "build/goose-v2026.4-macos-arm64/goose"))
SDL = ROOT / "third_party/goose_gfx/third_party/SDL"
PACKAGE = "com.kaitk.kabe"
MIN_SDK = "29"
TARGET_SDK = "36"


def run(*cmd, cwd=None):
    print("+", " ".join(str(c) for c in cmd), flush=True)
    subprocess.run([str(c) for c in cmd], cwd=cwd, check=True)


def llvm_bin(name):
    hosts = sorted((NDK / "toolchains/llvm/prebuilt").iterdir())
    return hosts[0] / "bin" / name


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("program", type=Path)
    ap.add_argument("--run", action="store_true", help="install over adb and start it")
    args = ap.parse_args()
    program = args.program.resolve()
    name = program.stem
    out = ROOT / "build/android" / name
    gen, native, apk_dir = out / "gen", out / "native", out / "apk"
    gen.mkdir(parents=True, exist_ok=True)

    # 1. Goose to C.
    run(GOOSE, "-o", gen / "program.c", program, cwd=program.parent)
    run(GOOSE, "--emit-runtime", gen / "goose_runtime.c")

    # 2. goose_gfx's C layers with patches/goose_gfx applied, then libSDL3.so and libmain.so.
    gfx_src = out / "goose_gfx_src"
    fresh = out / "goose_gfx_src.new"
    if fresh.exists():
        shutil.rmtree(fresh)
    shutil.copytree(ROOT / "third_party/goose_gfx/src", fresh / "src")
    for patch in sorted((ROOT / "patches/goose_gfx").glob("*.patch")):
        run("patch", "-s", "-p1", "-i", patch, cwd=fresh)
    if gfx_src.exists():
        shutil.rmtree(gfx_src)
    fresh.rename(gfx_src)
    if not (native / "build.ninja").exists():
        run("cmake", "-S", ROOT / "android", "-B", native, "-G", "Ninja",
            f"-DCMAKE_TOOLCHAIN_FILE={NDK / 'build/cmake/android.toolchain.cmake'}",
            "-DANDROID_ABI=arm64-v8a", f"-DANDROID_PLATFORM=android-{MIN_SDK}",
            "-DCMAKE_BUILD_TYPE=Release",
            f"-DGOOSE_PROGRAM_C={gen / 'program.c'}",
            f"-DGOOSE_RUNTIME_C={gen / 'goose_runtime.c'}",
            f"-DGOOSE_GFX_SRC={gfx_src / 'src'}")
    run("cmake", "--build", native, "--target", "main")

    # 3. The APK's tree: stripped libraries and SDL's Java as dex.
    if apk_dir.exists():
        shutil.rmtree(apk_dir)
    libs = apk_dir / "lib/arm64-v8a"
    libs.mkdir(parents=True)
    for so in (native / "libmain.so", native / "SDL/libSDL3.so"):
        run(llvm_bin("llvm-strip"), "--strip-unneeded", so, "-o", libs / so.name)

    android_jar = PLATFORM / "android.jar"
    classes = out / "classes"
    if classes.exists():
        shutil.rmtree(classes)
    classes.mkdir()
    java = sorted(str(p) for p in (SDL / "android-project/app/src/main/java").rglob("*.java"))
    run("javac", "-nowarn", "-Xlint:-options", "-source", "8", "-target", "8",
        "-bootclasspath", android_jar, "-d", classes, *java)
    run(BUILD_TOOLS / "d8", "--release", "--min-api", MIN_SDK, "--lib", android_jar,
        "--output", apk_dir, *sorted(str(p) for p in classes.rglob("*.class")))

    # 4. Link, add, align, sign.
    unaligned = out / f"{name}-unaligned.apk"
    aligned = out / f"{name}.apk"
    run(BUILD_TOOLS / "aapt2", "link", "-o", unaligned, "--manifest",
        ROOT / "android/AndroidManifest.xml", "-I", android_jar,
        "--min-sdk-version", MIN_SDK, "--target-sdk-version", TARGET_SDK)
    run("zip", "-q", unaligned, "classes.dex", cwd=apk_dir)
    run("zip", "-q", "-0", "-r", unaligned, "lib", cwd=apk_dir)
    run(BUILD_TOOLS / "zipalign", "-f", "-P", "16", "4", unaligned, aligned)
    keystore = Path.home() / ".android/debug.keystore"
    if not keystore.exists():
        keystore.parent.mkdir(exist_ok=True)
        run("keytool", "-genkeypair", "-keystore", keystore, "-storepass", "android",
            "-alias", "androiddebugkey", "-keypass", "android", "-keyalg", "RSA",
            "-validity", "10000", "-dname", "CN=Android Debug,O=Android,C=US")
    run(BUILD_TOOLS / "apksigner", "sign", "--ks", keystore, "--ks-pass", "pass:android",
        aligned)
    unaligned.unlink()
    print(f"{aligned} ({aligned.stat().st_size // 1024} KB)")

    if args.run:
        run("adb", "install", "-r", aligned)
        run("adb", "shell", "am", "start", "-n", f"{PACKAGE}/org.libsdl.app.SDLActivity")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as e:
        sys.exit(e.returncode)
