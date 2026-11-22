# 107: The manor scene, in the game and on the home screen

Status: in-progress (an epic, 2026-11-20; on the branch `room-light`)

The 3D board's scene carried over the finish line: the board's light fitted to the room
per season in the game, with options, and a home screen shot of the library with the sun
through the park's trees, dust in the beam, the window soft behind, at our chosen cameras
(autumn first). The work is in the tasks below; this file keeps their order and what is
done. The tiers decide what each device draws (`AGENTS.md`'s render tiers: 2D, 3D, high).

## In the game: the board's light

- [x] Rooms per season: key, fill, ambient, shadow strength (task 104)
- [x] The window's pattern and the tree's shadow, its species, its wind, the tuner (tasks
      104, 105)
- [ ] The rooms' profiles chosen per season, winter's snow light or sun (task 104)
- [ ] The library's dapple close to `library-table-01`; the maple's leaves (task 105's
      follow-ups)
- [x] The literature's wind: two noises along and across it (task 105's follow-ups)
- [ ] The ngfx renderer's 5 ms more on shadow-map frames with the pattern on, found and
      fixed (task 105)
- [ ] The tiers' table: each effect and its quality per tier, at build time (task 104)
- [ ] The options in settings: the room's light, the tree, the neutral light; thought
      through with the background's options before merging (tasks 095, 104). The way
      agreed (the user, 2026-11-20): one setting, Light, for the 3D board on its table:
      Neutral, Room, Sunlit window. In the game the window's pattern is still and light,
      the dapple mostly on the table and the board's edges so the squares read; the
      dense dapple, the wind, and the dust are the home screen's, by tier, not a setting
- [ ] Device numbers on the Mac and the A33, against before (tasks 104, 105)
- [x] The gusts briefer and weaker (the user, 2026-11-20): their strength, length and
      how often on `rooms::Room` with tuner flags, defaults about 1.5 to 2 s and about
      half today's push (a gust now lasts about 5 s every 20 and pushes the leaves about
      3 times calm air's), each gust quickening only some regions of branches. Done:
      1.75 s every 20 s, half the push, reaching about 0.4 of the crown (task 105)
- [ ] The shadows in the light tuner (the user, 2026-11-20): the board casts none on the
      table, and the pieces cast shadows but don't shade themselves; checked in shots
      first, the pieces' own shadow perhaps the high mode's only. The user's shot of the
      autumn board at a low angle shows it floating: no shadow or contact darkening on
      the table under its edge. Fixes 1 to 3 of `build/notes/plans/shadows.md` done
      (2026-11-21): the table samples the key's shadow map (the tier's taps, min() with the
      board's outline), its polish's highlight hidden in full under the board, a tight
      crease at the foot; the pieces' own fine shadows (fixes 4, 5) later
      (`build/notes/shadow-fixes/`)
- [ ] The autumn board's frame, its outer sides, too rough seen at a glancing angle
      (the user, 2026-11-20): matte and streaky where waxed wood would catch a sheen; the
      squares are fine. A wax coat on its frame (2026-11-21, `looks::Theme.frame_wax`):
      the corner's sparkle a smooth highlight, the sides' relief halved; to judge again
- [x] An FPS counter in the light tuner (the user, 2026-11-20): frames a second and
      the frame's time while it draws every frame (the wind on), to judge the high
      mode's cost as the room fills. F shows it, G waits for the GPU each frame; no GPU
      timer in SDL's GPU; the first numbers in task 110
