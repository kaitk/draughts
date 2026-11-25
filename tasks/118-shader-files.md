# 118: The 3D shaders split into files by what they draw

Status: in-progress (the split and `at_top` done 2026-11-25; the material split's measure after task 120)

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

- [x] A plan first, for the user: the groups and files, what stays shared, and how
      `scripts/ngfx_3d_shaders.py` finds the pieces after the move
- [x] The move, text unchanged: every pipeline's assembled GLSL byte-identical before
      and after (dump them both ways and diff), both apps and the tuner built, the tests
      passing, the game's shot unchanged on gfx and ngfx
- [x] `TABLE_FRAG`'s tests of the top's height (`p.y > TABLE_TOP - 0.01`, for the board's
      shadows and `on_table`) named once, as `at_top`, and kept off the chairs, whose backs rise
      past that height (tried in task 107's chairs, round 2, and left for this split)
- [x] `docs/architecture/rendering.md` and `agents/` say where each kind of shader lives
- [ ] Then, separately: where one fragment shader branches on a material (`TABLE_FRAG`'s
      `v_mat`: the top, the base, the chairs' wood, cloth and braid; `ROOM_FRAG`'s kinds), what
      splitting it into pipelines would cost and save, measured on the Mac and the tablet
      (task 115) before anything is changed

## Results (2026-11-25)

The plan the user agreed: `src/render3d/shaders.goose` an index of imports, the pieces in
ten files of `src/render3d/shaders/` in the one namespace `shaders`, so no `embed_shader`
call changed. Lines: `room` 2,030, `bake` 1,460, `board` 1,290, `passes` 729, `light` 727,
`table` 550, `outside` 476, `air` 439, `tree` 396, `frame` 186. `ROOM_FRAG` (1,550) and
`BAKE_FRAG` stay one piece each: splitting them is the material work below.

- Goose takes a package's files in a subfolder (`import .shaders.room;`), from the
  package's own file or another of its files; checked in a scratch package first.
- The readers: `ngfx_glsl.strings` takes a folder, refusing a name defined twice; the
  ngfx 3D and 2D writers, `scripts/room_fixed.py` (`room.goose`), `shader_report.py` and
  `test/model3d/geometry` (`frame`, `table` and `room`, joined with `str`) read the new
  files.
- The check: all 131 pieces' text identical, by name, before and after, and no line lost;
  the call sites in `render3d_gpu.goose`, `render3d.goose` and the tuner untouched; the
  ngfx writers' output identical but the written files' header line, which names the
  folder now. The binaries differ (0.6 MB of the gfx app's 41, 2.7 of the tuner's 56):
  Goose lays the constants out in the order they are declared, so `cmp` can't check a
  move. The shots: the tuner's four views and the table's byte-identical, the game's shot
  at most 1 level on gfx and ngfx, none over 8. All of `scripts/test.sh` passed.
- `at_top` (`p.y > TABLE_TOP - 0.01 && !chair`) named once in `TABLE_FRAG` for `top`, the
  board's foot occlusion and its shadow, all three off the chairs. No pixel moved in the
  four views, the table's, the chairs' close and low views, or the game's on gfx and
  ngfx (at most 1 level): the foot's occlusion fades out 1.4 units (about 5 cm) from the
  board and its shadow never reaches the chairs, so the chairs were in the test's reach
  only by name. `room_light_at`'s `in_room` (round 2's) is a ramp below the top, not this
  test, and stays.
- The ngfx build: macOS's update left the Command Line Tools without `metal`, and the
  written shaders' new header made every blob stale, so it was built with Xcode's
  toolchain and its 26.4 SDK (`agents/testing.md`).
