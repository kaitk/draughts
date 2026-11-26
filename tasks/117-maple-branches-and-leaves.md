# 117: The maple's branches and leaves

Status: todo

The maple outside the library's windows (`trees::grow_whole`, task 107) reads as a rough
draft: its wood is straight and regular, and its leaves sit on the twigs at random. Grow
it so it reads like the photographed Norway maple: limbs in straight runs joined by sharp
turns where a leader broke and a side shoot took over, stubs, bare inner limbs, fans of
fine twigs that hang down, and leaves only at the shoot tips in level plates.

The path follows the asymmetric fork of Gao and Newberry 2025 (PNAS Nexus pgaf003, code
in github.com/mnewberry/treescale, `grove.js`) for forks and thickness, with the tropism
per segment of Palubicki et al. 2009 in place of its single upward pull. The trunk, the
hero limbs, the envelope, culling and the dice per branch stay. The research, prior art,
CPU previews and the open questions are in `build/notes/tree/branches/index.html` (local).

Photos (local, not in git): `build/notes/tree/photos/bare-maple/PXL_20261124_070810793.MP.jpg`
(broken leader, stub, twig fans), `PXL_20261124_070740245.jpg` (zig-zag limbs),
`PXL_20261124_070822921.jpg` (the whole tree), `ai-branch-canopy.png` (leaves on a
branch), and `build/notes/tree/photos/tartu-maple-1.jpg` (leaf plates from below).

## Acceptance criteria

- [x] The user answers the page's open questions (one leader or codominant stems, how
      crooked, the hanging limb).
- [x] A gravity layer on the grown skeleton: each node bends by the mass it carries
      against a stiffness by r⁴, corrected upward (more in young wood), in place of
      `Habit.sag`; heavier wood sags more, thicker less, upright wood not at all.
- [x] Palubicki's shedding: shaded inner wood dies back, some of it as stubs.
- [ ] A tropism per segment by thickness: thick wood rises, thin wood levels out and
      sags, side shoots lean out of the crown.
- [ ] Broken leaders in wood of 5-35 cm: the thick side ends as a stub, the thin side
      takes over, turned 30-50°; 1-3 elbows a limb.
- [ ] A fork's length scales with the room to the envelope, so tips reach the shell.
- [x] Thin wood deep in the crown dies back, some of it as stubs.
- [x] Leaves only on each tip's current shoot: the tip pair and one pair a quarter turn
      below, stalks longer for leaves pointing down; the blades' tilt drawn from the
      measured Norway maple tilts by season and height (the user's answer of 2026-11-26 in
      place of "level within about 15°"), some flat, some cupped, some sagging.
- [ ] Each step behind a tuner switch, checked first as a CPU silhouette from
      `tools/tree_dump` against the photos, then on the Mac and the tablet.
- [ ] Growth stays under 100 ms on the Mac (now 6.5 ms) and the segment and leaf counts
      within `MAX_WHOLE_SEGMENTS` and `MAX_CARDS`; the times recorded here.
- [ ] The decision recorded in `docs/decisions/` and `docs/architecture/` updated.

## Step one: the branch skeleton (2026-11-26)

Built into `trees::grow_whole` (`tree_whole.goose`, and the passes in
`tree_skeleton.goose`), each part off by default as `trees::Growth`, set by the light
tuner and `tools/tree_dump` alike:

| Part | Tuner switch | `tree_dump` flag | Tried |
|---|---|---|---|
| Broken leaders: in 5-35 cm wood a stub goes on, the side shoot takes over 22 % thinner, turned 30-50°; a hero limb FEWEST..MOST, a branch one at even odds | `--tree-elbows FEWEST,MOST,TURN_LO,TURN_HI` (0,0,30,50) | `--elbows` | 0, 1-2, 3 |
| The gravity layer in place of `Habit.sag` (Stava's bend, a beam's stiffness by r⁴, the correction up 85 % young, 25 % old); twigs turn with their wood | `--tree-gravity S` (0) | `--gravity` | 1, 2, 4 |
| Shedding: a branch whose twigs' sky share (five ways through a grid of the twigs' full-leaf foliage, whatever the season) is under LIGHT dies; STUBS of the branches and branchlets stay as their first segment | `--tree-shed LIGHT,STUBS` (0,0.5) | `--shed` | 0.3, 0.45, 0.6 |

With gravity or shedding on, the tree is grown whole, shed, bent, then culled
(`keep_parts`); the app culls a copy of the whole tree (`cull_copy`) rather than growing it
twice. Off, every dump and the tests are byte-identical to before. One leader, the trunk,
the hero limbs, the envelope, culling and the dice per branch are unchanged; the leaves'
placement, the bark and the tube's junctions too (leaves move rigidly with their twig).

