#!/usr/bin/env python3
"""An independent draughts move generator, to check rules/ against.

It shares no code or layout with rules/: the board is a dict from (x, y) to a
piece, and the rules are written out from their text. Slow, plain, and meant
to be read.

    test/perft.py perft VARIANT DEPTH [FEN]       counts per depth
    test/perft.py moves VARIANT FEN               legal moves, one per line
    test/perft.py compare VARIANT GAMES PLIES     random games, each position's
                                                  moves checked against build/perft
    test/perft.py puzzles VARIANT FILE            each puzzle's lines played here, every
                                                  move legal and each position's moves
                                                  checked against build/perft

VARIANT is russian, international, english or brazilian. A move prints as its start, its
end, and the squares it takes, sorted: "c3 e5 d4", the form `perft --moves`
prints too.
"""

import random
import subprocess
import sys
import time
from pathlib import Path

# tools/perft.goose built natively (scripts/test.sh), .exe on Windows.
PERFT = str(Path(__file__).resolve().parent.parent / "build" /
            ("perft.exe" if sys.platform == "win32" else "perft"))

DIRS = [(-1, 1), (1, 1), (-1, -1), (1, -1)]


class Variant:
    def __init__(self, name, size, rows, men_back, flying, majority, crowning, first,
                 algebraic):
        self.name, self.size, self.rows = name, size, rows
        self.men_back, self.flying, self.majority = men_back, flying, majority
        self.crowning = crowning  # "continue", "end", or "stop"
        self.first, self.algebraic = first, algebraic


VARIANTS = {
    "russian": Variant("russian", 8, 3, True, True, False, "continue", "w", True),
    "international": Variant("international", 10, 4, True, True, True, "end", "w", False),
    "english": Variant("english", 8, 3, False, False, False, "stop", "b", False),
    # International's rules on 8x8: men take backward, kings fly, the most pieces must
    # be taken, and a man is crowned only where its move ends.
    "brazilian": Variant("brazilian", 8, 3, True, True, True, "end", "w", True),
}


def dark(v, x, y):
    return 0 <= x < v.size and 0 <= y < v.size and (x + y) % 2 == 0


