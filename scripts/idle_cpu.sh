#!/bin/sh
# Measure the app's CPU use while it sits idle: the CPU time of the thread running the
# Goose program (SDLThread) and of the whole process, and how often the program's thread
# went to sleep. Touch nothing while it runs. The app must be running.
#
#   scripts/idle_cpu.sh [seconds]      default 60
#
# An idle board should show a fraction of a percent and about one voluntary switch a
# second (frame()'s wait). A spinning loop shows near 100% and almost no voluntary
# switches.
P=$(sed -n 's/^APP_ID = "\(.*\)"/\1/p' "$(dirname "$0")/android.py")   # the application id
S=${1:-60}
pid=$(adb shell pidof $P | tr -d '\r')
[ -n "$pid" ] || { echo "$P is not running" >&2; exit 1; }
# The computer's worker (src/app/think.goose) is an SDLThread too, started later: take the
# first, the program's.
tid=$(adb shell "grep -l SDLThread /proc/$pid/task/*/comm" | tr -d '\r' | cut -d/ -f5 | sort -n | head -1)
sample() {
  adb shell "cut -d' ' -f14,15 /proc/$pid/task/$tid/stat; cut -d' ' -f14,15 /proc/$pid/stat;
    grep ^voluntary /proc/$pid/task/$tid/status" | tr -d '\r' | tr '\n' ' '
}
a=$(sample)
sleep "$S"
b=$(sample)
echo "$a $b" | LC_ALL=C awk -v s="$S" -v pid="$pid" '{
  t = ($7 + $8) - ($1 + $2); p = ($9 + $10) - ($3 + $4); w = $12 - $6
  printf "pid %s, %d s: program thread %.2f s CPU (%.2f%%), process %.2f s, %d voluntary switches\n",
    pid, s, t / 100, t / s, p / 100, w }'
