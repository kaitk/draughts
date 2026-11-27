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

## Acceptance criteria

- [ ] The controlled checks in Cycles at about five tone levels, bronze B's among them, with
      a clean-brass control, on a page beside the specification's target
- [ ] The user's pick of a level and the look of the mottling
- [ ] The material in the game behind a tuner flag, default off, matching Cycles at a
      close-up and at play distance, without shimmer
- [ ] Its cost per view and on the phone tier; the door handles and hinges on it later
