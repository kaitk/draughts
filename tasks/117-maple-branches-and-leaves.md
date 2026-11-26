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
- [ ] Leaves only on each tip's current shoot: the tip pair and one pair a quarter turn
      below, stalks longer for leaves pointing down, blades level and facing up within
      about 15°.
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
