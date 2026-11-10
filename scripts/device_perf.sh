#!/bin/sh
# The README's performance rows for the Android device connected (or the one
# ANDROID_SERIAL names), on both boards in the same game scene: Russian, wood, the start.
# With the release installed and the screen kept on (adb shell svc power stayon usb).
#
#   scripts/device_perf.sh [frames]     default 1000 (the bench's most)
#   BOARDS=flat scripts/device_perf.sh  one board only (flat or 3d)
#
# Per board, once the device is cool: the bench (--bench N), and over its presented
# frames the compositor's own count (SurfaceFlinger's timestats): how long each frame
# stayed on screen, which no clock in the app can tell. From that: frames per second on
# average and at the 1% low (the 99th percentile's frame), the frame time's P50 and P99,
# and how many frames missed their refresh (on screen for more than one). Then the app
# opened again and left at rest: its idle CPU for 25 s (scripts/idle_cpu.sh) and memory.
P=$(sed -n 's/^APP_ID = "\(.*\)"/\1/p' "$(dirname "$0")/native.py")   # the application id
N=${1:-1000}
A=$P/.DraughtsActivity
SCENE="--screen game --theme wood --variant russian"
cool() {
  while [ "$(adb shell dumpsys thermalservice | sed -n 's/^Thermal Status: //p' | tr -d '\r')" != 0 ]; do
    sleep 10
  done
}
# Blocks until the program logs a line matching $1, a pattern that doesn't match itself
# (a bracketed last letter), as adbd logs the command with it.
await() { adb logcat -m 1 -e "$1" >/dev/null; }
for b in ${BOARDS:-flat 3d}; do
  echo "== $b"
  cool
  tag=bench2d; [ $b = 3d ] && tag=bench3d
  adb logcat -c
  adb shell dumpsys SurfaceFlinger --timestats -enable >/dev/null
  adb shell am start -S -n $A --es args "'--board $b $SCENE --bench $N'" >/dev/null
  await "$tag: presentin[g]"
  adb shell dumpsys SurfaceFlinger --timestats -clear >/dev/null
  await "$tag: presente[d]"
  adb shell dumpsys SurfaceFlinger --timestats -dump | LC_ALL=C awk -v app="$P/" '
    /^layerName/ { on = index($0, app) > 0 && index($0, "SurfaceView") > 0 }
    on && /^averageFPS/ { avg = $3 }
    on && /^displayRefreshRate/ { hz = $3 }
    on && /^present2present histogram/ { getline; hist = $0 }
    END {
      n = split(hist, a, " "); total = 0
      for (i = 1; i <= n; i++) { split(a[i], kv, "="); ms[i] = kv[1] + 0; c[i] = kv[2] + 0; total += c[i] }
      if (total == 0) { print "no frames counted"; exit }
      period = 1000 / hz; missed = 0; seen = 0; p50 = 0; p99 = 0
      for (i = 1; i <= n; i++) {
        if (ms[i] > 1.5 * period) missed += c[i]
        seen += c[i]
        if (!p50 && seen >= 0.50 * total) p50 = ms[i]
        if (!p99 && seen >= 0.99 * total) p99 = ms[i]
      }
      printf "compositor: %d frames at %s Hz: avg %.1f / 1%% low %.0f fps, frame time P50 %d / P99 %d ms, %d missed a refresh (%.1f%%)\n",
        total, hz, avg, 1000 / p99, p50, p99, missed, 100 * missed / total }'
  adb shell dumpsys SurfaceFlinger --timestats -disable >/dev/null
  await "$tag: summar[y]"
  adb logcat -d | grep -E "$tag: (summary,|[0-9]+x)" | sed 's/.*bench/bench/'
  adb shell am start -S -n $A --es args "'--board $b $SCENE'" >/dev/null
  sleep 12
  "$(dirname "$0")/idle_cpu.sh" 25
  adb shell dumpsys meminfo $P | grep -E "GL mtrack|EGL mtrack|TOTAL PSS"
done
adb shell am start -S -n $A >/dev/null
