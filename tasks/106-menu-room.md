# 106: The library around the board on the home screen

Status: todo (planned 2026-11-20, after tasks 104 and 105; autumn only at first)

The home screen's shot of the manor's library (task 093's direction, `library-menu-01`,
`style-01`, local in `design/manor/`): the window with its curtains and the park beyond,
the sun through the trees falling across the board on its table, at the camera angles we
choose, with pans only on the home screen. The game's views don't draw the room (culled
or left out), only the floor where it shows.

## The way there (the user agreeing, 2026-11-20)

1. The board's light in the game finished first, with its options: the rooms' profiles,
   the tree on or off, the neutral light (tasks 104, 105).
2. The floor: herringbone parquet (kalasaba) and a rug, as in `style-01`, procedural or one
   texture, baked as the table is; cheap, and seen in some of the game's views. For the
   game, not needed for the first home shot.
3. A simplified concept of the room from the home screen's camera, from ChatGPT, with few
   elements: the window's niche and lace curtains, wainscot and wallpaper, the floor and
   rug, the round table; modelled from it, not from `library-menu-01`'s detail.
4. The room as simple geometry, drawn once into the kept backdrop when the camera rests,
   so drawing stays on change. The window's light works in world space, so the sun's
   patch and the leaves' shadows fall on the walls and floor too.
5. Outside and depth of field: blurred strongly outside, lightly on the curtains, the board
   sharp; once, as the camera is fixed.
6. The showcase after: dust in the sunbeam (task 104's follow-ups), lower camera angles,
   the table's props (tasks 100, 102, 103).

## What the first home shot needs (the user, 2026-11-20)

- The wallpaper and wainscot; the window's white painted sills, its shutters, the niche's
  reveals and frame (simple materials, tuned later); the lace curtains.
- The table top as it is: passable, as the camera stays near it at first; a whole table
  model later.
- Outside, at first: a picture taken from outside, in perspective, set a little beyond the
  window and blurred (or blurred beforehand), with the sun's bright blurred spot through
  the crown, as in the autumn photographs (`library-menu-01`'s flare).
- Not yet: the floor and rug (the game's), the room's far walls, other seasons.

## Images to make first (a ChatGPT session of its own, in parallel, the user, 2026-11-20)

The floor's and the window wall's look come from images before any modelling; saved in
`design/manor/pieces/` with their prompts in `prompts.txt`, the ones the app uses cut to size
and put in git once chosen (`AGENTS.md`'s rule on images):

- The simplified concept of the home shot from its camera: the window niche, curtains,
  wainscot and wallpaper, the round table with the board, the floor's edge (step 3).
- The wallpaper: a tileable swatch of `style-01`'s muted gold-brown floral on a dark
  blue-grey ground (task 093's surfaces), straight on, even light.
- The wainscot: a panel of the dark panelled wood, straight on, to model or bake from.
- The window: its frame, bars, white sills, shutters and the niche's reveals, in
  elevation, for proportions and materials.
- The lace curtain: a straight-on swatch of its pattern, for a cut-out texture.
- Outside: the park seen from the window's height, in perspective, autumn, the low sun
  in the crown, for the blurred picture behind the window.
- For the game's views later: the herringbone (kalasaba) parquet, straight on, and the
  rug (`style-01`'s), straight on.

## Acceptance criteria

- [ ] A simplified concept of the home shot chosen, saved in `design/manor/concepts/`
- [ ] The window wall (wallpaper, wainscot, niche, sills, shutters, curtains) and the
      view outside behind the board on the home screen, autumn, at the chosen cameras
- [ ] The room drawn only when the camera moves or the scene changes; its cost and
      memory recorded on the Mac
- [ ] The floor and rug in the game's views
