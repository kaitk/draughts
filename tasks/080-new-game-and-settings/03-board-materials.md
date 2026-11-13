# 03: Wood, stone, or auto for the 3D board

Status: in-progress

A choice for the raised board: Wood, Stone, or Auto, the season's own (the user,
2026-11-13). It replaces task 045, which listed every alternative look; this offers two
per season. The flat board doesn't change.

| Season | Auto | Wood | Stone |
| --- | --- | --- | --- |
| Autumn | wood | maple and walnut in cherry (`looks::autumn`) | **new**: `--autumn 1` to 3 |
| Winter | stone | **new**: `--winter 1` to 3 | slate in marble (`looks::winter`) |
| Spring | stone | Baltic carved oak (`SPRING_BALTIC`) | elven carved stone (`SPRING_ELVEN`) |
| Summer | wood | `looks::summer` | amber-carved granite (`SUMMER_AMBER`), to finish |

Spring's wood could be the birch (`looks::spring`) instead of the Baltic oak; the user
to choose.

To decide: one choice for every season (Wood shows each season's wood), or one per
season (settings shows the theme season's two boards, each season remembers its own).
One choice is simpler to show and to say; per season matters only if a child likes
autumn's stone but spring's wood.

Steps:

1. Autumn's stone and winter's wood in `poc/3d`, as looks beside the others, made with the
   bake's existing machinery (stone mottling and veins, the woods' models, the carving),
   shots beside each season's other board for the user. A new concept is welcome.
2. Summer's amber stone finished: the open points in task 041 (the amber reads as an
   inlay, the motifs small against the squares).
3. The choice in the player's file, the renderer picking the look from season and
   material; the flags (`--spring`, `--summer`, `--marble`) kept for tuning.
4. The bake's cost of each new look on the Pixel 7a and the A33, and the memory the same.

## Autumn's stone and winter's wood (2026-11-13)

Three takes each, as variants beside the season's own look (`looks::AUTUMNS`,
`WINTERS`), picked with `--autumn N` and `--winter N` in `poc/3d` and the app, 0 the
current look and still the default. All made with the bake as it was: no shader
changed. One new piece of machinery: a look may have its own frame marble
(`looks::marble_for`, `render3d::marble_of`), since the marble had been one for every
stone frame, winter's chosen one; autumn's stone frames take theirs, winter's stays
`--marble`'s. Judged headless only, 960 × 720, beside each season's board.

- **Autumn 1, travertine and red jasper** (`looks::autumn_stone`, the pick): honed
  travertine light squares (0.9 0.79 0.62, roughness 0.4), cloudy (the stone's
  clouding 0.16 and a finer mottling 0.2 at 4 a unit); polished red jasper dark ones
  (0.52 0.24 0.13, roughness 0.28), mottled with pale veins (`dark_ring` 0.3, 6, 0.12);
  a deep brown inlay; a solid block of dark brown marble with soft golden veins and fine
  cracks, Emperador Dark's (`looks::EMPERADOR`, marble 5, past the ones M cycles: base
  0.2 0.125 0.085, veins 0.62 0.48 0.32, width 0.014, softness 0.6, cracks 0.4, wave
  1.4, polish 0.75). Cream travertine (0.92 0.85 0.72) and rust-brown (0.34 0.17 0.11)
  pieces. Autumn's light. The first veins (0.8 0.64 0.44, crisper) read as gold paint
  and were toned down.
- **Autumn 2, carved** (`autumn_carved`): the same field in a weathered brown stone
  frame (0.4 0.3 0.23), mitred, speckled (`stone.w` 0.6) and coarse, carved with the
  elven vines (`looks::AUTUMN_VINES`: motif 0, depth 0.023, scale 23.685, moss 0.15),
  their leaves rust (`fill` 0.72 0.38 0.14, 0.7). First at 0.86 0.42 0.12 full, the
  leaves read as orange beads.
- **Autumn 3, sandstone and porphyry** (`autumn_porphyry`): golden sandstone (0.88 0.73
  0.5) and a finely mottled red-brown porphyry (0.4 0.17 0.15), a speckled dark brown
  stone frame, mitred, with its own clouding (no marble). The plainest of the three.
- **Winter 1, limed ash and smoked oak** (`looks::winter_wood`, the pick): ash light
  squares (0.8 0.77 0.72) and smoked oak dark ones (0.36 0.33 0.31), ring-porous (wood
  2's rings, `light_ring` 0.07 0.4 0.5 0.45), limed: white in the pores and grain as
  frost (`looks::LIMED`: pickle 0.3, warmth -0.3, varnish 0.1, sanding 0.3), a mitred
  frame of blue-grey stained oak (0.3 0.31 0.34) limed the same; ivory (0.88 0.86 0.82)
  and smoked dark (0.22 0.23 0.25) pieces, the dark one with a wood figure. Winter's
  light. At first pickle 0.6 and lighter squares (0.85 0.83 0.8): under winter's light
  they read as white plastic and grey fabric, not wood.
- **Winter 2, Nordic carved** (`winter_carved`): the same field in a smoked oak frame
  (0.2 0.2 0.22) carved with the folk band (`looks::NORDIC`: motif 1, depth 0.015,
  scale 6), the cut pale wood (0.86 0.86 0.84): diamonds, zigzags, a meander, a tree of
  life mid-side, the corners' sun wheels reading as snowflakes.
- **Winter 3, stained birch** (`winter_stained`): pale birch (0.84 0.81 0.74) and birch
  stained slate blue-grey (0.4 0.44 0.5), winter's stone colors in wood, in a deep
  blue-grey stained frame; satin (`looks::COOL`). Reads most plainly as wood, the blue
  perhaps too much like a stain.

Shots (headless, the session's scratchpad `looks/new/`): `cmp-autumn.png` and
`cmp-winter.png` (the current board beside the pick), `takes-autumn.png` and
`takes-winter.png` (all takes), `low-sheet.png` and `lowcrops.png` (`--pitch 22 --yaw
18`, 2× crops of the far and right frames): the far frames blur smoothly into the mips,
no speckle or moiré, the carved bands included. The defaults are unchanged: the same
pixels as before for autumn, winter (marbles 0 and 1 too), spring and summer 4.

Bake on the Mac (M1 Pro, warm, `--bench 50 --size 1920x1200`, the plan and the frame
map with their mips, waited for, three runs, each within 1 ms): autumn's wood 23 ms,
autumn 1 33, autumn 2 47, autumn 3 41; winter's slate 31, winter 1 23, winter 2 27,
winter 3 22. A frame costs the same as any look's (2.3 ms waited): the same textures.

Open: the user's pick of each, then the chosen take's tuning in the panel (P; the
panel's marble tunes winter's, not autumn 1's own); the takes' bake on the A33 (step 4).

## Acceptance criteria

- [ ] Autumn's stone and winter's wood made; shots of all eight boards; the user's pick
- [ ] Summer's stone finished
- [ ] The choice in settings (per 02's take) and the player's file; Auto as today's looks
- [ ] Bake time of the new looks on the A33
