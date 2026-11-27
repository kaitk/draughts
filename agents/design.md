# Design work: references, images, and the look

What a session needs to work on the app's look without the conversations that settled it.
The values themselves are in `docs/architecture/rendering.md` ("Look"); this file says
where they came from, how to check against them, and what has been tried.

## Reference images

All of them are local, in `~/Downloads` on the user's Mac, made with ChatGPT image
generation, and are not to be checked in. On another machine or account they may be
missing: ask the user for them rather than guessing from memory.

| File | What it shows | Use it for |
| --- | --- | --- |
| `Autumn Checkers Board with Crowned King-1.png` | A close-up of the autumn board, 1254 px | The preferred board and pieces: the thin raised lip with a light outer line, one wide rim around a flat face, warm wood with calm grain |
| `Winter Stone Checkers Board-2.png` | The same close-up for winter | The same, in stone: a steel-blue lip, felt-like squares |
| `ChatGPT Image Nov 7, 2026, 08_19_31 PM.png` | The autumn board in 3D, a low angle | The pieces' true shape: flat-topped matte discs with a fine step, rounded only at the outer edge; read the top-down look from it |
| `kabe_theme_design_boards/kabe_autumn_wood.png` | The autumn design board: home, game in both orientations, puzzles, palette | Layout, panel, buttons, states (glow ring, dots, red ring) |
| `kabe_theme_design_boards/kabe_winter_stone.png` | The winter design board | As above |
| `kabe_theme_design_boards/kabe_spring_birch_four_seasons.png` | The four seasons side by side, and the spring screens | Each season's palette and scene |
| `kabe_theme_design_boards/kabe_winter_sea_comparison.png` | Winter and summer (sea) screens | The sea theme |
| `Kabe Winter Stone UI Board.png` | A winter UI board, 1536 px | Glass panels and buttons |
| `draughts-store/icon/master-winter-jump-1254.png` | The winter jump: a 3×3 stone board at three-quarters, a dark slate piece in the centre, the ivory stacked king jumping it along a pale blue arc, on navy (#06172b corners, #0d2139 top) | The winter master: copy it to `design/icon/master-winter.png` and run `tools/assets/icon.py` (`design/icon/README.md`); the monochrome layer is drawn from its geometry |
| `draughts-store/icon/master-autumn-jump-1254.png` | The autumn jump, the shipped icon: the same scene in wood, a dark brown piece, the cream king, a golden arc, on dark brown (#140c09 corners) | The autumn master: `design/icon/master-autumn.png`, built with `tools/assets/icon.py autumn --res DIR`; its geometry matches winter's within 0.25 dp |
| `Autumn Light in the Manor Library.png` | ChatGPT's repaint of our own `--light physical` shot (`draughts-now-autumn-physical.png`: autumn, `--plan-eye 6.5,4.3,1.4 --plan-at 2.655,5.403,1.400 --fov 73`, 1536 × 1024, the same framing) in `library-autumn-02`'s style (2026-11-26; copies in `build/notes/autumn-grade/img/`) | The autumn tone and grade (the door's wall, the floor, the wainscot, the ceiling), and the lace lit against the lace in shade; not its sun patches on the far wall, which our sun can't throw |
| `draughts-store/tablet-home-with-icons.png` | The icon candidates mocked up on the tablet's real home screen, 82 px | How an icon reads at the launcher's size |

Where the close-ups and the design boards differ, the close-ups win for the board and
pieces; the design boards still set the layout, glass, and controls.

## How the user makes images

- Design boards and backgrounds come from ChatGPT; the user asks for the prompts
  (the design boards' prompt is in git history at fed389b,
  `prototypes/design-boards-prompt.md`; the backgrounds' in `design/backgrounds/README.md`) and saves the
  results to `~/Downloads`.
- Final backgrounds get an AI upscale on the user's Windows desktop (RTX 4090, ComfyUI)
  with Snowtime's pipeline. Originals and masters stay local and out of git,
  with a README saying how to make them again.

## Checking a look against the references

- Comparisons with Cycles go through the light tuner's camera: `tools/blender/app_camera.py`
  takes Cycles' light (`scene.py`'s `-combined.npy`) and the tuner's log at the same view
  and writes the picture the tuner's exposure, AgX and season's grade would make of it, so
  only the light differs. Cycles' own PNG has another exposure and no grade (2026-11-27).
- Look at the reference up close before writing a shader: crop and enlarge with
  `magick ref.png -crop WxH+X+Y +repage -resize 300% crop.png`, and read the crop.
- Put the app's screenshot beside the reference at the same scale
  (`magick ours.png ref.png +append cmp.png`): `--size 960x600` on a 2× Mac saves
  1920 × 1200.
- Measure colors instead of judging them: `magick ref.png -crop 100x100+X+Y +repage
  -scale 1x1! -format '%[pixel:p{0,0}]' info:` gives a patch's mean.
- Text bare on the photograph that a bright patch (birch bark, snow) washes out:
  `gui::shadowed` draws it over a dark halo with no shader change (the text shader takes
  a dark color from `gui::write` with `own` true); the alternative is a glass pill.
  Spring's birch is the brightest patch behind the left edge in the tablet's landscape.
- To show that a change touched only one thing, take the same headless shot before and
  after and box the differing pixels: `magick a.png b.png -compose difference -composite
  -threshold 0 -format '%@' info:` prints the box (WxH+X+Y).
- Preview SVG (an icon's vector layer, say) in a browser page shot with `agent-browser`:
  ImageMagick's built-in SVG renderer drops stroked paths, and the Mac has no `rsvg`.
  For an icon, show the central 72 of its 108 dp in circle and squircle masks at 48 and
  82 px (the tablet's launcher size).
- A UI icon: judge it at the row's 34 dp, not large. Where a solid
  shape meets an outline, either let it run under the outline or cut a clear gap (about
  1.5 units); a hairline between them reads badly. An outlined isometric disc needs about
  2.5 units in its top ellipse and 3 in its side, or it fills in. ChatGPT is useful for
  ideas but places things loosely; the 3D prototype's `--jump` gave a real pose to draw
  from (`poc/3d/board3d.goose`, in the history before 2026-11-14).
- Tuning a 3D look with sliders: the 3D prototype's panel (P, V or Print prints the
  values) no longer builds against `src/render3d/`, so run it from the tree it last built
  in: `git archive 29ae796^ | tar -x -C <scratch>`, link `third_party/goose_gfx`,
  `third_party/smaa`, and `build/goose-v2026.4-macos-arm64` into it, copy the look's
  current lines from `src/model3d/looks.goose` and the shader's in, then from its
  `poc/3d` `goose build -o board3d board3d.goose` and `board3d --theme summer --summer 6
  --panel` (the flags in its header). Its renderer is the older one, so carry back the
  printed values, not its shots (2026-11-16, summer's stone).
- The pieces' values have a tuner of their own on the current renderer,
  `tools/piece_tune.goose` (task 094), run from `tools/`. Its Pieces slider previews
  Plastic, Jade, maple and walnut (Wood, with Varnish and Relief sliders), or ivory with
  Slate or polished black Marble, independently of the board; B toggles their scattering.
  On winter's stone board the Marble slider (and `--marble N`) picks the frame's marble;
  the spring Stone board has its own scattering switch, its strength, radius and color
  depth printed. Key moves the light with its shadow: compare on minus off at each key
  position with the camera fixed. The defaults are the look's, which the game uses on a
  desktop. `--shot` saves the board without the controls. Spring stone has Jade and
  Plastic as profiles 0 and 1 for `board_shot`.
- The table under the 3D board: `tools/table_tune.goose` (task 095), its take, season,
  wood, age, polish, light and edge on sliders; P prints the table as Goose for
  `src/model3d/tables.goose`.
- What each side has taken, on the table: `tools/taken_tune.goose` (task 099); P prints a
  command that shows the same again and the layout's `TableLayout` literal for
  `taken3d::TABLE_LAYOUTS`.
- The room's light, the window, and the tree outside: `tools/light_tune.goose` (tasks 104
  and 105); `--dump-map out.pgm` writes the tree's map as the sun sees it (the board falls
  on its middle third), P prints the room as Goose for `src/model3d/rooms.goose`. Script
  sweeps of its flags under bash: zsh passes an unquoted `$args` as one word.
- The room round the table, its herringbone floor and panelling (`model3d::surfaces`):
  the light tuner (always with the room; the app's board alone is the app's), `--view room` (V), `--eye X,Y,Z,0 --at
  X,Y,Z,0` for a camera of its own, `--dump-oak PREFIX` for the baked fields at 1:1,
  `--wallpaper-tile M` for the wall a tile of the wallpaper covers (0.9 m; the slider
  under Wallpaper, 0.65 to 1.4 m, and L cycles a real paper's 0.65 m, 0.9 m and
  style-01's 1.4 m). The
  library's window is smaller than the room's plan; for the room's shots pass a 1.1 ×
  2.5 m one, `--panes 11,12.7,1,0 --opening 3,6,4,0.45 --wall 36,20,-2,2`. The room
  is judged as lit, no lift: its own light is `--bounce` and `--room-exposure`
  (rooms::Room's, the room's surfaces only), so the board's stays as it is (task 104's
  notes, `build/notes/room-oak-2/`). Before-and-after pairs of the tuner from an older
  commit: `git archive` it into a scratch folder, link `third_party/*`,
  `build/goose-v2026.4-macos-arm64` and `build/mac/goose` into it, and build there.
- The light tuner's gusts (`rooms::Room.gust`): `--gust-strength K`, `--gust-length S`,
  `--gust-every S` (the wind's seconds), `--gust-reach K` (how much of the crown, 1 all),
  on sliders under Wind and printed by P. A sequence of a gust: shots at `--wind-time`
  0.25 s apart, one run each; against the same times with `--gust-strength 0` for its
  footprint (`build/notes/gusts/`).
- The light tuner's frame counter (F, top right): frames a second, the mean and worst
  frame over half a second, and the time in the loop before the submit; G (`--fps-wait`)
  waits for the GPU each frame, as `--bench`'s first phase. SDL's GPU has no timer
  queries, so no GPU time: for that, a Metal System Trace (`agents/testing.md`).
  `--fps-seconds S` prints each half second's line and quits, headless too. Uncapped on
  the Mac the GPU clocks down until it is busy, so a light scene reads about 3.4 ms
  whatever it draws; a cost shows once it passes that.
- The stove (2026-11-24, `build/notes/stove-build/`): `build/stove-build/shots.sh EXE TAG
  [SIZE] [NAMES]` takes the four views, the board, the stove view and three close-ups
  (`close` the corner at eye height, `top` the frieze, cornice and crest, `foot` the
  plinth and the door).
- The library's whole room in the light tuner (`model3d::room_shell`, task 107's demo):
  the shell (walls, wainscot, three box windows, two doors, cornice, ceiling). `--view room|window|hall|stove` (V cycles them after the board's
  orbit) are a person's eyes in the plan; `--plan-eye X,Y,H --plan-at X,Y,H` a camera in plan metres (x along the window
  wall from the stove's end, y from the hall wall, H up from the floor), `--fov DEG`. With
  the shell the room's light comes through its own windows (`shaders::LIGHT_FN`'s
  `shell_open`), not `--wall`/`--panes`, which still light the board and table; behind
  the windows the park (`model3d::view_out`: the sky worked out round the key's sun, the
  band, the oak), or with `--outside off` (U) the plain sky as before (the plain fade, the
  tuner's `SKY_*`, which give the board's ambient either way); the park's exposure is
  `--outside-exposure K`, the slider "Outside's exposure" (`rooms::Room.outside`, printed
  by P). The view toward the sun from the window's middle: `--plan-eye 4.5,6.6,1.6
  --plan-at 4.84,7.54,1.93 --fov 30`. `--dump-map` writes the
  map the renderer bakes then (the shell's 2048 × 768). Its mesh's triangles and making
  time print with a `--shot`'s bake line. The shot pages: `build/notes/room-demo/`,
  `build/notes/room-outside/`.
  The shutters: `--shutters off` (H) leaves them out (the mesh and the bake made again).
  In `shell_mesh`'s wall builders s runs to the left as seen from the room (the plan is
  mirrored into the world), so a door's right leaf is at -s; check a side with a shot.
  Builder 19's close-ups (shutters' hinges, a door's lever): `build/notes/builder-19/shots.sh`.
  The plan's window wall is at y 7.0 (the niche to 7.8), the middle window's reveals at
  x 3.85 and 5.15; builder 19b's close-ups of the cap's return and the brass:
  `build/notes/builder-19b/shots.sh` (`EXE=` runs another tuner binary).
  The curtains (`model3d`'s `curtains.goose`, task 107): `--lace f3|f2|f|d` (C cycles)
  picks the lace's way, f3 the default and the only one built into the app; the others
  are kept in reserve in `design/materials/`, which the tuner reads at the start from
  `tools/` (a way's panel mask by `tools/materials/lace_panel.py LIBRARY TAG OUT`, from
  `build/notes/lace-library/TAG/`; touch `src/native/materials.c` after f3's PNG changes); their shots and close-ups by
  `build/curtains-build/shots.sh EXE TAG` (`build/notes/curtains-build/`). The
  tie-backs' and the hem's close-ups and the lace's ways and table tops side by side:
  `build/choices-2026-11-21/shots.sh` (`build/notes/choices-2026-11-21/`; the right
  tie-back `--plan-eye 5.6,6.3,1.1 --plan-at 5.3,6.9,0.95 --fov 32`, the hem from above
  `--plan-eye 4.0,6.35,0.95 --plan-at 3.78,6.9,0.05 --fov 34`).
  The tie-back's settling (`curtains.goose`'s `settle_tie`): print its result headless
  with a scratch program importing `model3d` and calling `room_shell::settle_tie`
  (`goose run`, half a second), as `build/tieback-top/probe/` did; sweep its constants
  under bash. Close-ups from the front, the side, above and both sides:
  `build/tieback-top/tie.sh EXE TAG`. In PBD a ring's links pull a uniform stretch back
  only weakly (by sin(π/N)), so a soft collider stretches the loop: hence the girth's
  projection, applied to the last positions too so it adds no speed; steps longer than
  1/240 s go unstable with the push's cap and the grip per iteration.
  The games table's base (`mesh::table_base`, task 107): its top 0.95 m across; shots by
  `build/games-table-build/shots.sh EXE TAG` (`build/notes/games-table-build/`), the
  base's close-up `--plan-eye 5.75,4.75,0.62 --plan-at 4.5,5.8,0.36 --fov 42`.
  The shell's own light (task 107's light round): `--shell-sun X,Y` (penumbra's widening,
  the sun on the room over the board's), `--baked SKY,BOUNCE,HARMONICS,SHADE` (the probes'
  two sources and what the room keeps of the old ambient; `0,0,1,1` the old light),
  `--bloom STRENGTH,WHITENESS,KNEE,SIGMA` (`0,0,0,0` off); all printed by P. The bake's
  time prints with the shot's bake line. Shots: `build/light-round-1/shots.sh EXE TAG`
  (the four reference cameras and close-ups), `build/notes/light-round-1/`.
  With the shell on, the tree is `rooms::shell_tree`'s (placed for its three windows),
  not the one `--tree`/`--crown`/`--foliage` set: change it there (task 107's quick
  pass: `build/notes/quick-pass/`, the views and close-ups by `build/quick-pass/shots.sh`).
  Its limbs' width and blur in the map are `rooms::SHELL_LIMBS`. The doors' feet, the
  plinth's corners and the windows close up: `build/leftovers/shots.sh EXE TAG [NAMES]`
  (`build/notes/leftovers/`). To see the probes alone, `--baked 7,12,0,0`.
  The corners' and edges' shade (`rooms::Room.corners`, baked by `model3d::corner_map`):
  `--corners STRENGTH,REACH,0,0` (reach in metres; `0,0.4,0,0` off), the Light section's
  Corners' shade and reach, printed by P. The table's own map (`render3d::table_map`)
  draws whenever the room and the table show. Close-ups of the plinth by a bookcase, an
  inside corner floor to cornice (portrait), the piers' caps, the niches, the doors and
  the table's feet: `build/ao-fixes/shots.sh EXE TAG [NAMES]` (`EXTRA` in the environment
  adds flags; `build/notes/ao-fixes/`). A shader value to check by eye: write it to
  `result` and `return` in a scratch build (the table map's visibility on the base read
  white where the sun reaches, 2026-11-21). The shade is baked (`corner_map`, 2026-11-21): the bake's
  time and atlas print with a shot's bake lines; to judge the map against the old per-pixel
  shade, write `corner` to `result` in both builds (brass set to 1, as it ignores it) and
  compare (`build/b21/shots.sh EXE TAG`, `build/b21/cmp.sh A B`, `build/notes/builder-21/`).
- The light tuner's panel is in sections that open and close, kept for the session
  (`SECTIONS`): Scene, Light (Light in detail inside), Sun and tree (the sun, the tree,
  wind, the board's window, noise leaves), Wallpaper, Wainscot and panelling, Ceiling,
  Curtains and lace, Bookcases and books, Table, Outside, Dust, Camera and views (and the
  walk), Debug, Keys (every key).
  `--sections all|scene,light,..` opens those at the start (names in `SECTION_NAMES`),
  `--shot-panel` draws the panel in a `--shot`. A drag that starts on the panel holds the
  tree's and the probes' bakes (`render3d::Gpu.bake_held`) and bakes once on release.
  `--oak-tint L,S` and `--ceiling-tint L,S` (the panel's Oak light and colour, Ceiling
  light and colour) scale the panelling oak's and the ceiling's albedo in ROOM_FRAG,
  lightness and saturation about its luminance, 1,1 as made; the probes' bounce doesn't
  follow them. The look of 3,0.6 and 0.75,1.5 is baked since 2026-11-21 (the oak's
  `surfaces::Oak.tint` at the end of its bake, the ceiling's `LOOK.ceiling_shade` and
  `ceiling_light`, the probes' and reflections' albedos with them), so 1,1 is that look;
  the baked default matches the old tinted shot within a level on the oak (a shaded
  panel's mean sRGB 49.3, 29.8, 18.1 against 49.0, 29.7, 18.0), the rest moving only
  by the bounce and reflections now following the colours (`build/notes/choices-2026-11-21/`).
  The references' wainscot in shade is about (66,38,22) (`build/notes/reference-compare/`). P prints, after the room's literal, the flags that show
  the same again, exactly (`build/notes/tuner-sections/`).
- The light tuner's walk round the room (`Walk`): Tab or the button under Camera and
  views captures the mouse (goose_gfx's `set_mouse_relative`) and hides the panel; WASD
  walk at 1.4 m/s (Shift 2.5×), the mouse looks (0.1° a pixel, pitch within ±85°), C
  sits (eye 1.2 m, else 1.6 m), Q goes down and E up (1 m/s, free to 0.2 m off the floor
  and the ceiling), R goes back to the view's eye, Esc or Tab (or losing focus) back to
  the panel. While walking the tuner's letter
  keys (W, S, D, C..) are the walk's. It turns the room and its shell on; the eye keeps
  0.6 m off the plan's walls (the views' near plane, 0.39 m, reaches 0.58 m at its
  corners), no furniture collision. The camera stays where the walk left it till R, V or
  another view; P prints it as `--plan-eye`, `--plan-at` (2 m ahead) and `--fov 60`, a
  shot from which matches exactly. The camera isn't light: walking bakes nothing. Tested
  headless by `--walk-test N` (injected keys and mouse, 1/60 s steps; the path's stops and
  P's check by `build/walk-mode/walk.sh EXE OUT`, `build/notes/walk-mode/`).
- The bookcases by the hall door and their books (task 107): `--books off` (B) leaves the
  books out of the mesh (the empty cases), `--book-fade K` scales the sun's fade (1 as
  made; the panel's Their fade). The hall view (`--view hall`) shows both cases; the
  shelves close up and the cases' sides by `build/bookcases-build/shots.sh EXE TAG
  [NAMES]` (`build/notes/bookcases-build/`). A shelf's fill prints in
  `test/model3d/books.goose`. The books' atlas and colours come from
  `tools/materials/books.py` (`design/materials/README.md`); with `--preview` it writes
  the atlas coloured as the shader colours it, to judge a palette without the app.
  The books' fill, colours and fade are worth judging in the hall view against
  `library-autumn-02`'s case (`build/notes/books/crops/la2-bookcase.png`). The tone round
  (`build/notes/books-tone/`, shots by `build/books-tone/shots.sh EXE TAG [NAMES]`) put
  them beside it at the same scale and measured a shelf's mean colour (a 110 × 40 patch
  of books, gaps and all) against the concept's rows: sRGB 0.26, 0.16, 0.10 is the
  target. Change the covers in `books.py` and keep its `colour()` the shader's; a case's
  inside is darkened by the books' and the case's vertex occlusion and `case_shade`
  (the cases' heights repeated in `ROOM_FRAG`: change them with `bookcases.goose`).
- The doors' and windows' painted wood (`room_shell`'s `joinery.goose`, `relief.goose`):
  `--paint-relief K` (the tile, 1 as made; the panel's Wainscot section). A door in the sun
  close up: `--plan-eye 0.7,2.8,1.3 --plan-at 0.0,2.8,1.2 --fov 30`; the casement's meeting
  `--plan-eye 4.45,6.5,1.25 --plan-at 4.5,7.5,1.3 --fov 18`; the shutters `--plan-eye
  4.9,6.0,1.5 --plan-at 3.95,7.25,1.4 --fov 40`. Builder 25's shots and the step matrix:
  `build/b25/shots.sh EXE TAG [NAMES]`, `cmp.sh A B`, `measure.sh ROUND TAG=EXE,FLAGS..`
  (`build/notes/builder-25/`; the steps' and the old paint's flags it used are gone). The
  relief at its physical heights hardly shows in the room's light; at 15 it shows its
  direction (brush along the grain).
- The sills' limestone (`room_shell`'s `limestone.goose`, `shell_mesh::sill_slab`,
  `ROOM_SILL`). The look's values are `surfaces::Look.sill` (arris radius, band's reach, nose's darkening in linear albedo, dust's width); its colour
  is the old stone's (`Look.stone`), so the probes' `STONE_ALBEDO` still holds. Close-ups of
  the middle sill: from above `--plan-eye 4.3,6.55,1.15 --plan-at 4.55,7.2,0.8 --fov 30`,
  the nose `--plan-eye 4.2,6.25,0.95 --plan-at 4.5,7.05,0.78 --fov 28`, along the arris in
  the sun `--plan-eye 4.15,6.8,0.92 --plan-at 4.7,7.08,0.79 --fov 24`, the dust at the
  frame `--plan-eye 4.5,6.75,1.2 --plan-at 4.5,7.35,0.8 --fov 30`. Builder 26's shots, the
  parts alone, the costs: `build/b26/shots.sh EXE TAG [NAMES]`, `parts.sh EXE`, `cmp.sh A
  B`, `rounds.sh` (`build/notes/builder-26/`). A value worth checking by eye: write it to
  `albedo` in a scratch build (the dust's `t` bands showed it lay right but too thin).
- The window view (task 107, builder 27, `build/notes/builder-27/`): `--view table-window`
  (V) from a chair behind the games table; Y the lace's hang (0.15 or 0), D the dust
  (`off|on|sparse|dense|coarse`, the presets only in that view), `--lace-sun`,
  `--lace-scatter`, `--sun-veil`, `--glass-film`, `--scratches` each a strength (1 as
  made, 0 off), Z all of them off and back. The sun across the window wall is `--wall`'s
  turn (`--wall 36,T,-2,2`, 20 today), not `--azimuth`, which turns the room with it.
  A flag given twice takes its first value (`flag_value`): in sweeps put the step's flag
  before the all-off list. Shots, each step alone, W0's framings and the costs:
  `build/b27/shots.sh EXE TAG [NAMES]` (`twv` the view, `sun` toward the sun, `lace`),
  `parts.sh EXE TAG [NAMES]`, `w0.sh EXE`, `cmp.sh A B`, `rounds.sh`, `page.py`.
  The film and the scratches show only within about 35° of the sun: judge them at
  `--plan-eye 4.5,6.6,1.6 --plan-at 4.84,7.54,1.93 --fov 30`, native (`--scene-scale 1`);
  at the less-turned placement over the trees in the left window's leaves `--plan-eye
  4.6,6.2,1.25 --plan-at 4.4,7.5,1.35 --fov 35` (`build/b31/glass.sh EXE TAG`, also
  toward the sun). Their tile is half a millimetre a texel since builder 31 (a millimetre
  read as 3-4 px wide hairlines from 1.3 m at 3024 × 1890); `--glass-film 0` against
  the default, diffed, isolates the film.
- The pieces' halo on the field (builder 31, `build/notes/builder-31/`): two terms, both
  from `OCC_FRAG`'s map (`field_occ`): the ambient times it, and Filament's
  micro-shadowing in `LIT_FRAG`, which scales the sun by `nl / sqrt(1 - ao)` (squared on
  the field), so at the menu's 15° sun a field point at ao 0.8 keeps a third of the sun
  on the pieces' lit side. HDR is not why it reads darker in the menu (the board's HDR and
  8-bit outputs within a level). `--halo K` and `--halo-reach K` (the Table section's
  sliders; 0 the shader's `HALO` and `HALO_REACH`, 1 and 1) scale the map through the
  squares buffer's spare `zw`, so a value the user picks is a one-line change of the
  constant. Removing the pieces' share from the micro-shadowing alone is a `LIT_FRAG`
  change (`build/b31/halo-micro.patch`); judge on the game's shot
  (`build/b31/gamec.sh EXE TAG`, a gfx-only build, `scripts/mac.py --gfx-only`, 35 s)
  and the menu's close-up `--view room --plan-eye 4.4,4.9,1.45 --plan-at 4.4,5.8,0.78
  --fov 28`.
- The sun through the shell's windows (task 107, builder 29, `build/notes/builder-29/`): the
  board and the table in the room take the sun through the shell's own windows
  (`shaders::LIT_SHELL`, `TABLE_SHELL`), so a turn of `--wall` that puts the board behind a
  pier shades it. `--sun-check` prints, from the board's middle and corners and a ring on the
  table, where the ray toward the sun leaves the room (a window's glass, a bar, the sash or
  frame, or the wall) and what the game's window said (and, since builder 30, the field's 81
  points); `--table-at X,Y` moves the games
  table in the plan (the table-window view's chair with it). The box window's two casements,
  0.2 m apart, and the 0.8 m wall cut an oblique beam narrow: past about 12° across the wall
  the board is lit only with the table moved along the wall, and past about 25° hardly at
  all; the board's 0.37 m diagonal equals one sash's light, so a stile's shadow often
  crosses it. `build/b29/sweep.py` runs the same check in Python over turns, heights and
  places (the board turns with the room: its corners at 105 − turn degrees in the plan);
  `options.sh EXE TAG` shoots the six verified options. The tree's dapple falls on the board
  in most of them; `--leaves noise` takes the tree out of the sun's path to judge the beam.
- Light where no glass is (builder 30, `build/notes/builder-30/`): `shell_open`'s terms must
  each be cut to the casements (`casement`, or `glazing` for a blurred share), never the
  niche's outline alone; the lace's scattered light had been, and drew an arch round every
  patch. To see one term alone, write it as `through` in a scratch build
  (`through = niche * lace.x`, the lace's shadow alone, showed it was there but faint); the
  user's two cameras: the far window's patch on the hall wall `--plan-eye 7.6,4.6,1.7
  --plan-at 7.6,0.0,0.3 --fov 62`, the middle window and its lace `--plan-eye 4.5,4.0,1.9
  --plan-at 4.5,7.0,2.05 --fov 58`, at `--wall 36,0,-2,2 --sun-height 18`
  (`build/b30/halo.sh EXE TAG`).
- The menu scene's placement (builder 30, `build/notes/builder-30/`): the light tuner's A
  cycles `PLACE_NAMES` (`--place NAME`; `less-turned`, `PLACE_DEFAULT`, without it since
  2026-11-22, so `--azimuth` is overridden unless `--place free`), each a verified sun turn and height, table place,
  board turn (`--board-turn`, the board's own z from the window wall's line; it sets the
  key's azimuth, `azimuth_for`, so `--azimuth` and the Round slider are overridden once it
  is given) and table turn (`--table-turn`), with the table-window view's eye for it
  (`build/b30/eyes.py`). The Table section has the sliders and the sun-check's counts
  (the field's 81 points, the table's 72), live; the table moves into the plan when the
  slider is let go (the shell, the view out and the probes made again: `--place-then NAME`
  takes a placement on the third frame, and its shot matched a direct one exactly). The
  sun's turn across the wall is also under Sun and tree, The sun ("Across the wall").
  Height hardly matters for which glass lights the board (the lower sash from 12° to 29°);
  the turn and the table's x do. The board's field fits one leaf's light only turned
  against the sun's turn (`build/b30/sweep.py`'s `board_glass`). Plans: `build/b30/plan.py
  OUT` (SVG, a true top view, x growing to the left), shots `build/b30/options.sh EXE TAG`.
  In zsh a `$extra` of several flags passes as one word and the tuner ignores it: sweep in
  bash.
- The dust in the beam (builders 29 and 33): `--dust points` (the default, builder 33;
  `--motes N` their number) draws real dust's points, fibres and glinting flakes in the
  sunbeam's own volume over the table (`light_tune`'s `beam_box`, BEAM_*), lit only by the
  direct sun; `motes|motes-few|motes-many` are builder 29's tumbling flakes, `sparse|dense|
  coarse` the old round points in the box. `--point-px SIGMA`, `--glints K` (0 off),
  `--air DRIFT,RISE,SWIRL,SIZE`, `--near K`, `--mote-bright K` (40: exact points are too
  faint to see against the wainscot), `--mote-glint EXP`, `--mote-fibres SHARE`. The dust
  shows at native size only: shoot at 3024 × 1890 and diff against `--dust off` (`-alpha off
  -compose difference`) to find it; for the glints and the drift, step `--wind-time` by
  1/60 s or 0.25 s (`build/b33/shots.sh`).
- The haze in the beam (builder 33, `build/notes/builder-33/`): `--haze menu|game`, HDR
  on, needs the room's pre-pass. The realistic strengths
  (`--haze-sigma` 5e-5 to 4e-4) only lift the dark wainscot toward the sun; `game` (4e-4)
  reads as a soft beam, `menu` (3e-3, stripes soft 4, `--haze-toward 4`) is close to the
  ChatGPT study's. Looking toward the sun the bars' stripes converge on it and read as god rays:
  keep `--haze-toward` up wherever the stripes are strong. `--haze-look G,EVEN,TAPS,SOFT`
  (0.7,0.2,12,1); sigma and softness are also sliders under Dust. Compare against
  `build/notes/window-view/refs/` (Gabinio, Sigüenza, the ChatGPT study). The haze's cost
  is its own passes after the main one (the cross-section, the haze, its add); find them
  in a Metal trace by the encoders that appear with `--haze` on (`build/b33/measure.sh`).
- HDR and the lens (task 111, builder 28, `build/notes/builder-28/`): the tuner draws the
  scenic views in HDR by default; X or `--hdr off` gives the 8-bit picture to compare
  against, and only the shell with its view out, 4× MSAA and no room view draws HDR (the
  panel's Lens section says which). Compare a look in both: in HDR the lace and the
  glass's film blend in linear light and read stronger, the surfaces within 2-3 levels.
  `--lens-view depth|coc` (1, apart from the walk's Q) shows the depth and the lens's
  disc (`--dof on`, `--focus M`, 0 the view's target; `--aperture PCT`, `--dof-caps
  N,F`): judge a focus there before any blur. Builder 28's scripts: `build/b28/look.sh EXE TAG SIZE NAME "flags"..`,
  `cmp.sh A B`, `game.sh`, `rounds-b1.sh`, `rounds-b2.sh`, `page.py`.
- The sun in the view out and the HDR glow (builder 32, `build/notes/builder-32/`): in the
  less-turned menu view the sun sits at about (1255, 400) of a 3024 × 1890 shot, at the foot
  of the upper sash's left leaf; at wind time 0 a leaf covers it, so compare looks at
  `--wind-time 6`; there the sun is mostly behind the upper sash's glazing bar (1-3%
  open), which `--view-nudge 0.04,0,0` clears, but the user keeps the eye (2026-11-22: the
  menu's cameras are a design step of their own). `--sun-look made|veil` (made the
  default; veil builder 34's look b, the eye's veil, kept off to retry behind the new
  maple; builder 32's other presets, looks a, c and d, the needles and the lace's lobe
  toward the sun were removed 2026-11-22, in git before 8e504edf), `--sun-eye
  STRENGTH,HALF_DEG,END_DEG,AMBER`, `--sun-disc R,LIMB,EDGE,BRIGHT`, `--sun-glare
  CORE,WIDTH,GLOW,WIDTH`, `--sun-tree DENSITY,REACH,BACKLIGHT,SHARP` (today's tree seen from
  its shadow's map along the view), `--glow STRENGTH,THRESHOLD,KNEE,REACH`, `--glow-levels
  N`; sliders in the Outside section. The glow shows only with HDR; 8 bits keep the old
  window glow. Shots: `build/b35/look.sh EXE TAG SIZE NAME "flags"..`, `cmp.sh A B`,
  `game.sh`; costs `build/b35/rounds.sh` (`measure.sh` filters the trace by the exact
  executable name, so the user's open tuner is left out).
- The camera under `--light physical` (task 122, step 5, `build/notes/light-physical/#step5`):
  AgX (`--camera-toe agx`, `none` the shoulder as before) at an exposure metered once at the
  bake (the room's log-average to 0.18), `--camera-ev` (the "Camera EV" slider) on top; the
  glow's threshold is then in the picture's light (`AGX_GLOW`, 0.006 from 16). Judge a look
  against Cycles at the EV the tuner prints with `--shot` ("the camera's meter ... EV"):
  `tools/blender/scene.py --exposure EV`. Blender's AgX on any linear EXR:
  `build/review122/s5/agx_ref.py` (OCIO in Blender's Python).
- The tuner's `--wall X,Y,Z,W` is applied after the placement: its y is the sun's turn
  across the window wall, so `--wall 36,20,-2,2` (Room's default, in older shot scripts)
  moves the sun from the default placement's 12° to 20°. The exporter's sun is the
  placement's; leave `--wall` out of shots compared with Cycles (2026-11-27).
- The light tuner draws the 3D scene at the screen's native size by default (2026-11-22);
  `--scene-pixels 4.1` (`render3d::HIGH_SCENE_PIXELS`) or `--scene-scale K` draw it smaller
  and upscale it (N cycles native, 0.85, 0.75, 0.67 and the 4.1 MP cap; M the upscale). Builder 24's crops and sweeps:
  `build/b24/shots.sh EXE TAG`, `crops.py`, `measure.sh ROUND TAG=EXE,FLAGS..` (under the
  quiet lock; in zsh, a list in a variable doesn't split into words: run sweeps in bash),
  `build/notes/builder-24/`.
- The park on the ground (task 109's look test, `build/notes/builder-32/park/`): the light
  tuner's `--park ground|no-shading|no-leaves|no-grounding|no-shadows` (start only; off by
  default) puts a lawn, autumn leaves and the oak's picture as seven grounded cards into the
  view out (`view_out::lawn`, `PARK_TREES`; `shaders::PARK_FN` between `OUTSIDE_FRAG` and
  `OUTSIDE_MAIN`, the tuner's own `TUNED_OUTSIDE` and `TUNED_OUTSIDE_HDR`). A card's place
  is in both `PARK_TREES` and PARK_FN's `CARD`, in the same order. The lawn stays one plain
  colour: albedo patches seen at a few degrees read as shadows, and the user disliked them
  (2026-11-22). Shots `build/b32-park/batch.sh TAG` (each view with every part off), `crops.sh`;
  a tuner built elsewhere than `build/<name>` (`scripts/mac.py ... -o`) keeps other
  agents' binaries.
- The tuners are built with `scripts/mac.py tools/NAME.goose`, run from `tools/`,
  and shoot headless with `GOOSE_GFX_HEADLESS=1` and `--shot out.png`.

## Normals on profiles (a rule, 2026-11-21)

Swept and lathed profiles shade as curves: a profile point's normal is its two
segments' mean, and only a turn sharper than a crease angle (37°, `surfaces::CREASE`,
`surfaces::smooth_normal`) keeps each segment's own. The shared routines do it:
`shell_mesh::sweep` (and so `sweep_oak`, the caps, plinths, cornices and the bookcases'
mouldings), `surfaces::panel_ring` (the wainscot's, doors' and
shutters' panels), `mesh::turned` (a doubled point is a crease); `mesh::sweep` takes each
point's normal from its `Profile`, the curtains' `tube` and `ball` theirs from the
centre, and the books' spines bend theirs (`books::spine_at`). Left flat, as they are
flat: the door architraves (a stepped profile whose turns are all creases or under a
degree), the sills (a square slab, the nose's arris eased in the shader), the casements
(plain boxes). New furniture, frames and mouldings go through these routines, or do the
same: a flat normal a segment shows a cove or an ovolo as bands, which the user has
caught twice (the cornice, the cap's nose).

## What has been tried and set aside

- Generated tabletop pictures and a plain painted tabletop behind the 2D board: they
  looked like flat stock textures next to the design boards. Don't propose more
  generated-image rounds for 2D surfaces.
- A strong light pool, a frame, and a crafted board with grain and seams on the 2D board.
  The 2D board stays simple; rich materials and lighting belong to the 3D board.
- Visible wood grain, and any regular stripe in it (sines), which bands when the board
  is seen from afar: the close-up's grain is smooth, irregular, and barely there.
- On the 3D board, grain as noise drawn out along it read as soft streaks beside the 3D
  reference; growth rings from a pith axis per piece, with pores, read as wood and don't
  band from afar. Crop the frame's front and a square of each at 300% beside the
  reference and measure the patches.
- Two rings on the pieces (an inner ring at half the radius as well as the rim), then a
  wide rounded rim like a tyre, and gloss: the pieces are flat, matte turned discs. The
  close-ups' rims are wider and rounder than ours; ours follow the 3D reference, with a
  groove and a narrow shoulder. A face too matte lost the dark pieces' edge highlight.
- The design boards' icons are a little heavier, and their bulb is filled; the
  prototypes' 2.4-unit stroke and outlined bulb look right on the tablet and stay.
- Left different from the design boards on purpose: their wood grain is finer and
  straighter; their lifted piece shows a tall side, ours lifts 0.8% of the board with a
  growing shadow.

When an idea drifts from the references, prototype it cheaply and put it next to the
matching reference before investing in it.
