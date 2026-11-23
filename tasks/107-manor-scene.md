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
- [x] The depth of field's groundwork (2026-11-22, builder 28, task 111,
      `build/notes/builder-28/`): the lens and its tuner controls, the scenic views in a 4×
      RG11B10F HDR target tonemapped after (the 8-bit picture one key away, X), a 1× depth
      of the scene with the lace by its coverage and its views (Q). HDR costs the room view
      nothing in all (the main pass 11.93 to 11.63 ms at 3024 × 1890, the tonemap 0.45 after
      it), the depth 0.19; the game unchanged. Open: the lace and the glass's film read
      stronger in HDR, to retune
- [x] The sun through a real window (2026-11-22, builder 29, `build/notes/builder-29/`):
      the board and the table lit through the shell's windows, not the game's window
      that followed the sun (the 30° sun had lit the board through the pier). Six sun and
      table options verified by `--sun-check` (`--table-at`); the box window allows about
      ±10° across the wall with the table as made, 25° with it moved. Main pass at 3024 ×
      1890 native, two rounds: table-window view 8.18-8.28 to 8.84-8.90 ms, room view
      11.73-11.90 to 11.87-11.90. Open: the user's pick (sun, height, table), then made the
      default; the tree's dapple over the board in most options
- [x] Dust as real dust (builder 29): tumbling flakes and lint in the beam's volume, lit by
      the direct sun only (`--dust motes`, `motes-few`, `motes-many`; the round points kept).
      Main pass 8.84-8.90 with the dust off, 8.90-8.98 motes, 8.86-8.89 few, 8.90-8.91 many,
      8.88-9.09 the old points; the beam's haze (`--beam-haze 0.0004`, off) 9.72-9.74.
      Open: density and brightness from the user's eye; whether the haze stays
- [x] The windows' light only through the glass (2026-11-22, builder 30,
      `build/notes/builder-30/`): the lace's light below no longer leaks round the glass in
      the niche's arch (with the tree's dapple in it), the lace no longer glows in that arch,
      and its shadow shows on the patch's sides (0.6 cm a metre over the sun's penumbra,
      was 3). Main pass at 3024 × 1890 native, two rounds: room view 11.84-11.85 to 11.98
      ms, table-window view 9.02 to 8.95-8.97; the game's shot unchanged in both renderers
- [x] The menu scene's placement from the concept's sun (2026-11-22, builder 30,
      `build/notes/builder-30/`): library-home-01's sun is about 20° across the wall, 12° up
      (29° to show in the same pane from the table-window chair); with the table as made it
      lights none of the board's field (`--sun-check`, 0 of 81), with the table 0.375 m
      toward the stove's end (4.125, 5.8) and the board turned -20° all of it (81 of 81).
      The players sit across the beam (the board turned by minus the sun's turn), each chair
      0.9 m clear behind the table; the table's top turned 25° under the board. Six
      placements on the light tuner's A key (`--place`), sliders for the table's place and
      turn and the board's turn. Main pass at 3024 × 1890, two rounds: room view 11.86-11.87
      ms before and after, table-window view 8.87 both. Open: the user's pick, then made the
      menu scene's default; the sun's disc reads only as the sky's glare in the pane
- [x] The small fixes (2026-11-22, builder 31, `build/notes/builder-31/`): the light
      tuner's walk flies (Q down, E up; the lens view moved to 1); less-turned the default
      placement; the glass's scratches thinner (its tile half a millimetre a texel) and
      half as many; its film a quarter fainter; the pieces' halo given a strength and
      reach (`--halo`, `--halo-reach`, the game's look unchanged). The halo is mostly the
      sun's micro-shadowing from the pieces' occlusion, strongest at the menu's low sun,
      not HDR (the board's HDR and 8-bit pictures within a level). Main pass at 3024 ×
      1890 native, less-turned, two rounds: room view 11.64 / 11.56 ms before, 11.65 /
      11.61 after; table-window view 9.74 / 9.77 before, 9.76 / 9.74 after. The game's
      shot unchanged in both renderers. Open: the user's pick of the halo (strengths 0.6,
      0.35, 0.6 with reach 0.6, or the micro-shadowing without the pieces,
      `build/b31/halo-micro.patch`), then made the game's. The user picked D
      (2026-11-22, 13f1b7ca): the game's shot changed, the field lighter round the pieces'
      lit side (`build/notes/builder-32/`, section 7)
- [x] The sun in the view out and an HDR glow (2026-11-22, builder 32,
      `build/notes/builder-32/`): a glow from the HDR target's linear light before the
      tonemap (threshold with a soft knee, a quarter-size dual-filter chain of six levels,
      a reach and a strength), on by default in HDR in place of the old window glow, which
      stays the 8-bit fallback; the sun's look on flags (disc, limb, edge, brightness, a
      core halo and a wider glow) with five presets (`--sun-look made|real|tight|concept|
      soft`); today's tree seen against the sky from its shadow's map along the view, so the
      leaves pass the disc as their shadows pass the board. At 3024 × 1890 native, less-turned, two
      rounds: main pass room view 11.75 / 11.60 ms before, 11.60 / 11.68 after; menu view
      9.80 / 9.79 before, 9.82 / 9.94 after (10.19-10.29 with the tree seen everywhere);
      the HDR glow's passes 0.38-0.44 ms against the old glow's 0.55-0.57, the tonemap 0.37
      against 0.45-0.48; the frame's GPU sum room 15.07 / 15.01 to 14.79 / 14.85, menu 12.93
      / 12.95 to 12.77 / 12.85. The game's shot
      unchanged in both renderers. Open: the user's pick of the look (made the default
      then), and whether the tree seen stays near the sun or shows everywhere (until the
      new tree, W4)
