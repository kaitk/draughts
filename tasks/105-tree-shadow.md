# 105: A real tree's shadow through the window

Status: in-progress (on the branch `room-light` after task 104, 2026-11-20: the tree, its bake, the takes, and the tuner built; the look to be judged by the user)

Task 104's leaves are value noise: clumps, and single leaves within them. They read well
from afar, but up close the noise falls apart: real leaf shadow has branches as lines
that fork and thin, leaves clustered at the twigs' ends, open sky between the crowns, and
round sun flecks. The user found the first, clumps-only take more convincing at times
than the single leaves (2026-11-20). Model a tree and bake its shadow instead, as the
window's bars are modelled (the "rich" take in task 104's plan).

## The trees (references, local in `design/manor/`)

The trees outside the windows in the concept frames are the ones to cast (the user,
2026-11-20):

- `library-menu-01.png`: the park's old broadleaves close outside the library's window,
  a thick dark trunk rising through the right pane, limbs reaching across, a loose crown
  of yellow leaves with sky between the clusters, the low sun flaring through them.
- `library-autumn-01.png` and `-02.png`: the same seen from inside, orange palmate leaves
  (maples) right by the panes, a trunk and branches in the lower panes.
- `garden-facade-01.png`: the park from outside, old trees within metres of the windows,
  a broad oak with heavy crooked limbs at the left, slimmer trunks with thin hanging
  twigs and sparse yellow crowns (limes and birches) before the house.

So: a trunk and a few heavy limbs near the window (sharp in the shadow), a crown of
clustered broad leaves with open sky between (the flecks), and thin hanging twigs at the
crown's edge. A maple or a lime for the library; the oak's crooked limbs for winter's bare
take.

## What the light does

- Every gap between leaves is a pinhole: it projects an image of the sun's disc, so the
  flecks under a tree are round and grow with the distance whatever the gap's shape
  (Minnaert, *The Nature of Light and Colour in the Open Air*). The blur's width is the
  distance from the leaf to the surface times the sun's 0.53°, about 1 cm a metre: near
  twigs sharp, far crowns soft, as percentage-closer soft shadows widen the penumbra with
  the occluder's distance (Fernando, 2005).
- Games project foliage through the key light as a cookie (Unity) or a light function
  (Unreal), after the stage's branch gobo; ours is drawn by the app, not painted.

## Plan

1. **The tree**, generated at setup from a seed, plain data in `src/model3d/`: a trunk and
   limbs branching recursively with taper and droop (Weber and Penn, *Creation and
   Rendering of Realistic Trees*, 1995), or a crown grown toward a cloud of points
   (Runions, Lane and Prusinkiewicz, *Modeling Trees with a Space Colonization
   Algorithm*, 2007); leaves as small ellipses clustered at the twigs' ends, turned
   along them. Per season: autumn's thinning leaves, winter's bare branches (the sunny
   hall, task 104's `HALL_SUN`), spring's young sparse ones, summer's full crown.
2. **The bake**: the tree drawn, as seen from the sun, into a map of how much light passes
   (one channel, 512 or 1024 square with mips, under 1.5 MB), once when the room is put
   on. In two or three layers by depth (trunk and limbs, outer twigs, near leaves), each
   a channel, so the wind can move them apart.
3. **The sampling** in `window_light`, in place of the noise: where the ray from the
   point meets the tree's plane, the map at a mip as wide as the distance's blur, with a
   few taps in a disc for round flecks. The layers swayed apart by the wind (task 104's
   `Room.wind`), giving parallax and a believable sway without baking again.
4. **The tuner**: the tree's seed, size, density, leaf size, distance and blur on
   `tools/light_tune`'s sliders; the noise kept as the cheap take to compare.
5. Side by side with `library-table-01` and `library-autumn-02` and the noise takes.

## Tiers

The high mode's (task 104's tiers table): one to five texture taps a lit pixel in place
of five noise taps, about the same cost or less; the bake once at setup; the map's memory.
The sway, if kept, draws every frame and is the home screen's.

## Done so far (2026-11-20)