def number(v, x, y):
    return (v.size - 1 - y) * (v.size // 2) + x // 2 + 1


def from_number(v, n):
    row, col = divmod(n - 1, v.size // 2)
    y = v.size - 1 - row
    x = col * 2 + (1 if y % 2 == 1 else 0)
    return x, y


def name(v, sq):
    x, y = sq
    return f"{chr(ord('a') + x)}{y + 1}" if v.algebraic else str(number(v, x, y))


def parse_square(v, text):
    if text[0].isalpha():
        return ord(text[0]) - ord("a"), int(text[1:]) - 1
    return from_number(v, int(text))


def start(v):
    board = {}
    for y in range(v.size):
        for x in range(v.size):
            if dark(v, x, y):
                if y < v.rows:
                    board[(x, y)] = "w"
                elif y >= v.size - v.rows:
                    board[(x, y)] = "b"
    return board, v.first


def parse_fen(v, fen):
    fields = fen.strip().rstrip(".").split(":")
    side = fields[0].strip().lower()
    board = {}
    for f in fields[1:]:
        f = f.strip()
        if not f:
            continue
        colour = f[0].lower()
        for item in f[1:].split(","):
            item = item.strip()
            if not item:
                continue
            king = item.startswith("K")
            if king:
                item = item[1:]
            if "-" in item:
                lo, hi = map(int, item.split("-"))
                squares = [from_number(v, n) for n in range(lo, hi + 1)]
            else:
                squares = [parse_square(v, item)]
            for sq in squares:
                board[sq] = colour.upper() if king else colour
    return board, side


def forward(side):
    return 1 if side == "w" else -1


def last_row(v, side):
    return v.size - 1 if side == "w" else 0


def jumps(v, board, side, sq, king, taken, path, crowned, out):
    """Every way the capture from path[0], now on sq, can go on; finished
    captures go to out as (path, taken, crowned)."""
    x, y = sq
    origin = path[0]

    def empty(s):
        return dark(v, *s) and (s == origin or s not in board)

    def enemy(s):
        return s in board and board[s].lower() != side and s not in taken

    went_on = False
    for dx, dy in DIRS:
        if king and v.flying:
            k = 1
            while empty((x + k * dx, y + k * dy)):
                k += 1
            victim = (x + k * dx, y + k * dy)
            if not enemy(victim):
                continue
            landings = []
            k += 1
            while empty((x + k * dx, y + k * dy)):
                landings.append((x + k * dx, y + k * dy))
                k += 1
            # A king must land where it can take again, if there is such a square.
            onward = [l for l in landings if can_take(v, board, side, l, origin, taken | {victim})]
            for l in onward or landings:
                went_on = True
                jumps(v, board, side, l, True, taken | {victim}, path + [l], crowned, out)
            continue
        if not king and not v.men_back and dy != forward(side):
            continue
        victim = (x + dx, y + dy)
        land = (x + 2 * dx, y + 2 * dy)
        if not enemy(victim) or not empty(land):
            continue
        went_on = True
        now = taken | {victim}
        if not king and land[1] == last_row(v, side) and v.crowning != "end":
            if v.crowning == "continue":
                jumps(v, board, side, land, True, now, path + [land], True, out)
            else:
                out.append((path + [land], now, True))
        else:
            jumps(v, board, side, land, king, now, path + [land], crowned, out)
    if not went_on and taken:
        out.append((path, taken, crowned or (not king and y == last_row(v, side))))


def can_take(v, board, side, sq, origin, taken):
    found = []
    jumps(v, board, side, sq, True, taken, [origin, sq], False, found)
    return any(len(t) > len(taken) for _, t, _ in found)


def moves(v, board, side):
    """Legal moves as (path, taken set, crowned)."""
    caps = []
    for sq, piece in board.items():
        if piece.lower() == side:
            jumps(v, board, side, sq, piece.isupper(), frozenset(), [sq], False, caps)
    if caps:
        if v.majority:
            most = max(len(t) for _, t, _ in caps)
            caps = [c for c in caps if len(c[1]) == most]
        seen, unique = set(), []
        for path, taken, crowned in caps:
            key = (path[0], path[-1], taken)
            if key not in seen:
                seen.add(key)
                unique.append((path, taken, crowned))
        return unique
    quiet = []
    for (x, y), piece in board.items():
        if piece.lower() != side:
            continue
        king = piece.isupper()
        for dx, dy in DIRS:
            if not king and dy != forward(side):
                continue
            k = 1
            while dark(v, x + k * dx, y + k * dy) and (x + k * dx, y + k * dy) not in board:
                to = (x + k * dx, y + k * dy)
                quiet.append(([(x, y), to], frozenset(), not king and to[1] == last_row(v, side)))
                if not king or not v.flying:
                    break
                k += 1
    return quiet


def play(board, side, move):
    path, taken, crowned = move
    after = dict(board)
    piece = after.pop(path[0])
    for t in taken:
        del after[t]
    after[path[-1]] = piece.upper() if crowned else piece
    return after, "b" if side == "w" else "w"


def perft(v, board, side, depth):
    ms = moves(v, board, side)
    if depth == 1:
        return len(ms)
    return sum(perft(v, *play(board, side, m), depth - 1) for m in ms)


def move_text(v, move):
    path, taken, _ = move
    caps = sorted(taken, key=lambda s: number(v, *s))
    return " ".join(name(v, s) for s in [path[0], path[-1]] + caps)


def fen(v, board, side):
    parts = [side.upper()]
    for colour in "wb":
        squares = sorted((s for s, p in board.items() if p.lower() == colour),
                         key=lambda s: number(v, *s))
        parts.append(colour.upper() + ",".join(("K" if board[s].isupper() else "") + name(v, s)
                                               for s in squares))
    return ":".join(parts)


def compare(v, games, plies, seed=1):
    """Plays random games and checks each position's moves against build/perft."""
    rng = random.Random(seed)
    positions = []
    for _ in range(games):
        board, side = start(v)
        for _ in range(plies):
            ms = moves(v, board, side)
            if not ms:
                break
            positions.append((board, side))
            board, side = play(board, side, rng.choice(ms))
    bad = 0
    for board, side in positions:
        f = fen(v, board, side)
        want = sorted(move_text(v, m) for m in moves(v, board, side))
        got = subprocess.run([PERFT, v.name, "1", f, "--moves"], capture_output=True,
                             text=True, check=True).stdout.split("\n")
        got = sorted(l for l in got if l)
        if got != want:
            bad += 1
            print(f"differs at {f}\n  python: {want}\n  goose:  {got}")
    print(f"{len(positions)} positions, {bad} differ")
    return bad == 0


def same_moves(v, board, side):
    """Whether build/perft gives the position's moves as this generator does."""
    f = fen(v, board, side)
    want = sorted(move_text(v, m) for m in moves(v, board, side))
    got = subprocess.run([PERFT, v.name, "1", f, "--moves"], capture_output=True,
                         text=True, check=True).stdout.split("\n")
    if sorted(l for l in got if l) != want:
        print(f"differs at {f}")
        return False
    return True


def puzzles(v, path):
    """Plays each `line` of a puzzle file (docs/architecture/puzzles.md) from its
    `position`: a move is its squares apart by -, x, or :, the stops of a capture or only
    its ends, and must be exactly one legal move here."""
    bad = count = 0
    board = side = None
    for raw in open(path):
        key, _, value = raw.split("#")[0].strip().partition(" ")
        if key == "variant" and value.strip() != v.name:
            print(f"the file is {value.strip()}'s, not {v.name}'s")
            return False
        if key == "position":
            board, side = parse_fen(v, value)
            count += 1
        if key != "line":
            continue
        b, s = board, side
        for word in value.split():
            if not same_moves(v, b, s):
                bad += 1
            stops = [parse_square(v, t) for t in word.replace("x", "-").replace(":", "-").split("-")]
            found = [m for m in moves(v, b, s) if m[0][0] == stops[0] and m[0][-1] == stops[-1]
                     and (len(stops) == 2 or m[0] == stops)]
            if len(found) != 1:
                bad += 1
                print(f"{word} is {len(found)} legal moves at {fen(v, b, s)}")
                break
            b, s = play(b, s, found[0])
    print(f"{count} puzzles, {bad} problems")
    return bad == 0


def main():
    if len(sys.argv) < 3 or sys.argv[2] not in VARIANTS:
        sys.exit(__doc__)
    cmd, v = sys.argv[1], VARIANTS[sys.argv[2]]
    if cmd == "perft":
        board, side = parse_fen(v, sys.argv[4]) if len(sys.argv) > 4 else start(v)
        for d in range(1, int(sys.argv[3]) + 1):
            t = time.time()
            print(d, perft(v, board, side, d), f"{time.time() - t:.1f} s", flush=True)
    elif cmd == "moves":
        board, side = parse_fen(v, sys.argv[3])
        for m in sorted(move_text(v, m) for m in moves(v, board, side)):
            print(m)
    elif cmd == "compare":
        sys.exit(0 if compare(v, int(sys.argv[3]), int(sys.argv[4])) else 1)
    elif cmd == "puzzles":
        sys.exit(0 if puzzles(v, sys.argv[3]) else 1)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
