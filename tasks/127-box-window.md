# 127: The box window rebuilt from its reference

Status: in-progress

The library's windows are window B (`model3d::shell`, `shell_mesh`'s casement constants,
`build/notes/windows/`): a simplified box window. The user had ChatGPT write a detailed
reference for a Baltic manor box window of about 1890–1905 (2026-11-26; local, not in git:
`build/notes/window-reference/`, `README.md` its specification with diagrams and two concept
pictures; the originals in `~/Downloads/manor-window/`). The concept windows resemble that
specification more than ours do: the two casements, the lower sashes with one bar each, the
fixed upper lights of 3 × 3, the hinges, the crémone rods, the stays, the sills.

The aim is the look, not the joinery: geometry where the silhouette or the light needs it
(profiles, the meeting stiles, the sills), normal maps on cruder geometry where it doesn't
(the crémone rods' detail, the hinges' knuckles, the mouldings' fine profile). The glazing
needn't be built pane by pane as the era did: one glass sheet per casement's plane, as now,
with the bars over it, if it looks the same. The specification may be too detailed; take
what shows from the room's cameras.

The light work (task 122) reads the casements: `room_shell::casement_members` (the bake's
sun and sky through the frames), `LIGHT_FN`'s `casement()` (the window's light map and
the visible patches), the probe volumes in the space between the panes, the tracer's and
the Cycles export's closed casement backs. A new window changes all of them together, from
one description of its members.

## The specification against the room's cameras (2026-11-26)

Shots of today's window beside the concept: `build/notes/box-window/index.html` (scratch
`build/bw/shots.sh` in the worktree; autumn, `--light physical`).

Today's window already has the specification's divisions: two casements 0.2 m apart, a
transom, each upper half 2 × 3 × 3 panes, each lower leaf one bar. What differs is
everything the eye reads close up: plain boxes where the concept has moulded bars round
every pane, a 35 mm cover strip down the whole middle (over the transom too) where the
specification has a fixed upper mullion and two lower meeting stiles with a lip, the frame
3 cm proud of the sashes, and no hardware on the casements at all.

What a millimetre is on screen, at the window's inner glass:

| Camera | Distance | mm a pixel, 3840 × 2160 | 5120 × 2880 |
|---|---|---|---|
| Menu (`table-window`), the app's | 3.7 m | 2.0 | 1.5 |
| Reference view (`--fov 73`) | 3.3 m | 2.3 | 1.7 |
| Window view | 6.4 m | 3.4 | 2.6 |
| Room view, the far window | 6.9 m | 3.7 | 2.8 |
| Casement close-up, the walk's nearest (tuner) | 1.0–1.25 m | 0.5 | 0.4 |

The app's nearest camera is the menu's: 2 mm a pixel. The tuner's close-ups are for
checking, and the walk may come later; nothing should break at 0.5 mm a pixel, but the
budget is set at the menu's.

