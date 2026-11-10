#!/bin/sh
# The README's performance row for each board on the Android device connected (or the
# one ANDROID_SERIAL names), the same game scene for both: Russian, wood, the start.
# With the release installed and the screen kept on (adb shell svc power stayon usb).
#
#   scripts/device_perf.sh [frames]     default 1000 (the bench's most)
#
# Per board: the bench (--bench N) once the device is cool, then the app opened again
# and left at rest, its idle CPU for 25 s (scripts/idle_cpu.sh) and its memory.
P=$(sed -n 's/^APP_ID = "\(.*\)"/\1/p' "$(dirname "$0")/native.py")   # the application id
N=${1:-1000}
A=$P/.DraughtsActivity
SCENE="--screen game --theme wood --variant russian"
cool() {
  while [ "$(adb shell dumpsys thermalservice | sed -n 's/^Thermal Status: //p' | tr -d '\r')" != 0 ]; do
    sleep 10
  done
}
for b in flat 3d; do
  echo "== $b"
  cool
  adb logcat -c
  adb shell am start -S -n $A --es args "'--board $b $SCENE --bench $N'" >/dev/null
  tag=bench2d; [ $b = 3d ] && tag=bench3d
  i=0
  while ! adb logcat -d | grep -q "$tag: summary\|bench2d: .*presented"; do
    i=$((i + 1)); [ $i -gt 120 ] && { echo "no $tag line" >&2; break; }
    sleep 2
  done
  adb logcat -d | grep -E "$tag: (summary|[0-9]+x)" | sed 's/.*bench/bench/'
  adb shell am start -S -n $A --es args "'--board $b $SCENE'" >/dev/null
  sleep 12
  "$(dirname "$0")/idle_cpu.sh" 25
  adb shell dumpsys meminfo $P | grep -E "GL mtrack|EGL mtrack|TOTAL PSS"
done
adb shell am start -S -n $A >/dev/null