The gravity checks (`test/model3d/tree_skeleton.goose`) give the study's numbers: a level
limb 6 m long, 10 cm, drops 8.8°, 10.1° with side shoots, 4.0° at 20 cm, 5.0° rising 45°,
none upright.

Counts, old-leader, no low limb, whole: off 37,881 segments, 34,528 leaves; elbows 1-2,
gravity 1, shedding 0.45,0.5: 28,824 segments (52 stubs of broken leaders), 30,453 leaves;
culled 20,682 segments, 17,704 leaves. All within `MAX_WHOLE_SEGMENTS` and `MAX_CARDS`.

Times on the Windows PC (tools/tree_dump, -O2), whole tree: off 7.0 ms (the Mac's 6.5);
all three on 14.4 ms: growth 6.5, shedding 5.6, bend 2.0, keep 0.3; culled by
`grow_whole` 16.8 ms, by `cull_copy` about 3 ms more on the whole. The PC grows today's tree
about as fast as the Mac, so on the Mac about 15 ms, far under 100. Cheaper paths per tier:
`SHED_WAYS` 1 (up alone, about a fifth of the shedding's rays), and the bend only for wood
over 1 cm (twigs already turn with their wood).

Pictures (local, `build/notes/tree/branches/build/`): `elbows.jpg` (0, 1-2, 3 elbows a hero
limb beside the photo crops), `gravity.jpg` (off, 1, 2, 4), `shedding.jpg` (off, 0.3, 0.45,
0.6), `app-up-compare.jpg` and `app-compare.jpg` (the light tuner with `--tree-draw`, all
three on against off). `src/sheet.py` makes the sheets from tree_dump's dumps.

Against the photos, what still looks wrong:

- The elbows show on a limb seen from its side but hardly at the whole tree's size; the
  side shoot's turn at random often keeps the limb's way, so few read as the photos' sharp
  zig-zags. The user's count (0, 1-2 or 3) is open; a turn kept in the limb's vertical
  plane, or larger, may read better.
- Gravity 1 levels the limbs and arches them; 2 and 4 add little, as the bend saturates
  at Stava's largest angle. The limbs still leave the trunk too steeply and straight
  compared with the photos' level runs, and no twig fans hang.
- Shedding at 0.45 clears the inner thin wood and leaves stubs on the limbs; at 0.6 the
  crown thins too much. It removes few leaves, as the shaded twigs are already leafless
  inner ones.
- Not yet seen on the Mac or the tablet.

## Step two: the leaves (2026-11-26)

Ported from the leaf study (`build/notes/tree/leaves/`) into `trees::add_plates`,
`trees::leaf_shapes` (`src/model3d/tree_leaves.goose`) and `shaders::TREE_LEAF_VERT`, each
part off by default as `trees::Growth`, set by the light tuner and `tools/tree_dump` alike:

| Part | Tuner switch | `tree_dump` flag |
|---|---|---|
| Plates: a twig's leaves only on its current shoots, the tip's pair and one a quarter turn below, and SPURS short shoots of one pair along its outer part; the lower leaf of a pair larger (up to 1.22) on the longer stalk (up to 1.45), the outer of a side pair's stalk 1.15 (Weisse 1895, softened as the study); blades spread level, nudged apart in plan by NUDGE (the study's mosaic) | `--tree-plates ON,SPURS,NUDGE` (0,2,0) | `--plates` |
| Tilt: each blade's tilt from level drawn from Chianucci et al. 2018's Norway maple counts (summer, 13 September, 11 October), blended by SEASON (0 summer, 1 mid-September, 2 October) and the height in the crown, plus SAG degrees inside and low; 2, October, gives today's look (median 42°, as today's rule's) | `--tree-tilt ON,SEASON,SAG` (0,2,8) | `--tilt` |
| Bend: each blade flat, cupped up or one of four sagging shapes by the study's chances times SHARE, its amount 0.3-1 and twist (TWIST degrees at most) packed into the card's `face.w`; the six shapes bent at startup as triangle lists before the cards in their buffer | `--tree-bend SHARE,TWIST` (0,25) | `--bend` |
| The leaves' mesh: by the tier with the bend on (the high tier, HDR, a 21-vertex fan hugging each atlas leaf's outline, 78 drawn; the standard tier the card in four rows bent along its midrib, 24 drawn), else flat cards; or one for all | `--tree-leaf-mesh tier\|card\|rows\|fan` | |

