# 041: A carved spring board

Status: in-progress

Another spring look for the 3D board (the user, 2026-11-09, after the first spring take of
pale birch with sage squares): something like ivory or pale jade in spring's greens, with
carving, perhaps in the spirit of a Southeast Asian temple, or, the user's later thought
and maybe the better one, elven: flowing Art Nouveau-like leaf and vine work in pale stone
overgrown with moss, as in fantasy ruins (Tolkien's elves, the ruins in The Witcher 2).
Our own motifs in that spirit, nothing copied from either. A thought to explore, not a
settled look; try both directions.

- Prototype it in `poc/3d` as a look in `src/model3d/looks` beside the birch, switchable,
  and judge both side by side.
- Carving as relief the bake can make: a border band of repeating motifs (lotus, leaf
  scrolls) on the frame (lotus and leaf scrolls for the temple take, interlaced vines and slender leaves
for the elven one), maybe a fine engraved line round the field; real depth only
  where it reads at the board's size on a phone (normal and height in the bake, the
  frame's profile for the larger forms), filtered so it doesn't shimmer.
- Materials: a warm ivory or bone for the light squares and the frame, a soft jade or
  celadon green for the dark squares, polished, with a faint figure; pieces to match.
- Image references from the user's image generator, as for the other themes
  (`agents/design.md`): ask for prompts when starting.
- Cost on the Pixel against the birch: bake time and memory.

## The elven take (2026-11-09)

The elven direction first, built: spring's look 1 (`looks::elven`), switched with
`--spring N` and G in the prototype and `--spring N` in the app (0 the birch, the
default). No reference images yet (none in `~/Downloads` when checked); our own motifs.

- **Frame:** ivory-white stone, roughness 0.32 (a soft polish), its faint clouding the
  stone figure's. On its top and its outer face a carved band 0.28 wide: two vines
  swaying ±0.078 round the band's middle, crossing over and under in turn, a slender
  bent leaf from each vine into each eye between crossings (the two turned half round
  each other, so the eye swirls), a pair of leaves reaching out at each crossing,
  leaning one way and then the other. At each corner a leaf knot on the diagonal: a boss
  over the vines' last crossing, a ring they pass under, four leaves out from it. A faint
  moss green in the cut ground, patchy, most at the motifs' feet.
- **Field:** ivory stone light squares (0.9 0.87 0.79), polished jade dark ones (0.42
  0.52 0.44, roughness 0.2) with a cloudy figure, a deeper jade inlay with a fine engraved
  line down its middle. **Pieces:** ivory (0.93 0.9 0.82) and deep jade (0.2 0.3 0.25).
- **Tuning panel** (P): depth (0.018 world units), scale (7 eyes a side, made odd), moss
  (0.6), stone warmth (0) and jade depth (0.5, the jade colors to the power 0.5 + it),
  `looks::Carving`, printed by Print as a literal for `looks::ELVEN`.

How it is made (`shaders::BAKE_FRAG`'s `carving`, `vines`, `leaf`): a height field in
the frame map's bake, signed distances in world units. The vines are offset curves
y = ±A cos(kx) (distance by the curve's slope), the leaves vesicas (two circles'
intersection) bent by an offset growing with the square of the length along them, the
knot rings and discs. Each motif is domed from its distance (a rounded profile over
most of its half width), the band's ground cut `depth` in round them; the under vine
dips and leaves a gap beside the over one at each crossing. The height goes into the
normal by the bake's finite difference, the hollow into the cavity (the occlusion), the
albedo (a little darker, mossier) and the roughness. Every edge at least a texel soft,
so the mips average it and the frame's existing Toksvig term (the normal map's alpha)
widens the roughness where it blurs; LIT_FRAG's specular antialiasing does the rest. No
new geometry: the profile stays.

The mapping (`looks::Theme.build.w` 1): the frame is mitred, each side its own band of
the map. For the carved frame, across is the length along the profile (`v_uv.y`), so a
band keeps its place over the rounded edge and round the rounded corners, where the
vines follow an arc at the band's middle radius. Two sides meet on each corner's
diagonal, one at +along and the other at -along in its own band, so the band's along
is laid out by |along| near the corners, the period set so a crossing falls on the
diagonal, and the symmetric knot hides the mirror's seam. LIT_FRAG's tangent frame
turned the relief's across the wrong way on the -z and +x sides (raised vines lit as if
cut in, found in shots against the key light); the carved frame flips it there, the
wood is left as it was.

