# 093: The manor room

Status: in-progress (exploratory, 2026-11-17: concept art only; not for 1.0, and it may
end up in a later chess app instead)

A render option that sets the 3D board in a whole room: a table by a window in a
fictional Estonian manor, with the park outside. The time of day is fixed per season, so
almost all of the room's light can be baked. Only the board and pieces get live light and
shadow. The key light still comes from the left, through the window. The room is real
geometry, so the camera can look around (the title screen, panning). During play the
camera rests, so the room is drawn once into a colour and depth target when the camera
stops, and each frame draws only the board and pieces over it, keeping draw-on-change.

Scope: one room first, dressed per season; a second (a stair hall with a tiled floor, for
the stone board) later. Desktop and Apple A13 or newer are the target; weaker devices get
a lower tier or keep today's backgrounds.

First (2026-11-17): task 094, the pieces' materials, and task 095, a mahogany table
under the board, both on main. The room may then be dropped, or become only a blurred
backdrop behind the table (a window and a chair, as in `hall-winter-table-02.png`).

The boards in a manor: a stone like the concept's (`hall-winter-table-02.png`, speckled
grey stone with a carved leaf border) fits; summer's lichen stone and the carved pagan
sets don't fit a Baltic-German house. Revisit those looks if the room is adopted, not
before.

## Choices so far (2026-11-17)

- A Baltic-German manor in Estonia, fictional, after Vihula, Schloss Fellin, and
  Alatskivi's rooms. 1890–1905 (late Historicism into early Jugendstil) if the concept art
  holds up.
- The room faces the garden side, where the park's old trees stand close to the windows.
- Look development in Blender (Cycles, AgX), which also bakes the lightmaps and probes,
  so the approved look is the one shipped. The engine's tone mapping is AgX to match.
- Two framings: on the home screen the window is the picture and the board sits to one
  side; in play the camera holds the board and the table, little else.
- In play, a streak of sun across the board with the window bars' and the curtain's
  shadow in it: a baked light pattern (a cookie on the key light), still, so drawing
  stays on change.
- Faked subsurface scattering on the pieces, as in `library-table-01.png`: the light
  pieces glow warm at their edges and in their shadow's terminator where the sun
  strikes them, like ivory or bone. A few terms in the piece shader (wrapped diffuse,
  a warm tint toward the shadow side, a little light through the rim from behind), no
  extra pass.
- Still props that catch the light, from `library-table-01.png`: a glass vase whose
  caustics are baked into the table's light with the window's pattern (Cycles renders
  them; at run time they are part of a texture), the vase itself a cheap fake refraction;
  a crocheted lace doily or runner under it, a flat mesh with a cut-out lace texture.
- Depth of field during play: the room behind the board is soft, which keeps the board
  readable and the assets cheaper.

## Subtasks

- `01-concept-art.md`: style, layout, and concept frames from ChatGPT
- Later, each a file when it starts: the Blender blockout and look development; the
  engine's HDR target, tone mapping, and bloom, with the board's light taken from the room;
  the room's geometry, lightmaps, and probes in the app; furniture and props; the
  seasonal dressing; device tiers and memory; the second room.

## Acceptance criteria

- [ ] A chosen room and decade, with concept frames per season (01)
- [ ] A Blender scene whose Cycles renders are the approved look
- [ ] The room in the app on the Mac, with the board lit to match it
- [ ] A13 and newer at the display's rate in play, the room cached while the camera rests
- [ ] A tier for weaker devices, and the room's memory and download size recorded
