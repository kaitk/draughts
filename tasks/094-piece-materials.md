# 094: The pieces' materials

Status: todo

The 3D pieces read as plastic next to the concept art (`design/manor/library-table-01.png`,
`hall-winter-table-02.png`, local; task 093 on the `manor-room` branch): there the light
pieces glow warm at their edges where the sun strikes them, like ivory, bone, or marble,
and no two pieces shine alike. Two things make the difference, and both go in the piece
shader (`src/render3d/shaders.goose`) with their values in the looks
(`src/model3d/looks.goose`), per piece material, not per season:

- **Faked subsurface scattering**: wrapped diffuse light so the light reaches a little past
  the terminator, a warm tint along it instead of grey, and a little light through the rim
  when the key light is behind the piece. Strong on light stone and bone, faint on dark
  wood. A few terms in the existing pass: no extra pass and no setting to turn it off (the
  3D board draws only on change).
- **Variation**: the roughness a little uneven across a piece, the worn edges duller, a
  faint difference in tone between pieces. The pieces stay matte turned discs: gloss and
  a wide round rim were tried and set aside (`agents/design.md`).

Tune with versions side by side: `tools/board_shot.goose` takes the strength and tint as
flags and shoots each season's looks at the rest angle, compared against the concepts at
the same crop.

## Acceptance criteria

- [ ] The piece shader scatters light by the looks' strength and tint per material
- [ ] Roughness and tone vary across and between pieces, without banding from afar
- [ ] `board_shot` shoots versions with the values as flags; the chosen ones in the looks,
      with shots of each season before and after in this file
- [ ] No change to the frame's GPU time measurable on the Mac; the A33 checked at the end
