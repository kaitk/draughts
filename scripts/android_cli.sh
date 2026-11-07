#!/bin/sh
# Builds a headless Goose program (no gfx) as a plain Android executable, pushes it to
# the tablet, and runs it there with the arguments given, printing its output:
#
#   scripts/android_cli.sh tools/aibench.goose
#   scripts/android_cli.sh tools/perft.goose russian 9
#
# No APK and no SDL: the program's C and the Goose runtime's C, compiled with the NDK's
# clang at -O2 as `goose build` compiles them on the Mac, into build/android/cli/.
# GOOSE and ANDROID_NDK override the tools, as in scripts/android.py.
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
GOOSE=${GOOSE:-$root/build/goose-v2026.4-macos-arm64/goose}
SDK=${ANDROID_HOME:-$HOME/Library/Android/sdk}
NDK=${ANDROID_NDK:-$SDK/ndk/29.0.14206865}
CC=$(ls -d "$NDK"/toolchains/llvm/prebuilt/*/bin | head -1)/aarch64-linux-android29-clang

program=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
shift
name=$(basename "$program" .goose)
out=$root/build/android/cli/$name
mkdir -p "$out"
(cd "$(dirname "$program")" && "$GOOSE" -o "$out/program.c" "$program")
"$GOOSE" --emit-runtime "$out/goose_runtime.c"
"$CC" -O2 -w "$out/program.c" "$out/goose_runtime.c" -lm -o "$out/$name"
adb push -q "$out/$name" /data/local/tmp/ >/dev/null
adb shell "/data/local/tmp/$name $*"
