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

- [ ] The user answers the page's open questions (one leader or codominant stems, how
      crooked, the hanging limb).
- [ ] Below the limbs, each node forks in two: asymmetry 1..6, radii by r^α (α about
      2.3), the thin side at atan(a), the thick at atan(1/a), the fork's plane a quarter
      turn from the last, length ∝ r^(2/3); levels 2-4 of `Habit` go.
- [ ] A tropism per segment by thickness: thick wood rises, thin wood levels out and
      sags, side shoots lean out of the crown.
- [ ] Broken leaders in wood of 5-35 cm: the thick side ends as a stub, the thin side
      takes over, turned 30-50°; 1-3 elbows a limb.
- [ ] A fork's length scales with the room to the envelope, so tips reach the shell.
- [ ] Thin wood deep in the crown dies back, some of it as stubs.
- [ ] Leaves only on each tip's current shoot: the tip pair and one pair a quarter turn
      below, stalks longer for leaves pointing down, blades level and facing up within
      about 15°.
- [ ] Each step behind a tuner switch, checked first as a CPU silhouette from
      `tools/tree_dump` against the photos, then on the Mac and the tablet.
- [ ] Growth stays under 100 ms on the Mac (now 6.5 ms) and the segment and leaf counts
      within `MAX_WHOLE_SEGMENTS` and `MAX_CARDS`; the times recorded here.
- [ ] The decision recorded in `docs/decisions/` and `docs/architecture/` updated.

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
