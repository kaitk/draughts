#!/usr/bin/env python3
"""The app's shaders as standalone GLSL, and the Mali Offline Compiler's report for each
(task 059): the 3D renderer's, and the screen's (the flat board, its pieces, the UI).

Pulls each shader's parts out of src/render3d/shaders.goose, joined as embed_shader
joins them (render3d::setup's calls, repeated in SHADERS below: keep them in step),
writes them to build/shaders/<name>.<stage>, checks each with glslangValidator (the
Vulkan SDK's) into SPIR-V, and, when malioc is on PATH (Arm Performance Studio), prints
its report for the given cores.

    python tools/perf/shader_report.py                     # extract and check only
    python tools/perf/shader_report.py --core Mali-G615    # and malioc's report (the tablet)
    python tools/perf/shader_report.py --core Mali-G710 --core Mali-G68
    python tools/perf/shader_report.py --core Mali-G615 --table   # one line a shader
    python tools/perf/shader_report.py --core Mali-G615 --table --only room   # names starting so
"""
import argparse
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# A part names a constant of src/render3d/shaders.goose, or of another file as file.NAME.
SOURCES = {"": os.path.join(ROOT, "src", "render3d", "shaders.goose"),
           "draw.": os.path.join(ROOT, "src", "gfx", "draw_gpu.goose"),
           "widgets.": os.path.join(ROOT, "src", "gfx", "widgets_gpu.goose"),
           "room_fixed.": os.path.join(ROOT, "src", "render3d", "room_fixed.goose")}
OUT = os.path.join(ROOT, "build", "shaders")

# The room's shared parts after its defines (make_room_tier's room_frag).
ROOM_FS = ["SHELL_WINDOWS", "FS_SET", "FRAME", "ROOM_HEAD", "WIND_FN", "LIGHT_FN"]
# name, stage, parts in embed_shader's order (render3d::setup).
SHADERS = [
    ("lit", "vert", ["VS_SET", "FRAME", "LIT_VERT"]),
    ("lit", "frag", ["FS_SET", "FRAME", "LIT_HEAD", "SHADOW_FN", "WIND_FN", "LIGHT_FN", "LIT_FRAG"]),
    ("quad", "vert", ["VS_SET", "FRAME", "QUAD_VERT"]),
    ("empty", "frag", ["EMPTY_FRAG"]),
    ("full", "vert", ["FULL_VERT"]),
    ("backdrop", "frag", ["FS_SET", "FRAME", "FADE_FN", "BACKDROP_FRAG"]),
    ("catcher", "frag", ["FS_SET", "FRAME", "SHADOW_CATCHER_FRAG"]),
    ("marks", "frag", ["FS_SET", "FRAME", "MARKS_FRAG"]),
    ("marks_pulse", "frag", ["MARKS_PULSE", "FS_SET", "FRAME", "MARKS_FRAG"]),
    ("show", "vert", ["SHOW_VS", "SHOW_BLOCK", "SHOW_VERT"]),
    ("show", "frag", ["SHOW_FS", "SHOW_BLOCK", "SHOW_FRAG"]),
    ("kept", "frag", ["KEPT_FRAG"]),
    ("bake", "frag", ["BAKE_FRAG"]),
    ("crown", "frag", ["CROWN_FN", "CROWN_FRAG"]),
    # The room as the phone's tier draws it (render3d_gpu.goose's make_room_tier and room_frag:
    # no screen maps, the window's light map, the sharp box on the floor and metals).
    ("room", "vert", ["VS_SET", "FRAME", "ROOM_VERT"]),
] + [(f"room_{g}", "frag", defs + ["NO_SSAO"] + (["WINDOW_MAP"] if mapped else []) + ROOM_FS + (["TABLE_MAP_FN"] if mapped else [])
      + ["SSAO_FN", "TONE_FN", "ROOM_FRAG"])
     for g, defs, mapped in [("floor", ["ROOM_FLOOR", "SHARP_BOX"], True), ("floor_nobox", ["ROOM_FLOOR"], True),
                             ("walls", ["ROOM_WALLS"], True), ("paint", ["ROOM_PAINT"], True), ("sill", ["ROOM_SILL"], True),
                             ("metals", ["ROOM_METALS", "SHARP_BOX"], True), ("metals_nobox", ["ROOM_METALS"], True),
                             ("glass", ["ROOM_GLASS"], False), ("lace", ["ROOM_LACE"], False)]] + [
    # The same with the room's block as constants after ROOM_HEAD (room_frag_fixed).
    (f"room_{g}_fixed", "frag", defs + ["NO_SSAO", "WINDOW_MAP"] + ROOM_FS[:4] + ["room_fixed.ROOM_FIXED"] + ROOM_FS[4:]
                                  + ["TABLE_MAP_FN", "SSAO_FN", "TONE_FN", "ROOM_FRAG"])
     for g, defs in [("floor", ["ROOM_FLOOR", "SHARP_BOX"]), ("walls", ["ROOM_WALLS"]), ("paint", ["ROOM_PAINT"]),
                     ("sill", ["ROOM_SILL"]), ("metals", ["ROOM_METALS", "SHARP_BOX"])]] + [
    ("table_room", "vert", ["VS_SET", "FRAME", "TABLE_VERT"]),
    ("table_room", "frag", ["TABLE_ROOM", "SHELL_WINDOWS", "NO_SSAO", "FS_SET", "FRAME", "TABLE_HEAD", "TABLE_SHELL", "SHADOW_FN",
                            "WIND_FN", "LIGHT_FN", "TABLE_MAP_FN", "SSAO_FN", "TABLE_FRAG"]),
    ("lit_few", "frag", ["SHADOW_FEW", "FS_SET", "FRAME", "LIT_HEAD", "SHADOW_FN", "WIND_FN", "LIGHT_FN", "LIT_FRAG"]),
    ("outside", "vert", ["VS_SET", "FRAME", "OUTSIDE_VERT"]),
    ("outside", "frag", ["FS_SET", "FRAME", "OUTSIDE_HEAD", "WIND_FN", "LIGHT_FN", "TONE_FN", "OUTSIDE_FRAG", "OUTSIDE_MAIN"]),
    # The screen's (src/gfx/draw_gpu.goose's setup, widgets_gpu.goose's).
    ("board2d", "frag", ["FADE_FN", "draw.THEME_BLOCK", "draw.SHARED_BLOCK", "draw.BOARD_FRAG"]),
    ("piece2d", "vert", ["draw.SHARED_BLOCK", "draw.STACK_BLOCK", "draw.PIECE_VERT"]),
    ("piece2d", "frag", ["FADE_FN", "draw.THEME_BLOCK", "draw.SHARED_BLOCK", "draw.MAN_BLOCK", "draw.STACK_BLOCK",
                         "draw.PIECE_FRAG"]),
    ("ui", "vert", ["draw.SHARED_BLOCK", "widgets.VERT"]),
    ("ui_base", "frag", ["widgets.BASE", "FADE_FN", "draw.THEME_BLOCK", "draw.SHARED_BLOCK", "draw.MAN_BLOCK",
                         "widgets.FRAG"]),
    ("ui_icons", "frag", ["widgets.ICONS", "FADE_FN", "draw.THEME_BLOCK", "draw.SHARED_BLOCK", "draw.MAN_BLOCK",
                         "widgets.FRAG"]),
    ("ui_faces", "frag", ["widgets.FACES", "FADE_FN", "draw.THEME_BLOCK", "draw.SHARED_BLOCK", "draw.MAN_BLOCK",
                         "widgets.FRAG"]),
]


