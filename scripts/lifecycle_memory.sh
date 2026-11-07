#!/bin/sh
# Measure the app's memory over Android lifecycle cycles: each cycle sends it home and
# resumes it, then rotates it to portrait and back. Prints PSS, native heap and graphics
# memory (KB) and the pid after each cycle, then any errors in logcat. The rotation
# settings are restored at the end. The app must be running.
#
#   scripts/lifecycle_memory.sh [cycles]      default 20
P=com.kaitk.kabe
A=$P/.KabeActivity
N=${1:-20}
acc=$(adb shell settings get system accelerometer_rotation)
rot=$(adb shell settings get system user_rotation)
trap 'adb shell settings put system user_rotation $rot; adb shell settings put system accelerometer_rotation $acc' EXIT
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 0
adb logcat -c
row() {
  adb shell dumpsys meminfo $P | awk -v c="$1" -v pid="$(adb shell pidof $P)" '
    /TOTAL PSS:/ { pss = $3 } /Native Heap:/ && !nat { nat = $3 } /Graphics:/ && !g { g = $2 }
    END { print c, pss, nat, g, pid }'
}
echo "cycle pss_kb native_kb graphics_kb pid"
row 0
i=1
while [ $i -le $N ]; do
  adb shell input keyevent KEYCODE_HOME; sleep 1.5
  adb shell am start -n $A >/dev/null 2>&1; sleep 1.5
  adb shell settings put system user_rotation 1; sleep 1.5
  adb shell settings put system user_rotation 0; sleep 1.5
  row $i
  i=$((i + 1))
done
echo "errors in logcat:"
adb logcat -d -s goose:* SDL:* AndroidRuntime:E DEBUG:* | grep -iE "error|fatal|crash|abort|fail"
true