- [x] Real dust's points and an analytic haze in the sunbeam (2026-11-22, builder 33,
      `build/notes/builder-33/`): the table-window view's dust is points by default
      (energy-conserving footprints, fibres, glints, drift in world units; 250, 500, 1000;
      builder 29's motes as `--dust motes`, within a level of their old picture), the
      sprite haze replaced by an analytic one, off by default (`--haze clean|lived|dusted|
      study`, softer stripes toward the sun). At 3024 × 1890 native, less-turned, two
      rounds: menu view main pass 9.87 / 9.92 ms with the points against 10.08 / 9.82 with
      builder 29's motes and 9.81 / 10.06 with the dust off, the dust's pass 0.24-0.34; room
      view 11.68 / 11.61 against 11.64 / 11.62. The haze's passes 0.7 ms (the cross-section 0.15, the haze at half
      size 0.34-0.37, its add 0.18-0.22), the frame's GPU sum 12.99 / 12.78 to 13.48-13.80
      in the menu view at any strength, room view 14.76 / 14.80 to 15.42 / 15.55; at full
      size 14.44 / 14.62. The first exact haze
      cost 3.9-4.0 ms at half size and 14.9 at full; the atlas of the beam's cross-section
      brought it down. The game's shot unchanged in both renderers. Open: the user's pick
      of the dust's density and of the haze's strength (off, dusted or study); on mobile the
      haze is off (a cheaper version would be a quarter size without the lace and the tree)
