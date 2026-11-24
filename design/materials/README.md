# Materials

Masks the 3D room's surfaces sample, and the pictures of the view out of its windows,
built into the program from here (`src/native/materials.c`).

| File | What it is |
| --- | --- |
| `wallpaper_mask.png` | The library's wallpaper: the gold flowers as one channel, 1024² L8, tileable, 0.6 MB. 0 is the ground, 1 the gold print; `shaders::ROOM_FRAG` tints it and keys its roughness from `surfaces::LOOK` and tiles it over 1.4 m of wall (`surfaces::PAPER_TILE`). In git. |
| `plaster_tone.png` | The library's limewash (`tools/materials/plaster.py`): its tone, 1024² L8, tileable over 4 m (`surfaces::PLASTER_TILE`), 0.66 MB. `ROOM_FRAG` tints it from `surfaces::LOOK.plaster_shade` to `.plaster_light` in linear light, with a slow noise in the room's frame over it so the tile's patches don't repeat, on the ceiling, cornice, reveals and arches. In git. |
| `outside_band.png` | The park's far tree line on a cylinder 110 m out (`tools/materials/outside.py`), 2048 × 336 RGBA over ±64° from straight out, 16 px a degree, rows linear in height from 14.05 m under the lawn to 26.26 m over it; sRGB, premultiplied in linear light, its sky cut to clear; 0.44 MB. `model3d::view_out` puts it on its cylinder round the middle window, `shaders::OUTSIDE_FRAG` draws it unlit. In git. |
| `outside_oak.png` | The oak, 29.8 × 20 m, a billboard 70 m out at 22° right of straight out, 584 × 392 RGBA as the band, 0.26 MB. In git. |
| `books_atlas.png` | The library's books' spines (`tools/materials/books.py`), 1024 × 928 RGBA at 0.7 texels a millimetre, 194 cells (a volume each of `book_titles.py`'s 51 titles) packed in rows by height with 4 texels between: R the cover's tone (in 64 steps), G gilt or ink, B the label, A wear (in 16 steps), 1.03 MB. The baker writes its cells and the covers' and labels' colours as `src/model3d/book_cells.goose`; `shaders::ROOM_FRAG` colours a spine from them (`model3d::books`). In git. |
| `rug.png` | The rug under the games table (`tools/materials/rug.py`), drawn from nothing: 1280 × 880 RGBA at 2.5 mm a texel, 3.2 m along (the pile's 3 m and 0.1 m of fringe at each end) by 2.2 m; sRGB albedo with no light in it, A the fringes' cover (1 on the pile), 2.1 MB. `shaders::ROOM_FRAG` lays it on the floor round the table (`render3d::put_rug`). In git. |
| `lace_f2.png`, `lace_f.png`, `lace_d.png` | The curtains' lace, three ways of it while the choice is open (f2 shown, the light tuner's `--lace` picks another): the way's field tile (1024 rows over 0.56 m, `surfaces::LACE_TILE`) over its hem's border (384 rows, 0.21 m), 1024 × 1408 L8, 0.7 MB each: 0 where the light passes, 1 the thread. `tools/materials/lace_panel.py` puts each together from the lace library's bake (`tools/materials/lace_rose2.py` for f2, `lace_rose.py` for f, `lace_blossom.py` for d); `shaders::ROOM_FRAG` reads down the field's tile and on into the hem at the cloth's foot. In git; the two not chosen go once the user chooses. |

To make the mask again, with numpy and Pillow from Homebrew and the downloads of
`design/manor/` at hand (`library-wallpaper-mask-01.png`, `library-wallpaper-01.png`;
local, not in git):

```sh
python3 tools/materials/wallpaper.py OUT_DIR
cp OUT_DIR/wallpaper_mask.png design/materials/
touch src/native/materials.c    # the compiled C is cached by its source
```

The baker also writes `wallpaper_preview.png` and `wallpaper_rough.png`, which stay out of
git: the shader takes the colours and roughness from the mask. The plaster the same way:
`python3 tools/materials/plaster.py OUT_DIR`, then copy `plaster_tone.png` here and touch
`src/native/materials.c`. The lace, from a way's bake in the lace library:

```sh
python3 tools/materials/lace_rose2.py build/notes/lace-library/f2 --seed 4   # MANOR_DIR as its header says
python3 tools/materials/lace_panel.py build/notes/lace-library f2 design/materials/lace_f2.png
touch src/native/materials.c
```

The books' atlas and its cells, from the titles in `tools/materials/book_titles.py`,
set in the OFL fonts in `tools/materials/fonts/` (each with its `OFL.txt`; the fonts stay
there, only the PNG goes into the program):

```sh
python3 -I tools/materials/books.py OUT_DIR            # --preview adds atlas_colour.png
cp OUT_DIR/books_atlas.png design/materials/
cp OUT_DIR/book_cells.goose src/model3d/
touch src/native/materials.c
```

The view out's band and oak, from task 109's panels and oak in `design/manor/outside/`
(local), as `design/manor/outside/park.py` puts them together; the sky is worked out in the
shader, so the baker's `outside_sky.png` stays out:

```sh
python3 -I tools/materials/outside.py OUT_DIR      # MANOR_DIR=<checkout>/design/manor from a worktree
cp OUT_DIR/outside_band.png OUT_DIR/outside_oak.png design/materials/
touch src/native/materials.c
```

The rug, drawn by its baker alone (no download; `--preview` adds `rug_preview.png`, the rug
on a floor-brown ground):

```sh
python3 -I tools/materials/rug.py OUT_DIR
cp OUT_DIR/rug.png design/materials/
touch src/native/materials.c
```