def constants(text):
    """Each top-level `let NAME = "...";` or `let NAME = \"\"\"...\"\"\";` as its string."""
    out = {}
    for m in re.finditer(r'^let ([A-Z_0-9]+) = """\n(.*?)\n\s*""";', text, re.S | re.M):
        out[m.group(1)] = m.group(2)
    for m in re.finditer(r'^let ([A-Z_0-9]+) = "((?:[^"\\]|\\.)*)";', text, re.M):
        out[m.group(1)] = m.group(2).encode().decode("unicode_escape")
    return out


def glslang():
    exe = shutil.which("glslangValidator")
    if exe:
        return exe
    sdk = os.environ.get("VULKAN_SDK")
    if sdk:
        p = os.path.join(sdk, "Bin", "glslangValidator.exe")
        if os.path.exists(p):
            return p
    return None


def find_malioc():
    """malioc on PATH, or in Arm Performance Studio's newest install (its installer
    doesn't add it to PATH on Windows)."""
    exe = shutil.which("malioc")
    if exe:
        return exe
    base = os.path.join(os.environ.get("ProgramFiles", r"C:\Program Files"), "Arm")
    if os.path.isdir(base):
        for d in sorted(os.listdir(base), reverse=True):
            p = os.path.join(base, d, "mali_offline_compiler", "malioc.exe")
            if os.path.exists(p):
                return p
    return None


