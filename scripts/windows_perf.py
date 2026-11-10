#!/usr/bin/env python3
"""Windows' rows of the README's performance table, as scripts/device_perf.sh takes an
Android device's and ios_perf.py the iPhone's: both boards full screen in the same game
scene (Russian, wood, the start).

    python scripts/windows_perf.py [frames]     default 1000; build first with
                                                scripts/windows.py src/app/draughts.goose
    BOARDS=3d python scripts/windows_perf.py    one board; REST=0 leaves the rest out
    EXE=build/ngfx/draughts.exe FLAGS="--aa smaa" python scripts/windows_perf.py
                                                another build, and flags added to each run

Per board: the bench (--bench N) with PresentMon recording the app's presents, and of
those between the bench's "presenting" and "presented" lines (stamped here as they
arrive) the frames that reached the display: frames per second on average and at the 1%
low, the time each stayed on screen (P50, P99), how many were dropped (never shown) or
held for more than one refresh, the GPU's busy time a frame, the latency from present
to display, and how Windows presented them (composed by DWM, or flipped straight to the
screen). Then the app at rest, its CPU time and private bytes as it counts them itself
(--rest 25).

PresentMon (github.com/GameTechDev/PresentMon, its command line exe) is
build/presentmon/PresentMon-*.exe, or PRESENTMON. It needs no admin rights here: it
attaches to the app by its process id once the app is running.
"""

import datetime
import os
import statistics
import subprocess
import sys
import tempfile
import threading
import time
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXE = (ROOT / os.environ.get("EXE", "build/windows/draughts.exe")).resolve()
SCENE = ["--size", "full", "--screen", "game", "--theme", "wood", "--variant", "russian",
         *os.environ.get("FLAGS", "").split()]
SESSION = "draughts_perf"


def presentmon():
    if os.environ.get("PRESENTMON"):
        return os.environ["PRESENTMON"]
    found = sorted((ROOT / "build/presentmon").glob("PresentMon-*.exe"))
    if not found:
        sys.exit("no PresentMon: download PresentMon-<version>-x64.exe from "
                 "github.com/GameTechDev/PresentMon/releases into build/presentmon/")
    return str(found[-1])


def launch(flags):
    """The app, its console lines stamped as they arrive: (local time, line)."""
    p = subprocess.Popen([str(EXE), *flags], cwd=EXE.parent, stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT, text=True)
    lines = []

    def read():
        for line in p.stdout:
            lines.append((datetime.datetime.now(), line.rstrip()))
    threading.Thread(target=read, daemon=True).start()
    return p, lines


def wait_for(lines, text, seconds):
    for _ in range(int(seconds * 10)):
        if any(text in line for _, line in lines):
            return True
        time.sleep(0.1)
    return False


def pct(xs, p):
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(p / 100 * len(xs)))]