With plates on and gravity, the blades keep their way while their twig bends
(`bend_by_weight`'s `turn_blades`). A step-one bug is fixed on the way: `add_cards`
shadowed its `first` with a random angle, so every card's segment was one of the trunk's
first: the leaves didn't move with their twig under gravity and weren't shed with it.
Step one's counts with shedding were therefore too high: old-leader, elbows 1-2, gravity 1,
shedding 0.45,0.5 now has 21,102 leaves whole (not 30,453), 13,960 culled (not 17,704).

The checks (`test/model3d/tree_leaves.goose`), whole tree, no reshaping: 33,154 leaves;
96 % of the pairs standing one over the other have the larger leaf lower, 91 % on the
longer stalk; the medians of the tilt at the top and low in the crown 15° and 23° in
summer, 22° and 24° in mid-September, 42° and 42° in October (Raabe et al.: 15, 22-23;
22, 24-26; 42); with the bend at 1, 55 % flat, 16 % cupped, 29 % sagging; the shapes' 7,776
float4s with unit normals, their counts the shader's.

Counts, old-leader, elbows 1-2, gravity 1, shedding 0.45,0.5, plates 1,2,1, tilt 1,2,8, bend
1,25: 20,428 leaves whole, 13,424 culled, within `MAX_CARDS`.

Times on the Windows PC (tools/tree_dump, -O2), the whole tree with step one's three on:
14.4 ms with today's leaves; plates 16.8, nudged 30.6, tilted 34.0, bent 34.2. The nudge
(16 steps, every pair in a twig's plate) costs 14 ms of it; NUDGE 0 keeps 20 ms. The shapes
take 12 ms, once a growth of the geometry (`tree_geometry`). Under the 100 ms budget, as
the Mac grows about as fast.

Frame cost on the PC (RTX 4090, the tuner at 1600 × 1000, HDR, `--fps-wait`, the
table-window view moved to the window): 0.83 ms a frame with today's leaves and with the
plates; the fan 0.865 (+0.035), the rows 0.84 (+0.01); the flat fan as the bent. Not yet
measured on the tablet, where the rows must be timed before they are kept.

The ngfx build compiles the new leaf shader (the cards after the shapes, the packed
leaf) but draws flat cards only: the bent variants have no ngfx pipelines yet.

Pictures (local, `build/notes/tree/leaves/build/`): `placement.jpg` (today's rule, plates,
nudged, tilted in October: a patch of crown from below, the side and against the light, and
the whole tree, beside the photo crops), `bends.jpg` (flat and bent in October, bent in
September and summer), `app-compare.jpg` (the light tuner near the middle window: today,
plates tilted, bent, summer), `app-zoom.png` (flat against bent, close). `src/dump_view.py`
draws a dump's leaves as the shader does, from its `leaf-shapes.bin`.

Against the photos, what still looks wrong:

- From the room the bends hardly show: the leaves are a few pixels, and the bend shows as
  light changing across a blade rather than a new outline. Close up, as the study said.
- The plates read as rosettes from below and thin layers from the side, as the photos'
  plates do, but the crown from the room looks a little sparser in clumps; SPURS 3 fills it.
- Summer's level blades seen from below the crown turn to slivers at the window's angle;
  right for summer, but the tint stays autumn's: the season sets the tilt alone.
- Shed twigs take their leaves now, so shedding at 0.45 thins the crown by a third.
- Not yet seen on the Mac or the tablet.

## Step three: the bark, the junctions and the roots (2026-11-26)

Built on the Windows PC, each part off by default, set by the light tuner (and the wood's
shape by `tools/tree_dump --junctions --roots --tier N` too):

| Part | Tuner switch | Where |
|---|---|---|
| The bark tile in four ages: a fracture growth (Lefebvre and Neyret 2002) whose cracks keep the time they opened, tapered by their distance to their free ends, furrows by a distance transform, a cavity from blurs; height and cavity, one age a channel, the age blended by the wood's radius | `--tree-bark off\|on`, `--tree-relief K` (1) | `trees::bark_layers`, `tree_bark.goose`; `TREE_WOOD_FRAG` |
| The normal from the height's slope over the pixel's footprint (high: 5 taps; standard: 3, `TREE_BARK_STANDARD`; phone: screen derivatives, `TREE_BARK_PHONE`), the cavity on the sky, an AO microshadow on the sun | with the bark | `TREE_WOOD_FRAG` |
| Scattering emulated: wrap lighting past the terminator, tinted warm | `--tree-scatter W` (0; 0.5 tried) | `TREE_WOOD_FRAG` |
| Roughness: Oren-Nayar in place of Lambert (the old wood had no specular to take away) | `--tree-rough S` (0; 0.8 tried) | `TREE_WOOD_FRAG` |
| Junctions: the collar swells, more beneath; the parent swells round the foot with a ridge in the crotch; a fillet and the foot welded under the parent's skin (wood over 2 cm, standard 4 cm); the parent's grain flows round the foot (ψ = X(1 − 1/ρ²)); the crease shaded; rounded ends on stubs | `--tree-junctions off\|on` | `trees::shaped_tubes`, `tree_junctions.goose` |
| The flare: 6 roots (strong and weak, one gap), the trunk's lowest rings the level lines of trunk and roots as one surface, so no seam; the roots run out flat into the lawn | `--tree-roots off\|on` | `trees::rooted_radius`, `tree_junctions.goose` |
| The tier of the wood's shape | `--tree-wood-tier high\|standard\|phone` | `trees::WoodShape` |

Off, the wood mesh, the shader's path and the tests are as before.

Times on the PC (tools/tree_dump, -O2): the bark tile 35 ms (best of 5), once at
startup, with its mips; the tube mesh, junctions and roots on, high 22.7 ms (13.0 plain),
standard 15.1, phone 13.6. Tube triangles of the culled tree: plain 16,752; high 81,956
(roots alone 56,072); standard 29,632; phone 20,328 (no roots). A tree grown again costs
6.2 ms growth plus 22.7 wood, so about 29 ms with the tile made once; under 100 ms.

Pictures (local, `build/notes/tree/bark-roots/build/`): `tile-layers.png` (the four ages
flat), `tile-far.png` and `tile-close.png` (a trunk beside the lawn photo's crops),
`tile-ages.png` (2 to 90 cm wood), `flare-*.png`, `collar-*.png` and `fork-*.png` (CPU
renders of the shaped mesh: new, today's, the grain, the wire), `app-near-off-on.png`,
`app-keys.png` and `app-material.png` (the light tuner, `--tree-draw wood`, near the
window: off and on; the sun from either side; off, scatter, rough, both). `src/` holds
the scripts that make them from tree_dump's dumps.

What still looks wrong:

- The furrows are wider and interlaced now, but the plates still read a little drawn,
  their edges too even; the photo's ridges are rougher and broken across.
- Scatter at 0.5 warms the shadow side; roughness at 0.8 flattens the lit side. Both are
  subtle at the window's distance and need the user's eye; neither is on by default.
- A small step where a fork's thinner branch meets its parent, from the rings' spacing,
  and now and then a notch beside a junction on the trunk.
- The trunk is mostly backlit from the near-window view, and the flare hidden by the
  pier, so the roots show only in the CPU renders.
- Not yet seen on the Mac or the tablet; the standard and phone tiers checked only as
  compiled shaders and counts.
- The tuner cleanup (2026-11-26) removed the hall in winter sun (`rooms::HALL_SUN`), so
  `test/model3d/trees.goose` and its golden output lost that room's line.

## Round one and the user's answers (2026-11-26)

Three CPU studies, each local in `build/notes/tree/`, with one page of choices
(`choices.html`): the branches (`branches/compare.html`: space colonisation, Palubicki
2009, our Weber-Penn generator with broken leaders, Gao and Newberry's forks, each with
gravity off and on), the leaves (`leaves/index.html`), and the bark, junctions and roots
(`bark-roots/index.html`). The user added gravity's sag of branches and leaves as a core
point (`build/notes/tree-gravity/`, Stava et al. 2014), and bark and roots
(`build/notes/bark-roots/`).

The user's answers:

- The method: our Weber-Penn generator with broken leaders and a gravity layer (Stava's
  bending with a beam's stiffness, r⁴, and the correction upward), in place of
  `Habit.sag`, with Palubicki's shedding of shaded wood. This replaces Gao and Newberry's
  forks below: the criterion on forks of two no longer holds.
- One leader for now; codominant stems later, in a task of their own.
- Crooked: a few clear elbows a limb (1-3), to be seen before it is settled.
- All seasons in the end, so the leaves' tilt and sag follow the season (Raabe et al.
  2015: the top of the crown flattest in summer, steeper as the leaves age).
- Bark: a texture and junctions, its relief strong enough for the stark furrows of old
  maple bark; the roots built even though the window pier hides the trunk's base.
- Later, not yet built: the bark still looks a little like plastic. Two causes to try: no
  scattering under the surface (an emulation, not the real thing), and its specular and
  roughness (bark shows no visible shine).

## The user's verdict on the first research (2026-11-24)

The research is better than before, but the prototype's maple looks wrong and needs much
more work, in a later session. Only one method was prototyped: Gao and Newberry's forks
(`grove.js`), with Palubicki's bending by thickness. The other methods were weighed in a
table but not tried. Next time:

- [ ] Prototype several methods side by side on the CPU, each drawn beside the same photo
      crops: space colonisation (Runions et al. 2007) for the whole crown; Palubicki et al.
      2009 with its shadow grid (grown at low detail if it is too slow whole); our
      Weber-Penn generator with broken leaders added; Gao and Newberry's forks. Pick by
      the pictures, not by the table.
- [ ] Read the open code first (ez-tree, Blender's Sapling, friggog/tree-gen, grove.js)
      and start from published methods and their parameters, not from invented rules.
