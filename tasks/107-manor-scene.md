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
      shadow, its pattern blurred, in the room. Way f2 for now, `--lace f|d` in the tuner
      while the choice is open; the brass a plain procedural one (`surfaces::LOOK.brass`)
      until the gilt and brass study lands (`model3d`'s `curtains.goose`,
      `build/notes/curtains-build/`, costs in task 110)
- [x] The games table's base, option A of `build/notes/games-table/` (2026-11-21): a
      turned pedestal (rings under the top, an urn, a beaded neck, a drum) and four
      cabriole legs from the drum curling into scroll toes on the floor, the top's
      lathe and stepped rim kept, all the top's flame mahogany with the grain along the
      column and legs; one mesh with the top, drawn in the game too, where the top hides
      it (the renderer check and the tuner's game shot unchanged). The legs are swept by
      `mesh::bar`, a rounded section along a curve, for later furniture's legs and
      rails. Its shadow on the floor and the top's on it worked out in the shaders, as
      the old turned foot's (removed). The top's size, 1.05 m or 0.80 m, waits for the
      user: the light tuner's `--table-top` (`build/notes/games-table-build/`, costs in
      task 110)
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
- [ ] The images from ChatGPT: the simplified concept, the wallpaper, wainscot, window,
      lace, the park outside (task 106's list)
- [ ] Dust in the sunbeam (task 104's follow-ups)
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
