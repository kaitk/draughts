#!/usr/bin/env python3
"""Builds a daily-puzzle library from tools/puzzles.goose's output (task 088).

    tools/library.py merge OUT IN...     joins `batch`/`games` outputs, keeping each puzzle once:
                                         by its position, and by its line and side to move
    tools/library.py split IN N PREFIX   splits a merged file into N for `rate` to run in parallel
    tools/library.py candidates OUT LIB IN...
                                         `rate` outputs as a library file for `build/puzzles kings
                                         --every`, numbered from 0, leaving out the puzzles LIB
                                         holds and those assemble would; at most 4,096
    tools/library.py passed OUT CANDIDATES KINGS...
                                         the candidates the kings outputs neither mark DISAGREES
                                         nor PREFERS, for assemble
    tools/library.py assemble OUT VARIANT IN...
                                         joins `rate` outputs into the file the app embeds,
                                         sorted by difficulty: `id | difficulty | theme level |
                                         goal in moves | position | line`; IN may be `passed`'s
                                         output too. The puzzles OUT
                                         already holds stay with their ids and difficulties (a
                                         player's file keeps puzzles by id); IN's not among them
                                         by position or line are added, numbered after the
                                         highest id; a capture-first puzzle rated CHOICE_FROM or
                                         more without a real choice (`rate`'s last shape number
                                         0) is left out
    tools/library.py rerate OUT IN...    gives the puzzles OUT holds, found by position, the
                                         difficulty IN's `rate` outputs give them, ids kept,
                                         and sorts OUT again: after `rate` changes, for the
                                         puzzles it now rates otherwise
    tools/library.py drop OUT ID...      takes the puzzles with those ids out of OUT; their ids
                                         stay unused

The whole pipeline, per variant (docs/development.md, "Daily puzzles"):

    build/puzzles --variant V batch SEED PER SECONDS > find-SEED.txt     (several seeds at once)
    tools/library.py merge merged.txt find-*.txt
    tools/library.py split merged.txt 10 rate-in
    build/puzzles rate rate-in-N.txt > rate-out-N.txt                    (each at once)
    tools/library.py candidates cand.txt src/puzzles/library-V.txt rate-out-*.txt
    build/puzzles kings cand.txt N 10 --every > kings-N.txt              (each at once)
    tools/library.py passed passed.txt cand.txt kings-*.txt
    tools/library.py assemble src/puzzles/library-V.txt V passed.txt
"""
import os
import sys

CAP = 4000
BAND = 100
MAX_ID = 4096               # puzzles::MAX_LIBRARY: every id is under it
CHOICE_FROM = 500           # puzzles::CHOICE_FROM: from this difficulty a capture needs a real choice


def entries(paths):
    """The variant named, and each puzzle line's fields, from the files in order."""
    variant = None
    for path in paths:
        with open(path, encoding="utf-8") as f:
            for raw in f:
                line = raw.strip()
                if not line or line.startswith("#"):
                    continue
                if line.startswith("variant "):
                    name = line.split()[1]
                    if variant not in (None, name):
                        sys.exit(f"{path}: variant {name}, not {variant}")
                    variant = name
                    continue
                yield variant, [x.strip() for x in line.split("|")]


def merge(out, paths):
    seen, kept, dropped, variant = set(), [], 0, None
    for variant, f in entries(paths):
        # theme level | goal in k | FEN | line | source
        fen, line = f[2], f[3]
        keys = (("fen", fen), ("line", fen[0], line))
        if any(k in seen for k in keys):
            dropped += 1
            continue
        seen.update(keys)
        kept.append(" | ".join(f))
    with open(out, "w", encoding="utf-8") as o:
        o.write(f"variant {variant}\n")
        o.writelines(k + "\n" for k in kept)
    print(f"{len(kept)} kept, {dropped} seen before", file=sys.stderr)


def split(path, n, prefix):
    variant, rows = None, []
    for variant, f in entries([path]):
        rows.append(" | ".join(f))
    for i in range(n):
        with open(f"{prefix}-{i}.txt", "w", encoding="utf-8") as o:
            o.write(f"variant {variant}\n")
            o.writelines(r + "\n" for r in rows[i::n])


def library(path):
    """The puzzles of a library file as rows (id, difficulty, theme level, goal, FEN, line).
    A line without an id, from before ids, takes its place in the file from 0."""
    rows = []
    if not os.path.exists(path):
        return rows
    for _, f in entries([path]):
        if len(f) == 5:
            f = [str(len(rows))] + f
        rows.append((int(f[0]), int(f[1]), f[2], f[3], f[4], f[5]))
    return rows


def rated(f):
    """A `rate` output line's (difficulty, theme level, goal, FEN, line), or a library
    line's (`passed`); "no choice" for one assemble leaves out, None for no puzzle."""
    if len(f) == 6 and f[0].isdigit():
        return (int(f[1]), f[2], f[3], f[4], f[5])
    # difficulty | misses pattern | shape | theme level | goal in k | FEN | line | source
    if len(f) < 7 or not f[0].lstrip("-").isdigit():
        return None
    if int(f[0]) >= CHOICE_FROM and f[2].split()[-1] == "0":
        return "no choice"
    return (int(f[0]), f[3], f[4], f[5], f[6])


def candidates(out, lib, paths):
    known = set()
    for r in library(lib):
        known.update((("fen", r[4]), ("line", r[4][0], r[5])))
    variant, rows, left = None, [], 0
    for variant, f in entries(paths):
        row = rated(f)
        if row is None:
            continue
        keys = () if row == "no choice" else (("fen", row[3]), ("line", row[3][0], row[4]))
        if row == "no choice" or any(k in known for k in keys):
            left += 1
            continue
        known.update(keys)
        rows.append((len(rows),) + row)
    if len(rows) > MAX_ID:
        sys.exit(f"{len(rows)} candidates, past the {MAX_ID} a library file holds: give fewer IN")
    write(out, variant, rows, sort=False)
    print(f"{len(rows)} candidates, {left} left out", file=sys.stderr)


