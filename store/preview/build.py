#!/usr/bin/env python3
"""Fill the store previews, play.html and app-store.html beside this script, with the texts.

    store/preview/build.py            check the texts' limits, copy the images, fill the pages

Reads the listing texts from store/listing-en.md, listing-et.md, and app-store.md, so the
pages show what would be pasted; checks each against its store's limit; and copies the
screenshots, the feature graphic, and the icons from ~/Downloads/draughts-store/ (outside
git, store/README.md) into img/, scaled down to what a store page shows, as JPEG. img/ is
not in git: run this once to see the pages with their pictures. DRAUGHTS_STORE names
another image folder.
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
STORE = HERE.parent
IMAGES = Path(os.environ.get("DRAUGHTS_STORE", Path.home() / "Downloads/draughts-store"))
SHOTS = IMAGES / "screenshots"
SCENES = ["01-home-3d-winter", "02-game-autumn", "03-game-3d-summer", "04-puzzles-spring",
          "05-puzzle-winter", "06-settings-autumn", "07-computer-summer"]


def fences(path):
    """Each `## heading` with the ```text fence under it, by the heading's first words."""
    text = path.read_text()
    out = {}
    for m in re.finditer(r"^##+ ([^\n(]+?)\s*(?:\([^)]*\))?\n(?:(?!^##).)*?```text\n(.*?)\n```",
                         text, re.S | re.M):
        out.setdefault(m.group(1).strip(), m.group(2))
    return out


def table_field(path, field):
    m = re.search(r"^\| " + re.escape(field) + r" \|[^|]*\| `([^`]+)`", path.read_text(), re.M)
    return m.group(1) if m else ""


def check(label, text, limit, unit="chars"):
    n = len(text.encode()) if unit == "bytes" else len(text)
    status = "ok" if n <= limit else "OVER"
    print(f"{status:4} {label}: {n} of {limit} {unit}")
    if n > limit:
        check.failed = True
    return n


check.failed = False


def image(src, dst, width):
    """Scale src to width into img/dst as JPEG; False when src is missing."""
    if not src.exists():
        print(f"missing {src}")
        return False
    out = HERE / "img" / dst
    out.parent.mkdir(parents=True, exist_ok=True)
    if not out.exists() or out.stat().st_mtime < src.stat().st_mtime:
        fmt = ["-quality", "86"] if dst.endswith(".jpg") else []
        subprocess.run(["magick", src, "-resize", f"{width}x", *fmt, out], check=True)
    return True


def main():
    en, et = fences(STORE / "listing-en.md"), fences(STORE / "listing-et.md")
    apple = fences(STORE / "app-store.md")
    play = {}
    for lang, f in (("en", en), ("et", et)):
        play[lang] = {"title": f["Title"], "short": f["Short description"],
                      "full": f["Full description"]}
        check(f"Play {lang} title", f["Title"], 30)
        check(f"Play {lang} short description", f["Short description"], 80)
        check(f"Play {lang} full description", f["Full description"], 4000)
    asc = {
        "name": table_field(STORE / "app-store.md", "Name"),
        "subtitle": table_field(STORE / "app-store.md", "Subtitle"),
        "promo": apple["Promotional text"],
        "keywords": apple["Keywords"],
        "description": apple["Description"],
    }
    check("App Store name", asc["name"], 30)
    check("App Store subtitle", asc["subtitle"], 30)
    check("App Store promotional text", asc["promo"], 170)
    check("App Store keywords", asc["keywords"], 100, "bytes")
    check("App Store description", asc["description"], 4000)

    have = {}
    have["icon"] = image(IMAGES / "icon/play-512.png", "icon-512.png", 512)
    have["apple_icon"] = image(IMAGES / "icon/apple-1024.png", "icon-apple.png", 512)
    have["feature"] = image(SHOTS / "play-0.1/feature-graphic-draft.png", "feature.jpg", 1024)
    for lang in ("en", "et"):
        for s in SCENES:
            for cls, w in (("phone", 540), ("tablet", 1280)):
                have[f"play-{cls}-{s}-{lang}"] = image(
                    SHOTS / f"play-0.2/{cls}/{s}-{lang}.png", f"play-{cls}-{s}-{lang}.jpg", w)
            for cls, w in (("iphone-6.9", 660), ("ipad-13", 1032)):
                have[f"{cls}-{s}-{lang}"] = image(
                    SHOTS / f"app-store-0.2/{cls}/{s}-{lang}.png", f"{cls}-{s}-{lang}.jpg", w)

    data = {"play": play, "apple": asc, "scenes": SCENES, "have": have}
    line = "const DATA = " + json.dumps(data, ensure_ascii=False) + ";  // build.py writes this line"
    for name in ("play", "app-store"):
        path = HERE / f"{name}.html"
        page, n = re.subn(r"^const DATA = .*;  // build\.py writes this line$",
                          lambda _: line, path.read_text(), flags=re.M)
        if n != 1:
            sys.exit(f"{path}: no DATA line")
        path.write_text(page)
        print(f"wrote {path}")
    if check.failed:
        sys.exit("a text is over its limit")


if __name__ == "__main__":
    main()
