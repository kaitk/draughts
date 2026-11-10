#!/bin/sh
# The README's performance rows for the Android device connected (or the one
# ANDROID_SERIAL names), on both boards in the same game scene: Russian, wood, the start.
# With the release installed and the screen kept on (adb shell svc power stayon true).
#
#   scripts/device_perf.sh [frames]     default 1000 (the bench's most)
#   BOARDS=flat scripts/device_perf.sh  one board only (flat or 3d)
#
# Per board, once the device is cool: the bench (--bench N), and over its presented
# frames the compositor's own count (SurfaceFlinger's timestats): how long each frame
# stayed on screen, which no clock in the app can tell. From that: frames per second on
# average and at the 1% low (the 99th percentile's frame), the frame time's P50 and P99,
# and how many frames were dropped (the one before on screen for more than one refresh). Then the app
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
# Which build is measured: the installed APK, matched against the release built here
# (build/android/draughts/draughts-release.apk) and the commit it was built from.
apk=$(adb shell pm path $P | sed -n 's/^package://p' | tr -d '\r' | head -1)
sum=$(adb shell sha256sum "$apk" | cut -d' ' -f1)
built="$(dirname "$0")/../build/android/draughts/draughts-release.apk"
if [ -f "$built" ] && [ "$(shasum -a 256 "$built" | cut -d' ' -f1)" = "$sum" ]; then
  echo "build: the release built here from $(cat "${built%.apk}.commit" 2>/dev/null || echo 'an unrecorded commit'), sha256 $(echo $sum | cut -c1-12)"
else
  echo "build: not the release built here (sha256 $(echo $sum | cut -c1-12)), installed $(adb shell dumpsys package $P | sed -n 's/^ *lastUpdateTime=//p' | tr -d '\r')"
fi
adb shell getprop ro.product.model | tr -d '\r' | sed 's/^/device: /'
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
  # The app's layer with the most frames (the dump can hold an earlier run's, and the
  # SurfaceView's background); its histogram is in whole ms, so the rates count refreshes:
  # a frame on screen for k refreshes takes k, and none is faster than the display.
  dump="${TMPDIR:-/tmp}/device_perf_timestats.txt"
  adb shell dumpsys SurfaceFlinger --timestats -dump > "$dump"
  LC_ALL=C awk -v app="$P/" '
    /^layerName/ { on = index($0, app) > 0 && index($0, "SurfaceView") > 0 && index($0, "Background") == 0; k++ }
    on && /^displayRefreshRate/ { hz[k] = $3 }
    on && /^present2present histogram/ { getline; hist[k] = $0 }
    END {
      best = 0; most = -1
      for (j in hist) {
        n = split(hist[j], a, " "); s = 0
        for (i = 1; i <= n; i++) { split(a[i], kv, "="); s += kv[2] }
        if (s > most) { most = s; best = j }
      }
      if (most <= 0 || !hz[best]) { print "compositor: no frames counted"; exit }
      period = 1000 / hz[best]
      n = split(hist[best], a, " "); total = 0; refreshes = 0; dropped = 0
      for (i = 1; i <= n; i++) {
        split(a[i], kv, "="); ms[i] = kv[1] + 0; c[i] = kv[2] + 0
        r[i] = int(ms[i] / period + 0.5); if (r[i] < 1) r[i] = 1
        total += c[i]; refreshes += r[i] * c[i]; if (r[i] > 1) dropped += c[i]
      }
      seen = 0; p50 = 0; p99 = 0
      for (i = 1; i <= n; i++) {
        seen += c[i]
        if (!p50 && seen >= 0.50 * total) p50 = r[i]
        if (!p99 && seen >= 0.99 * total) p99 = r[i]
      }
      printf "compositor: %d frames at %d Hz: avg %.1f / 1%% low %.0f fps, frame time P50 %.1f / P99 %.1f ms, %d dropped (%.1f%%)\n",
        total, hz[best], hz[best] * total / refreshes, hz[best] / p99, p50 * period, p99 * period, dropped, 100 * dropped / total }' "$dump"
  adb shell dumpsys SurfaceFlinger --timestats -disable >/dev/null
  await "$tag: summar[y]"
  adb logcat -d | grep -E "$tag: (summary,|[0-9]+x)" | sed 's/.*bench/bench/'
  adb shell am start -S -n $A --es args "'--board $b $SCENE'" >/dev/null
  sleep 12
  "$(dirname "$0")/idle_cpu.sh" 25
  adb shell dumpsys meminfo $P | grep -E "GL mtrack|EGL mtrack|TOTAL PSS"
done
adb shell am start -S -n $A >/dev/null
