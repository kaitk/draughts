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
- `library-autumn-02.png`: the same seen from inside, orange palmate leaves
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

- What stays when real trees come (the user, 2026-11-20: later the room may get real
  trees, rendered and baked, with simplified billboards to match; this work shouldn't be
  thrown away then). The parts are apart: the generator (`trees::grow`, the species) makes
  segments and leaves; the bake (`trees::draw_map`) turns any segments and leaves into the
  four-layer map, each layer blurred by the sun's disc at its depth; the shader
  (`tree_light`, the noise's dapple in its crown) and the renderers' upload read only the
  map. A tree made elsewhere (modelled, or grown here till it looks as the concepts do and
  kept) feeds the same bake, or a map rendered offline (Blender) in the same layout
  replaces it; the window's light, the sway, and the dapple stay. The generator could
  also write its tree out as a mesh to start a modelled one, or the billboards, from.

- The wind made natural (2026-11-20, the user: the warping bent heavy branches; mild
  wind, leaves ruffling now and then). After Crysis's vegetation (Sousa, GPU Gems 3,
  ch. 16: a main bending of the whole tree, slow and rigid, and a detail bending of the
  leaves, fast, small, each on its own phase), SpeedTree's gusts, and Habel and others'
  physically guided trees (2009: thick limbs slow and barely moving, thin twigs faster
  and more). LIGHT_FN's `wind_at` gives a slow sway and a gust whose front crosses the
  crown; the limbs lean a tenth of the leaves' sway as one piece, never warped; each leaf
  layer shifts whole, more and on its own phase the farther out; in a gust `ruffle_at`
  flickers small patches of leaves fast and tiny. The noise's canopy keeps a soft warp,
  scaled by the gust. `Room.wind`: strength, speed, the leaves against the limbs, ruffle;
  mild by default (0.06).

