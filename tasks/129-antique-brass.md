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

## In the game, level 4 (2026-11-27)

The user picked level 4 for now ("we'll fix the hues etc later"), the other choices left to
this task: the levels' hue drift kept, the concept's mottling sizes, half the colour's
contrast. Ported behind the light tuner's `--window-metal LEVEL,MOTTLE,ROUGH,NICHE`, off by
default, its four values live sliders (now the Window section) and in the P print:

- The tile: `room_shell::brass_tile` (`src/model3d/brass_tile.goose`), wrapped value noise at
  whole periods, ranked by a histogram; 1024², 62.5 µm a texel, R the rank and G the pits,
  RGBA8 with its mips (5.6 MB), made in 0.18 s when the box window first shows.
- ROOM_FRAG's window metal (`window_hw`): the tile box-projected by world position, three taps;
  the states, levels and means as `BRASS_*` (the solver's numbers on the game's tile); the
  mottling fades to the level's mean between 1 and 4 mm a pixel; the phone tier (`NO_SSAO`)
  reads no tile and takes the mean. The level is continuous (`brass_level` mixes the two either
  side). Under level 1 the flat bronze B as before.
- The wear in the vertices: `lathe_along`'s `wear` (the grip's 1) puts the rub in the
  material's fraction, `WINDOW_HARDWARE` plus `WEAR_SPAN` times it: the whole grip a little,
  its convex rings more, its necks darker; the shader lifts the rank by 0.35 times it.
- The block: `window_metal` at the Surfaces block's end (`room_shell::window_metal`), so
  `room_fixed`'s spans stay; kept a uniform (`scripts/room_fixed.py`'s KEEP). It also holds
  the niche's share (`WINDOW_NICHE`'s 0.3), for task 128's light.
- The export: `--window-metal` as the tuner's; `brass_tile.ppm` (the game's tile) and
  `scene.json`'s `gloss.window_metal_look`, which `scene.py` follows; the wear from the vertex
  colour's g. The micro-finish is left out of both: finer than a pixel at the close-up.

