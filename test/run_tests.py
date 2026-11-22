#!/usr/bin/env python3
"""Runs the tests under test/<area>/, as goose-http's and plod's runners do.

Each test/<area>/<name>.goose is a program. Its stdout must be
test/expected/<area>/<name>.out, and it must exit 0. By default the tests run in
batches through the compiler's TinyCC, a `goose --multi-test` run per batch, but
for SLOW's, whose search TinyCC's code takes 9 to 28 s over, which each build at
-O2 at once beside the batches: about 20 s on a 10-core M-series Mac, against
60 s all through TinyCC (--tinycc). --build builds each with `goose build` (C at -O2) into
build/test/<area>/<name>/ and runs that instead, which is what the app ships.
Every failure is reported, with a count per area at the end.

--dump runs them with DRAUGHTS_TEST_VERBOSE=1, which makes the layout tests print the
coordinates, sizes, and quad counts they measured besides their checks (test/drive's
`verbose`), and writes each one's stdout to build/test/dump/<area>/<name>.out, comparing
nothing: diff two dumps to see a layout change by the pixel.

GOOSE names the compiler (default: the pinned release under build/).

    test/run_tests.py [-j JOBS] [--build | --tinycc] [--bless | --dump] [-v] [AREA | NAME ...]
"""

import argparse
import concurrent.futures
import difflib
import os
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
EXPECTED = HERE / "expected"
OUT = ROOT / "build" / "test"
DUMP = OUT / "dump"
RELEASE = ("goose-v2026.4-windows-x64/goose.exe" if os.name == "nt" else
           "goose-v2026.4-linux-x64/goose" if sys.platform.startswith("linux") else
           "goose-v2026.4-macos-arm64/goose")
GOOSE = os.environ.get("GOOSE", str(ROOT / "build" / RELEASE))
TIMEOUT = 300
# Directories under test/ that hold the tests' shared packages, not tests.
PACKAGES = {"drive"}
# The tests TinyCC's code runs longest, by area/name (seconds through TinyCC, and built
# at -O2 then run, on an M-series Mac, 2026-11-14): built at -O2 by default.
SLOW = {
    "game/aim",         # 28, 8
    "game/camera",      # 12, 8
    "game/pace",        # 12, 3
    "ai/blunders",      # 11, 2
    "ai/levels",        # 9, 2
    "puzzles/library",  # 9, 2
    "model3d/tree_whole",  # 5, 1
}
# What `goose --multi-test` ends each file's part of stdout and stderr with.
MULTIMARK = "==== goose --multi-test: exit"


def run(argv, cwd=ROOT):
    try:
        r = subprocess.run([str(a) for a in argv], cwd=cwd, capture_output=True, timeout=TIMEOUT)
    except subprocess.TimeoutExpired:
        return None, "", f"timed out after {TIMEOUT} s"
    text = lambda b: b.decode("utf-8", errors="replace").replace("\r\n", "\n")
    return r.returncode, text(r.stdout), text(r.stderr)


def split_multi(text, files):
    """{file: (exit code, what it printed)} for each file the stream marks."""
    parts, pos = {}, 0
    for f in files:
        m = re.compile(rf"\n?{re.escape(MULTIMARK)} (-?\d+) {re.escape(f)}\n").search(text, pos)
        if not m:
            break
        parts[f] = (int(m[1]), text[pos:m.start()])
        pos = m.end()
    return parts


def multi_test(files):
    """{file: (exit code, stdout, stderr)}, from one `goose --multi-test` run;
    a file that run didn't get through runs alone."""
    code, out, err = run([GOOSE, "--multi-test", *files])
    outs, errs = split_multi(out, files), split_multi(err, files)
    return {f: (outs[f][0], outs[f][1], errs[f][1]) if f in outs and f in errs
            else run([GOOSE, f]) for f in files}


def build_and_run(test):
    work = OUT / test.parent.name / test.stem
    if work.is_file():          # an executable of the old flat build/test/<name>/
        work.unlink()
    work.mkdir(parents=True, exist_ok=True)
    exe = work / test.stem
    code, out, err = run([GOOSE, "build", "-o", exe, test.relative_to(ROOT).as_posix()])
    if code != 0:
        return 1, "", "goose build failed\n" + out + err
    return run([exe], cwd=work)