- **The tree** (`src/model3d/trees.goose`, tested in `test/model3d/trees.goose`): grown
  from a seed at setup, Weber and Penn's way: a trunk, limbs, branches, twigs and fine
  twigs (five levels), each a few segments bent at random (crooked), turned up at the
  young end and down where the twigs hang, tapering; leaves as ellipses along the outer
  part of the twigs on short stalks. Every branch takes its dice from its parent's, the
  leaves dice of their own, so pruning or leafiness never changes another branch. Only
  what falls on the map is kept (a branch whose offspring can't reach it is not grown),
  and nothing nearer the house than 6 units. A root struct with capped counts (8000
  segments, 40000 leaves), filled only when the room is put on.
- **The map**: the tree projected along the key onto the wall's plane through the
  trunk, 512 texels square, RGBA8: R, G, B the twigs and leaves in thirds by depth
  (nearer the house to farther), A the trunk and limbs; each layer rasterised with
  antialiased coverage (a leaf lets `foliage.z` of the sun through) and then blurred by
  the sun's disc at the layer's mean distance (an ellipse, longer by 1 / cos where the
  key meets the wall slanted; row running sums), so the gaps become round flecks and the
  near layer stays sharper than the far. Its square is the opening as the key carries
  it out, cut to what reaches the table (`rooms::TABLE_REACH`), about 27 units across in
  the library, so a texel is about 0.05 units. Mips made on the CPU; uploaded level by
  level (`gpu_sampled`, `gpu_upload` in both renderers). Baked in `render3d::draw` when
  `put_room` finds its inputs changed (`tree_key`), never in the steady frame loop.
- **The sampling** (`shaders::LIGHT_FN`'s `tree_light`): the point carried along the
  key onto the map (the same projection as the bake), four `textureLod` taps, one a
  layer, each swayed by the wind on its own (the limbs `wind.x`, the leaves `wind.z`
  times more, farther more, plus a flutter), at a mip for the blur a point farther from
  the window than the board's middle adds. The tree's map is bound after each shader's
  own textures (`LIT_HEAD`, `TABLE_HEAD` before `LIGHT_FN`), slot 7 on the board and 5
  on the table. `Room.tree.x` 0 keeps the noise, the cheap take.
- **The takes**: the library a dense crown in autumn leaf (seed 4); winter's sunny hall a
  bare crooked oak (its branches long thin streaks at the 8° sun); spring sparse small
  leaves; summer's evening a full crown. The tree is scaled down from life (a 70-unit
  trunk, leaves 0.3 to 0.4 units) and its blur is 0.3 of the sun's disc
  (`Room.tree_blur`): at true size and blur the leaves at 2 to 3 m merge into blobs a
  square wide, coarser than the concept's flecks.
- **The tuner**: T switches tree and noise; seed, trunk height, leafy, trunk along and
  foot, crooked, twigs hang, leaf length, width and light, trunk away, tree blur, leaves'
  sway; the bake's time shown; P prints the new fields. Flags `--leaves tree|noise`,
  `--seed`, `--tree`, `--crown`, `--foliage`, `--trees`, `--wind X,Y,Z,W`, `--tree-blur`,
  `--wind-time` for headless shots.

Measured on the Mac (M1 Pro, built at -O2): growing 0.2 to 2.6 ms, the map 22 to 55 ms
(the bare oak fastest, the summer crown slowest); with the upload about 25 to 75 ms in the
tuner. Memory: the map 1.33 MB on the GPU (1 398 100 bytes with its mips); while baking,
about 4.5 MB on the data stack (the tree up to about 1.2 MB, a float plane 1 MB, the
blur's running sums about 1.1 MB, the map 1.4 MB), given back after. A lit pixel: four
bilinear-mip taps of one small texture and some 30 ALU operations (six sines, a log2), in
place of five value-noise taps (twenty hashes) and their sines; not timed on a GPU yet.

Still off (2026-11-20): the shade is coarser than the concept's on the board, where a
board sees only a few clusters; the crown's composition depends much on the seed and the
trunk's place; the table's dark wood shows the pattern weakly; spring's pattern is faint;
leaves are ellipses (maple lobes lost in the blur anyway); the twigs of the bare oak are
short and straight.

- Both together (2026-11-20, the user agreeing): `Room.tree.x` 2 takes the tree's limbs
  and its leaves' shade, blurred `crown_blur` mips more, as the crown's shape, and fills it
  with the noise's dapple as far as `crown_fill` says. The limbs' long shadows and the
  concept's even dapple together. A bare tree's crown has no leaves, so winter shows only
  its branches (the user: in winter thinner bare branches in place of the leaves).
  T in the tuner cycles noise, tree, both; `--leaves both`.

- Species (2026-11-20, the user: the species matters for the leaves, a maple's and an
  oak's differ above all in size): `trees::Species` holds what was fixed per level (the
  segments, children, angles, crookedness, rise, hang, leaves) with whether the children
  come in opposite pairs and the leaves' size and width. A broadleaf (the first take), a
  Norway maple (opposite pairs, a dense rounded crown, big broad leaves), a small-leaved
  lime (many small rounded leaves, hanging twigs), and an oak (zig-zag limbs, wide
  angles, many short crooked twigs thin at the tips, a fine net when bare, slim leaves
  clustered at the ends). `Room.species`: the library a maple, the sunny winter hall the
  oak, spring and summer a lime. The tuner's Kind.

## Acceptance criteria

- [ ] A generated tree whose shadow reads as branches and leaves, not noise, on the board
      and the table, next to the concept frames (built; for the user to judge)
- [x] Round sun flecks that soften with the distance, near twigs sharp
- [x] A take per season, winter's bare
- [x] The sway by layers in the tuner
- [x] Its bake time and memory recorded on the Mac; its tier noted in task 104