def passed(out, cands, paths):
    failed, checked = set(), set()
    for path in paths:
        with open(path, encoding="utf-8") as f:
            for line in f:
                if line.startswith("#") or "|" not in line:
                    continue
                i = int(line.split("|")[0])
                checked.add(i)
                if "DISAGREES" in line or "PREFERS" in line:
                    failed.add(i)
    rows = library(cands)
    variant = next(entries([cands]))[0]
    unchecked = [r[0] for r in rows if r[0] not in checked]
    if unchecked:
        sys.exit(f"not checked: {unchecked[:10]}")
    write(out, variant, [r for r in rows if r[0] not in failed], sort=False)
    print(f"{len(rows) - len(failed)} passed, {len(failed)} failed", file=sys.stderr)


def assemble(out, variant, paths):
    old = library(out)
    known = set()
    for r in old:
        known.update((("fen", r[4]), ("line", r[4][0], r[5])))
    if len({r[0] for r in old}) != len(old):
        sys.exit(f"{out}: an id given twice")
    new, dropped, no_choice = [], 0, 0
    for named, f in entries(paths):
        if named not in (None, variant):
            sys.exit(f"variant {named}, not {variant}")
        row = rated(f)
        if row is None:
            continue
        if row == "no choice":
            no_choice += 1
            continue
        keys = (("fen", row[3]), ("line", row[3][0], row[4]))
        if any(k in known for k in keys):
            dropped += 1
            continue
        known.update(keys)
        new.append(row)
    # The index holds puzzles::MAX_LIBRARY (4096): past CAP, thin the new puzzles' fullest
    # bands of BAND, the easy middle the camps give most of, and keep the rarer hard end
    # whole. The puzzles already there stay.
    new.sort(key=lambda r: (r[0], r[3]))
    while len(old) + len(new) > CAP and new:
        bands = {}
        for i, r in enumerate(new):
            bands.setdefault(r[0] // BAND, []).append(i)
        full = max(bands.values(), key=len)
        del new[full[len(full) // 2]]
    next_id = max((r[0] for r in old), default=-1) + 1
    rows = list(old)
    for i, r in enumerate(new):
        rows.append((next_id + i,) + r)
    if rows and max(r[0] for r in rows) >= MAX_ID:
        sys.exit(f"an id past {MAX_ID - 1}")
    write(out, variant, rows)
    print(f"{len(rows)} puzzles: {len(old)} kept, {len(new)} new, {dropped} seen before, "
          f"{no_choice} without a real choice", file=sys.stderr)


def rerate(out, paths):
    rows = library(out)
    variant = next(entries([out]))[0]
    place = {r[4]: i for i, r in enumerate(rows)}
    changed = 0
    for named, f in entries(paths):
        if named not in (None, variant):
            sys.exit(f"variant {named}, not {variant}")
        if not f[0].lstrip("-").isdigit():
            continue
        if f[5] not in place:
            sys.exit(f"not in {out}: {f[5]}")
        i = place[f[5]]
        if rows[i][1] != int(f[0]):
            print(f"{rows[i][0]}: {rows[i][1]} to {f[0]}", file=sys.stderr)
            rows[i] = (rows[i][0], int(f[0])) + rows[i][2:]
            changed += 1
    write(out, variant, rows)
    print(f"{len(rows)} puzzles, {changed} rated again", file=sys.stderr)


def drop(out, ids):
    rows = library(out)
    variant = next(entries([out]))[0]
    gone = {int(i) for i in ids}
    kept = [r for r in rows if r[0] not in gone]
    if len(rows) - len(kept) != len(gone):
        sys.exit(f"not in {out}: {sorted(gone - {r[0] for r in rows})}")
    write(out, variant, kept)
    print(f"{len(kept)} puzzles, {len(gone)} dropped", file=sys.stderr)


def write(out, variant, rows, sort=True):
    """The library file: its rows sorted by difficulty, then position."""
    if sort:
        rows.sort(key=lambda r: (r[1], r[4]))
    with open(out, "w", encoding="utf-8") as o:
        o.write("# Daily puzzles, generated by tools/puzzles.goose (batch, games) and rated by its\n")
        o.write("# `rate`; built by tools/library.py. One a line, by difficulty:\n")
        o.write("# id | difficulty | theme level | goal in moves | position | line\n")
        o.write(f"variant {variant}\n")
        for r in rows:
            o.write(" | ".join([str(r[0]), str(r[1]), r[2], r[3], r[4], r[5]]) + "\n")


def main():
    a = sys.argv[1:]
    if len(a) >= 3 and a[0] == "merge":
        merge(a[1], a[2:])
    elif len(a) == 4 and a[0] == "split":
        split(a[1], int(a[2]), a[3])
    elif len(a) >= 3 and a[0] == "assemble":
        assemble(a[1], a[2], a[3:])
    elif len(a) >= 3 and a[0] == "rerate":
        rerate(a[1], a[2:])
    elif len(a) >= 4 and a[0] == "candidates":
        candidates(a[1], a[2], a[3:])
    elif len(a) >= 4 and a[0] == "passed":
        passed(a[1], a[2], a[3:])
    elif len(a) >= 3 and a[0] == "drop":
        drop(a[1], a[2:])
    else:
        sys.exit(__doc__)


main()
