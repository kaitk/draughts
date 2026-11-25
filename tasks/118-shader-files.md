# 118: The 3D shaders split into files by what they draw

Status: todo

`src/render3d/shaders.goose` holds every 3D shader of the app in one file, 8,152 lines and
77 GLSL pieces (heads, shared functions, vertex and fragment bodies) put together by
`embed_shader` calls. Finding the part that draws one thing (the table, the room's
shell, the lace, the tree, the glow) means scrolling through all of it, and one edit can
touch a piece another pipeline shares without it being plain. The user asked for it to be
split the best way for editing, low effort at first but correct (2026-11-25), with no
hidden complexity, no slower shaders on Mali, and a way toward fewer ubershaders later.

The pieces fall into groups by what they draw: the shared ones (`FRAME`, `TOE_FN`,
`LIGHT_FN`, `SHADOW_FN`, `TONE_FN`, `FADE_FN`, `FULL_VERT`, `QUAD_VERT`), the board and pieces
(`LIT_*`, `CROWN_*`, `OCC_FRAG`, `SHADOW_CATCHER_FRAG`, `MARKS_FRAG`), the table and its chairs
(`TABLE_*`), the room's shell and floor (`ROOM_*`, `WINDOW_MAP_*`), the view out (`OUTSIDE_*`,
`PARK_FN`), the tree (`TREE_*`, `CARD_*`, `WIND_FN`), the screen passes (`SSAO_*`, `GTAO_FRAG`,
`GLOW_*`, `HDR_TONE_FRAG`, `PLANAR_*`, `UPSCALE_FRAG`, `BAKE_FRAG`, `SHRINK_FRAG`, `BLUR_FRAG`,
`COPY_FRAG`, `KEPT_FRAG`, `SHOW_*`), and the air (`DUST_*`, `HAZE_*`). A first step is moving
each group into its own file under `src/render3d/shaders/` in the same namespace, text
unchanged, so nothing compiles differently.

## Acceptance criteria

- [ ] A plan first, for the user: the groups and files, what stays shared, and how
      `scripts/ngfx_3d_shaders.py` finds the pieces after the move
- [ ] The move, text unchanged: every pipeline's assembled GLSL byte-identical before
      and after (dump them both ways and diff), both apps and the tuner built, the tests
      passing, the game's shot unchanged on gfx and ngfx
- [ ] `TABLE_FRAG`'s tests of the top's height (`p.y > TABLE_TOP - 0.01`, for the board's
      shadows and `on_table`) named once, as `at_top`, and kept off the chairs, whose backs rise
      past that height (tried in task 107's chairs, round 2, and left for this split)
- [ ] `docs/architecture/rendering.md` and `agents/` say where each kind of shader lives
- [ ] Then, separately: where one fragment shader branches on a material (`TABLE_FRAG`'s
      `v_mat`: the top, the base, the chairs' wood, cloth and braid; `ROOM_FRAG`'s kinds), what
      splitting it into pipelines would cost and save, measured on the Mac and the tablet
      (task 115) before anything is changed