def summary(text):
    """malioc's main shader in a few numbers: work registers and occupancy, spilled bytes,
    the share of 16-bit arithmetic, and the cycles per unit on the shortest and longest path."""
    m = {"regs": "", "occ": "", "spill": "0", "spilled": "", "fp16": "", "total": {}, "short": {}, "long": {}, "bound": ""}
    main = text.split("Main shader", 1)[-1]
    r = re.search(r"Work registers: (\d+)(?: \(.*?at (\d+)% occupancy\))?", main)
    if r:
        m["regs"], m["occ"] = r.group(1), (r.group(2) or "100") + "%"
    r = re.search(r"Spill region: (\d+) bytes", main)
    if r:
        m["spill"] = r.group(1)
    r = re.search(r"Spill usage: (\d+) bytes", main)
    if r:
        m["spilled"] = r.group(1)
    r = re.search(r"16-bit arithmetic: (\d+)%", main)
    if r:
        m["fp16"] = r.group(1) + "%"
    head = re.search(r"^\s+((?:[A-Z]+\s+)+)Bound$", main, re.M)
    if head:
        units = head.group(1).split()
        for key, label in (("total", "Total instruction cycles:"), ("short", "Shortest path cycles:"),
                           ("long", "Longest path cycles:")):
            r = re.search(re.escape(label) + r"\s+(.*)$", main, re.M)
            if r:
                vals = r.group(1).split()
                m[key] = dict(zip(units, vals))
                if key == "total" and len(vals) > len(units):
                    m["bound"] = vals[len(units)]
    return m


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--core", action="append", default=[], help="a Mali core for malioc, e.g. Mali-G615")
    ap.add_argument("--table", action="store_true", help="one line a shader: registers, spills, cycles, bound")
    ap.add_argument("--only", action="append", default=[], help="only the shaders whose name starts so")
    args = ap.parse_args()

    consts = {}
    for prefix, path in SOURCES.items():
        with open(path, encoding="utf-8") as f:
            consts.update({prefix + k: v for k, v in constants(f.read()).items()})
    os.makedirs(OUT, exist_ok=True)
    validator = glslang()
    malioc = find_malioc()
    if args.core and not malioc:
        sys.exit("malioc isn't on PATH or in Program Files/Arm: install Arm Performance Studio (its Mali Offline Compiler)")

    failed = False
    rows = []
    for name, stage, parts in SHADERS:
        if args.only and not any(name.startswith(o) for o in args.only):
            continue
        body = "\n".join(consts[p] for p in parts)
        # `patch` and `flat` are keywords to glslang's 450, not to the compiler goose uses:
        # BAKE_FRAG and the UI's FRAG name locals so.
        body = re.sub(r"\bpatch\b", "patch_", body)
        body = re.sub(r"\bbool flat\b", "bool flat_", body)
        body = re.sub(r"\(!flat\)", "(!flat_)", body)
        body = re.sub(r"\bflat \?", "flat_ ?", body)
        body = re.sub(r"([!(&|] *)flat\b(?! (?:in|out))", r"\1flat_", body)
        src = "#version 450\n" + body + "\n"
        path = os.path.join(OUT, f"{name}.{stage}")
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(src)
        spv = path + ".spv"
        if validator:
            r = subprocess.run([validator, "-V", "-S", stage, path, "-o", spv], capture_output=True, text=True)
            if r.returncode != 0:
                failed = True
                print(f"{name}.{stage}: glslang failed\n{r.stdout}{r.stderr}")
                continue
        for core in args.core:
            r = subprocess.run([malioc, "--vulkan", "--core", core, f"--{stage}ment" if stage == "frag" else "--vertex", path],
                               capture_output=True, text=True)
            if args.table:
                rows.append((core, f"{name}.{stage}", summary(r.stdout + r.stderr)))
            else:
                print(f"===== {name}.{stage} on {core} =====")
                print(r.stdout + r.stderr)
    if rows:
        # Spill: the stack's spill region and the bytes it moves (malioc's Spill usage, where
        # it gives one). Cycles: the total over every branch, the shortest path, the longest
        # (N/A past a loop of unknown count). Bound: the busiest unit in the total.
        print(f"{'core':<10} {'shader':<22} {'regs':>4} {'occ':>4} {'spill':>9} {'fp16':>4} "
              f"{'A tot':>6} {'LS tot':>6} {'T tot':>6} {'A shrt':>6} {'LS shrt':>7} {'A long':>6} {'LS long':>7} {'bound':<5}")
        for core, shader, m in rows:
            spill = m["spill"] + ("/" + m["spilled"] if m["spilled"] else "")
            t, sh, lo = m["total"], m["short"], m["long"]
            print(f"{core:<10} {shader:<22} {m['regs']:>4} {m['occ']:>4} {spill:>9} {m['fp16']:>4} "
                  f"{t.get('A', ''):>6} {t.get('LS', ''):>6} {t.get('T', ''):>6} {sh.get('A', ''):>6} {sh.get('LS', ''):>7} "
                  f"{lo.get('A', ''):>6} {lo.get('LS', ''):>7} {m['bound']:<5}")
    if not validator:
        print("glslangValidator not found (the Vulkan SDK): extracted only, into", OUT)
    elif not failed:
        print("extracted and compiled", len(SHADERS), "shaders into", OUT)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
