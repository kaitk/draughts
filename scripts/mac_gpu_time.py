#!/usr/bin/env python3
"""The 3D board's GPU time a frame on the Mac, from Instruments' Metal System Trace: the
measure tasks 070, 071, and 077 compare the renderers by (agents/testing.md, Frame pacing).

    scripts/mac_gpu_time.py EXE [flags...]    record EXE's 3D bench full screen and print
    scripts/mac_gpu_time.py --trace T PROC N  read a trace already recorded

EXE runs `--size full --screen game --variant russian --theme wood --board 3d --no-vsync
--bench 300` and the flags after it (`--aa off`, say), under `xctrace record` with a
watchdog, as a record can hang after its app exits. From the trace: the bench's loop
phase, the third of its last 4 × N presents (src/app/draw3d.goose's Bench); the union of
the process's GPU intervals over it a frame (whatever their depth, which is Instruments
stacking what runs at once, not nesting); the overlap, their sum over the union; and the
GPU's performance states over the same window. Compare builds at the same states (full
screen runs at Maximum), three traces each, interleaved. The trace is deleted after.
"""
import os
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

N = 300
FLAGS = ["--size", "full", "--screen", "game", "--variant", "russian", "--theme", "wood", "--board", "3d",
         "--no-vsync", "--bench", str(N)]


def rows(trace, schema):
    """The table's rows, each a list of its cells with xctrace's id/ref sharing resolved."""
    x = subprocess.run(["xcrun", "xctrace", "export", "--input", trace, "--xpath",
                        f'/trace-toc/run[@number="1"]/data/table[@schema="{schema}"]'],
                       capture_output=True, check=True).stdout
    ids = {}

    def res(e):
        r = e.get("ref")
        if r is not None:
            return ids[r]
        if e.get("id") is not None:
            ids[e.get("id")] = e
        for c in e:
            res(c)
        return e
    for row in ET.fromstring(x).iter("row"):
        yield [res(c) for c in row]


def measure(trace, proc, n=N):
    def ours(e):
        return e.tag == "process" and e.get("fmt", "").startswith(proc + " ")
    pres = sorted(int(r[0].text) for r in rows(trace, "ca-client-present-request") if ours(r[6]))
    if len(pres) < 4 * n:
        sys.exit(f"{len(pres)} presents of {proc}, fewer than the bench's 4 × {n}")
    last = pres[-4 * n:]
    lo, hi = last[2 * n], last[3 * n - 1]
    frames = n - 1
    iv = sorted((max(s, lo), min(s + d, hi)) for s, d in
                ((int(r[0].text), int(r[1].text)) for r in rows(trace, "metal-gpu-intervals") if ours(r[10]))
                if min(s + d, hi) > max(s, lo))
    total = sum(b - a for a, b in iv)
    union, cur = 0, None
    for a, b in iv:
        if cur is None or a > cur[1]:
            if cur:
                union += cur[1] - cur[0]
            cur = [a, b]
        else:
            cur[1] = max(cur[1], b)
    if cur:
        union += cur[1] - cur[0]
    states = {}
    for r in rows(trace, "gpu-performance-state-intervals"):
        s, d = int(r[0].text), int(r[1].text)
        if min(s + d, hi) > max(s, lo):
            states[r[2].text] = states.get(r[2].text, 0) + min(s + d, hi) - max(s, lo)
    st = ", ".join(f"{k} {100 * v / (hi - lo):.0f}%" for k, v in sorted(states.items(), key=lambda kv: -kv[1]) if v)
    return f"{union / frames / 1e6:.2f} ms a frame, overlap × {total / max(union, 1):.2f}, {frames} frames [{st}]"


def main():
    a = sys.argv[1:]
    if a[:1] == ["--trace"]:
        print(measure(a[1], a[2], int(a[3])))
        return
    if not a:
        sys.exit(__doc__)
    exe = os.path.abspath(a[0])
    d = tempfile.mkdtemp()
    trace = os.path.join(d, "t.trace")
    try:
        cmd = ["xcrun", "xctrace", "record", "--template", "Metal System Trace", "--output", trace,
               "--launch", "--", exe, *FLAGS, *a[1:]]
        try:
            subprocess.run(cmd, cwd=d, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=150)
        except subprocess.TimeoutExpired:
            print("xctrace hung after the app; reading what it saved", file=sys.stderr)
        print(measure(trace, os.path.basename(exe)))
    finally:
        shutil.rmtree(d, ignore_errors=True)


if __name__ == "__main__":
    main()