The game's grip at the handle view against Cycles' (the same crop's mean, sRGB): level 4 110,
75, 43 against 99, 64, 34; flat 92, 61, 33 against 85, 53, 27: the same 8 to 11% lighter, the
niche's light (task 128). With `--phone-tier` the room's constants read stale at `paper` with
the flag off as well (not this change). Rebased onto `box-window` 561e2723 (the three-lobed
keeper); the keeper reshot.

## On `room-light`, with the niche's light (2026-11-27)

Rebased onto `room-light` d8eeec25 (task 127's box window and task 128's niche light merged).
`room_fixed.goose` written again from the tuner's phone tier: unchanged, as `window_metal` is
kept a uniform. With the niche's light in the probes the window's metal read brighter in the
tuner than Cycles; measured as the handle view's crops over the casement frame's beside them
(their green, so the two renderers' exposures cancel):

| | Grip / frame | Housing / frame |
|---|---|---|
| Cycles, level 4 | 0.50 | 0.32 |
| Tuner, level 4, niche 0.3 | 0.89 | 0.73 |
| Tuner, level 4, niche 0.15 | 0.77 | 0.58 |
| Tuner, level 4, niche 0.05 | 0.64 | 0.44 |
| Tuner, level 4, niche 0 | 0.54 | 0.33 |
| Cycles, flat | 0.42 | 0.17 |
| Tuner, flat, niche 0 | 0.41 | 0.18 |

The niche's share is now 0 by default (`WINDOW_METAL_OFF`), the flat bronze's too: the niche's
light in the probes gives what the share used to stand in for.

## The user's verdict (2026-11-27)

The user prefers the old flat bronze for now: the tuner's Window section has a "Metal" switch,
bronze (default) or antique brass (level 4 when first turned on). The brass is merged into
`room-light` off by default to keep working on. What needs work, from the user's look at the
pairs (Cycles' pictures look right, the game's don't):

- The mottling reads too strong in the game, where in Cycles it is subtle and nice.
- The bronze's specular, flat or brass: flat and blurry in the game, where Cycles shows crisp,
  broken highlights on the grip, the rod and the keeper. The window metal reflects only the
  room's wide light (`room_wide`) since task 127 (the box's sharp `room_reflection` read far too
  bright from the niche), so it has no sharp reflection and no highlight but the sun's.

## The tuner's Window section (2026-11-27)

The user couldn't find the brass's level. The window's rows are now a top-level section of
their own, Window (`--sections window`; the board's window pattern under Sun and tree is now
`board-window`), open at the start: the shutters (H), the glass's film and scratches, the
metal (bronze or antique brass), the brass's level, mottling and roughness, and the niche's
light. The level shows with the bronze too, holding 4; moving it turns the brass on. The
lace's rows stay in Curtains and lace.

## The user's second verdict, and the metal's highlights (2026-11-27)

The user, after the Window section: the brass's level about 2, or between 1 and 2, once the
material looks better ("it fits the room much more"); its roughness and mottling likely need
tuning too; the antique brass may be the default under `--light physical` once tuned against
Cycles ("doesn't look THAT bad in practice"), the bronze kept behind the Metal switch. Aim for
Cycles' look: how much the mottling shows and the material itself.

What Cycles' highlights are, from the handle view at 1920 × 1080 (scratch `cyc.py` running
`scene.py` with a hook; the EXR's passes over the grip's ball, flat bronze, linear): all but
the finial's top is glossy indirect, the metal reflecting lit surfaces, not the sun's or the
sky's direct light (ball: 0.0011 indirect, 0.0002 direct). With the sun off the ball keeps
0.0008 of 0.0014, with the sky off 0.0005: the sky through the panes and the sunlit reveals
and room, about 3 to 2. The crisp highlights on the grip's and keeper's rims are the bright
panes beside them, seen at a slant through both casements; at a steeper slant the box between
the panes (its lining) takes them, so they stay thin. Hiding the lace from glossy rays halves
the housing's room-facing face (0.066 to 0.032 of the frame, sRGB).

The game had none of it: the window's metal has reflected only `room_wide` since task 127.
`niche_seen` (ROOM_FRAG) now gives it the panes: the reflected ray meets the inner and the
outer glass, each through `casement()` with its members as deep as they are at that slant and
blurred as the lobe widens, and sees the view out's light (`lace_light`) through both,
`room_wide` elsewhere; `window_metal.w` its share (it was the niche's share, 0 since task 128;
the shutters' hinges keep theirs). Without the outer casement the rims lit all round, a chrome
look. Taking the room's box (`room_seen`) for the rays turned to the room instead was tried:
the ball, stem and rod then match Cycles (flat 0.30, 0.30, 0.33 against 0.30, 0.33, 0.33) but
the housing's face reads 0.41 against 0.066, with sharp door shapes on the ball; left out.

The handle view, each part's sRGB green over the casement frame's beside it (exposures cancel);
the mottle as the local contrast in linear light (std of the green over a 6 px blur of it) on
faces clear of edges:

| | Ball | Stem | Top | Housing | Rod | Mottle: ball, stem, housing |
|---|---|---|---|---|---|---|
| Cycles, flat bronze | 0.30 | 0.33 | 0.35 | 0.066 | 0.33 | 0.10, 0.14, 0.12 (noise) |
| Game before (`f56d4987`), flat | 0.21 | 0.24 | 0.37 | 0.009 | 0.08 | |
| Game, flat, panes 1 | 0.28 | 0.25 | 0.50 | 0.009 | 0.08 | |
| Cycles, level 2 | 0.79 | 0.67 | 0.70 | 0.48 | 0.79 | 0.19, 0.22, 0.07 |
| Cycles, level 1.5 | 0.93 | 0.78 | 0.80 | 0.59 | 0.95 | 0.19, 0.26, 0.07 |
| Game, level 2, panes 1 | 0.77 | 0.57 | 0.81 | 0.29 | 0.52 | 0.08, 0.27, 0.35 |
| Game, level 1.5, panes 1 (the default) | 0.82 | 0.61 | 0.84 | 0.33 | 0.57 | 0.07, 0.30, 0.34 |
| Game, level 1.5, mottling 0.75 | 0.85 | 0.59 | 0.86 | 0.32 | 0.54 | 0.09, 0.23, 0.28 |

The upper keeper's rod (the `niche` view), over the stile beside it: Cycles 0.23 flat, 0.79 at
1.5; the game 0.04 flat (before and after), 0.50 at 1.5.

What is left is the light the parts facing the room reflect: the housing's face, the rod, the
grip's middle. The probes' light that way (`room_wide`), at the hardware and 0.3 m into the
room alike, reads about seven times darker than Cycles' (flat housing 0.009 against 0.066),
half of Cycles' being the lit lace beside the window, which the probes don't hold; the room's
box reads six times brighter. So the game's metal facing the room is dark, its dielectric
deposits lit by the probes' irradiance, and the mottling shows as dark metal with lit islands:
the housing's local contrast 0.34 against Cycles' 0.07, whatever the mottling slider (0 to 1:
0.57 to 0.25), while the grip's stem matches (0.30 against 0.26). The mottling is the light's,
not the material's; it is for the room's light (task 128's session) or a lace term in
`niche_seen` later.

Picked, behind `--light physical` (the tuner's default there and the Cycles export's,
`room_shell::WINDOW_METAL_PHYSICAL`, 1.5, 0.5, 0, 1): the antique brass at level 1.5, the
user's range, as it reads nearest Cycles' level 2 on the room-facing parts (level 2 reads a
fifth darker there) while the ball stays within 4%; the mottling at the shared 0.5 (0.75 eases
the housing a little, 0.34 to 0.28, but the export would carry it to Cycles too); roughness as
it is (the game's highlights already read crisper than Cycles', the 95th percentile over the
median 2.4 against 1.6 on the ball). The bronze keeps the panes as well. Without
`--light physical` (the app) nothing changes: with the panes' share 0 and the bronze the tuner
shoots byte-identical to `f56d4987`. The phone tier draws no `niche_seen` (no `SHARP_BOX`).
Cost not measured (no frame timing while others render); `niche_seen` adds two `casement()`
calls on the hardware's pixels only.

Page: `build/notes/antique-brass/index.html` (its top section).

## Acceptance criteria

- [x] The controlled checks in Cycles at about five tone levels, bronze B's among them, with
      a clean-brass control, on a page beside the specification's target
- [x] The user's pick of a level (4, for now); the mottling's look left to revisit
- [x] The material in the game behind a tuner flag, default off, matching Cycles at a
      close-up and at play distance (the niche's light aside, task 128)
- [ ] No shimmer as the eye moves, checked in the tuner on the Mac
- [ ] Its cost per view and on the phone tier; the door handles and hinges on it later
