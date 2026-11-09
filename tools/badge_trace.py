#!/usr/bin/env python3
"""Trace a badge's silhouette (black on white PNG) into assets/badges/<animal>.svg.

    tools/badge_trace.py fox ~/Downloads/fox.png

Thresholds the image, traces it with potrace, and sets the SVG's viewBox to the square
around the shape's smallest enclosing circle, with a margin, so the badge drawing
(src/app/widgets.goose, BADGE_HALF) keeps every animal inside the piece's inner ring at the
same optical size. Needs ImageMagick (magick) and potrace.
"""
import math, os, re, subprocess, sys, tempfile

MARGIN = 1.04  # the circle's radius over the viewBox's half side, inverted: room to the ring


def black_points(png, step):
    """The dark pixels' centres, every `step` pixels, in the image's pixel units."""
    out = subprocess.run(["magick", png, "-colorspace", "gray", "-sample",
                          f"{100.0 / step}%", "-threshold", "50%", "txt:-"],
                         check=True, capture_output=True, text=True).stdout
    pts = []
    for line in out.splitlines()[1:]:
        m = re.match(r"(\d+),(\d+):.*#000000", line)
        if m:
            pts.append(((int(m[1]) + 0.5) * step, (int(m[2]) + 0.5) * step))
    return pts


def enclosing_circle(pts):
    """A near-smallest circle round the points: start at the box's centre, then step the
    centre towards the farthest point while the radius shrinks."""
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    step = max(max(xs) - min(xs), max(ys) - min(ys)) / 4
    far = lambda x, y: max((px - x) ** 2 + (py - y) ** 2 for px, py in pts)
    r2 = far(cx, cy)
    while step > 0.5:
        best = None
        for dx, dy in ((step, 0), (-step, 0), (0, step), (0, -step)):
            d = far(cx + dx, cy + dy)
            if d < r2:
                r2, best = d, (cx + dx, cy + dy)
        if best:
            cx, cy = best
        else:
            step /= 2
    return cx, cy, math.sqrt(r2)


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    name, png = sys.argv[1], os.path.expanduser(sys.argv[2])
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    with tempfile.TemporaryDirectory() as tmp:
        pbm = os.path.join(tmp, "in.pbm")
        subprocess.run(["magick", png, "-colorspace", "gray", "-threshold", "50%", pbm],
                       check=True)
        svg = subprocess.run(["potrace", "-s", "--flat", "-r", "72", "-t", "8",
                              "-O", "0.4", "-o", "-", pbm],
                             check=True, capture_output=True, text=True).stdout
    cx, cy, r = enclosing_circle(black_points(png, 4))
    h = r * MARGIN
    vb = f'viewBox="{cx - h:.1f} {cy - h:.1f} {2 * h:.1f} {2 * h:.1f}"'
    svg = re.sub(r'\s(width|height)="[^"]*"', "", svg)
    svg = re.sub(r'viewBox="[^"]*"', vb, svg, count=1)
    svg = re.sub(r"<\?xml.*?\?>\s*|<!DOCTYPE.*?>\s*|<metadata>.*?</metadata>\s*", "", svg,
                 flags=re.S)
    note = (f"<!-- Traced from {os.path.basename(png)} by tools/badge_trace.py; the viewBox "
            f"is the square round the shape's enclosing circle. -->\n")
    svg = re.sub(r"(<svg[^>]*>\n?)", lambda m: m[1] + note, svg, count=1)
    dst = os.path.join(root, "assets", "badges", f"{name}.svg")
    with open(dst, "w") as f:
        f.write(svg)
    print(f"{dst}: circle at ({cx:.0f}, {cy:.0f}) r {r:.0f}, {len(svg)} bytes")


if __name__ == "__main__":
    main()