- [ ] The high mode drawing every frame: on desktops, and on laptops and tablets on
      mains power, a setting forcing it (`docs/decisions/rendering.md`, "Frames and
      battery"); the game's clock ticking, the window's pattern swaying gently

## The home screen's shot (autumn)

- [x] The library as a whole room, its layout chosen from ChatGPT images (task 109)
      For now the room view has the room's own three windows and the game keeps its
      window; later the game and the home screen share one room, perhaps others later
      (the user, 2026-11-20)
- [x] A rough demo of the whole library in the light tuner, to see the room as a whole
      (the user, 2026-11-20): the tree's map over the whole window (step 2 of
      `build/notes/plans/shell.md`), the shell from task 109's plan as data and one mesh
      made once (wainscot A, window B, door 1, ceiling B, wallpaper all round, lime
      plaster), the room lit through its three windows; four views, shots and frame times
      in `build/notes/room-demo/` (tasks 109, 110). Next: shadow fixes 1 to 3
      (`build/notes/plans/shadows.md`), the outside's layers, then the pieces refined one
      by one (the wainscot from the sketches, the window wall, the lace)
- [x] The view out of the shell's three windows (2026-11-21): task 109's band and oak, the
      sky worked out in the shader round the key's sun, exposed on its own
      (`rooms::Room.outside`, 1.8); the room view only, the game keeps its photograph;
      no blur baked, depth of field later (tasks 109, 110, `build/notes/room-outside/`)
