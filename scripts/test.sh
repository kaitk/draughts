#!/bin/sh
# Every check of the rules, stopping at the first that fails:
#
# 1. goose check of the app: every shader its embed_shader calls compile, as the app's
#    build compiles them (a GLSL error is a Goose compile error), in half a second.
# 2. test/run_tests.py: the programs under test/<area>/ against their golden output.
# 3. tools/perft.goose, built natively: move counts from each start position
#    against published values (International, English, Brazilian) and against
#    test/perft.py's (Russian).
# 4. test/perft.py compare: random games, every position's moves against the
#    independent Python generator.
# 5. test/perft.py puzzles: every puzzle's lines played by it, each position's moves
#    checked against build/perft, for each variant's set.
#
# GOOSE names the compiler (default: the pinned release under build/).
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
case $(uname -s) in
    Darwin) release=goose-v2026.4-macos-arm64/goose ;;
    Linux) release=goose-v2026.4-linux-x64/goose ;;
    *) release=goose-v2026.4-windows-x64/goose.exe ;;
esac
GOOSE=${GOOSE:-$root/build/$release}
export GOOSE

(cd src/app && "$GOOSE" check draughts.goose)
echo "== app checked, its shaders compiled"

test/run_tests.py

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

python3 test/perft.py compare russian 40 120
python3 test/perft.py compare international 20 150
python3 test/perft.py compare english 40 120
python3 test/perft.py compare brazilian 40 120

python3 test/perft.py puzzles international src/puzzles/international.txt
python3 test/perft.py puzzles russian src/puzzles/russian.txt
python3 test/perft.py puzzles brazilian src/puzzles/brazilian.txt
