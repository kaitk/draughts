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
indirect without the albedo: the light the app's shading puts on a white surface),
`-combined.npy` (the combined light, for `app_camera.py`), and `.json` (the time and the means). Its flags: `--view NAME` (or the tuner's `--plan-eye X,Y,Z
--plan-at X,Y,Z --fov DEG`), `--out PATH`, `--size WxH`
(960x540), `--samples N` (512, denoised), `--exposure EV` (0), `--textures on|off`,
`--device gpu|cpu`, `--save-blend` (a `.blend` beside the render, to open in Blender),
`--paper physical|look` (the wallpaper as the app's `--light physical` draws it, the default,
with its engraved mask, `--paper-mask engraved|today`), `--wood ours|picks|SPEC.json` (the
panelling, the table and chairs, and the floor as finished woods, as the tuner's `--woods`;
the specs in `woods/`).
Hold the GPU lock while rendering (`agents/perf.md`).

The exporter's flags set the room as the tuner's do: `--table-at X,Y`, `--sun AZ,HEIGHT`,
`--sun-take K,H` (the sun's strength over the clear sky's and the height its colour is taken
as: `--light physical`'s autumn sun, 0.25 and 8 degrees, by default; 1,-1 the clear sky's),
`--window-turn DEG`, `--table-turn DEG`, `--lace-hang M`, `--books`, `--chairs`, `--rug
on|off`, `--box-window on|off` (task 127's box window, on; off window B, to be dropped), `--backs on|off` (the casements' backs, which the room's mesh leaves out since they
face away from the room; on, or the space between the panes takes too little light). `--maps on` also makes, on the GPU with the app's own code, the pictures the
surfaces read (the defaults are the tuner's at its default placement, less-turned):

- `table_albedo.png` (sRGB, the polish's roughness in alpha) and `table_normal.png` (the
  normal's x and z in r and g, the wear's patches in b): render3d's bake of the table's
  wood (autumn, the flame mahogany, as the tuner).
- `wall_albedo.png` and `wall_normal.png`: the panelling oak's field as render3d bakes it
  (`BAKE_FRAG`'s mode 5, 2048², a tile of `WALL_FIELD`), the roughness in alpha, its slopes
  along u and v in r and g.
- `floor_albedo.png` and `floor_normal.png`: the floor drawn by `ROOM_FRAG` itself, unlit
  (its `SURFACE_OUT` define), laid out in the floor's uv: the herringbone, each plank's
  place in the oak's field, its tone, the patched ones, the joints, the wear round the table
  and along the room, the darker wax along the walls, the scratches; the roughness in
  alpha; the normal along u, v and up (the grain, the planks' tilt and cup, 8 bits). A
  texel is `--floor-mm` millimetres (2: 4500 × 3500, about 50 MB).

## The frame

Metres, z up, the table's middle (the board's world origin) on the floor at the origin:
x is the table's plan x less the plan's x, y the plan's y less the table's. The plan's own
frame is mirrored against the world's, so the export turns it instead.

## What is exported

`room.obj` has an object for each part and material, named as its material: the shell's
`floor`, `oak` (the wainscot and the cases), `paper`, `stone`, `plaster`, `ceiling`,
`paint`, `books`, `stove_tile`, `brass`, `cord`; the window's `glass` and `lace`; the
`table_top`, `table_base`, `chair_wood`, `chair_seat`, `chair_trim`, and the `rug`. Each
vertex keeps its normal and its uv as the app makes them (world units on the shell and the
chairs' cloth, the rug's 0 to 1), and a colour: r its occlusion, g its piece's own tone
(the material's fraction). `scene.json` has the sun (toward it, and its irradiance as the
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

## Through the tuner's camera

`scene.py`'s PNG is Blender's AgX at `--exposure`, with no season's grade, so beside the
tuner's `--light physical` shot it differs in the camera as well as the light.
`app_camera.py` (plain Python, numpy and Pillow) writes the picture the tuner's camera
makes of Cycles' light: the tuner's metered exposure from its log, HDR_TONE_FRAG's AgX fit
and the season's grade, with Cycles' radiance taken as the tuner's light as is (units 1,
measured on the sunlit door; the header has how). Shoot both at the same view and size:

```sh
cd tools && GOOSE_GFX_HEADLESS=1 ../build/light_tune --season autumn --light physical --woods ours \
    --plan-eye 6.5,4.3,1.4 --plan-at 2.655,5.403,1.400 --fov 73 --size 1536x1024 --shot ref.png > ref.log
cd .. && Blender -b --python-exit-code 1 --python tools/blender/scene.py -- --wood ours \
    --plan-eye 6.5,4.3,1.4 --plan-at 2.655,5.403,1.400 --fov 73 --size 1536x1024 --out build/x/ref
python3 tools/blender/app_camera.py build/x/ref-combined.npy --log tools/ref.log --out build/x/ref-app.png
```

`--compare tools/ref.png` prints the levels between the two; `--grade none`, `--white`,
`--look` and `--saturation` change the grade, `--ev` the exposure. It takes an older render's
`.exr` too, through Blender's own Python. The port's check, the tuner's `--tone-probe` light
through it against its own shot, is in the header.

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
through without refraction, reflecting 0.6 of Fresnel's; the lace as `room_light` describes
it (`scene.json`'s `lace`, task 124): its mask (`design/materials/lace_f3.png`) on the uv as
`LIGHT_FN`'s `lace_place` lays it, the thread `density` of the cloth where the mask is 1 and
more at a slant, scattering its albedo diffusely, `through` of it on through the cloth and the
rest back (`--lace sheet` the sheet letting `LACE_LETS` through before; `--lace-seen` shows the
thread's own light). The room's surfaces from `--maps on`, as `ROOM_FRAG` reads them, its values in `scene.json`'s
`surfaces`: the floor's pictures over its uv's rectangle (`floor_laid`), under the wax as a
coat at the oak's roughness times the wax's share, following a quarter of the relief; the
panelling's field a tile of `wall_field` on the uv, each piece's tone and the thresholds by
the vertex colour's g, the grime and roughness by its r; the wallpaper's mask
(`design/materials/wallpaper_mask.png`) a tile of `paper_tile`, mixed from its ground to its
gold print in linear light, their roughness likewise. Without the maps these three keep
their mean albedos.
`--textures off` gives every surface its mean albedo, matte, for the light alone; with
textures on, `-light.png` takes off the gloss passes, which are not denoised.

## The antique brass (task 129)

The window's hardware as a mottled, aged brass, as ROOM_FRAG draws it with the light tuner's
`--window-metal LEVEL,MOTTLE,ROUGH,NICHE`: the exporter takes the same flag, writes the game's
tile (`brass_tile.ppm`, from `room_shell::brass_tile`) and the values (`gloss.window_metal_look`),
and `scene.py` puts the material on `window_metal` (`--window-metal flat|LEVEL` overrides the
level). `brass_model.py` holds the model and the levels, `brass.py` the Cycles material (the tile
box-projected by position, the wear from the vertex colour's g), `brass_check.py` the
controlled check: a sphere, the real handle and a plate under neutral light (`--level
LEVEL|clean|flat`, `--turn on` mirrors the light, `--mottle`, `--micro DIR` the concept's
micro-finish). `brass_tile.py` made the concept's tile and solves the levels from the game's:

```sh
GOOSE_GFX_HEADLESS=1 build/blender/export --box-window on --window-metal 4 --maps on
python3 tools/blender/brass_tile.py --levels build/blender/brass_tile.ppm   # brass_model.LEVELS, ROOM_FRAG's BRASS_*
Blender -b --python-exit-code 1 --python tools/blender/brass_check.py -- --level 4
Blender -b --python-exit-code 1 --python tools/blender/scene.py -- --exposure 3.4 \
    --plan-eye 4.3,6.75,1.55 --plan-at 4.5,7.4,1.64 --fov 20 --out build/scratch/handle
```

`scene.py` takes the tuner's `--plan-eye`, `--plan-at` and `--fov` in place of a named view.

## Left to do

- The procedural surfaces still flat: the limewash (`plaster_tone.png`), the limestone
  sills, the books' spines
  (`books_atlas.png` and `book_cells.goose`), the stove's glaze, the lace's pattern
  (`lace_f3.png`). Each needs its uv as the shader takes it.
- The board and the pieces; the park and the tree outside (the bake dims the sun by the
  tree's leaves, about a quarter through two of the three windows; not modelled).
- The floor's wax per board (`PLANAR_FLOOR`'s `wax`: each board's own, none in the joints,
  thinner where worn), and the sheen lobes on the oak and the paper.
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