- [x] The quick pass against the concepts (2026-11-21), only what no light explains: the
      plaster, paint and cornice aged (limewash #beb4a3 to #d0c8b8, paint #c6beae), the
      ceiling's blotches calmed, pale limestone sills, the wallpaper's ground warm brown-grey
      (#423831), the wainscot 1.2 m on every wall with a plain plinth on a lip, the floor
      darker along all four walls, the room's tree for three windows, the glass clearer
      (`build/notes/quick-pass/`, tasks 104, 109). The light itself waits for ChatGPT
      renders of our room
- [x] The curtains, option A of `build/notes/curtains/` (2026-11-21): over each window a
      22 mm brass rod at 3.68 m on two brackets with 45 mm ball finials, a lace panel each
      side gathered on it (rod pocket, 1.20 m of cloth on 0.55 m of rod) and tied back at
      0.95 m with a cream cord to a brass hook; the folds carried down to a wavy hem that
      rises toward the inner edge, the lace's scalloped border along it. The lace sheer and
      lit through: the sun on its back with the bars' and leaves' shadows, scattered forward
      toward an eye looking at the sun through it, the sky and park behind the niche; its
      shadow, its pattern blurred, in the room. Way f3 since the user's choice
      (2026-11-21), `--lace f2|f|d` in the tuner in reserve; the brass a plain procedural
      one (`surfaces::LOOK.brass`) until the gilt and brass study lands (`model3d`'s `curtains.goose`,
      `build/notes/curtains-build/`, costs in task 110)
- [x] The games table's base, option A of `build/notes/games-table/` (2026-11-21): a
      turned pedestal (rings under the top, an urn, a beaded neck, a drum) and four
      cabriole legs from the drum curling into scroll toes on the floor, the top's
      lathe and stepped rim kept, all the top's flame mahogany with the grain along the
      column and legs; one mesh with the top, drawn in the game too, where the top hides
      it (the renderer check and the tuner's game shot unchanged). The legs are swept by
      `mesh::bar`, a rounded section along a curve, for later furniture's legs and
      rails. Its shadow on the floor and the top's on it worked out in the shaders, as
      the old turned foot's (removed). The top 0.95 m across since the user's choice
      (2026-11-21, `build/notes/tieback-top/`), in the game and the room; the game's shot
      unchanged but on tall phones in portrait, whose foot now shows the near rim; the
      light tuner's `--table-top 1.05|0.80` for the others (`build/notes/games-table-build/`,
      costs in task 110)
- [x] Light, round 1, against ChatGPT repaints of our room (2026-11-21,
      `build/notes/light-round-1/`): the shell's sun sharper (penumbra about the sun's
      disc) and 2.2 times stronger on the room's surfaces; its sky through the niches and
      the sun's patches thrown back once baked into a probe grid when the room turns on
      (no SSAO); the window's glow (a small bloom of what is near white, no rays); the waxed
      floor and the brass reflecting the room's box, its doors and its windows; the oak
      outside blurred like the band. The game's shot and the renderer check unchanged;
      costs in task 110. Round 2: the polished table's reflection (TABLE_FRAG), the
      reflection's cost (1.1 ms), the bake's soft band across the hall door, the floor's
      patches still dappled and softer than the references', the lace lit by the probes
- [x] The quick pass's and round 1's leftovers (2026-11-21, `build/notes/leftovers/`): the
      room's tree draws its trunk and limbs half as wide and their shadow three times as
      soft (`rooms::SHELL_LIMBS`, the shell's map only), so no bold bar crosses a sun
      patch; the probes sit half a step in from every wall, the floor and the ceiling
      (30 × 26 × 13), and a probe in the row before a surface takes none of that surface's
      own sun patches, which rang dark across the doors (the band on the hall door); the
      floor before each door's opening keeps no darker wax band, its contact line at the
      threshold's nose; the plinth and the cap mitred into the inside corners. Still off:
      the wainscot in the shade, three to ten times darker than the references' (the
      window wall's most); the ceiling is already brighter than theirs, so more bounce
      won't do: a lighter, greyer oak for the panelling, and more light on the window
      wall, are a choice for the user
- [x] The bookcases by the hall door and their books (2026-11-21,
      `build/notes/bookcases-build/`): option B of `build/notes/bookcases/`, two tall open
      oak cases built into the hall wall either side of the door, the wainscot and paper
      stopping at their sides as at a door, a folio base 0.45 m deep whose ledge carries
      the cap's line at 1.20 m, an upper case 0.30 m deep to 2.84 m under a 140 mm cornice
      on the architrave head's band, two bays, pilaster strips with sunk panels; option B
      of `build/notes/books/`, about 390 books, boxes with rounded spines sampling a mask
      atlas (`tools/materials/books.py`, 0.7 texels a mm) coloured per book from a table by
      the vertex's material, filled by size with sets together to 85 to 92%, a few leaning
      and lying flat, faded toward the door's side. One mesh with the shell; the light
      tuner's Bookcases and books section (`--books`, `--book-fade`). The game's shot and
      the renderer check unchanged; costs in task 110. Still off: the cases cast no shadow
      of their own in the sun (their interiors take the sun unshaded where it reaches
      them, which the default keys don't), the books read a little bright and orange
      beside `library-autumn-02`'s, and no hero books or busts yet
- [x] The books' tone toward `library-autumn-02`'s case (2026-11-21,
      `build/notes/books-tone/`): covers mostly aged calf and half calf browns, cloth and
      coloured half leather muted and rarer, dark labels; each volume a shade of its own,
      heads and tails darker and rubbed; long sets in runs of two to eight volumes, heights
      mixed on a shelf; the spines darker toward the shelf over them and near the case's
      sides, the backs and undersides darker, and the sun kept off what the case and its
      books hide (`case_shade`). The shelves' mean colour sRGB 0.27, 0.17, 0.10 against the
      concept's 0.26, 0.16, 0.10 (0.40, 0.25, 0.15 before). The game's shot unchanged (max
      difference 0), frame times unchanged (3.4 ms, the Mac's floor). Still off: the
      shelves look emptier above the books than the concept's glazed case, no hero books
      or busts, and the books cast no shadow on each other in the sun
- [x] The night run's follow-ups (2026-11-21, `build/notes/choices-2026-11-21/`): the
      wallpaper's tile 0.9 m by default; the panelling oak three times lighter and greyer
      and the ceiling's own darker, warmer limewash, the look the tuner's tints showed,
      baked (the oak's bake, `surfaces::LOOK`'s ceiling colours, the probes' and
      reflections' albedos following); the tie-backs a soft knotted cream cord with
      tasselled tails, its run hanging in a catenary to a small brass hook at ±0.95 m; the
      folds round at the hem (12 columns a fold below 0.83 m, the hem scalloping between
      the turns); lace f3 as a fourth way. The game's shot unchanged; costs in task 110.
      Open for the user on the page: the lace's way (f2, f, d, f3, all four kept) and the
      table's top (1.05 or 0.80 m), shown close up in the light and from further away
- [x] Step 1 of the morning's order (2026-11-21, `build/notes/ao-fixes/`): the sun's
      highlight no longer shows through the walls (the pier's cap, the floor: it took the
      shade's 10% floor of the key, now only the sun through a window); the games table
      casts its own shadow in the room from a map of its own (top and base, on the floor,
      the walls and the base itself), the floor under the base darker by its drum's and
      legs' occlusion, tightest at the scroll toes; the shell's corners and edges darkened
      analytically in every tier, its indirect light only (`rooms::Room.corners`, 1 and
      0.4 m; the floor along the walls, the inside corners, under the cornice, the cap, the
      sills, the niches, the doors, the bookcases). The game's shot and the renderer
      check unchanged; costs in task 110. Still off: the room in shade a little darker
      without the false sheen (style-01's mean 7% with the corners), the table's base dark
      (its ambient is the game's harmonics, not the room's probes), the furniture, books
      and folds left to SSAO (step 2)
- [x] Step 2 of the morning's order (2026-11-21, `build/notes/tieback-top/`): lace f3 the
      default (f2, f, d kept); the games table's top 0.95 m in the game and the room (its
      map at the 1.05 m top's scale, so the game's shot is unchanged but on a 9:19.5 phone
      in portrait, where the near rim and the fade past it now show at the foot, and a
      corner of it at 9:16); the tie-back settled once at build by a simulation of the
      cord round the bundle's soft gathered waist, the knot an overhand at 0.91 m on the
      front, the loop rising to 0.94 m at the back, the cloth gathered round the loop where
      it lies. Costs in task 110. Still off: the cord's loop is seen through the lace
      behind the bundle, as before; the near rim on tall phones, for the user. Then, the
      same day: the shell's swept mouldings, the panels' rings and the books' spines with
      smooth normals (a crease at 37°, the rule in `agents/design.md`); the wainscot
      stopped against the doors' architraves on wider, deeper plinth blocks
- [x] Step 3 of the morning's order, the light's bounces (2026-11-21, `build/notes/bounce/`):
      the shell's corners round the bookcases, the doors' plinth blocks and architraves,
      the sills' noses and the niches' piers as finite boxes and the openings as holes, so
      no wedge of shade runs off an outside corner; the baked light bounced three times
      between 1,208 cells over the room's surfaces from every source (the sun's rays, the
      sky through the niches on the floor, sills and reveals, the backlit lace); the lace
      letting less through where it is gathered, in the bake and its sun shadow, that
      shadow faint and soft beside the bars'; the games table on the room's probes in the
      room (a variant of its shader, the game's as it was). Against the repaints (sRGB
      luma, style-01 and autumn-02's cameras): the hall wall's wainscot in shade 8 to 11%
      and 7 to 10% (theirs 10 and 8), the paper 11 to 18% and 15 to 22% (18, 18), the
      ceiling 49 to 54% (49, 40), the window wall's wainscot 6 to 8% and 4 to 5% (15, 13),
      the floor in shade 15 to 18% and 10 to 13% (27, 22); the table's top at menu-01 9 to
      13% (34). The exposure and the shade's 10% floor of the key kept. Costs in task 110.
      Still off: the window wall's wainscot and the floor in shade, which want the floor's
      larger sun patches of the repaints; the ceiling a little bright against autumn-02;
      the table's top dull beside the repaints' sunlit one
- [x] Step 4, ambient occlusion from the screen (2026-11-21, `build/notes/ssao/`): half
      size, the room, the table, the board and the pieces drawn into where each pixel is
      and which way it faces, eight taps on a spiral turned across a 4 × 4 block and
      blurred over it by distance, no noise in a still frame; the room's and the table's
      indirect light only, by the lesser of it and what the mesh and the corners know
      (so the box's planes and the shelves aren't darkened twice); standard and high
      tiers, off on a phone; strength, reach, bias and gain in the tuner's Light section,
      `--ssao`, and its views `--ssao-view alone|kept`. A decision replacing "no SSAO".
      The game's shot unchanged: the game shows no room, and the board's own shader
      doesn't take it (the board's foot on the table and its pieces' shade are analytic
      already). Costs in task 110. Still off: the books between volumes read only a
      little darker, as the cases' own shade is already deep there; the hall view's books
      are too small on the screen for the 0.35 m reach to find their gaps; the wall seen
      through the lace keeps the corners' shade alone; ngfx draws it but no ngfx tool shows
      the room yet, so it is built and not seen
- [x] Step 5, the floor's mirror (2026-11-21, `build/notes/planar/`): the view out, the
      table and the room drawn mirrored under the floor at half size (the room's shader
      without its sharp reflections or SSAO), taken back into the room's light with each
      texel's distance along the reflection; the floor reads it along its board's tilted
      normal through a wax film half the oak's roughness, blurred by the film's lobe at that
      distance and streaked down the screen by 1 / n·v; each board's wax its own; 0.85 of
      it. Standard and high tiers; phones and the brass keep the room's box. Tuner:
      `--planar`, `--planar-view floor|map|distance`, `--planar-size`. A decision replacing
      the box for the floor. Costs in task 110. Still off: the references' bright window and
      lace streaks at the window wall's foot read fainter (the windows stand 0.9 m up, so
      their reflection lands nearer the camera, where Fresnel is low); the table's
      reflection inverted with the room's tonemap, not its own; ngfx draws it, unseen
- [x] Light fixes against style-01's and autumn-02's result-2 (2026-11-21,
      `build/notes/light-fixes/`): the table's sun shadow takes only the sun as the bars'
      do (on a grey floor 140 against a bar's 144, before 130), no broad blob under it;
      the floor's mirror steady as the eye moves (a tent over its half-size picture, a
      blur of at least two texels across and four down, the film's normal without the
      grain), its light kept before the tonemap with the view out six times its look, and
      worn wax turning its mirror into the oak's rough sheen; the thresholds a rounded oak
      board; the table's base on the room's toe (sRGB 29, 16, 10, the reference's 36, 18,
      10, before 52, 24, 6); the lace stopping 28% of the sun where flat (11% before);
      paint eggshell and the paper a little glossy. Still off: the references' bright
      window sheen near the camera is stronger than ours; the sun's sheen on paint and
      paper is small at this camera (the references' sun is whiter); a soft lighter band on
      the stove's end wall from the first gather of the sun's patches and the backlit lace
      (+20% over its neighbours, not fixed: a run without the lace as a source and a wider
      gather onto the probes next); the threshold's worn middle for the materials pass
- [x] The table's own look back and the floor's mirror steadied (2026-11-21,
      `build/notes/mirror-steady/`): the games table in the room keeps the board's
      tonemap toe again (table-01's top in shade sRGB 65, 31, 9, as at efc452ef; the base's
      orange cast left for its own light); the mirror's resolve makes NaN, infinity and
      negatives black before the mips (a few bad texels had made large black blotches),
      the empty texels repeat the nearest drawn one, and the floor blurs it in five taps
      of one mip chosen from the lobe's widths (at least 3 texels across, 6 down) in place
      of the anisotropic read. Frame times unchanged (room ~7.7 ms on the Mac). The ×6 sky
      greys the floor by the window (style-01 76, 48, 31 at 1×, 93, 70, 60 at 6×), kept.
      Still to check: the flips in the real window (Tab), not reproduced headless.
- [x] Panels, contact shadows and the light retuned (2026-11-21, builder 18,
      `build/notes/builder-18/`): the panels experiment applied (crease 0.85, ring
      occlusion 0.6 held to 4 mm, contact shadows), the light with today's toe (sun 4.4,
      baked 7,6, fill 0.2, bounce grey 0.25, one bounce, sun saturation 0.6, broad sheen on
      paint and paper), the oak keeping the old sun (wainscot close-up in sun 216, 136, 85;
      the panels alone 217, 137, 87); the doors' dashed line round the field gone (its 2 mm
      fillet shaded from the bevel to the field); the toes switch in the tuner's own
      shaders. Style-01 against result-2: paper in sun 147 (146), door in sun 222 (217),
      door in shade 157 (155), the wainscot in shade 31 (40, before 44). Frame time at
      style-01, 1600 × 1000 on the Mac: 7.5 → 8.9 ms (room 7.5 → 9.1) (the contact shadow's code 0.5, the
      sheen 0.5, the rest the shader's size; none of it switched off by its uniform); the
      game's shot unchanged (max difference 0)
- [x] The shutters made real and the doors hung (2026-11-21, builder 19,
      `build/notes/builder-19/`; option A and part 2 of `build/notes/shutters/`): two
      0.325 m leaves a side folded against the reveal from 2 cm to the lining, three brass
      knuckles at the lining and two between the leaves, the middle window's right pair
      14° ajar, the cap stopped at the pier's corner, the bake taking the stack's face and
      the narrowed opening; `--shutters off` (H) in the tuner. The doors' faces 1.5 cm in
      (2 before), 4 cm leaves with 3 mm joints, a meeting bead, three knuckles a leaf, a
      lever on the right leaf. The shell's triangles 32,630 → 34,834 (+2,204: the knuckles
      2,040 of it). The game's shot unchanged (max difference 0), the renderer check
      unchanged (no pixel over 32, gfx and ngfx). Frame times: see the page (the GPU was
      shared with other agents' runs). Still off: brass in a niche reads dark (it sees the
      room's box, and the screen's occlusion darkens the lining's knuckles near black)
- [x] The cap's return and the niches' brass (2026-11-21, builder 19b,
      `build/notes/builder-19b/`): the wainscot's cap wraps 1.5 cm into each reveal again,
      ending square 5 mm before the leaves, its underside closed round the corner (the
      plinth never meets the reveal); brass takes no screen or corner occlusion, and in a
      niche reflects the window's light as it faces out. The shell's triangles 34,834 →
      35,074. The game's shot unchanged (max difference 0). Frame times, 1600 × 1000, the
      least of four rounds against 47083109: room 9.1 → 9.6 ms, style-01 9.0 → 9.5, window
      8.4 → 8.9, the window from in front 6.0 → 6.3
- [x] The bounce's artifacts and the mirror's boiling, applied (2026-11-21, builder 20):
      the probes' exact light on their planes, walled probes, thrown light at most 0.85,
      the lace's own share, the probes' bounce 10; the mirror's tent mips and a map at
      least 1600 across. The bake 77.6-78.4 → 88.1-89.0 ms (five runs each). Frame times
      not measured: other agents rendered at the same time (for the measuring pass on a
      quiet Mac). The game's shot unchanged (max difference 0). Turns against a dense
      reference: the fix at the reference's own frame-to-frame change; the error at 3200 × 2000 near the windows 1.20 levels a frame (full size
      0.96); a temporal accumulation of the map built, no gain, dropped
- [x] The corners' shade baked into an atlas with the shell's mesh (2026-11-21, builder 21,
      task 110's fix 1, `build/notes/builder-21/`): the main pass 23.6 to 18.3 ms at
      3024 × 1890, the frame 27.6 to 21.7; the look within a level on average, the game
      unchanged; the bake about 300 ms on the CPU
- [x] The brass and the books drawn with a pipeline of their own that sees the room's box
      sharply (2026-11-22, builder 22, task 110's fix 2, `build/notes/builder-22/`): the
      main pass 18.3 to 15.1-15.4 ms at 3024 × 1890, the frame 21.7 to 18.4-18.7; the
      look unchanged but one pixel of a tie-back's hook, the game unchanged
- [x] The room drawn with a pipeline per material group, compiled per tier, the tonemap a
      define (2026-11-22, builder 23, task 110's fix 3, `build/notes/builder-23/`): the
      main pass 14.8 to 10.8-10.9 ms at 3024 × 1890 (5.0 to 3.6 at 1512 × 945), the frame
      18.1 to 13.7; the look and the game unchanged
- [x] The 3D scene drawn under a 4.1 MP budget and scaled up with Catmull-Rom on a
      Retina screen, the UI at its pixels (2026-11-22, builder 24, task 110's fix 4,
      `build/notes/builder-24/`): the frame 13.7 to 10.9 ms at 3024 × 1890; the budget the
      user's choice from the page's crops; the floor's parts measured for a later cut
- [x] The doors' and windows' painted wood, the paint research's quiet variant, with a
      pipeline of its own (2026-11-22, builder 25, `build/notes/builder-25/`;
      `docs/decisions/rendering.md`): fillets on every arris (1.2 mm doors, 0.9 mm
      windows), the quirks shallower, each piece tilted and each panel cupped; a 3 mm dirt
      band in the recesses and a hairline at the joints; a relief tile made at startup
      (25 ms, 1.4 MB) for the sheen and the normal; sheen 0.36 doors, 0.42 windows. The old
      paint one key away in the light tuner (J), each step switchable
      (`--paint-off`, `--paint-relief`). The mesh 35,074 to 37,906 triangles; the main
      pass +0.24 ms at 3024 × 1890 against before (+0.44 against the split alone, which
      saved 0.20); the rest of the room and the game's shot unchanged. Open: the lived
      extras (chips, hand grime, kick scuffs), the relief's strength, and some dashing of
      the windows' sub-pixel fillets
- [x] The windows' sills a Vasalemma-type limestone, with a pipeline of its own
      (2026-11-22, builder 26, `build/notes/builder-26/`; `docs/decisions/rendering.md`):
      the crinoid speckle from a tile made when the shell first shows (67 ms, 5.6 MB), a
      patchy polished band, the nose's arris eased 4 mm in the shader with a few chips, the
      nose 6% darker at its foot, a dust line before the inner casement; the old stone one
      key away in the light tuner (I), each part switchable (`--sill-off`). The room's main
      pass 0.16 ms cheaper than before at 3024 × 1890 (the split saved 0.18, the limestone
      costs 0.02); the game's shot unchanged. Open: the colour (the old stone's mean kept,
      the research's a little paler), the chips' count and the speckle's contrast
- [ ] The images from ChatGPT: the simplified concept, the wallpaper, wainscot, window,
      lace, the park outside (task 106's list)
- [x] The window view's steps on the split pipelines (2026-11-22, builder 27,
      `build/notes/builder-27/`; `docs/decisions/rendering.md`): the table-window view, the
      lace hung 0.15 m further over the openings, the sun's shadows on the lace at full
      depth and its glow, its light scattered below, the sun's veil, the glass's wiped film
      and cleaning scratches, each a strength in the light tuner (Z all off). The room
      view's main pass 0.99 ms dearer at 3024 × 1890 (the light below 0.70), the
      table-window view's 0.46; the game's shot unchanged. Open: the sun's place and the
      framing (the shots' options), the light below's cost, the strengths
- [x] Dust in the sunbeam (task 104's follow-ups): from the table-window view only,
      motes over the games table lit through the shell's windows, a pixel or two across
      (`--dust sparse|dense|coarse`; builder 27). Open: which density
- [ ] The window wall and the view outside, drawn once into the kept backdrop, with depth
      of field (task 106)
- [ ] The camera's angles and pans for the home screen (task 106)

## The table and the room around it, after the first shot

- [ ] The floor and rug, seen in the game's views (task 106)
      The rug's first bake (`tools/materials/rug.py`) keeps the download's wrinkles in its
      colour; flatten them or draw it again before it is used (the user, 2026-11-20)
- [ ] The table's props: the chess clock (100), the pieces' box (102), the score sheet and
      pencil (103)
- [ ] The writing desk to play on, with and without its green leather (task 108;
      postponed: not in the first shot, and more work)
- [ ] A whole model of the round table, as the camera moves farther

## Merging

- [ ] The decisions in `docs/decisions/rendering.md` and `docs/architecture/rendering.md`
- [ ] The branch squashed and merged, the user approving
