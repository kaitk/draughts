#!/usr/bin/env python3
"""The iPhone's rows of the README's performance table, as scripts/device_perf.sh takes
an Android device's: both boards in the same game scene (Russian, wood, the start).

    scripts/ios_perf.py [frames]        default 1000; the development build installed
                                        (scripts/ios.py src/app/draughts.goose --device --run)

Per board: the bench (--bench N) with Instruments' Animation Hitches recorded through it,
and from its displayed-surfaces table the frames that reached the display between the
bench's "presenting" and "presented" lines (stamped on the Mac as they arrive): frames
per second on average and at the 1% low, the frame time's P50 and P99, and how many were
dropped (the one before on screen for more than one refresh). Then the app at rest, its
CPU time and memory footprint as it counts them itself (--rest 25). The device is the one scripts/ios.py
picks (DRAUGHTS_IOS_DEVICE to choose); keep it unlocked with Auto-Lock off. Instruments
sometimes can't reach the phone right after devicectl used it ("timed out waiting for
device to boot"): the script retries, and reconnecting the cable clears it.
"""

import datetime
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from ios import BUNDLE_ID as APP_ID, device  # noqa: E402
from native import ROOT  # noqa: E402

SCENE = ["--screen", "game", "--theme", "wood", "--variant", "russian"]
HZ = 60.0   # the iPhone 13 mini's display; ProMotion phones would need theirs read


def launch(dev, flags, console=False):
    cmd = ["xcrun", "devicectl", "device", "process", "launch", "--device", dev,
           "--terminate-existing", *(["--console"] if console else []), APP_ID, *flags]
    if not console:
        subprocess.run(cmd, capture_output=True, check=True)
        return None, []
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    lines = []      # (ms since the epoch, line)

    def read():
        for line in p.stdout:
            lines.append((time.time() * 1000.0, line.rstrip()))
    threading.Thread(target=read, daemon=True).start()
    return p, lines


def record(udid, template, out, seconds, attach="Draughts", tries=10, until=None):
    """An Instruments recording, ended early (as Ctrl-C does) once `until()` holds; retried
    while Instruments can't find the app or reach the phone."""
    for _ in range(tries):
        time.sleep(1)
        shutil.rmtree(out, ignore_errors=True)    # a failed try may leave it begun
        p = subprocess.Popen(["xcrun", "xctrace", "record", "--template", template, "--device", udid,
                              "--attach", attach, "--time-limit", f"{seconds}s", "--output", out],
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        while p.poll() is None:
            if until and until():
                time.sleep(1)
                p.send_signal(signal.SIGINT)
                break
            time.sleep(0.5)
        log = p.communicate()[0]
        if "saved" in log:
            return
        time.sleep(4)
    sys.exit(f"Instruments couldn't record: {log.strip().splitlines()[-1]}")


def table(trace, schema):
    """An exported table's rows, each a list of its cells' values (ids resolved)."""
    xml = subprocess.run(["xcrun", "xctrace", "export", "--input", trace, "--xpath",
                          f'/trace-toc/run[@number="1"]/data/table[@schema="{schema}"]'],
                         capture_output=True, text=True, check=True).stdout
    ids, rows = {}, []

    def val(e):
        if e.get("ref"):
            return ids[e.get("ref")]
        for c in e:
            val(c)
        if e.get("id"):
            ids[e.get("id")] = e.text
        return e.text
    for row in ET.fromstring(xml).iter("row"):
        rows.append([val(c) for c in row])
    return rows


def started(trace):
    toc = subprocess.run(["xcrun", "xctrace", "export", "--input", trace, "--toc"],
                         capture_output=True, text=True, check=True).stdout
    date = toc.split("<start-date>")[1].split("</start-date>")[0]
    return datetime.datetime.fromisoformat(date).timestamp() * 1000.0


def frames(board, dev, udid, n, work):
    tag = "bench2d" if board == "flat" else "bench3d"
    trace = str(work / f"hitches-{board}.trace")
    p, lines = launch(dev, ["--board", board, *SCENE, "--bench", str(n)], console=True)
    record(udid, "Animation Hitches", trace, 30 + n * 6 // 100,
           until=lambda: any(f"{tag}: presented" in line for _, line in lines))
    p.terminate()
    at = {k: t for t, line in lines for k in ("presenting", "presented") if f"{tag}: {k}" in line}
    if len(at) < 2:
        sys.exit(f"no {tag} lines in the console")
    t0 = started(trace)
    lo, hi = (at["presenting"] - t0) / 1000 + 0.15, (at["presented"] - t0) / 1000 - 0.1
    period = 1000.0 / HZ
    r = sorted(max(1, round(float(row[1]) / 1e6 / period))
               for row in table(trace, "displayed-surfaces-interval")
               if lo <= float(row[0]) / 1e9 <= hi)
    if not r:
        sys.exit("no frames counted")
    k = len(r)
    p50, p99 = r[(k - 1) // 2], r[min(k - 1, int(0.99 * k))]
    dropped = sum(1 for x in r if x > 1)
    print(f"display: {k} frames at {HZ:.0f} Hz: avg {HZ * k / sum(r):.1f} / 1% low {HZ / p99:.0f} fps, "
          f"frame time P50 {p50 * period:.1f} / P99 {p99 * period:.1f} ms, "
          f"{dropped} dropped ({100 * dropped / k:.1f}%)")
    for _, line in lines:
        if f"{tag}: summary" in line:
            print(line[line.index(tag):])


def rest(board, dev):
    """The app at rest: its own count of its CPU time and footprint (--rest), as
    Instruments' Activity Monitor can't reach the phone reliably after devicectl."""
    p, lines = launch(dev, ["--board", board, *SCENE, "--rest", "25"], console=True)
    for _ in range(90):
        time.sleep(1)
        done = [line for _, line in lines if "process CPU" in line]
        if done:
            time.sleep(1)
            for _, line in lines:
                if "rest: " in line:
                    print(line[line.index("rest: "):])
            break
    else:
        print("no rest line in the console")
    p.terminate()


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    dev, udid = device()
    work = Path(tempfile.mkdtemp(prefix="ios_perf_"))
    commit = ROOT / "build/ios/draughts/device/Draughts.commit"
    print("build:", commit.read_text().strip() if commit.exists() else "the development build installed")
    for board in os.environ.get("BOARDS", "flat 3d").split():
        print("==", board)
        frames(board, dev, udid, n, work)
        rest(board, dev)
    print("traces in", work)


if __name__ == "__main__":
    main()
