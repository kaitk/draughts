# 039: Procedural wood for the 3D board

Status: in-progress

The 3D prototype's wood (task 015) was noise drawn out along the grain: next to the 3D
reference (`ChatGPT Image Nov 7, 2026, 08_19_31 PM.png`) and its swatch sheet (`Four-Way
Wood and Cream Texture Swatch.png`, both local, `agents/design.md`) it read as soft wavy
streaks, where the reference has crisp fine grain, tree-like growth lines and small pores
(the user, 2026-11-09). This task compares wood models baked once into the same 2048²
maps, at startup and on a theme change, and picks one. The design rules still hold: no
regular stripes or sines that band from afar, calm grain on the squares.

## Research (2026-11-09)

What makes wood read as wood, and what of it is cheap to bake on a mobile GPU:

- **Growth rings are the distance from the pith**, cut by the plane the board was sawn
  on: a quarter-sawn face passes near the pith, so the rings show as nearly straight
  parallel lines; a flat-sawn face lies above it, and where the pith axis leans out of
  the face the rings show as arches (cathedrals). Perturb the axis and the radius with
  low-frequency noise. The classic solid texture (Peachey and Perlin, 1985); Blender's
  Wave texture in Rings mode with distortion is the same idea, and its users note that
  rings round a point rather than an axis, and too clean a profile, don't read as wood
  ([Blender manual](https://docs.blender.org/manual/en/2.82/render/shader_nodes/textures/wave.html),
  [Blender Artists thread](https://blenderartists.org/t/wood-texture-physically-correct-using-wave-texture/1168334)).
- **Liu, Dong, Hašan and Marschner, "Simulating the structure and texture of solid
  wood"** (SIGGRAPH Asia 2016; preprint "Procedural wood textures",
  [arXiv 1511.04224](https://arxiv.org/abs/1511.04224),
  [project](https://research.cs.cornell.edu/wood)), what was taken:
  - A time volume, t = r / the mean ring width + a triangle wave + 1D noise of t (uneven
    years), and the rings a smoothed rectangular wave of t: an asymmetric profile, the
    early wood light, the late wood darker, a sharp edge between one year's late wood
    and the next year's early wood.
  - Pores as sparse elongated kernels aligned with the fibres, their size modulated by
    the ring (ring-porous woods have big pores in the early wood only, diffuse-porous
    woods even ones; walnut and cherry are semi-ring-porous or diffuse, maple diffuse
    with tiny pores). The pore mask, negated, is the bump; stained pores are darker.
  - Color by Beer's law, c = exp(−σ(l0 + lg·g + lp·p)): darker wood is also more
    saturated, as stained wood is. With σ from the base color this is base^(1 + a).
  - Rays: ribbons running out radially, dark flecks on a flat-sawn face, bright on
    quarter-sawn ones.
  - Fibre direction from the distortion's Jacobian, for the anisotropic highlight.
- **Larsson, Ijiri, Yoshida, Huber, Fredriksson, Broman and Igarashi, "Procedural
  texturing of solid wood with knots"** (ACM ToG 41(4), SIGGRAPH 2022,
  [dblp](https://dblp.uni-trier.de/rec/journals/tog/LarssonIYHFBI22.html), simplified on
  Shadertoy as `fsyyzt`): the rings as isosurfaces of a growth-time field from the pith
  with knots' own fields merged in. Knots don't belong on a fine board's veneer, so only
  the pith-distance idea was taken.
- **Marschner, Westin, Arbree and Moon, "Measuring and modeling the appearance of
  finished wood"** (SIGGRAPH 2005,
  [PDF](https://www.graphics.cornell.edu/pubs/2005/MWAM05.pdf)): finished wood's sheen
  is a subsurface highlight from the fibres, which moves as the board turns
  (chatoyancy). Not taken yet: it needs a fibre direction per texel and a second lobe in
  the lit shader.
- Shader write-ups found by search (a Three.js wood material, the Rusteria example): rings
  from a sharpened wave, fibres and pores from stretched noise at other scales, pores
  rougher than the rings. Not looked into: Substance's wood generators (closed) and how
  Filament's or Spartan's samples get their wood; the papers above took the time.

## Candidates

All four are variants of the one bake (`shaders::BAKE_FRAG`, `mode.y`), chosen with
`--wood N` or cycled with W, which rebakes the plan and the frame map and nothing else;
nothing is allocated per frame. Each square is its own piece (its own log and cut), each
mitred side of the frame its own band of the frame map and its own piece, each side of
the inlay its own. Per surface the theme gives a ring width, how flat-sawn it is, the
late wood's darkening and the pores' density (`theme::Theme`'s `*_ring`). Stone is
unchanged in every variant.

- **0, noise** (before): noise drawn out along the grain, with the fourth pass's furrows
  and open pores on the frame.
- **1, growth rings** (a): the distance from a pith axis per piece, the axis wandering
  and leaning out of the face, the radius wobbled at three scales, uneven years, an
  asymmetric profile with a sharp late-wood edge (at least 1.5 texels soft), each year's
  late wood its own strength; fine fibre streaks along the grain, which cross the ring
  lines at a slant where the axis leans; color by Beer's law.
- **2, growth rings with pores and a fibre relief** (b): (a), plus vessels as short
  tapering dashes along the grain, scattered in columns whose rows are shifted at random
  (more and bigger in the early wood), sparse ray flecks across the grain, and the fibres
  in the height; the pores darker, rougher and deeper, with a cavity term; the edges
  a texel soft, so the mips average them instead of aliasing, and the frame's existing
  Toksvig term (the normal map's alpha) widens the roughness where they blur.
- **3, noise with lines and pores laid over** (c, the earlier idea): (0) plus thin
  straight dark lines, a texel or two across, broken into lengths, and scattered pores.

## Comparison

Autumn, maple and walnut squares in a mitred cherry frame. Patches measured at the
reference's framing (`--size 1448x1086`), the same rectangles in the reference and in
each shot: the frame's front top (300 × 28 at 500, 905), the right side's top (18 × 100 at
1302, 455), a light square and a dark square (90 × 70 at 750, 445 and 615, 445). Mean
sRGB; grey std (contrast); fine, the grey's std after a 1.5 px blur is taken off (crisp
detail); spacing, 2π × std / the rms gradient across the grain after the light's slow
gradient is taken off (an effective line spacing, in pixels).

| Patch | Measure | Reference | 0 noise | 1 rings | 2 rings + pores | 3 noise + lines |
| --- | --- | --- | --- | --- | --- | --- |
| Frame front | mean | 171 87 32 | 157 78 30 | 169 86 41 | 162 78 31 | 146 71 23 |
| | std / fine | 12.6 / 7.4 | 14.7 / 8.8 | 9.1 / 6.4 | 12.3 / 9.2 | 14.5 / 9.8 |
| | spacing | 6.4 px | 5.8 | 5.3 | 5.1 | 5.2 |
| Frame right | mean | 133 71 31 | 163 80 29 | 172 87 34 | 167 81 30 | 150 72 24 |
| | std / fine | 13.3 / 7.1 | 7.5 / 3.5 | 9.6 / 7.0 | 10.0 / 7.7 | 9.3 / 5.6 |
| | spacing | 6.1 px | 7.8 | 5.2 | 5.1 | 6.3 |
| Light square | mean | 250 188 118 | 246 186 122 | 246 183 117 | 246 183 117 | 243 183 118 |
| | std / fine | 4.0 / 3.1 | 2.6 / 0.8 | 3.3 / 2.2 | 3.4 / 2.3 | 4.2 / 2.3 |
| | spacing | 5.1 px | 8.4 | 5.1 | 5.0 | 6.0 |
| Dark square | mean | 123 68 35 | 123 73 45 | 124 75 47 | 123 75 47 | 120 73 46 |
| | std / fine | 9.4 / 7.1 | 4.2 / 2.1 | 9.5 / 5.7 | 10.8 / 7.5 | 6.7 / 5.3 |
| | spacing | 5.1 px | 5.4 | 5.1 | 4.8 | 4.3 |
| Cost | bake, warm | | 32–35 ms | 33–34 ms | 37–38 ms | 43–46 ms |
| | frame | | 9.25–9.39 ms | 9.31–9.41 ms | 9.37–9.42 ms | 9.32–9.38 ms |

The swatch sheet's quadrants agree with the reference: maple 246 182 108 (std 5.1),
walnut 107 58 26 (10.2), cherry 168 85 28 (12.8). The reference's right side is darker
than every variant because its light falls differently there, not the wood.

Look, at the default view and in 300% crops:

- **0** reads as soft streaks and blotches: the furrows give the frame's front contrast,
  but as blurred lengths, not lines; the squares have almost no fine detail (fine 0.8 and
  2.1 against 3.1 and 7.1).
- **1** reads as wood at once: long coherent growth lines that wander, merge and vary in
  strength, the walnut's wavy and the maple's calm and straight, close to the swatch.
  Alone it is too clean, a little like printed veneer: the frame's front has less
  contrast than the reference (9.1 against 12.6).
- **2** is the closest: the rings' lines with the reference's fine stipple of pores and
  flecks on the frame, the walnut's mottled fine grain, every measure within a few units
  of the reference's except the frame front's fine detail, a little crisper (9.2 against
  7.4), and its mean a little darker (within 10).
- **3** keeps 0's blotches under the new lines, and its frame is darker and redder
  (146 71 23); the lines look laid on rather than grown.
- A far, low view (`--pitch 20 --yaw 10`, 1920 × 1200): no banding or moiré on the far
  frame or the far squares in any variant; the pores average out in the mips.

How: `--shot` headless at `--size 1448x1086` for the measures and crops, a numpy script
over the patches (kept in the session's scratchpad, not in the repo). The bake's time is
`bake_surfaces`' print (the two bakes, their mips and a wait), a run's first bake after a
build excluded (about 1 s: the pipeline compiling); it happens at startup, on a theme
change and on W. Frame: `--bench 200 --size 1920x1200`, the four variants alternated over
three rounds, the median of each run's cpu + gpu waited; the very first run's 12.7 ms
dropped as an outlier. The Mac's GPU ran slower than in task 015's passes (about 9.4 ms
against 5 ms on the same measure), but evenly for all four: the wood costs nothing a
frame, as expected of a texture.

## Recommendation

**2, growth rings with pores and a fibre relief**, now the default (`--wood 2`); 0, 1 and
3 stay selectable with `--wood` and W for the user to compare. It costs about 4 ms more
bake than 0 on the Mac (37 against 33 ms) and nothing a frame.

The user (2026-11-09): 2 and 3 both look great. 2 stays the default; 3 is kept as the
alternative, and the choice can be made once they're seen in the game. 2 is the more
realistic wood, the squares especially; 3's look appeals too. Later the material may
become a setting with several woods: pick a first, a second, and maybe a third take
after trying them in the 3D game.

Next, if the frame should come closer still: the reference's front shows more broad
tonal mottling and more pronounced cross-grain flecks; finished wood's moving sheen
(Marschner et al.) would need a fibre-direction map and a second specular lobe.

## The finish: varnish and sanding (2026-11-09)

Per wood model a finish in the look data (`looks::Finish`, baked into the wood only,
never the stone), set from the prototype's tuning panel (task 015): varnish lowers the
roughness (× 0.55 at 1) and fills the pores a little; sanding makes the grain's and the
pores' relief shallower (× 0.3 at 1); grain scales the figure's contrast round the base
color (in Beer's exponent); rings scale the rings' and the grain's spacing; warmth
shifts the color. The user's "the same wood, very slightly more varnish and sanded a
tiny bit more" is `looks::VARNISHED`, varnish 0.2 and sanding 0.15 (the roughness about
10% lower, the relief about 10% shallower), now the default for 2 and 3; 0 and 1 stay
plain. Side by side with `--plain`: the frame's rounded edge takes a slightly brighter
sheen and the pores read a touch softer, the color unchanged. Bake and frame cost as
before.

## Marble for winter's frame (2026-11-09)

The user (2026-11-09): try black wavy marbles for winter's frame, one solid block with
the figure running one way, the board's stone unchanged. `--marble N` and M switch
(0 the slate as before), and the app's `--marble N`; only the frame map is baked again.

How marble is made procedurally, what was taken:

- **Perlin, "An image synthesizer"** (SIGGRAPH 1985): marble as sin(x + turbulence(p)),
  veins where a ramp across the layers, disturbed by turbulence, crosses a level. Taken
  without the sine (which bands): the veins are contours of a ramp plus noise, so they
  run long and one way, wander, merge and part. Contours of noise alone close into
  rings and blobs; the first try looked like a contour map.
- **Quilez, "Domain warping"** ([iquilezles.org](https://iquilezles.org/articles/warp/)):
  f(p + fbm(p + fbm(p))), the flowing, folded look; its strength is the waviness.
- **Worley, "A cellular texture basis function"** (SIGGRAPH 1996): the edges of warped
  cells (F2 − F1) as a network of fine cracks between the main veins, in places.
- Each contour's width is kept even by dividing the distance by the field's slope
  (`fwidth`, the bake being a fragment shader), its strength hashed per contour and
  faded along its length; the cracks' width comes from the cells' coordinate, since
  `fwidth` of the edge distance jumps at the cells' edges and broke them into dashes.
  Fewer octaves (3) in the vein fields: five frayed the contours into squiggles.

The variants (`looks::marble`, all polished, flat, the figure leaning 24° off the
board's x):

- **1, Nero Marquina:** near black, crisp white veins, faint finer ones and cracks.
- **2, dark grey cloudy:** soft wide grey bands with halos, more warped, low contrast.
- **3, blue-black steel:** blue-black with steel-blue veins, the board's palette.
- **4, black with threads** (the one found): bundles of thin wavy white threads flowing
  one way, as in flow-banded black marbles, with Marquina's main veins.

The slate's steel-blue round on the frame edge is left out with a marble. Bake (the
frame map, its mips, waited for, warm, M1 Pro): slate 15.6 ms (its normal from three
samples), marbles 8.5 to 9.3 ms (flat, one sample a texel). A frame, `--bench 200 --size
1920x1200`: 5.3 to 5.6 ms with the slate or a marble, the same. Shots in the session's
scratchpad (`shots/tune/marble_default.png`, `marble_close.png`, `varnish_close.png`).
The user to pick one, or none, on the Mac.

## Summer's variants (2026-11-09)

The user (2026-11-09): summer's board should be clearly apart from autumn's, not another
warm wood; summer is the coast at sunset. Three variants beside the summer look as it
was (0), as looks after the seasons' (`looks::SUMMER_OAK`, `SUMMER_PICKLED`,
`SUMMER_TEAK`), each with its own wood's model and finish (`looks::wood_for`,
`finish_for`): `--summer N` and S in the prototype, `--summer N` in the app.

- **1, wood 3 in summer's palette:** wood 3's crisper lines and pores in peach and dusky
  rose, a rose-brown frame with open pores and furrows, varnished (`VARNISHED`).
- **2, pickled oak:** limewashed oak on wood 2 (rings with vessels): bleached oak light
  squares, rose-washed oak dark ones, a grey-beige driftwood frame, a satin matte
  (`PICKLED`, no varnish). New in the bake, `Finish.pickle` (0..1): the grain's exponent
  turns round (paler where it was darker) and the cavity (pores, grooves) fills with
  matte white, level, a little rougher.
- **3, teak and sand:** an oiled straight-grained teak frame with fine dark caulking
  seams along each mitred piece, a plank (0.17) apart over the top (`Theme.seam`, its
  strength `Finish.caulk`), round pale sand and terracotta squares, satin (`OILED`).

Pieces stay the theme's cream and plum, the plum a touch browner on 1 and 3. Both new
finish terms are in the tuning panel (pickle, caulk; V prints them). Bake (the plan and
the frame map, their mips, waited for, warm, `--bench` in summer): 26 to 35 ms for each
of the four, run to run within the same spread. Shots in the session's scratchpad
(`shots/summer/sheet.png`, `strip.png` beside autumn, `corners.png`, `squares.png`).
The user to pick one on the Mac and tune it.

## Carved variants (2026-11-09)

Summer 4 and 5 are amber stone, a carved granite frame round honed sandstone and red
stone squares (4) or limestone and serpentine (5); spring 2 is Baltic folk oak on wood
2 with an oiled finish (`OILED_OAK`, `wood_for`, `finish_for`). All in task 041. The
stone surfaces gained a finer mottling with pale veins (a stone surface's `*_ring`, unused
by stone before) and the frame granite's speckle (`Theme.stone.w`). The mitred bands'
split moved into the gap between them, so the foot of each mitred piece's face keeps its
own seed (task 041): autumn's and summer's mitred frames change in that strip only.

## Acceptance criteria

- [x] `--wood N` and W switch the wood's model, rebaking only on a switch
- [x] Growth rings (a), with pores and a fibre relief (b), and the earlier overlay idea
      (c) beside the old bake, measured against the reference and the swatch
- [x] The bake's and a frame's cost per variant on the Mac
- [x] The recommended variant the default
- [ ] The user's look at the four on the Mac, and the bake's time on the tablet
- [x] Marbles for winter's frame beside the slate, `--marble N` and M, and the finish
      (varnish, sanding) with the user's preset on 2 and 3
- [ ] The user's pick of the marble and the finish, tuned with the panel
- [x] Summer's three variants beside the summer look, `--summer N` and S, pickle and
      caulk in the panel
- [ ] The user's pick of summer's variant
