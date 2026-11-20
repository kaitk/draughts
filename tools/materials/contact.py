#!/usr/bin/env python3
"""Writes OUT_DIR/contact.html: each baked material flat, tiled 3x3, and from afar, beside
the concept it should match. Run the bakers into OUT_DIR first.

    python3 tools/materials/contact.py OUT_DIR
"""

import os
import sys

import numpy as np
from PIL import Image

import common as cm

# style-01's light, from its white door: the wallpaper's preview is lit by it to compare.
DOOR_SRGB = (92, 74, 54)
DOOR_ALBEDO_SRGB = (205, 199, 184)
LIGHT_GAIN = 1.9

CONCEPT_CROPS = {   # name: (source, box)
    'style_wall': ('style-01.png', (760, 150, 1080, 290)),
    'style_floor': ('style-01.png', (880, 850, 1536, 1024)),
    'style_wainscot': ('style-01.png', (900, 500, 1080, 700)),
    'style_rug': ('style-01.png', (500, 720, 1270, 950)),
}


def save_jpg(img, path, size=None):
    if size:
        img = img.resize(size, Image.LANCZOS)
    img.convert('RGB').save(path, quality=90)


def split(out, name):
    """An RGBA bake's albedo and roughness as images of their own, for the page."""
    im = Image.open(os.path.join(out, name + '.png'))
    if im.mode == 'RGBA':
        im.convert('RGB').save(os.path.join(out, f'c_{name}_albedo.png'))
        im.getchannel('A').save(os.path.join(out, f'c_{name}_rough.png'))


def tiled(out, name, scale):
    im = Image.open(os.path.join(out, name + '.png')).convert('RGB')
    w, h = im.size
    big = Image.new('RGB', (w * 3, h * 3))
    for i in range(3):
        for j in range(3):
            big.paste(im, (i * w, j * h))
    save_jpg(big, os.path.join(out, f'c_{name}_3x3.jpg'), (int(w * 3 * scale), int(h * 3 * scale)))
    # From afar: box-filtered in linear light to an eighth, as a mip level would be.
    far = cm.downscale(cm.load(os.path.join(out, name + '.png'))[..., :3], 8)
    far = np.tile(far, (6, 6, 1))
    Image.fromarray((np.clip(far, 0, 1) * 255 + 0.5).astype(np.uint8)).save(
        os.path.join(out, f'c_{name}_far.png'))


