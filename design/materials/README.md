# Materials

Masks the 3D room's surfaces sample, built into the program from here
(`src/native/materials.c`).

| File | What it is |
| --- | --- |
| `wallpaper_mask.png` | The library's wallpaper: the gold flowers as one channel, 1024² L8, tileable, 0.6 MB. 0 is the ground, 1 the gold print; `shaders::ROOM_FRAG` tints it and keys its roughness from `surfaces::LOOK` and tiles it over 1.4 m of wall (`surfaces::PAPER_TILE`). In git. |
| `plaster_tone.png` | The library's limewash (`tools/materials/plaster.py`): its tone, 1024² L8, tileable over 4 m (`surfaces::PLASTER_TILE`), 0.66 MB. `ROOM_FRAG` tints it from `surfaces::LOOK.plaster_shade` to `.plaster_light` in linear light, with a slow noise in the room's frame over it so the tile's patches don't repeat, on the ceiling, cornice, reveals and arches. In git. |
| `lace_mask.png` | The lace's coverage (`tools/materials/lace.py`, its first bake, a stand-in), 1024² L8 over 0.56 m (`surfaces::LACE_TILE`), 0.26 MB: 0 where the light passes, 1 the thread. In git. |

To make the mask again, with numpy and Pillow from Homebrew and the downloads of
`design/manor/` at hand (`library-wallpaper-mask-01.png`, `library-wallpaper-01.png`;
local, not in git):

```sh
python3 tools/materials/wallpaper.py OUT_DIR
cp OUT_DIR/wallpaper_mask.png design/materials/
touch src/native/materials.c    # the compiled C is cached by its source
```

The baker also writes `wallpaper_preview.png` and `wallpaper_rough.png`, which stay out of
git: the shader takes the colours and roughness from the mask. The plaster and the lace the
same way: `python3 tools/materials/plaster.py OUT_DIR` and `lace.py OUT_DIR`, then copy
`plaster_tone.png` and `lace_mask.png` here and touch `src/native/materials.c`.