| Part | On screen at the menu | Built as | Why |
|---|---|---|---|
| Frame (head, jambs, sill), 70 face, 80 deep | 35 px | Geometry: a box with a 15 mm rebate step to the sash | its depth throws the frame's shadow on the sash; the step is the line the concept shows round each leaf |
| Transom 90, upper mullion 60 (fixed) | 45, 30 px | Geometry, boxes | silhouette and the light's pattern |
| Upper lights' surround 40 | 20 px | Geometry, moulded on the glass edge | the pane's ring starts here |
| Lower sashes: stiles 60, rails 60/85 | 30–43 px | Geometry, moulded on the glass edge | as above |
| Meeting stiles and the active sash's lip (8 × 13) | 60 px, the lip 4–6 px | Geometry: two stiles and a lip strip on the right one | the lip's step is a shadow line the eye catches; replaces today's cover strip |
| Glazing bars, upper 24, lower 32, 40 deep | 12–16 px | Geometry, a coarse section (face, two slopes, web) | the bar's width and depth are the light's pattern |
| The ogee moulding round every pane (9.5 mm, 7 mm relief) | 5 px | A ring per pane, mitred at its corners, 3 segments a side with the ogee's normals (smooth normals, no texture) | the shading band shows at 5 px; the S-curve itself doesn't. A ring per pane gives the specification's clean mitres where bars cross |
| Glass, 3 mm | | One sheet per casement plane, as now | the bars cover the joins; a sheet a pane adds nothing seen |
| Putty | | Left out | faces the space between the panes (inner) or the outside (outer); behind the bar's web from the room |
| Hinges, 3 a sash, barrel 11 × 80 | 5 × 40 px | Geometry: an 8-sided barrel, two leaves; the knuckle's seam a normal break | the concept shows them; small silhouette |
| Crémone: housing 110 × 30 × 16, handle 75 | 55 × 15 px | Geometry, a rounded box and a bent handle | the concept's one piece of hardware in the middle |
| Crémone rods 6 × 6, guides, keepers | 3 px | Rods as thin boxes; guides and keepers left out | rods show as a line; guides 12 px long, keepers hidden by the transom's and sill's edges |
| Slide bolts on the passive leaf, 65 × 20 × 10 | 32 × 10 px | Geometry, a box and a knob each | cheap, near the leaf's ends |
| Stays | 2 px | Left out | parked against the frame, not in the concept; with an open sash later |
| Outer casement | through the glass, at 0.2 m more | The same description mirrored in depth: its room side shows mouldings and its crémone (the specification puts its hardware on the space's side); hinges outside, left out | seen through the inner glass in every view |
| Drip moulding, outer sill's fall | | Left out | outside faces; not seen from the room |
| Box lining | | As now | |

Proportions in our opening (1.3 m niche, 0.98 m between the frame's jambs, 2.5 m high):
the members keep the specification's sizes in millimetres and the panes take what is left,
so they come out narrower than the concept's (upper about 110 × 170 mm, lower 370 wide).
The transom stays at two thirds up (today's; the concept's is 68%, the specification's
71%): the menu's placements were verified with the sun in the upper sash's lowest panes.

The one description: a table of the window's members in its own metres (box, kind,
casement, leaf, the moulding on which edges), each leaf's hinge axis, its panes'
rectangles, made once from the specification's measures fitted to the opening. The mesh
builds each member by its kind; `casement_members` returns its boxes (so the bake, the
probe volumes and the closed backs in the tracer and the Blender export follow); the Goose
readers of the layout (`cheap_casement`'s and `glazing`'s CPU twins, `render3d::casement_sash`,
`light_tune::casement_at`) read the measures; `LIGHT_FN`'s `casement()` keeps its own
`const float`s, checked equal by `test/model3d/geometry.goose` as the board's are. The
hardware stays out of the light's members: within a member's outline but for the handle
(35 mm out) and the hinges' barrels (11 mm), a few millimetres of shadow.

## The box window, behind `--box-window on` (2026-11-26)

Results page: `build/notes/box-window/index.html` (step 2); scratch `build/bw/` in the worktree
(`shots.sh`, `same.sh`, `pts/` with `cavstat.py`). The user's real-world reference, a restored
manor's new box windows from a local newspaper (2026-11-26; one pane each upper light, otherwise
the same parts), set the look: plain, not overdone.

- The description: `src/model3d/box_window.goose` (`BoxCasement`, its four `BoxLight`s, the
  members, each leaf's hinge axis, `pane_in`). The mesh (`box_casement_mesh`): the frame as
  `paint_box`es, its face where window B's was (the sill's dust and the corners' shade are drawn
  to it), the lights 15 mm behind it in its rebate; a ring a pane (flat, a 6 mm rounded step,
  the side to the glass, the bar's web behind it), the cells meeting on the bars' middles so
  neighbours share whole edges; the left leaf's lip; one glass sheet a casement; two long barrel
  hinges a leaf, the crémone on both casements, two bolts on the passive leaf, in
  `MAT_BRASS + 0.5`, which ROOM_FRAG shades as the specification's dark brass (`WINDOW_BRASS`).
- `casement()` takes either layout by `shell_case.x` (a new vec4 in every block carrying the
  shell's fields; y to w kept for a sash's opening): one body with the measures picked, not a
  second function, whose five call sites cost about 0.4 ms with the flag off. Flag off: the four
  views and the casement close-up byte-identical or one level, under both lights, but one pixel
  of the menu view at 19 levels (the reordered arithmetic; each build is deterministic).
- Triangles: the room's mesh 49,130 → 52,082; the glass and lace unchanged.
- The light against the tracer: between the panes, the 11 points seen from the room 0.95 (error
  factor 1.41) → 1.01 (1.34), all 19 1.76 → 1.62; the 22 props' points unchanged (2.051 →
  2.059, the bake alone 4.40 → 4.35). A fix on the way: the probe volumes' pane depth was window
  B's (18 mm behind the plane; the box window's is 13 mm before it), so the sun crossed the inner
  leaves' backs as glass and the outer frame read 0.05 against 0.24.
- Against Cycles (the export with `--box-window on`, EV 3.40 and 1.40): the window's crop keeps
  today's distance within two levels.
- Cost, rough (runs under another session's builds): +0.4 to 0.8 ms a view at 3840 × 2160.
- Left as before: `cheap_casement` (the cheap mirror) keeps window B's means; the export maps the
  hardware to the curtains' brass.

## Acceptance criteria

- [x] The specification read against the room's cameras: what shows, what is geometry,
      what a normal map, what is left out; noted here with the reason
- [x] The new window built from one description of its members that the mesh, the bake,
      `casement()`, the probe volumes, the tracer and the Blender export all read
- [ ] The look against the concept pictures and Cycles: close-ups of a window from the
      room, at the metered exposure and at EV −2
- [ ] Its triangles and its cost per view (`tools/perf/mac_room_bench.py`), and the light's
      numbers against the tracer unchanged or better
- [x] An open sash possible later (the hinges' axes in the description), not animated now
