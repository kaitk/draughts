# 127: The box window rebuilt from its reference

Status: todo

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

## Acceptance criteria

- [ ] The specification read against the room's cameras: what shows, what is geometry,
      what a normal map, what is left out; noted here with the reason
- [ ] The new window built from one description of its members that the mesh, the bake,
      `casement()`, the probe volumes, the tracer and the Blender export all read
- [ ] The look against the concept pictures and Cycles: close-ups of a window from the
      room, at the metered exposure and at EV −2
- [ ] Its triangles and its cost per view (`tools/perf/mac_room_bench.py`), and the light's
      numbers against the tracer unchanged or better
- [ ] An open sash possible later (the hinges' axes in the description), not animated now