- Tuning the library on the tree alone (2026-11-20, the user: the noise looks
  unrealistic; trees and their crowns only for now, autumn first, small gusts). What the
  search found (`tools/light_tune --dump-map` writes the map the sun sees; its middle
  35% is what falls on the board):
  - The map covers only about 26 units of the tree (the opening carried out to it, cut to
    the table), the board its middle 9. So where the trunk stands decides everything: at
    first the window looked at the trunk and two limbs, which no leaf setting changed.
  - A tall far tree (400 units, 200 out) blurs by the sun's disc into a few soft blobs
    and limbs, five to ten times less fine detail than a small near one (70 units, 30
    out), the agent's scale model; the concept's flecks want the near one.
  - Leaves strung along the twigs left the crown's shell sparse where the window looks.
    `Species.spray` scatters a twig's leaves in a loose ball about it (a segment's
    length times spray), and the outer branches (level 2) carry leaves too, so the
    shell fills evenly with gaps: the maps now read as foliage.
  - The library's default: the maple, trunk along 15, foot -50, leafy 1.5 (the board's
    part lets through about 40%, the most fine detail of the grid). Winter's oak, bare,
    is a fine net now, not a fishbone; spring's lime is sparse over the board.
  - The tuner regrouped (the user): the scene, the tree, the wind, the sun at the top; the
    window, the noise's leaves, and the light in detail (the room's profile) below.
    `--wall`, `--panes`, `--opening` added.
  - Shell sweeps: run them under bash; zsh doesn't split an unquoted `$args`, and every
    flag silently went as one ignored word (a whole afternoon's sweeps were the default).

- The ruffle warped the leaves into swirls (the user's shot, 2026-11-20): it moved each
  small patch of the map by its own offset, as large as the patch, which smears. Now
  nothing moves the map unevenly: each leaf layer shifts whole, and in a gust the near and
  middle layers blend, patch by patch, with themselves nudged a leaf's width as a whole,
  so patches flip between two places like turning leaves (two more taps in a gust only).
  The noise's single leaves lost their ruffle with it.

- The maple's leaves palmate (the user, 2026-11-20: its distinct shape, as in the
  concepts; the others are good): `Species.lobes`, 5 for the maple, drawn by the leaf's
  radius waving round it, pointed lobes out from the stalk and to the sides, shallow
  sinuses, the two by the stalk smaller, a notch where it joins. Through the sun's blur
  the lobes show as the clusters' edges; larger leaves (Leaf long) keep more of them.

- The literature's wind (2026-11-20, the first follow-up): the sines are gone. After
  Zioma (GPU Gems 3, ch. 6), each layer shifts by two value noises of time, one along the
  wind and one across it, a new random value every few seconds, eased between: irregular
  and never repeating. The limbs follow only the whole tree's slow sway (one noise pair,
  a new value every 4 to 6 s), a tenth as far as the leaves, as one piece. Each leaf layer
  adds its own pair on top (a new value every 2 to 3 s), quicker the farther out (Habel
  and others, 2009: thick limbs slow and barely moving, thin twigs faster and more), so
  the layers never move in step.
  A gust is a quick noise let through only while a slow one is high: about five seconds
  every twenty or so, 17% of the time; it pushes all layers along the wind and stirs the
  leaves' own noise more. Its front still crosses the crown along the wall. The ruffle's
  patch flip is kept as it was. Nothing warps the map: each layer only shifts, whole.
  - The noise runs on the CPU, once a frame (`rooms::wind_at`, tested in
    `test/model3d/wind.goose`): each layer's shift in calm air and what a full gust adds,
    and the gust with its change along the wall, go to the shaders in the frame's block
    (`wind_now`, `tree_shift[4]`, in place of `tree_sway`). A pixel only adds the gust's
    share: about 20 ALU operations and no sines, where the sines took about 45 and seven
    sines (`noise_leaves`' `wind_at` too). The taps are as before: four, six in a gust.
  - Shots in the tuner, the library at a calm (40 s) and a gust (17.5 s), and eight frames
    0.25 s apart across a gust's start, before and after, beside `library-table-01`; and
    each layer's shift over a minute, before and after (`build/notes/wind/`, local). In a
    gust the board shows less contrast, before as now: the ruffle blends the near and
    middle leaves with themselves nudged.

- The two renderers on shadow-map frames (2026-11-20): a reported 5 ms more for ngfx on
  frames that draw the shadow map again, with the window's pattern on, didn't show in any
  measure. `--background table --window on --bench 300`, the waited frame's P50 with the
  shadow map against the pass alone, in ms:

  | Run | gfx | ngfx |
  | --- | --- | --- |
  | headless 1280x800 | 3.38 / 3.60 | 3.24 / 3.31 |
  | headless 2560x1600 | 5.17 / 5.13 | 5.17 / 5.12 |
  | headless 3024x1964, `--no-vsync` | 6.17 / 6.13 | 6.11 / 6.09 |
  | window, 2560x1600 | 6.01 / 5.88 | 5.70 / 5.65 |
  | gfx-only build, headless 2560x1600 | 5.27 / 6.15 | |

  The shadow pass itself costs under 0.1 ms in both; stone, birch, and sunset differ by
  0.1 to 0.5 ms either way. `tools/perf/mac_gpu_time.py` (every frame draws the shadow
  map): gfx 13.84 ms a frame at Maximum, ngfx 14.21 at Medium. The tree's map is baked
  and uploaded only from `theme_end`'s `put_room`, never on a shadow frame, in both.

- The maple's leaves and the library's dapple (2026-11-20, the second follow-up),
  toward `library-table-01`:
  - The maple's leaves come in clusters of three or four on one foot (`Species.cluster`),
    their stalks fanned out and the blades overlapping. Each blade is turned at random
    about its stalk, then leans toward the sun a little (`face`), so most show their
    outline foreshortened and some only a sliver. A leaf is drawn from its two half axes
    as the sun sees them (`Leaf.tip`, `side`), not an angle and a width. The leaves
    nearest the house are up to 60% larger (`near`), and the near layer is blurred half
    as much as the others (`near_blur`), so their lobes show at the flecks' edges. The
    other species keep the old leaves (their test lines are unchanged).
  - The library: seed 11, the trunk's foot at -10, -60, leafy 1.0, leaves 0.4 long
    letting 15% through, `tree_blur` 0.2. The board and the table now lie under foliage
    with many gaps, not half in open sky. The shade is deeper: `pattern.x` 0.9, the key
    7, the window's sky 0.45, the walls 0.22.
  - Measured on 1536x1024 shots against the same shot without the tree (`tools/
    light_tune`), lit and shaded patch means (sRGB, 8 px patches, 95th and 5th
    percentile) on the same surface; the reference's picked by hand:

    | | Before | After | `library-table-01` |
    | --- | --- | --- | --- |
    | Board, light squares | 176 / 96 (0.55) | 176 / 83 (0.47) | about 200 / 115 (0.58) |
    | Board, dark squares | 78 / 24 (0.31) | 76 / 18 (0.24) | about 105 / 30 (0.29) |
    | Table | 19 / 7 (0.37) | 19 / 6 (0.32) | 95 / 33 (0.35) |
    | Board in shade | 31% | 55% | about half |

    The darkest shade was already near the reference's; what was missing was how much of
    the board lies in shade and how many edges it has: the tree's light changes twice as
    often across the board as before (the mean step between 4 px patches 0.041 against
    0.022). The flecks are long streaks, as the low sun (18°) stretches them about three
    times along the light; the reference's are shorter and rounder.
  - The bake: 86 ms in the tuner (with the upload), 67 before, as the window now looks
    into more of the crown (1916 segments and 11 442 leaves against 752 and 6807); a lobe
    is worked out only near a leaf's edge. The map's memory is the same; the tree on the
    data stack up to about 0.4 MB more (a leaf 32 bytes, 24 before). The shader is
    unchanged.
  - Shots (local): `build/notes/leaves/`.
  - Tried and set aside: a map of 1024 texels (the flecks no sharper on the board: their
    softness is the low sun's stretch, not the texels); a blur far below 0.2 (no
    change); a wider spray of leaves round the twigs (gaps about the same).

## Follow-ups

- The literature's wind: done (above), for the user to judge in the tuner. If a wind
  field is ever needed, God of War's *Interactive Wind and Vegetation* (GDC). The
  Witcher 3's wind (SpeedTree's, by all accounts, tuned strong) is unpublished. The
  ruffle still flips patches on a sine each; a noise there too if it shows a rhythm.
  The tuner switches the wind's kind live (2026-11-20, the user disliking the noise): K
  or `--wind-kind sines|noise|still`, the sines restored as `rooms::wind_sines` and a
  uniform branch on `wind_now.w` (shots match the old shader's within its run-to-run
  pixel); the game stays on the noise till the user chooses.

- The maple's leaves read better but could still improve (the user, 2026-11-20): lobes
  that survive the blur (larger leaves near the window, a sharper near layer), leaves
  turned more variedly so not every one shows its full outline, clusters of a few
  leaves overlapping as on a real twig. Done (above), for the user to judge.

## Acceptance criteria

- [ ] A generated tree whose shadow reads as branches and leaves, not noise, on the board
      and the table, next to the concept frames (built; for the user to judge)
- [x] Round sun flecks that soften with the distance, near twigs sharp
- [x] A take per season, winter's bare
- [x] The sway by layers in the tuner
- [x] Its bake time and memory recorded on the Mac; its tier noted in task 104