def find_tests(names):
    tests = sorted(p for p in HERE.glob("*/*.goose") if p.parent != EXPECTED and p.parent.name not in PACKAGES)
    if names:
        wanted = {Path(n).stem for n in names}
        tests = [t for t in tests if t.stem in wanted or t.parent.name in wanted]
        if not tests:
            sys.exit(f"no test or area named {', '.join(names)}")
    return tests


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("names", nargs="*", metavar="AREA | NAME")
    ap.add_argument("-j", "--jobs", type=int, default=os.cpu_count() or 1)
    ap.add_argument("--build", action="store_true", help="build each natively and run that")
    ap.add_argument("--tinycc", action="store_true", help="run SLOW's through TinyCC too")
    ap.add_argument("--bless", action="store_true", help="write each run's stdout as expected")
    ap.add_argument("--dump", action="store_true", help="run verbose, writing each stdout to build/test/dump/")
    ap.add_argument("-v", "--verbose", action="store_true", help="print the passes too")
    args = ap.parse_args()
    if args.dump:
        os.environ["DRAUGHTS_TEST_VERBOSE"] = "1"
        DUMP.mkdir(parents=True, exist_ok=True)

    tests = find_tests(args.names)
    key = lambda t: f"{t.parent.name}/{t.stem}"
    built = (tests if args.build else [] if args.tinycc else
             [t for t in tests if key(t) in SLOW])
    batched = [t for t in tests if t not in built]
    with concurrent.futures.ThreadPoolExecutor(args.jobs) as pool:
        # The builds go in first, the longest work, then the batches fill the other workers.
        builds = [pool.submit(build_and_run, t) for t in built]
        files = [t.relative_to(ROOT).as_posix() for t in batched]
        workers = max(1, args.jobs - len(built))
        size = max(1, -(-len(files) // workers))
        done = {}
        for part in pool.map(multi_test, [files[i:i + size] for i in range(0, len(files), size)]):
            done.update(part)
        results = {t: done[t.relative_to(ROOT).as_posix()] for t in batched}
        results.update(zip(built, (f.result() for f in builds)))

    failed = set()
    for t in tests:
        code, out, err = results[t]
        name = key(t)
        expected = EXPECTED / t.parent.name / f"{t.stem}.out"
        got = out.rstrip("\n")
        problem, detail = None, ""
        if code != 0:
            problem, detail = f"exit {code}", out + err
        elif args.dump:
            (DUMP / t.parent.name).mkdir(exist_ok=True)
            (DUMP / t.parent.name / f"{t.stem}.out").write_bytes((got + "\n").encode("utf-8"))
        elif args.bless:
            if not expected.exists() or expected.read_text(encoding="utf-8").rstrip("\n") != got:
                expected.parent.mkdir(exist_ok=True)
                expected.write_bytes((got + "\n").encode("utf-8"))
                print(f"blessed {expected.relative_to(ROOT)}")
        elif not expected.exists():
            problem = f"no {expected.relative_to(ROOT)}"
        else:
            want = expected.read_text(encoding="utf-8").rstrip("\n")
            if got != want:
                problem = "stdout differs"
                detail = "\n".join(difflib.unified_diff(want.splitlines(), got.splitlines(),
                                                        "expected", "got", lineterm=""))
        if problem:
            failed.add(t)
            print(f"FAIL {name}: {problem}")
            if detail.strip():
                print("    " + detail.strip().replace("\n", "\n    "))
        elif args.verbose:
            print(f"ok   {name}")

    for area in sorted({t.parent.name for t in tests}):
        n = sum(1 for t in tests if t.parent.name == area)
        bad = sum(1 for t in failed if t.parent.name == area)
        print(f"== {area}: {n - bad} passed" + (f", {bad} failed" if bad else ""))
    how = ("built at -O2" if args.build else
           f"through TinyCC, {len(built)} built at -O2" if built else "through TinyCC")
    print(f"== {len(tests)} tests {how}: " + (f"{len(failed)} failed" if failed else "all passed"))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
