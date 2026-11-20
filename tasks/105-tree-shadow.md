# 105: A real tree's shadow through the window

Status: todo (planned 2026-11-20, on the branch `room-light` after task 104)

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

## Acceptance criteria

- [ ] A generated tree whose shadow reads as branches and leaves, not noise, on the board
      and the table, next to the concept frames
- [ ] Round sun flecks that soften with the distance, near twigs sharp
- [ ] A take per season, winter's bare
- [ ] The sway by layers in the tuner
- [ ] Its bake time and memory recorded on the Mac; its tier noted in task 104
