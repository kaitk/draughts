#!/usr/bin/env python3
"""Check that src/main/draughts_ngfx.goose and its sidecar hold everything the gfx root
and its sidecar hold, so the two copies can't drift apart. scripts/test.sh runs it.

The ngfx root has every import of the gfx root but gfx's backend (import gpu.backend;),
and only adds imports whose names hold "ngfx". Its sidecar has all of the gfx sidecar's
c_sources and c_include, and the same output, which gives both the app's ids. Goose has
no way to share these lists (docs/decisions/layout.md).
"""
import sys

from native import ROOT, program_name, sidecar

GFX = ROOT / "src/main/draughts.goose"
NGFX = ROOT / "src/main/draughts_ngfx.goose"
GFX_ONLY = {"import gpu.backend;"}


def imports(program):
    return {" ".join(line.split()) for line in program.read_text(encoding="utf-8").splitlines()
            if line.startswith("import ")}


def main():
    wrong = []
    gfx, ngfx = imports(GFX), imports(NGFX)
    for line in sorted(gfx - GFX_ONLY - ngfx):
        wrong.append(f"{NGFX.name} lacks `{line}`")
    for line in sorted(ngfx - gfx):
        if "ngfx" not in line:
            wrong.append(f"{NGFX.name} has `{line}`, which {GFX.name} lacks")
    for key in ("c_sources", "c_include"):
        for path in sorted(set(sidecar(GFX, key)) - set(sidecar(NGFX, key))):
            wrong.append(f"{NGFX.with_suffix('.build').name}'s {key} lacks {path.relative_to(ROOT)}")
    if program_name(GFX) != program_name(NGFX):
        wrong.append(f"the sidecars' output differ: {program_name(GFX)}, {program_name(NGFX)}")
    for w in wrong:
        print(w)
    sys.exit(1 if wrong else 0)


if __name__ == "__main__":
    main()
