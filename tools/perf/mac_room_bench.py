#!/usr/bin/env python3
"""Times light tuner builds on the Mac, headless, before and after alternated.

    python3 tools/perf/mac_room_bench.py BEFORE AFTER [MORE ...]
        [--views table,corner] [--sizes 3840x2160] [--rounds 2] [--seconds 6]
        [--extra "--aa off"] [--full] [--who TAG] [--out FILE.json]

The quick check (the default, about a minute for two builds) is for a small change such as
a new prop: one view with the object in it, the corner only if the change can reach it
(`--views table,corner`), one size, two rounds of A B A B. --full is the long batch for
optimizing work: agents/perf.md's four views at both of the user's screens, two rounds,
about ten minutes for two builds.

Each run is the tuner with `--fps-seconds`, which prints the frame time each half second
and quits. The first three lines hold the start and the GPU filling, so a run's figure is
the median of the rest. A fresh binary's first runs are slow all through (26 to 38 ms
against 12.6 warm, 2026-11-25), so each build first runs 3 s at 640 x 360 in the first
view, which warms it. Holds build/perf/quiet.lock (agents/perf.md, "Measuring") for the whole
batch, waiting while another holds it.

Two runs of one build agree to about 0.3 ms at 3840 x 2160 (2026-11-25): a difference
under that is noise, and the spread printed beside each mean says how much there was.
"""
import argparse
import json
import os
import re
import statistics
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOCK = Path("/Users/kaitkasak/projects/personal/draughts/build/perf/quiet.lock")

# agents/perf.md's views, and the games table's front, where the props stand.
VIEWS = {
    "down":   "--plan-eye 6.0,3.0,1.7 --plan-at 6.0,3.05,0",
    "corner": "--plan-eye 8.4,0.6,1.6 --plan-at 2.0,5.0,0.5",
    "room":   "--view room",
    "menu":   "--view table-window",
    "table":  "--plan-eye 4.4,3.6,1.4 --plan-at 4.4,5.8,0.5",
}
FULL_VIEWS = ["down", "corner", "room", "menu"]
FULL_SIZES = ["3840x2160", "5120x2880"]
LINE = re.compile(r"light_tune: [\d.]+ fps, ([\d.]+) ms a frame")
SKIP = 3


def take_lock(who):
    LOCK.parent.mkdir(parents=True, exist_ok=True)
    told = False
    while True:
        try:
            fd = os.open(LOCK, os.O_WRONLY | os.O_CREAT | os.O_EXCL)
        except FileExistsError:
            if not told:
                print(f"waiting for {LOCK}: {LOCK.read_text().strip()}", flush=True)
                told = True
            time.sleep(30)
            continue
        os.write(fd, f"{os.getpid()} {int(time.time())} {who}\n".encode())
        os.close(fd)
        return


def drop_lock(who):
    try:
        if LOCK.read_text().split()[-1] == who:
            LOCK.unlink()
    except (FileNotFoundError, IndexError):
        pass


def run_one(exe, size, flags, seconds):
    """The median ms a frame of one run, or None if it printed too few lines."""
    argv = [str(exe), "--size", size, *flags.split(), "--fps-seconds", str(seconds)]
    env = dict(os.environ, GOOSE_GFX_HEADLESS="1", LC_ALL="C")
    try:
        r = subprocess.run(argv, cwd=ROOT / "tools", env=env, stdin=subprocess.DEVNULL,
                           capture_output=True, text=True, timeout=seconds + 120)
    except subprocess.TimeoutExpired:
        return None
    ms = [float(m[1]) for m in LINE.finditer(r.stdout + r.stderr)][SKIP:]
    return statistics.median(ms) if ms else None


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("builds", nargs="+", help="tuner executables, the first the baseline")
    ap.add_argument("--views", help="names from VIEWS, comma-separated (quick: table)")
    ap.add_argument("--sizes", help="comma-separated (quick: 3840x2160)")
    ap.add_argument("--rounds", type=int, default=2)
    ap.add_argument("--seconds", type=float, help="of frames a run (quick 6, full 5)")
    ap.add_argument("--extra", default="", help="flags for every run")
    ap.add_argument("--full", action="store_true", help="the long batch: four views, two sizes")
    ap.add_argument("--who", default="mac-room-bench", help="the lock's tag")
    ap.add_argument("--out", help="write the runs as JSON")
    args = ap.parse_args()

    builds = [Path(b).resolve() for b in args.builds]
    for b in builds:
        if not os.access(b, os.X_OK):
            sys.exit(f"not an executable: {b}")
    views = args.views.split(",") if args.views else FULL_VIEWS if args.full else ["table"]
    for v in views:
        if v not in VIEWS:
            sys.exit(f"no view {v}: {', '.join(VIEWS)}")
    sizes = args.sizes.split(",") if args.sizes else FULL_SIZES if args.full else ["3840x2160"]
    seconds = args.seconds or (5 if args.full else 6)
    names = [b.name for b in builds]
    if len(set(names)) < len(names):
        names = [str(b) for b in builds]

    took = time.time()
    take_lock(args.who)
    runs = []
    try:
        for b in builds:
            run_one(b, "640x360", f"{VIEWS[views[0]]} {args.extra}", 3)
        for rnd in range(1, args.rounds + 1):
            for size in sizes:
                for v in views:
                    for name, b in zip(names, builds):
                        ms = run_one(b, size, f"{VIEWS[v]} {args.extra}", seconds)
                        runs.append({"round": rnd, "size": size, "view": v, "build": name, "ms": ms})
                        print(f"{rnd} {size} {v:6} {name}: " + (f"{ms:.2f} ms" if ms else "no figure"),
                              flush=True)
    finally:
        drop_lock(args.who)

    print(f"\n== {time.time() - took:.0f} s; mean ms a frame (spread between rounds)")
    head = f"{'size':10} {'view':6} " + " ".join(f"{n[-22:]:>22}" for n in names)
    print(head + ("   change" if len(builds) > 1 else ""))
    for size in sizes:
        for v in views:
            cells, means = [], []
            for n in names:
                ms = [r["ms"] for r in runs if r["size"] == size and r["view"] == v
                      and r["build"] == n and r["ms"]]
                mean = statistics.mean(ms) if ms else None
                means.append(mean)
                cells.append(f"{mean:7.2f} (±{(max(ms) - min(ms)) / 2:.2f})" if ms else "      none")
            line = f"{size:10} {v:6} " + " ".join(f"{c:>22}" for c in cells)
            if len(builds) > 1 and means[0] and means[-1]:
                d = means[-1] - means[0]
                line += f"   {d:+.2f} ms ({100 * d / means[0]:+.1f}%)"
            print(line)
    if args.out:
        Path(args.out).write_text(json.dumps(runs, indent=1) + "\n")


if __name__ == "__main__":
    main()