def frames(board, n, work):
    tag = "bench2d" if board == "flat" else "bench3d"
    out = work / f"presentmon-{board}.csv"
    launched = datetime.datetime.now()
    p, lines = launch(["--board", board, *SCENE, "--bench", str(n)])
    pm = subprocess.Popen([presentmon(), "--process_id", str(p.pid), "--output_file", str(out),
                           "--date_time", "--no_console_stats", "--session_name", SESSION,
                           "--stop_existing_session"],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    ok = wait_for(lines, f"{tag}: presented", 120)
    subprocess.run([presentmon(), "--terminate_existing_session", "--session_name", SESSION],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    pm.wait(timeout=30)
    p.wait(timeout=60) if ok else p.kill()
    at = {k: t for t, line in lines for k in ("presenting", "presented") if f"{tag}: {k}" in line}
    if len(at) < 2:
        sys.exit(f"no {tag} lines from the app")
    lo = at["presenting"] + datetime.timedelta(seconds=0.1)
    hi = at["presented"] - datetime.timedelta(seconds=0.05)
    with open(out, encoding="utf-8-sig", newline="") as f:
        every = list(csv.DictReader(f))
    # "2026-11-10 12:05:01.123456789", to the microsecond for Python. PresentMon 2.6's
    # date is whole hours off local time here (its time zone), so its clock is put to the
    # app's launch, its first present a few seconds after it, by the nearest quarter hour.
    # Its hour has no leading zero before 10 ("2026-11-11 3:38:57.356"): pad it.
    def when(r):
        day, clock = r["CPUStartDateTime"].split(" ")
        return datetime.datetime.fromisoformat(f"{day} {clock.zfill(len(clock) + (clock.index(':') == 1))}"[:26])
    if not every:
        sys.exit("PresentMon counted no presents")
    off = datetime.timedelta(minutes=15 * round((when(every[0]) - launched).total_seconds() / 900))
    rows = [r for r in every if lo <= when(r) - off <= hi]
    if not rows:
        sys.exit("PresentMon counted no frames in the bench's presented phase")
    num = lambda r, k: float(r[k]) if r[k] not in ("", "NA") else None
    shown = [r for r in rows if num(r, "MsUntilDisplayed") is not None]
    gaps = [num(r, "MsBetweenDisplayChange") for r in shown if num(r, "MsBetweenDisplayChange")]
    period = statistics.median(gaps)
    held = sum(1 for g in gaps if g > 1.5 * period)
    gpu = [num(r, "MsGPUBusy") for r in rows if num(r, "MsGPUBusy") is not None]
    latency = [num(r, "MsUntilDisplayed") for r in shown]
    modes = {}
    for r in rows:
        modes[r["PresentMode"]] = modes.get(r["PresentMode"], 0) + 1
    # Each frame's time on screen in whole refreshes, as ios_perf.py counts them: the
    # flip's timestamps wobble by a fraction of a millisecond with nothing held.
    r = [max(1, round(g / period)) for g in gaps]
    p99 = pct(r, 99)
    print(f"display: {len(rows)} presents, {len(shown)} shown at {1000 / period:.0f} Hz: "
          f"avg {1000 * len(r) / (sum(r) * period):.1f} / 1% low {1000 / (p99 * period):.0f} fps, "
          f"frame time P50 {pct(r, 50) * period:.1f} / P99 {p99 * period:.1f} ms; "
          f"{len(rows) - len(shown)} dropped, {held} held over a refresh; "
          f"as timestamped P99 {pct(gaps, 99):.1f} ms")
    print(f"gpu busy P50 {pct(gpu, 50):.2f} / P99 {pct(gpu, 99):.2f} ms; present to display "
          f"P50 {pct(latency, 50):.1f} ms; {', '.join(f'{m} {k}' for m, k in modes.items())}")
    for _, line in lines:
        if f"{tag}: summary" in line:
            print(line[line.index(tag):])


def rest(board):
    """The app at rest: its own count of its CPU time and private bytes (--rest), which
    leaves the app running, so it is ended here once the line is out."""
    p, lines = launch(["--board", board, *SCENE, "--rest", "25"])
    if wait_for(lines, "process CPU", 90):
        for _, line in lines:
            if "rest: " in line:
                print(line[line.index("rest: "):])
    else:
        print("no rest line from the app")
    p.kill()
    p.wait()


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    if not EXE.exists():
        sys.exit(f"no {EXE}: python scripts/windows.py src/app/draughts.goose")
    work = Path(tempfile.mkdtemp(prefix="windows_perf_"))
    commit = subprocess.run(["git", "log", "-1", "--format=%h %cs", "--", "src"], cwd=ROOT,
                            capture_output=True, text=True).stdout.strip()
    print(f"build: {EXE.name} of {time.strftime('%Y-%m-%d %H:%M', time.localtime(EXE.stat().st_mtime))}"
          f" (src's last commit {commit})")
    for board in os.environ.get("BOARDS", "flat 3d").split():
        print("==", board)
        frames(board, n, work)
        if os.environ.get("REST", "1") != "0":
            rest(board)
        time.sleep(2)
    print("PresentMon's CSVs in", work)


if __name__ == "__main__":
    main()
