# 03: Wood, stone, or carved for the 3D board

Status: in-progress

A choice for the raised board: Wood, Stone, Carved, or Auto, the season's own (the user,
2026-11-13: first wood, stone, or auto; then three for every season, Carved the season's
best carved board whether wood or stone, wood plain wood and stone plain stone). It
replaces task 045, which listed every alternative look. The flat board doesn't change.

| Season | Auto | Wood | Stone | Carved |
| --- | --- | --- | --- | --- |
| Autumn | wood | maple and walnut in cherry (`--autumn 0`) | sandstone and porphyry, a solid speckled frame (`--autumn 3`) | rust vines in weathered stone (`--autumn 2`) |
| Winter | stone | limed ash and smoked oak (`--winter 1`) | slate in marble (`--winter 0`) | the same wood, a Nordic band in smoked oak (`--winter 2`) |
| Spring | carved | the birch (`--spring 0`) | ivory and jade, uncarved, veined and cracked (`--spring 3`) | the elven stone (`--spring 1`) |
| Summer | wood | `--summer 0` | the amber granite, uncarved (`--summer 6`) | amber signs in granite (`--summer 4`) |

The user's picks, 2026-11-13: winter's wood and carved both; autumn's 2 and 3, with no
seams at the frame's corners (stone shows none); spring 0, 1, and 3, the birch the wood
(bare wood is the better wood); Auto kept, today's defaults (winter's stone). The Baltic
oak (`--spring 2`) is liked but has no place yet.

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

## Three for every season (2026-11-13)

- Autumn 2 and 3 lost their corners' seams: autumn 3's frame is one solid block
  (`build.x` 1), autumn 2 keeps the mitred bands its carving needs with no joint drawn
  (`build.y` 0), as the elven frame.
- Spring's and summer's plain stones, `SPRING_STONE` (`--spring 3`) and `SUMMER_STONE`
  (`--summer 6`): their carved looks through `looks::plain` (the frame one solid block,
  no carving), keeping the carved looks' tints (`looks::variant`) and their own frame
  figure rather than winter's marble (`marble_for`).
- Shots: the scratchpad's `looks/new/plainstones.jpg` (carved beside plain) and
  `seamless.jpg` (autumn 2 and 3 with corner crops). `model3d` and `shell` tests pass.

## The plain stone weathered (2026-11-13)

The uncarved stones read bare. Moss and lichen alone (the carving pass's, with a motif 3
that cuts nothing) gave faint moss and lichen as spots; the user asked for the stone made
better as a whole, cracks or veins. Now `BAKE_FRAG`'s `cracks`: a warped cell field's
edges (1.7 cells a world unit), shown only where a broad noise lets them (so they run and
stop), 0.008 to 0.02 wide, a texel and a half soft, cut 0.006 deep; the moss settles in
and beside them (`looks::MOSSY`, moss 0.8, no lichen; summer's `WEATHERED`, moss 0.5,
lichen 0.08). Spring's plain stone has clearer veins (`stone.x` 0.2, the carved one's
0.07), on its ivory squares too. A first take at 3.2 cells and twice the width read as
crazy paving. Shots: the scratchpad's `looks/new/sp3view.jpg` (with a low-angle crop),
`su6m.png`.
