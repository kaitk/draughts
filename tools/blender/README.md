# Blender

The library room in Blender, for reference renders with Cycles to judge the app's light
against a path tracer (task 120). Two steps: the Goose exporter writes the room's meshes
and light from the program's own code, and `scene.py` builds the Blender scene from them
and renders one of the light tuner's views.

## Run

From the repository's root:

```sh
python3 scripts/mac.py tools/blender_export.goose -o build/blender/export   # render3d needs the patched goose_gfx
GOOSE_GFX_HEADLESS=1 build/blender/export --maps on   # room.obj, scene.json and the table's maps
/Applications/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 \
    --python tools/blender/scene.py -- --view close --samples 512
```

`scene.py` writes `build/blender/<view>.png` (AgX), `.exr` (multilayer: the combined
image and the diffuse passes), `-light.png` (the diffuse light alone, direct and
indirect without the albedo: the light the app's shading puts on a white surface), and
`.json` (the time and the means). Its flags: `--view NAME`, `--out PATH`, `--size WxH`
(960x540), `--samples N` (512, denoised), `--exposure EV` (0), `--textures on|off`,
`--device gpu|cpu`, `--save-blend` (a `.blend` beside the render, to open in Blender).
Hold the GPU lock while rendering (`agents/perf.md`).

The exporter's flags set the room as the tuner's do: `--table-at X,Y`, `--sun AZ,HEIGHT`,
`--window-turn DEG`, `--table-turn DEG`, `--lace-hang M`, `--books`, `--chairs`, `--rug
on|off`. `--maps on` also bakes the table's wood on the GPU with render3d's own bake (autumn,
the flame mahogany, as the tuner) and saves `table_albedo.png` (sRGB, the polish's roughness
in alpha) and `table_normal.png` (the normal's x and z in r and g, the wear's patches in b). The defaults are the tuner's at its default placement (less-turned).

## The frame

Metres, z up, the table's middle (the board's world origin) on the floor at the origin:
x is the table's plan x less the plan's x, y the plan's y less the table's. The plan's own
frame is mirrored against the world's, so the export turns it instead.

## What is exported

`room.obj` has an object for each part and material, named as its material: the shell's
`floor`, `oak` (the wainscot and the cases), `paper`, `stone`, `plaster`, `ceiling`,
`paint`, `books`, `stove_tile`, `brass`, `cord`; the window's `glass` and `lace`; the
`table_top`, `table_base`, `chair_wood`, `chair_seat`, `chair_trim`, and the `rug`. Each
vertex keeps its normal and its uv as the app makes them (world units on the chairs'
cloth, the rug's 0 to 1). `scene.json` has the sun (toward it, and its irradiance as the
shaders' `sun.light`), the sky's radiance through the windows and the bake's gains, the
albedos from `room_light`, and the named views: `down`, `corner`, `room`, `window`,
`hall`, `stove`, `menu` (the table-window view at less-turned), `front`, `close`, `low`,
`base`, each an eye, a target and a vertical field of view as the tuner frames them.

Each triangle is wound to face its vertices' normals: the app draws both sides and its
winding varies, and a path tracer flips the normal on a back face, which turns a lit
surface black. `scene.py` puts a black box round the shell, unseen by the camera and open
only at the windows' outer openings (`windows` in `scene.json`), since the shell, made for
rasterising, has gaps the sun and the sky would leak through.

`scene.py`'s `.json` also gives the light alone on the table's and the chairs' pixels by
the way each faces (toward the window, away, up, down, along the wall).

## Materials

Each surface at its mean albedo (`room_light`'s) with the shaders' roughness, from
`scene.json`'s `gloss` (the oak, the paper, the plaster, the paint, the stone; the floor's
wax as a clear coat, `rooms::Room.planar`; the brass from `surfaces::LOOK.brass`). The
table's wood from its maps, on the uv the export gives where `TABLE_FRAG` reads them (the
top from above, the edge unrolled, the base its own way, the chairs the plain base's),
recoloured for the base (`render3d::base_wood`, `base_look`) and the chairs (`CHAIR_WOOD`),
under the polish as a clear coat (`tables::Table.coat`), the top with its normal map.
Pictures from `design/materials/`: the chairs' tapestry (`tapestry.png`, 240 mm a tile)
and the rug (`rug.png`), both at a 2.2 gamma. The glass is two panes letting 0.92 each
through without refraction, reflecting 0.6 of Fresnel's; the lace a sheet letting
`LACE_LETS` through and its thread throwing `LACE_SCATTER` of the rest forward and as much
back. `--textures off` gives every surface its mean albedo, matte, for the light alone; with
textures on, `-light.png` takes off the gloss passes, which are not denoised.

## Left to do

- The procedural surfaces the program makes at startup: the oak's grain, the floor's
  herringbone, the wallpaper's print (`wallpaper_mask.png` tinted by `surfaces::LOOK`),
  the limewash (`plaster_tone.png`), the limestone sills, the books' spines
  (`books_atlas.png` and `book_cells.goose`), the stove's glaze, the lace's pattern
  (`lace_f3.png`). Each needs its uv as the shader takes it.
- The board and the pieces; the park and the tree outside (the bake dims the sun by the
  tree's leaves, about a quarter through two of the three windows; not modelled).
- Gloss: the polish's blotches and the wear tile (scratches, crazing, dents), the key's
  highlight widened to a window's (`coat.w`), the sides' figure drawn out along the grain
  (`SIDE_STREAK`), the sheen lobes; the base's mapping is per vertex, not per pixel.

## Import (planned)

Bringing shapes from Blender's ecosystem into the app (the rule: a downloaded model brings
its shape only; its surfaces take our procedural materials):

- Format: glTF 2.0 (`.glb`) or OBJ from Blender, triangulated, normals and one uv set.
- Our side: positions, normals and uvs into flat vertex and index arrays like
  `mesh::Vertex` or `corner_map::RoomVertex`, embedded in the program (`#embed`, as the
  pictures are) or loaded at startup; a material kind per part, mapped from the Blender
  material's or object's name to our `MAT_*` kinds (`surfaces`, `mesh`, `chairs`).
- A round trip works when both ways share this export's frame (metres, z up, the table at
  the origin), its units, and its object names; an imported part then lands where the
  exported one was, and the room's code turns it into the room's frame as it does the shell
  (`from_room`'s inverse).