- [x] The sun's looks a to d and the lace in the glow (2026-11-22, builder 34,
      `build/notes/builder-34/`, from `build/notes/window-view/refs/research-sun.html`):
      `--sun-look a|b|c|d` (a the true disc's edge hidden in builder 32's glow, 8000 over the
      sky; b the eye's veil in the tonemap, 3 / (1 + (θ/1.5°)²) white to amber out to 20°;
      c wider and twice as strong; d b with faint needles stopped by leaves and bars), the
      veil and needles scaled by the sun's open share from the glow's smallest level; the
      lace's narrow forward lobe toward the sun on `--lace-glow` (the lit fold within ~12° is
      already 0.9-2.5 × white without it, 1.1-3.1 with 20,12). Found: at less-turned the sun
      is behind a glazing bar (1-3% open); `--view-nudge 0.04,0,0` frees it. At 3024 × 1890
      native, two rounds (the user's tuner open at the time): menu view main pass 11.08 /
      10.17 ms before, 10.58 / 10.61 after (made), 10.57-10.73 with a-d; the tonemap 0.38-0.39
      to 0.43 (made) and 0.55-0.57 with the veil; room view main pass 11.95 / 12.01 to 11.94 /
      12.67, 12.25 / 12.32 with b; the frame's GPU sum menu 14.19 / 13.10 to 13.63 / 13.69,
      13.65-13.81 with a-d. Dust: only the points remain; fibres half as wide, light kept;
      haze levels `--haze menu` (study) and `game` (dusted). The game's shot unchanged in
      both renderers. Open: the user's pick of the look; the placement's eye nudge; a tonemap
      variant without the glare's code (0.04-0.05 ms with the veil off)
- [x] The sun's clean-up (2026-11-22, builder 35, `build/notes/builder-35/`): the user kept
      the made sun with the HDR glow. The lace's lobe toward the sun, the needles, looks a, c
      and d and builder 32's presets removed; look b kept as `--sun-look veil`, off by
      default, to retry with the new maple. The eye stays (no nudge, the user). The default
      shots byte-identical, the game's unchanged in both renderers. At 3024 × 1890 native, two
      rounds: menu view main pass 10.00 / 9.97 ms to 9.98 / 10.11, the tonemap 0.43 / 0.43 to
      0.39 / 0.38 (the needles' code was its extra cost), the frame's GPU sum 13.03 / 13.00 to
      12.99 / 13.10; room view main pass 11.73 / 11.80 to 11.73 / 11.73, the tonemap 0.43 /
      0.42 to 0.37 / 0.37; with the veil the menu's main pass 10.32 / 10.30, the tonemap
      0.49 / 0.48
- [x] The floor's cost (2026-11-23, `build/notes/floor-perf/`): looking straight down at
      the parquet (`--plan-eye 6.0,3.0,1.7 --plan-at 6.0,3.05,0`), headless 3024 × 1890, the
      frame 17.4 ms against 2.7 with the floor a flat colour: the floor about 14.7 ms. Each
      part by a build without it (frame ms saved, two rounds): the sun through the windows
      4.8 (the lace's shadow 2.0, the tree 1.3, the casements 0.8), the scratches 3.4, the
      table's shadow map 1.4, the mirror's lookup 1.9, the contact shadow 1.8, the three
      value noises 1.5, the door gaps in the walls' wax 0.5-1.0; MSAA, the oak's two taps, the
      screen's occlusion, the corners and `base_hides` near nothing. The parts sum past the
      whole (the shader's size: a branch round a texture read or a hoisted term made it
      slower). Kept: the scratch cells too far to reach skipped (byte-identical, 1.0 ms), no
      contact shadow on the floor (byte-identical in the straight-down, room and
      table-window views, 1.8 ms), the slow noises from a 1024² RG8 texture made once (at
      most 3 levels, 0.6 ms). Metal System Trace, main pass, two rounds: straight down 17.69 /
      17.49 to 12.55 / 12.51 ms, room view 11.75 / 11.63 to 10.42 / 10.54, menu view 9.88 /
      9.89 to 9.58 / 9.69; the frame's GPU sum straight down 20.92 / 20.65 to 15.67 / 15.61.
      At 5120 × 2880 the frame straight down 41.7 to 31.4 ms (the ceiling 11.4). Tried and
      dropped: hiding the table's taps or the box's light behind branches, a box test before
      the scratch cells' hashes, the plinth's lip hoisted (all slower). Open, the user's
      call: the scratches (2.4 ms left, at most 11 levels), the door gaps (about 1 ms, up to
      31 levels at the doorways), the mirror's blur in three taps (0.3-0.5 ms, up to 23
      levels in the window's streaks), the sun on the floor at a lower rate (the 4.8 ms)
      The user's picks (2026-11-23, `build/notes/floor-perf/options.html`, tried as tuner
      switches): the scratches from a 1.57 m repeating tile and no door gaps in the walls' wax,
      both renderers; the sun from a floor map and the table in four taps not wanted. The frame
      straight down 13.3-13.7 to 9.9 ms, room view 11.7 to 10.35, menu view 10.8 to 10.35
      (3024 × 1890); against before, at most 11 levels straight down (the scratches), 31 at
      the salon door. Next: the sun-derived bounds at the bake (planned, docs/decisions)
- [x] The floor's night (2026-11-23, `build/notes/floor-perf/night.html`): a breakdown at
      3840 × 2160 and 5120 × 2880 in four views (straight down, room, menu, and the room's
      corner, `--plan-eye 8.4,0.6,1.6 --plan-at 2.0,5.0,0.5`); the floor in pieces cut along the
      sun (`render3d::SunDerived`): frame straight down 15.8 to 12.5 ms (5K 27.5 to 21.6), room
      16.6 to 15.6, menu 15.7 to 15.1, corner 17.7 to 16.5 (5K 29.4 to 27.4); the floor's
      box reflection (six probe taps) left out where the mirror covers it, at most 1 level:
      straight down 12.4 to 11.3 (5K 21.4 to 19.5), room 15.4 to 15.1, corner 16.3 to 15.9
- [x] The floor's joints eased: tried and parked 2026-11-23, both removed (decision, `6cf9cccf`) (shell.md's "Floor joints"; the tuner's `--floor-joints
      flat|eased`, flat the default, `build/notes/floor-perf/joints.html`): deep (each board's
      edge rounded over 2.5 mm, the normal's full slope, the gap darker) was very aliased and far
      too strong. Eased: the edge's normal tilted 0.08 at the gap, faded out as a pixel grows past
      the 2.5 mm, and there a faint shade along the gap instead (`shaders::FLOOR_JOINTS`, a define
      in the tuner's own floor shaders, so the apps' flat floor has none of its code); the user's
      call. Times below (the joints' page)
- [x] The floor's mirror at a third of the screen, not half (the user's pick from
      `build/notes/floor-perf/night.html`'s proposal B; `render3d::planar_scale` 3): saves
      0.4-0.6 ms at 3840 × 2160 (straight down 0.62, room 0.57, menu 0.40, corner 0.61) and 1.4
      at 5120 × 2880; the windows' streaks a little blurrier (room max 35 levels), a little
      more shimmer in motion, accepted
- [x] The tree shadow's ruffle worked out only where it may turn a patch 5% or more (`LIGHT_FN`'s
      tree_light; night.html's proposal A, 0.35-0.5 ms at 3840 × 2160 with the ruffle compiled
      out): stills and two `--wind-time` shots within 1 level of before (a run's own noise).
      Saves 0.3 ms in the corner view, none straight down; skipping it only where the gust is
      0 saved nothing (the gust is somewhere on the crown every frame)
- [x] The painted wood's edges (2026-11-23, `build/notes/paint-edges/`): a fillet under a
      pixel shaded as the face toward the eye, and the joinery's T-junctions and open fillet
      ends closed in the mesh (37,906 to 40,182 triangles); the casements' crawling dots
      gone. Frame at 3840 × 2160, four rounds A B A B: menu 15.1 before and 15.7 after (14.9
      without one stray round), room 16.2 and 16.4, within a round's noise of ±1 ms
- [x] Skip the floor's mirror when the camera frustum excludes the floor (2026-11-23,
      `build/notes/mirror-skip/index.html`). Headless Mac light tuner at 3840 × 2160,
      with room surfaces and the view outside on. Two alternating before and after runs,
      six seconds each, with the first reported half-second window excluded for startup.

      | View | Before (ms) | After (ms) | Change (ms) | Byte-identical | Max RGB difference | Pixels over 8 |
      |---|---:|---:|---:|---|---:|---:|
      | Straight down | 10.87 | 11.03 | +0.16 | Yes | 0 | 0 |
      | Corner | 15.54 | 15.69 | +0.15 | No | 1 | 0 |
      | Room | 14.81 | 14.82 | +0.01 | Yes | 0 | 0 |
      | Menu | 14.79 | 14.74 | -0.06 | Yes | 0 | 0 |
      | Wall | 12.90 | 12.40 | -0.50 | Yes | 0 | 0 |
      | Ceiling | 7.29 | 6.76 | -0.53 | Yes | 0 | 0 |

      The corner's 182 changed pixels each differ by one level. The wall shot uses
      `--plan-eye 4.0,3.0,1.6 --plan-at 4.0,8.0,3.0` to frame above the floor.
      The ceiling uses `--plan-eye 6.0,3.0,1.6 --plan-at 6.0,3.05,4.0`.
- [x] Turn the floor's corners by the room's frame in the mirror's frustum test
      (2026-11-23, `build/notes/mirror-skip/pop.html`). Unturned, it missed a visible floor in
      about one view in eight (1,993 of 15,912 modelled walk views), and the floor popped to
      its sharp box reflection, as walking toward the stove-end door past
      `--plan-eye 4.85,3.5,1.6 --plan-at 0,3.5,1.2` (108 levels, 415,462 pixels over 8). Fixed,
      the steps and the four views at 3840 × 2160 match the mirror never skipped within one
      level; the wall and ceiling views still skip it.
- [x] Evaluate scissoring the floor mirror (2026-11-23). Rejected after both padding
      trials changed reflections. At 3840 × 2160, the 64-texel trial kept the thin-strip
      capture identical, but changed 234,989 corner pixels by more than eight levels.
      The 192-texel trial still changed 90,659 menu pixels by more than eight levels.
      The renderer keeps the full mirror target when the floor can show.

      Before and trial are means of two alternating runs in the headless Mac tuner,
      with the first window excluded. A separate tuner was detected at the start of
      the 64-texel comparison. The 5K Corner result with 192 texels includes one
      174.8 ms reporting window. See `build/notes/mirror-skip/index.html#mirror-rectangle`
      for all pixel differences and 300% crops.

      | Size | View | 64 texels (ms) | 192 texels (ms) |
      |---|---|---:|---:|
      | 3840x2160 | Straight down | 11.11 → 11.69 | 11.09 → 11.94 |
      | 3840x2160 | Corner | 15.43 → 15.32 | 15.80 → 16.20 |
      | 3840x2160 | Room | 14.58 → 14.44 | 14.98 → 15.39 |
      | 3840x2160 | Menu | 14.52 → 14.14 | 14.87 → 14.81 |
      | 3840x2160 | Wall | 12.31 → 12.24 | 12.69 → 12.68 |
      | 3840x2160 | Ceiling | 6.71 → 6.73 | 6.90 → 6.94 |
      | 3840x2160 | Thin strip | 14.43 → 13.37 | 13.91 → 13.67 |
      | 3840x2160 | Grazing | 14.83 → 14.82 | 14.83 → 15.40 |
      | 5120x2880 | Straight down | 18.82 → 21.13 | 20.93 → 22.00 |
      | 5120x2880 | Corner | 25.69 → 25.68 | 25.92 → 38.17 |
      | 5120x2880 | Room | 23.75 → 23.74 | 24.22 → 24.42 |
      | 5120x2880 | Menu | 24.01 → 24.28 | 24.66 → 24.57 |
      | 5120x2880 | Wall | 20.25 → 20.33 | 20.84 → 20.71 |
      | 5120x2880 | Ceiling | 12.12 → 12.03 | 12.32 → 12.34 |
      | 5120x2880 | Thin strip | 21.91 → 21.80 | 22.33 → 22.90 |
      | 5120x2880 | Grazing | 23.71 → 24.03 | 24.22 → 25.33 |

- [x] The lace's shade the default (fill in shade 0.5, folds' shade 1.5) and the tie-back's
      cord hung by gravity (2026-11-23, `build/notes/lace-cord/`): the loop drawn tight on
      each panel's cloth's convex hull, the tails and tassels relaxed from straight down to
      hang plumb or lie on the cloth below the tie. Triangles unchanged; the four views
      differ only at the tie-backs (straight down byte-identical; at 3840 × 2160 the
      corner 5,783 pixels over 8, the room 4,577, the menu 17,141). Frame times unchanged
      within the rounds' spread, measured on a loaded machine (corner 85.4-89.3 →
      89.2-90.1 ms, menu 88.9-91.7 → 91.9-94.1 at 3840 × 2160, all others' builds running).

- [x] The tie-back made real (2026-11-23, `build/notes/tieback-real/`).
  - [ ] Still open (the user, 2026-11-23, after Codex's ring): the loop tightened, its pinch
        deeper; the cord still seen through the lace where it passes behind it.
  - [x] The ivory cord (`build/notes/lace-cord-ivory/`): the lace's thread at half its
        linear albedo, from three quarters.
  - [x] The tilted ring sets the cord and the cloth's pinch in one plane, with the knot
        about 8 cm below the opposite point of the ring. The lace pattern follows the
        gathered cloth along the drop. The ring step keeps the triangle counts.
  - [x] The return arc is omitted behind the gathered lace, with its ends tucked into
        the folds. Opaque triangles drop from 40,182 to 38,262 and glass and lace stay
        at 12,540. Both middle-window panels have before, ring and hidden-return shots
        at 3840 × 2160 beside the reference.
  - The board and straight-down tuner shots are byte-identical at both sizes. The actual
    Mac game differs by at most two RGB levels, against four for a repeat of the same
    baseline. In the corner, room and menu views, the ties, lace patterns and their faint
    reflections account for the differences. The largest levels / pixels over eight
    are 222 / 101,895, 226 / 102,876 and 210 / 336,459 at 3840 × 2160, and
    233 / 196,805, 231 / 201,723 and 209 / 688,576 at 5120 × 2880.
  - Mac light tuner, two alternating rounds under the quiet lock, last three
    half-second samples of each run. The 5120 × 2880 results varied by up to 7.33 ms
    between runs of one build, so the lower corner and room averages are inconclusive.

    | View | 3840 × 2160 before → after (ms) | 5120 × 2880 before → after (ms) |
    | --- | ---: | ---: |
    | Straight down | 10.82 → 10.75 | 28.97 → 28.93 |
    | Corner | 15.57 → 15.77 | 31.62 → 28.62 |
    | Room | 15.08 → 15.33 | 26.77 → 23.97 |
    | Menu | 14.63 → 15.08 | 23.70 → 24.00 |

  - Both Mac apps build and the tests pass with NGFX set. ADB found no USB device.
- [x] Give glass and lace separate color shaders and index ranges (2026-11-23,
      `build/notes/glass-lace-split/`, baseline `9cf039d5`). Both renderers draw glass
      first in the room and floor mirror.
  - M1 Pro light tuner, two alternating six-second runs per build under the quiet lock.
    Each run contributes its last six half-second samples.

    | View | 3840 × 2160 before → after (ms) | 5120 × 2880 before → after (ms) |
    | --- | ---: | ---: |
    | Straight down | 11.04 → 11.28 | 18.77 → 18.48 |
    | Corner | 15.58 → 15.97 | 25.23 → 24.70 |
    | Room | 14.77 → 14.25 | 24.62 → 23.06 |
    | Menu | 14.94 → 13.69 | 24.79 → 22.67 |

  - Menu was faster in both rounds at each size. The largest same-build spreads across
    all views were 2.08 ms at 3840 × 2160 and 3.18 ms at 5120 × 2880.
  - Both straight-down shots were byte-identical. Maximum RGB levels / changed pixels
    were 2 / 1,300 (corner), 2 / 1,158 (room), and 2 / 100 (menu) at 3840 × 2160.
    At 5120 × 2880 they were 2 / 3,665, 2 / 2,392, and 1 / 217. All eight baseline
    repeats were byte-identical. The grazing shots from both ends of the wall, including
    the 1 cm camera shift, were within two levels. All of these shots had zero pixels
    over eight.
  - The corner became byte-identical with the mirror off. The corner's mirror-map
    debug view reached 10 levels at most, with six pixels over eight. A control that
    sorted the indices while keeping the original shader and single draw reproduced
    the larger differences in the debug view. The test suite passed with NGFX set,
    and both Mac apps built. The 3D home screen differed by at most one level on
    either backend. ADB found no connected tablet.
- [x] Artifacts the user saw (2026-11-23; crops in `build/notes/artifacts-2026-11-23/`, local):
  - [x] Single bright pixels sparkling on the dark oak of the wainscot and the bookshelves
        at some angles (`oak-sparkle-*.png`), and on the window wall's side, which is in
        shade (the user doubts the normal map's highlight, rightly: no sun to reflect there).
        Find the cause before fixing, in order: a broken value in one pixel (a division by
        nearly zero, a normalize of a zero vector, Inf or NaN; clamp and mark them in a
        debug view); the MSAA resolve in HDR (one bright sub-sample averaged with dark ones,
        as the bars' dashes); a bad SSAO or GTAO texel at a depth edge (switch each off);
        specular aliasing only where a highlight exists (then Toksvig or Kaplanyan-Hoffman)
    - Fixed (2026-11-23, Windows, Vulkan): pinholes, not shading. `--ssao-view broken`
      marked no non-finite value; the dots stayed with HDR off (35 levels over the oak
      instead of 52), GTAO off and SSAO off; the sun's highlight view showed them, but a
      view of each pixel's material showed the oak there turned from the sun and the light
      added after it, and with the view out off they took the plain sky's colour. Cracks at
      T-junctions of the stiles, rails, plinth and cap; each piece now cut where another's
      corner lies on it. Cracks (pixels showing the view out, 3840 x 2160): by the hall's
      bookcases 29 to 0, beside the hall door 38 to 10 (left on the door's architrave and
      paper), close to the window wall 147 to 122 (the windows' own edges), the corner 935
      to 885, the room 490 to 466. The four views against the build before: straight down
      byte-identical at both sizes; corner, room and menu at most a level in 5,000-20,000
      pixels at 4K (the wainscot and its reflection), and the dots (18-60 pixels over 8).
      The shell 38,262 to 46,026 triangles. Left: the doors' painted panels have the same
      junctions
  - [x] A thin light line along the wall's base behind the lace (`light-line-wall-base.png`):
        the floor's reflection, the plinth's contact line, the wax band or a leak at the
        wainscot's foot; find which with the tuner's debug views
    - Fixed (2026-11-23): the lace's own cloth below its hem, its mask read past the mask's
      bottom edge into the pattern's top through the repeating sampler (mips, anisotropy).
      It stayed with the mirror, the corners' map, the contact shadows, SSAO, GTAO and HDR
      each off. The lace's read held inside the edge, nothing drawn past the last row: the
      line's 500-1,100 pixels a view over 8 at 4K, the hem unchanged, the floor's reflection
      of the line a level
  - [x] The HDR glow pulsing on thin sun strips (the sill, the window's reveals) when the
        eye moves up or down, steady when it moves sideways (`glow-shimmer-*.png`): the
        first downsample averaged 4 x 4 blocks and thresholded after, so a strip a few
        pixels tall jumped as it crossed block rows. Fixed (2026-11-23,
        `build/notes/glow-steady/`): each tap thresholded, and the first pick a tent over
        8 x 8 pixels from sixteen taps; Karis's weighting not needed
    - The glow's halo round the middle window's strips, 3840 x 2160 from about 3.5 m, its
      variation about the trend over ten steps (the left and right leaves' reveals, the two
      sill patches); the strips' own light over the threshold varies 1.8-2.9%:

      | Steps | Before | Taps thresholded | Tent (kept) | Wider tent, 36 taps |
      | --- | --- | --- | --- | --- |
      | 2 mm up | 6.9, 7.7, 2.4, 5.0% | 6.5, 6.1, 2.0, 1.7% | 3.5, 3.4, 2.0, 1.8% | 3.1, 2.6, 2.5, 2.6% |
      | 5 mm toward | 3.4, 3.8, 2.6, 4.6% | 3.1, 3.0, 2.3, 2.3% | 2.5, 2.4, 2.1, 2.1% | 2.9, 2.7, 2.2, 2.3% |
      | 2 mm sideways | 0.07, 0.42, 0.07, 0.16% | 0.06, 0.18, 0.05, 0.10% | 0.05, 0.11, 0.06, 0.13% | 0.03, 0.08, 0.06, 0.14% |

    - At rest, 3840 x 2160 against the build before: straight down at most 1 level; the
      corner 19 levels, 266 pixels over 8; the room 45, 2,895; the menu 24, 791 (thin
      strips' edges only, the mean within 0.04 of a level); the sun's disc within 3.
      Two runs of the build before were byte-identical.
    - Frames on the M1 Pro, two rounds A B A B, the same to the counter's whole ms at
      3840 x 2160 (down 10, corner 14, room 13, menu 12) and 5120 x 2880 (18, 23, 21-22,
      21); the first pick's encoder 0.17 ms of fragment time, now 0.25-0.26, at 5120 x 2880
      (Metal System Trace, menu view). Tests pass with NGFX, both apps build; the app
      draws no HDR yet, so nothing changes on the tablet
- [ ] The lace in shade, open questions (`build/notes/lace-shade/trials.html`): a cooler
      tint in shade; trial 1 (more opacity at grazing angles) and trial 4 (motif against
      net), only if the user wants more after the defaults of 2026-11-23
- [ ] The window wall and the view outside, drawn once into the kept backdrop, with depth
      of field (task 106)
- [ ] The camera's angles and pans for the home screen (task 106)

## Oak texture sampling

Mac light tuner at 3840 × 2160, headless, with room surfaces and the outside on.
Each run averages the last six half-second samples. A and B alternated twice under the
shared GPU quiet lock. Pixel differences are the maximum absolute RGB channel difference
and the count of pixels whose difference exceeds eight levels. Full shots and crops are
in the worktree's `build/notes/oak-textures/index.html`.

### RG8 normal fields

Both renderers support RG8. The floor and walls use only the normal's two tangent
components. RG8 halves the normal mip payload and takes the four oak fields from 85.33 MiB
to 64.00 MiB at 2048². The corner repeat had 68 pixels change
one level. RG8 moved five by one level. The first timing sweep had a 23.4 ms menu
outlier. In the warmed rerun, straight down was 0.034 ms slower and the
corner and room gains varied between rounds. The app keeps RGBA8.

| View | A₁ / A₂ (ms) | B₁ / B₂ (ms) | Mean A → B (ms) |
|---|---:|---:|---:|
| Straight down | 10.783 / 10.800 | 10.767 / 10.883 | 10.791 → 10.825 |
| Corner | 15.400 / 15.233 | 15.233 / 15.283 | 15.317 → 15.258 |
| Room | 14.583 / 14.333 | 14.283 / 14.383 | 14.458 → 14.333 |
| Menu | 14.283 / 14.233 | 14.300 / 14.217 | 14.258 → 14.259 |

| View | Repeat max / pixels >8 | Trial max / pixels >8 | Trial pixels changed |
|---|---:|---:|---:|
| Straight down | 0 / 0 | 0 / 0 | 0 |
| Corner | 1 / 0 | 1 / 0 | 5 |
| Room | 0 / 0 | 0 / 0 | 0 |
| Menu | 0 / 0 | 0 / 0 | 0 |
| Grazing | 0 / 0 | 0 / 0 | 0 |
| Grazing, eye shifted 1 cm | 0 / 0 | 0 / 0 | 0 |

### 4× anisotropy

`--oak-aniso-4` tests 4× anisotropy on both the albedo and normal maps of the floor
and walls. Both settings use RGBA8 normals and the same tuner built on `6aa05f8d`. The app uses
8×. The grazing camera is at `6.0,1.0,0.6` facing `6.0,8.0,0.0` in plan metres.
The motion shot shifts the eye one centimetre along x.

| View | A₁ / A₂ (ms) | B₁ / B₂ (ms) | Mean A → B (ms) |
|---|---:|---:|---:|
| Straight down | 10.633 / 10.650 | 10.633 / 10.650 | 10.642 → 10.642 |
| Corner | 14.950 / 15.667 | 14.967 / 14.917 | 15.308 → 14.942 |
| Room | 14.183 / 14.233 | 14.150 / 14.067 | 14.208 → 14.108 |
| Menu | 13.967 / 14.217 | 14.150 / 13.950 | 14.092 → 14.050 |

| View | Repeat max / pixels >8 | Trial max / pixels >8 | Trial pixels changed |
|---|---:|---:|---:|
| Straight down | 0 / 0 | 0 / 0 | 0 |
| Corner | 0 / 0 | 31 / 617 | 264653 |
| Room | 0 / 0 | 26 / 393 | 214831 |
| Menu | 0 / 0 | 6 / 0 | 4448 |
| Grazing | 0 / 0 | 23 / 295 | 665137 |
| Grazing, eye shifted 1 cm | 0 / 0 | 19 / 296 | 664379 |

### Mip selection and compression proposal

The floor's gradients follow the room-to-plank rotation, axis swap and sign, and
divide by the same field size as the sampled coordinate. The plank width cancels.
At the center of the 4K straight-down view, a pixel spans about 1.20 base texels
(LOD 0.26). There is no mip bias or scale error to correct.

Export the fixed desktop and phone oak bakes with every mip. Keep albedo's sRGB
color and linear roughness alpha and the normals' linear XY. The current PPM dump
only exports RGB at level zero. Upload the encoded blocks into sampled textures and
use the procedural bake on devices without the format. Albedo needs sRGB compressed
formats in both wrappers, which currently expose linear formats. GPU encoding would
bake all mips, encode them into a compute buffer and copy the blocks to compressed
textures. It adds room-open time, temporary surfaces and a compressed copy path.

| Four 2048² textures including mips | Payload (MiB) |
|---|---:|
| RGBA8 | 85.33 |
| RGBA8 albedo with RG8 normals | 64.00 |
| ASTC 4×4 or BC7 | 21.33 |
| ASTC 6×6 | 9.53 |

Scaling the corner and room RG8 time changes in proportion to the bytes removed
estimates 0.17–0.44 ms of savings from full compression. The straight-down model
starts from a 0.034 ms regression, and the RG8 timing varied by round. The estimated
gain needs direct compressed-sample measurements.

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
