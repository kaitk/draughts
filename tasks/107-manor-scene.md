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
- [ ] The gusts briefer and weaker (the user, 2026-11-20): their strength, length and
      how often on `rooms::Room` with tuner flags, defaults about 1.5 to 2 s and about
      half today's push (a gust now lasts about 5 s every 20 and pushes the leaves about
      3 times calm air's), each gust quickening only some regions of branches
- [ ] The shadows in the light tuner (the user, 2026-11-20): the board casts none on the
      table, and the pieces cast shadows but don't shade themselves; checked in shots
      first, the pieces' own shadow perhaps the high mode's only. The user's shot of the
      autumn board at a low angle shows it floating: no shadow or contact darkening on
      the table under its edge
- [ ] The autumn board's frame, its outer sides, too rough seen at a glancing angle
      (the user, 2026-11-20): matte and streaky where waxed wood would catch a sheen; the
      squares are fine
- [x] An FPS counter in the light tuner (the user, 2026-11-20): frames a second and
      the frame's time while it draws every frame (the wind on), to judge the high
      mode's cost as the room fills. F shows it, G waits for the GPU each frame; no GPU
      timer in SDL's GPU; the first numbers in task 110
- [ ] The high mode drawing every frame: on desktops, and on laptops and tablets on
      mains power, a setting forcing it (`docs/decisions/rendering.md`, "Frames and
      battery"); the game's clock ticking, the window's pattern swaying gently

## The home screen's shot (autumn)

- [x] The library as a whole room, its layout chosen from ChatGPT images (task 109)
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
