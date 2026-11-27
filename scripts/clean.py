#!/usr/bin/env python3
"""Delete what builds, tests, and shots left in build/, keeping what is slow to get again.

    scripts/clean.py        delete
    scripts/clean.py -n     list what it would delete, and its size

Kept: the fetched releases (Goose's, astcenc, bundletool, PresentMon), the local notes
(build/notes/), SDL as Linux builds it (needs the draughts-jammy box; scripts/linux.py),
and iOS's provisioning project (scripts/ios.py). Everything else in build/ the scripts
make again when they next run; the copies of the Goose release with gfx rebuilt
(build/mac/goose/ and the like) come back in seconds, Android's and iOS's CMake builds of
SDL in a few minutes.
"""
import argparse
import fnmatch
import shutil
from pathlib import Path

BUILD = Path(__file__).resolve().parent.parent / "build"
KEEP = ["goose-v*", "astcenc-*", "bundletool-*", "presentmon", "notes", "linux/SDL",
        "ios/provision"]


def matches(path, whole):
    """Whether path is a KEEP pattern's (whole) or an ancestor of one's."""
    rel = path.relative_to(BUILD).parts
    for pattern in KEEP:
        parts = pattern.split("/")
        if (len(rel) == len(parts) if whole else len(rel) <= len(parts)) and all(
                fnmatch.fnmatchcase(r, p) for r, p in zip(rel, parts)):
            return True
    return False


def doomed(folder):
    """What goes under folder: each entry neither kept nor holding a kept one, and the
    holders' other entries likewise."""
    for path in sorted(folder.iterdir()):
        if not matches(path, whole=False):
            yield path
        elif not matches(path, whole=True) and path.is_dir() and not linked(path):
            yield from doomed(path)


def linked(path):
    """A symlink or a Windows junction (build/ngfx/goose-ngfx is one): removed itself, never
    walked into, so the checkout it points to stays."""
    return path.is_symlink() or path.is_junction()


def size(path):
    if linked(path) or path.is_file():
        return path.lstat().st_size
    return sum(f.lstat().st_size for f in path.rglob("*") if f.is_file() or f.is_symlink())


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("-n", "--dry-run", action="store_true", help="only list what would go")
    a = ap.parse_args()
    if not BUILD.exists():
        return
    total = 0
    for path in doomed(BUILD):
        n = size(path)
        total += n
        if a.dry_run:
            print(f"{n / 1e6:8.1f} MB  {path.relative_to(BUILD)}")
        elif path.is_dir() and not linked(path):
            shutil.rmtree(path)
        else:
            path.unlink()
    print(f"{'would free' if a.dry_run else 'freed'} {total / 1e6:.0f} MB")


if __name__ == "__main__":
    main()
