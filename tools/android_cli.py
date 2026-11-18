#!/usr/bin/env python3
"""Build a headless Goose program (no gfx) as a plain Android executable, push it to the
device, and run it there with the arguments given, printing its output:

    tools/android_cli.py tools/aibench.goose
    tools/android_cli.py tools/perft.goose russian 9

No APK and no SDL: the program's C and the Goose runtime's C (scripts/native.py's
goose_to_c), compiled with the NDK's clang at -O2 as `goose build` compiles them on the
Mac, into build/android/cli/<program>/. The tools are scripts/android.py's (GOOSE,
ANDROID_HOME, ANDROID_NDK).
"""
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from android import ADB, MIN_SDK, llvm_bin  # noqa: E402
from native import ROOT, goose_to_c, run  # noqa: E402


def build(program):
    """build/android/cli/<name>/<name>, for arm64 Android."""
    out = ROOT / "build/android/cli" / program.stem
    goose_to_c(program, out)
    exe = out / program.stem
    run(llvm_bin(f"aarch64-linux-android{MIN_SDK}-clang"), "-O2", "-w", out / "program.c",
        out / "goose_runtime.c", "-lm", "-o", exe)
    return exe


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    exe = build(Path(sys.argv[1]).resolve())
    run(ADB, "push", "-q", exe, "/data/local/tmp/")
    command = " ".join([f"/data/local/tmp/{exe.name}", *sys.argv[2:]])
    sys.exit(subprocess.run([str(ADB), "shell", command]).returncode)


if __name__ == "__main__":
    main()
