# 129: The antique brass material

Status: in-progress

Task 127 built the box window's hardware (the crémone's grip and housing, the rods, keepers,
guides and hinges, `room_shell::WINDOW_HARDWARE`, MAT_BRASS + 0.5, the fraction marking it)
in one flat metal, bronze B: sRGB 0.34, 0.25, 0.17, roughness 0.5 (`room_shell::WINDOW_METAL`,
ROOM_FRAG's `WINDOW_BRASS`, checked equal by `test/model3d/geometry.goose`; the Cycles
export's `window_metal`). The shutters' and doors' hinges take it too (`hinge_metal()`). The
user approved the shapes and that metal in Cycles, and wants the material itself made richer
after a specification ChatGPT wrote for them (2026-11-27; local, not in git:
`build/notes/window-reference/references/antique-brass-material.pdf`, 6 pages). Its page 1
figure is the look's target: mottled golden-brown aged brass, pale exposed metal on the
touched convex parts, darker recesses, broken highlights. Later the door handles take the
same material.

What the specification asks:

- One shared, seamless material family of aged yellow brass in three states: exposed brass
  (linear 0.91, 0.778, 0.423, the C260 anchor; metallic 1, roughness 0.22–0.36), light
  tarnish (0.55, 0.34, 0.13; metallic 0.8–1, roughness 0.34–0.48), dark deposits (0.10,
  0.055, 0.025; metallic 0–0.2, roughness 0.48–0.68), about 35/50/15 coverage.
- Mottling at physical size, the same scale on every part: clouds of 4–15 mm, islands of
  0.3–3 mm, sparse speckles of 0.07–0.35 mm (mostly roughness), a micro-finish of
  0.02–0.1 mm (a micro normal); a seamless tile of 64 mm, no Voronoi cells, stripes or
  pepper noise.
- Local wear over it: more exposed metal on the grip's touched convex parts, darker in
  recesses and sheltered flats; not a bright outline on every edge.
- Parity between Cycles and the game, from the same maps and mapping; mip filtering so the
  mottling fades to its mean at distance and doesn't shimmer.
- Controlled checks first: a sphere, a bevelled plate and the real handle under neutral
  light, a clean-brass control beside the aged one; then the room. Not darkening the metal
  to make up for a dark scene.

Conflicts, for the user to settle, not this task alone:

- The user found the first brass "WAY too bright" and asked for "something a bit more
  bronze"; task 127 settled on bronze B, whose colour is about the specification's dark
  deposit. The specification's mix is far lighter. The user wants to pick between a few
  darkness levels at the end, the Cycles look a good guide: the material's overall tone is
  a choice of about five levels, bronze B's mean among them.
- Task 128 fixes the niche's baked light, which reads too dark now: judge the tone in Cycles
  and the controlled checks, not in the tuner's niche.
- Our own procedural materials, no downloaded textures (`agents/design.md`); lean code, no
  allocation in the frame loop; the phone tier keeps it cheap or off. The parts are a few
  pixels to a few hundred on screen.

Everything new is behind a light tuner flag, default off, with shots, until the user picks.

## Plan

1. The concept in Cycles: the procedural material on a sphere, a plate and the handle under
   neutral light, at the levels, and the handle in the room; a page in
   `build/notes/antique-brass/` with the specification's target beside them. The user picks
   a level.
2. Then the port: the tile baked by the game's own code, ROOM_FRAG's window metal reading it,
   the wear per vertex, the level a tuner flag (`--window-metal`) that the Cycles export
   follows; the look tiers.

## The concept in Cycles (2026-11-27)

`tools/blender/brass_tile.py` makes the tile: 64 mm, 2048², periodic gradient noise at whole
periods (so the game's bake can make the same): clouds of 4–13 mm, blots of 1.3–2.7 mm and
flecks of 0.3–0.7 mm under a slight warp, ranked together into one field (r, 0 to 1 evenly),
pits of 0.2–0.4 mm (g, about 1%), and the micro-finish's height (0.06–0.1 mm, 16 bits).
`brass_model.py` holds the model and the levels; `brass.py` builds it in Cycles, box-projected
by world position; `brass_check.py` renders the controlled check (a 40 mm sphere, the real
handle cut from the room's mesh, a plate the housing's size, under a dark grey world and two
white cards); `scene.py --window-metal 1..5` puts it in the room (`flat`, the default, is
bronze B).

The states' coverage is a threshold on the rank, with soft edges (0.25 in rank). The levels:
the mean's luminance steps evenly in log from the specification's mix to bronze B; a darker
level moves coverage toward the deposits, scales the tarnish and deposits by its gain and the
bare metal by the gain to the 0.75, and tints the tarnish toward bronze B's hue
(`brass_tile.py --levels` solves the gains and tints from the tile).

| Level | Bare / tarnish / deposit | Gain | Mean, sRGB |
|---|---|---|---|
| 1 | 35 / 50 / 15 | 1.00 | 0.80, 0.70, 0.50 (the specification's values) |
| 2 | 28 / 52 / 20 | 0.62 | 0.65, 0.55, 0.39 |
| 3 | 22 / 52 / 26 | 0.39 | 0.53, 0.43, 0.30 |
| 4 | 16 / 52 / 32 | 0.25 | 0.42, 0.33, 0.23 |
| 5 | 10 / 52 / 38 | 0.17 | 0.34, 0.25, 0.17 (bronze B's mean) |

Where it departs from the specification, and why:

- The colour's mottling is pulled halfway to the level's mean: at full contrast the three
  states read as camouflage or rust beside the target's quiet patina (tried first, with
  sharper edges and a stronger warp: swirls like marble). Metalness and roughness keep their
  full contrast, which breaks the highlights.
- One field and thresholds instead of a base colour, surface and normal map: a level and the
  wear are then a few constants.
- The wear in Cycles is a stand-in: the grip found by where it stands (before the housing),
  the convex parts by Cycles' pointiness, the recesses by a 4 mm occlusion. The game would
  write it into the hardware's vertices.

In the room (the handle view, EV +3.4) level 5 reads darker than flat bronze B at the same mean:
its deposits are dielectric (metalness 0.1) and reflect little of the glass; level 4 reads
nearest to the approved look. Renders: 1600 × 900 checks about 70 s each at 256 samples on a
loaded Mac, the room views about 40 s.

Page: `build/notes/antique-brass/index.html`.

## Acceptance criteria

- [ ] The controlled checks in Cycles at about five tone levels, bronze B's among them, with
      a clean-brass control, on a page beside the specification's target
- [ ] The user's pick of a level and the look of the mottling
- [ ] The material in the game behind a tuner flag, default off, matching Cycles at a
      close-up and at play distance, without shimmer
- [ ] Its cost per view and on the phone tier; the door handles and hinges on it later