def main(out):
    for key, (src, box) in CONCEPT_CROPS.items():
        save_jpg(Image.open(cm.source(src)).crop(box), os.path.join(out, f'c_{key}.jpg'))
    for src in ('crop-wallpaper-01.png', 'crop-wainscot-01.png', 'library-parquet-01.png',
                'library-wainscot-01.png', 'library-rug-01.png'):
        im = Image.open(cm.source(src))
        if im.width > 1024:
            im = im.resize((1024, round(im.height * 1024 / im.width)), Image.LANCZOS)
        save_jpg(im, os.path.join(out, 'c_src_' + src.replace('.png', '.jpg')))

    # The wallpaper lit as style-01 lights its walls.
    light = (cm.to_linear(np.array(DOOR_SRGB) / 255) / cm.to_linear(np.array(DOOR_ALBEDO_SRGB) / 255)
             * LIGHT_GAIN)
    pv = cm.load(os.path.join(out, 'wallpaper_preview.png'))
    lit = cm.to_srgb(cm.to_linear(pv) * light)
    lit = cm.downscale(np.tile(lit, (2, 2, 1)), 4)
    Image.fromarray((lit * 255 + 0.5).astype(np.uint8)).save(os.path.join(out, 'c_wallpaper_lit.png'))

    for name in ('wallpaper_preview', 'parquet', 'wainscot_oak'):
        tiled(out, name, 0.5)
    for name in ('parquet', 'wainscot_oak'):
        split(out, name)
    has_rug = os.path.exists(os.path.join(out, 'rug.png'))

    def fig(src, caption, cls=''):
        return f'<figure class="{cls}"><img src="{src}"><figcaption>{caption}</figcaption></figure>'

    sections = [
        ('Wallpaper', 'wallpaper_mask.png: L8, 1024 px, one tile 1.4 m a side (7.3 px/cm). '
         'Tinted from ground and gold, roughness from it too (wallpaper_rough.png, L8; see wallpaper.py).', [
            fig('wallpaper_preview.png', 'flat, tinted'),
            fig('wallpaper_rough.png', 'roughness: 0.85 ground, 0.6 gold'),
            fig('wallpaper_mask.png', 'the mask'),
            fig('c_wallpaper_preview_3x3.jpg', 'tiled 3x3 (4.2 m)'),
            fig('c_wallpaper_preview_far.png', 'from afar: an eighth, 6x6'),
            fig('c_wallpaper_lit.png', "2 tiles under style-01's warm light"),
            fig('c_style_wall.jpg', 'style-01, the back wall'),
            fig('c_src_crop-wallpaper-01.jpg', 'crop-wallpaper-01'),
        ]),
        ('Parquet', 'parquet.png: RGB albedo (sRGB) and A roughness (linear), 1024 px, one tile 0.99 m a side (10.3 px/cm); '
         'oak planks 7 x 35 cm, 40 a tile.', [
            fig('c_parquet_albedo.png', 'albedo, flat'),
            fig('c_parquet_rough.png', 'roughness (A): 0.35-0.5 a plank, joints 0.8'),
            fig('parquet_height.png', 'height (optional): joints 1 mm, bevels'),
            fig('c_parquet_3x3.jpg', 'tiled 3x3 (3 m)'),
            fig('c_parquet_far.png', 'from afar: an eighth, 6x6 (6 m)'),
            fig('c_style_floor.jpg', 'style-01, the floor'),
            fig('c_src_library-parquet-01.jpg', 'library-parquet-01 (the download)'),
        ]),
        ('Wainscot oak', 'wainscot_oak.png: RGB albedo (sRGB) and A roughness (linear), 1024 px, one tile 0.50 m a side '
         '(20.5 px/cm), grain along y; rails swap u and v.', [
            fig('c_wainscot_oak_albedo.png', 'albedo, flat'),
            fig('c_wainscot_oak_rough.png', 'roughness (A): 0.38-0.48 a board'),
            fig('c_wainscot_oak_3x3.jpg', 'tiled 3x3 (1.5 m)'),
            fig('c_wainscot_oak_far.png', 'from afar: an eighth, 6x6'),
            fig('c_src_crop-wainscot-01.jpg', 'crop-wainscot-01'),
            fig('c_style_wainscot.jpg', 'style-01, the wainscot'),
            fig('c_src_library-wainscot-01.jpg', 'library-wainscot-01 (the download)'),
        ]),
    ]
    if has_rug:
        sections.append(('Rug', 'rug.png: RGB sRGB, 1536 x 1126, the whole rug, 3 x 2.2 m '
                         '(5.1 px/cm). Roughness 1.0 throughout: no map.', [
            fig('rug.png', 'flat', 'wide'),
            fig('c_src_library-rug-01.jpg', 'library-rug-01 (the download)', 'wide'),
            fig('c_style_rug.jpg', 'style-01, the rug'),
        ]))

    body = '\n'.join(
        f'<section><h2>{title}</h2><p>{note}</p><div class="row">{"".join(figs)}</div></section>'
        for title, note, figs in sections)
    html = f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Library materials</title>
<style>
:root {{ --bg: #1b1a19; --fg: #e8e4dc; --muted: #a39d92; }}
body {{ background: var(--bg); color: var(--fg); font: 15px/1.45 system-ui, sans-serif;
       margin: 0; padding: 16px 24px 48px; }}
h1 {{ font-size: 22px; margin: 8px 0 4px; }}
h2 {{ font-size: 18px; margin: 32px 0 4px; }}
p {{ color: var(--muted); margin: 0 0 12px; max-width: 70ch; }}
.row {{ display: flex; flex-wrap: wrap; gap: 14px; align-items: flex-start; }}
figure {{ margin: 0; width: 420px; max-width: 100%; }}
figure.wide {{ width: 640px; }}
img {{ width: 100%; display: block; image-rendering: auto; background: #000; }}
figcaption {{ color: var(--muted); font-size: 13px; margin-top: 4px; }}
</style></head><body>
<h1>Library materials</h1>
<p>Baked by tools/materials/*.py. Each material flat, tiled 3x3 to show seams, from afar
(box-filtered to an eighth in linear light, as a mip level), and beside the concepts.
Roughness is perceptual (Filament's), shown as grey: white is 1. Click an image to open it full size.</p>
{body}
<script>document.querySelectorAll('img').forEach(i => i.onclick = () => window.open(i.src));</script>
</body></html>
'''
    path = os.path.join(out, 'contact.html')
    with open(path, 'w') as f:
        f.write(html)
    print('wrote', path)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
