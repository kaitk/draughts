#!/usr/bin/env python3
"""Times the light tuner's room on an Android device, view by view and part by part.

    python tools/perf/tablet_room_bench.py [--serial S] [--seconds 24] [--views corner,room]
        [--variants base,scale75] [--extra "--scene-scale 0.5"] [--out build/perf/tablet-room/results.json]

The tuner (scripts/android.py tools/light_tune.goose --run) runs in its touch walk with the
phone's tier, so each run starts it with the view's camera and the variant's flags and
--fps-seconds, which prints the frame counter each half second and quits. The first
intervals hold the bakes and the GPU filling, so a run's figure is the median of its last
half. The base runs again at the end, so a device that warmed up shows it. --extra goes on
every run (a phone's bigger screen split at half the scale). The tuner holds itself in
landscape on Android (src/native/tuner_landscape.c), so a phone frames the views as a tablet.

The views are agents/perf.md's. The variants each leave one part out (or change the scale),
so the split says what each costs; parts overlap, so they don't add up.
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
SDK = Path(os.environ.get("ANDROID_HOME", Path(os.environ.get("LOCALAPPDATA", "")) / "Android/Sdk"
                          if os.name == "nt" else Path.home() / "Library/Android/sdk"))
ADB = str(SDK / "platform-tools" / ("adb.exe" if os.name == "nt" else "adb"))
PACKAGE = "io.github.kaitk.draughts.light_tune"
ACTIVITY = f"{PACKAGE}/io.github.kaitk.draughts.DraughtsActivity"

VIEWS = {
    "down":   "--plan-eye 6.0,3.0,1.7 --plan-at 6.0,3.05,0",
    "corner": "--plan-eye 8.4,0.6,1.6 --plan-at 2.0,5.0,0.5",
    "room":   "--view room",
    "menu":   "--view table-window",
}
VARIANTS = {
    "base":        "",
    "scale75":     "--scene-scale 0.75",
    "scale50":     "--scene-scale 0.5",
    "no-outside":  "--outside off",
    "no-books":    "--books off",
    "no-pattern":  "--window off",
    "no-shell":    "--shell off",
    "no-room":     "--room-surfaces off",
    "no-box":      "--box off",
    "aa-off":      "--aa off",
    "smaa":        "--aa smaa",
    "msaa":        "--aa msaa",
    "wind-still":  "--wind-kind still",
    "cheap":       "--window off --box off --aa off",
    "full-tier":   "--tier full",
    "map-off":     "--window-map off",
    "leaves-off":  "--phone-leaves off",
}
LINE = re.compile(r"light_tune: ([\d.]+) fps, ([\d.]+) ms a frame, worst ([\d.]+); in the loop ([\d.]+) ms")


def adb(serial, *args, check=True):
    return subprocess.run([ADB, "-s", serial, *args], text=True, capture_output=True, check=check).stdout


def run_one(serial, flags, seconds):
    adb(serial, "shell", "am", "force-stop", PACKAGE)
    adb(serial, "logcat", "-c")
    args = f"{flags} --fps-seconds {seconds}".strip()
    adb(serial, "shell", "am", "start", "-n", ACTIVITY, "--es", "args", f"'{args}'")
    # The loop ends after --fps-seconds, but on Android the process stays: done once the
    # lines have stopped coming for a few seconds (or the process went).
    deadline = time.time() + seconds + 60
    last, quiet = 0, 0
    while time.time() < deadline:
        time.sleep(2)
        if not adb(serial, "shell", "pidof", PACKAGE, check=False).strip():
            break
        n = len(LINE.findall(adb(serial, "logcat", "-d", "-s", "goose")))
        quiet = quiet + 1 if n == last and n > 0 else 0
        last = n
        if quiet >= 3:
            break
    log = adb(serial, "logcat", "-d", "-s", "goose")
    adb(serial, "shell", "am", "force-stop", PACKAGE)
    rows = [tuple(float(x) for x in m.groups()) for m in LINE.finditer(log)]
    if not rows:
        return None
    steady = rows[len(rows) // 2:]
    return {
        "intervals": len(rows),
        "fps": statistics.median(r[0] for r in steady),
        "ms": statistics.median(r[1] for r in steady),
        "worst_ms": max(r[2] for r in steady),
        "loop_ms": statistics.median(r[3] for r in steady),
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--serial", default=os.environ.get("ANDROID_SERIAL", ""))
    ap.add_argument("--seconds", type=int, default=24)
    ap.add_argument("--views", default=",".join(VIEWS))
    ap.add_argument("--variants", default=",".join(VARIANTS))
    ap.add_argument("--extra", default="", help="flags added to every run")
    ap.add_argument("--out", type=Path, default=ROOT / "build/perf/tablet-room/results.json")
    a = ap.parse_args()
    serial = a.serial or adb_default()
    model = adb(serial, "shell", "getprop", "ro.product.model").strip()
    results = {"device": model, "seconds": a.seconds, "extra": a.extra, "runs": []}
    variants = a.variants.split(",")
    plan = [(v, var) for v in a.views.split(",") for var in variants]
    if "base" in variants:
        plan += [(v, "base") for v in a.views.split(",")]
    for view, variant in plan:
        flags = " ".join(f for f in (VIEWS[view], VARIANTS[variant], a.extra) if f)
        r = run_one(serial, flags, a.seconds)
        row = {"view": view, "variant": variant, "flags": flags, **(r or {"error": "no frame lines"})}
        results["runs"].append(row)
        print(json.dumps(row), flush=True)
    a.out.parent.mkdir(parents=True, exist_ok=True)
    a.out.write_text(json.dumps(results, indent=1))
    print(a.out)


def adb_default():
    out = subprocess.run([ADB, "devices"], text=True, capture_output=True).stdout
    ids = [l.split()[0] for l in out.splitlines()[1:] if l.strip().endswith("device")]
    if len(ids) != 1:
        sys.exit(f"one device, or --serial: {ids}")
    return ids[0]


if __name__ == "__main__":
    main()
