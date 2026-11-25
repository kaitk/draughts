#!/bin/sh
# scripts/test.sh [quick]
#
# Every check, stopping at the first that fails, about 35 s on a 10-core M-series Mac.
# `quick` stops after step 2, run with --quick (about 15 s): the tests of the rules, the
# computer, the puzzles, and the board's aim and camera left out (LONG in
# test/run_tests.py), for a change to the 3D scene, the UI, or the tools. Run all of it
# after a change to src/rules/, src/ai/, src/puzzles/, src/board/, or src/game/, and before
# pushing; CI runs all of it.
#
# 0. scripts/strings_keys.py --check: strings/keys.goose is what strings/en.txt makes;
#    scripts/check_roots.py: the ngfx root and its sidecar hold all the gfx root's.
# 1. goose check of the app: every shader its embed_shader calls compile, as the app's
#    build compiles them (a GLSL error is a Goose compile error), in half a second.
#    With NGFX set, the root holding goose-ngfx too (scripts/ngfx.py).
# 2. test/run_tests.py: the programs under test/<area>/ against their golden output.
# 3. tools/perft.goose, built natively: move counts from each start position
#    against published values (International, English, Brazilian) and against
#    test/perft.py's (Russian).
# 4. test/perft.py compare: random games, every position's moves against the
#    independent Python generator, the four variants at once.
# 5. test/perft.py puzzles: every puzzle's lines played by it, each position's moves
#    checked against build/perft, for each variant's set, at once.
#
# GOOSE names the compiler (default: the desktop build's copy of the pinned release with the
# goose_gfx fork's gfx, build/<platform>/goose/, which the build scripts make and the app is
# built with, as the fork's gfx.goose has what the release's lacks; else the release itself).
set -e
quick=
case $1 in
    quick) quick=--quick ;;
    "") ;;
    *) echo "usage: scripts/test.sh [quick]"; exit 2 ;;
esac
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
case $(uname -s) in
    Darwin) release=goose-v2026.4-macos-arm64/goose; patched=mac/goose/goose ;;
    Linux) release=goose-v2026.4-linux-x64/goose; patched=linux/goose/goose ;;
    *) release=goose-v2026.4-windows-x64/goose.exe; patched=windows/goose/goose.exe ;;
esac
if [ -z "$GOOSE" ] && [ -x "$root/build/$patched" ]; then GOOSE=$root/build/$patched; fi
GOOSE=${GOOSE:-$root/build/$release}
export GOOSE

python3 scripts/strings_keys.py --check
python3 scripts/check_roots.py
(cd src/main && "$GOOSE" check draughts.goose)
echo "== app checked, its shaders compiled"
if [ -n "$NGFX" ]; then
    python3 scripts/ngfx.py
    echo "== ngfx build checked"
fi

test/run_tests.py $quick
if [ -n "$quick" ]; then
    echo "== quick: perft, the random games, the puzzles' lines, and the long tests left out"
    exit 0
fi

"$GOOSE" build -o build/perft tools/perft.goose >/dev/null
check() {
    got=$(build/perft "$1" "$2" | tail -1 | cut -d' ' -f2)
    if [ "$got" != "$3" ]; then
        echo "perft $1 $2: $got, expected $3"
        exit 1
    fi
    echo "== perft $1 $2: $got"
}
check international 8 6483961
check english 9 3963680
check russian 9 4570586
check brazilian 9 4431766

# The independent generator's checks, each in its own process, at once; each one's output
# kept apart and shown in order, a failure's last.
work=build/test/perft
rm -rf "$work"
mkdir -p "$work"
n=0
each() {
    n=$((n + 1))
    # Inside an if, as set -e would end the subshell before it writes the code.
    (if python3 test/perft.py "$@" > "$work/$n.out" 2>&1; then echo 0; else echo 1; fi > "$work/$n.code") &
}
each compare russian 40 120
each compare international 20 150
each compare english 40 120
each compare brazilian 40 120
each puzzles international src/puzzles/international.txt
each puzzles russian src/puzzles/russian.txt
each puzzles brazilian src/puzzles/brazilian.txt
wait
failed=0
i=1
while [ $i -le $n ]; do
    cat "$work/$i.out"
    if [ "$(cat "$work/$i.code")" != 0 ]; then failed=1; fi
    i=$((i + 1))
done
if [ $failed != 0 ]; then
    echo "== the independent generator's checks failed"
    exit 1
fi