The bands' measures were chosen for a phone, where the frame is 40 to 80 px: vines 0.034
across (about 4 px at a phone's 120 px a square), leaves 0.25 by 0.08, eyes about 1.2
long. Finer detail (veins on the leaves, tendrils) was left out.

Shots (`--shot`, headless, in the session's scratchpad `shots/spring/`): the default
view, a 2× crop of the near-left corner and the near side, a 2× crop of the right side,
and a low view (`--pitch 22 --yaw 18`), each beside the birch. The far frame at the low
view blurs smoothly into the mips with no speckle or moiré.

Cost on the Mac (M1 Pro, warm, `--bench 200 --size 1920x1200`, alternated three times
each): spring's bake (the plan and the frame map, their mips, waited for) 26.3 to 27.1 ms
for the birch, 28.6 to 29.4 ms for the carved stone; a frame 5.5 to 8.4 ms for either,
the same within the noise (the textures are the same). Memory: the same targets.

## Three carved looks from the user's images (2026-11-09)

The user's images (local, `~/Downloads`, `agents/design.md`): `Mossy Elven Checkers in
Birchwood.png`, `Baltic Folk Carved Checkers Board.png`, `Amber-Carved Stone Checkers in
the Forest.png`. The pieces keep our shape in every look, only recoloured; no signs or
amber dots in their recess.

- **Spring 1, elven, toned down to the mossy image.** The deep cut band is gone: two
  thin vines (0.032 across) and sage-tinted leaves (`Theme.fill`) stand at the stone's
  surface with only a shallow outline cut round them (0.011 wide, 0.015 deep), the
  stone beyond left whole, so they read as low relief as in the image; a little grime
  and occlusion at their feet. More moss: in the outline and near the motifs in
  patches, and along the frame's edges (its inner lip, the rounded edge, the foot of
  its face). The stone soft and slightly weathered (roughness 0.45, more clouding and
  faint veins), the jade olive and cloudy (a finer mottling with pale veins,
  `Theme.dark_ring` on stone), the corner knot kept (it reads). Colors measured from
  the image at the same framing: light squares 234 215 183 against its 233 213 187,
  jade 110 124 61 against 100 114 63; the dark pieces lighter, olive.
- **Spring 2, Baltic folk** (`looks::baltic`, `--spring 2`): a dark oiled oak frame
  (wood 2, `OILED_OAK`), mitred, its top carved with a band between two lines:
  diamonds with a cross in each, and between them by turns a zigzag with small crosses
  in its bays and a running meander; a sun wheel (a ring, eight widening spokes) on each
  corner's diagonal, a tree of life in the middle of the far and near sides, upright to
  the player on either. Straight-line SDFs (segments, |x| + |y| for the diamonds, wedges
  for the spokes), each a rounded groove 0.027 wide and 0.012 deep, the cut showing a
  lighter wood with the grain kept. Pale birch light squares (242 195 129 against 242 197
  136) and green-stained dark ones (91 88 38 against 83 78 19), dark oak and pale birch
  pieces.
- **Summer 4 and 5, amber stone** (`looks::summer_amber`, `summer_serpentine`,
  `--summer 4|5`): a grey-green granite frame, mitred blocks, speckled (dark and pale
  grains a texel or two across, `Theme.stone.w`), coarse (its mottling raised), with
  small lichen rosettes (more on the outer face) and moss along its edges; its top cut
  with sun signs (a disc, eight rays and eight short ones) and runic marks by turns (our
  own: an arrow, a diamond on a stave, two chevrons, a crossed stave), a tree of life
  mid-side on the far and near sides, a sun on each corner. The cuts filled with amber
  to 0.55 of their depth: no emissive pass, the bake gives it a warm albedo, darker where
  thin over the cut's walls and brighter where deep (the light it scatters back),
  roughness 0.08, little occlusion, its surface level so it catches the light. 4 keeps
  summer's warmth: honed warm sandstone and deep reddish stone squares, limestone and
  reddish pieces; 5 is as the image: pale limestone (225 202 171 against 221 197 160)
  and mottled deep green serpentine (72 74 36 against 70 74 47), a less warm key.

How: one carving with the motif a parameter (`looks::Carving.motif`, `BAKE_FRAG`'s
`carving`): 0 the vines in relief (`vines`), 1 the folk band (`folk`), 2 the signs
(`signs`), all on the elven machinery: the mitred map's bands with across along the
profile, the |along| layout that puts a symmetric knot or medallion on each corner's
diagonal over the mirror's seam, the height into the normal by the bake's finite
difference, the cut into the cavity, every edge a texel soft for the mips and the
frame's Toksvig term. The cut motifs are laid out by |along| over the whole side,
mirrored about its middle, n steps from the middle to the corner's medallion. Each
carved look has its own look id (`SPRING_ELVEN`, `SPRING_BALTIC`, `SUMMER_AMBER`,
`SUMMER_SERPENTINE`), spring's chosen through `Gpu.spring` and `looks::shown`, and its
own carving (`looks::carving_for`, taken when its look comes on; the panel's tuning
stays while it shows). The panel adds the motif, amber and lichen to depth, scale,
moss, warmth and dark (the dark squares' depth), V printing them as a `looks::Carving`.
The mitred bands' split moved into the gap between them (`(q.x - 0.13) / 1.4`): the
foot of each piece's face (past 1.2 along the profile) had taken the next band's seed,
a strip 0.056 high at the bottom of every mitred frame's face.

Shots (headless, the session's scratchpad `shots/carved/`): `cmp_elven_g.png`,
`cmp_baltic_g.png`, `cmp_serp_g.png` (each beside its image at 1448 × 1086),
`amber_g.png`; `crops_*_g.png` (2× the near-left corner and the near side's middle,
beside the image's); `low_sheet_g.png` and `lowcrop*_g.png` (`--pitch 22 --yaw 18`,
1920 × 1200): the far and right frames blur smoothly, no speckle or shimmer.

Bake on the Mac (M1 Pro, warm, the plan and the frame map with their mips, waited for,
the prototype's `--bench`): the birch 24 ms, elven 53 (29 before: the jade's mottling
and the edge moss), Baltic 35, summer 0 25, amber 4 and 5 54. Not measured on the Pixel
7a: it wasn't connected (the tablet was). A frame costs the same (the same textures).

Open: the amber reads as an inlay more than a deep cut beside the image; the image's
frames are wider than ours, so its motifs are larger against the squares; the folk
band's meander is a plain step line, not a key.

The user's values (2026-11-09): Baltic (look 10) is now spring's default, `--spring 2`,
with motif 2 (the amber signs, scale 3, amber 0.655, jade 0.62) on wood 3; the elven stone
(`--spring 1`) scale 23.685 with warmth 0.52, jade 0.64; summer's amber (`--summer 4`)
scale 3, lichen 0.085. `--spring 0` stays the birch. Details in task 015. Later the same
day, seen on the tablet, the elven stone became spring's default instead, the Baltic oak
`--spring 2`.

Left open by task 015: spring's and summer's looks were judged headless only, against
the prototype's 3D boards, not beside the user's reference images or on the tablet.

## Acceptance criteria

- [x] The carved look selectable beside the birch in the prototype and the game
      (`--spring N`, G)
- [ ] Side-by-side shots for the user to choose, with the bake's cost on the Pixel (the
      Mac's measured; the Pixel's to do)
- [ ] The temple take (lotus and leaf scrolls), if the elven one doesn't settle it
- [ ] The user's look at the elven take on the Mac, tuned with the panel
- [x] Spring 1 toned down to the mossy image; spring 2 Baltic folk oak; summer 4 and 5
      amber stone, the motif a parameter of one carving, in the panel
- [ ] The carved looks' bake on the Pixel 7a, and the user's pick
