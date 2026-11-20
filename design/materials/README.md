# Materials

Masks the 3D room's surfaces sample, built into the program from here
(`src/native/materials.c`).

| File | What it is |
| --- | --- |
| `wallpaper_mask.png` | The library's wallpaper: the gold flowers as one channel, 1024² L8, tileable, 0.6 MB. 0 is the ground, 1 the gold print; `shaders::ROOM_FRAG` tints it and keys its roughness from `surfaces::LOOK` and tiles it over 1.4 m of wall (`surfaces::PAPER_TILE`). In git. |

To make the mask again, with numpy and Pillow from Homebrew and the downloads of
`design/manor/` at hand (`library-wallpaper-mask-01.png`, `library-wallpaper-01.png`;
local, not in git):

```sh
python3 tools/materials/wallpaper.py OUT_DIR
cp OUT_DIR/wallpaper_mask.png design/materials/
touch src/native/materials.c    # the compiled C is cached by its source
```

The baker also writes `wallpaper_preview.png` and `wallpaper_rough.png`, which stay out of
git: the shader takes the colours and roughness from the mask.
