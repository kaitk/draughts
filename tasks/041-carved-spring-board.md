# 041: A carved spring board

Status: in-progress

Another spring look for the 3D board (the user, 2026-11-09, after the first spring take of
pale birch with sage squares): something like ivory or pale jade in spring's greens, with
carving, perhaps in the spirit of a Southeast Asian temple, or, the user's later thought
and maybe the better one, elven: flowing Art Nouveau-like leaf and vine work in pale stone
overgrown with moss, as in fantasy ruins (Tolkien's elves, the ruins in The Witcher 2).
Our own motifs in that spirit, nothing copied from either. A thought to explore, not a
settled look; try both directions.

- Prototype it in `poc/3d` as a look in `src/render3d/looks` beside the birch, switchable,
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

## Acceptance criteria

- [x] The carved look selectable beside the birch in the prototype and the game
      (`--spring N`, G)
- [ ] Side-by-side shots for the user to choose, with the bake's cost on the Pixel (the
      Mac's measured; the Pixel's to do)
- [ ] The temple take (lotus and leaf scrolls), if the elven one doesn't settle it
- [ ] The user's look at the elven take on the Mac, tuned with the panel
