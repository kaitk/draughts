# 094: The pieces' materials

Status: in-progress

The 3D pieces read as plastic next to the concept art (`design/manor/library-table-01.png`,
`hall-winter-table-02.png`, local; task 093): there the light pieces glow warm at their
edges where the sun strikes them, like ivory, bone, or marble, and no two pieces shine
alike. Two things make the difference, and both go in the piece
shader (`src/render3d/shaders.goose`) with their values in the looks
(`src/model3d/looks.goose`), per board look at first (similar looks will share values),
not per season:

- **Faked subsurface scattering**: wrapped diffuse light so the light reaches a little past
  the terminator, a warm tint along it instead of grey, and a little light through the rim
  when the key light is behind the piece. Strong on light stone and bone (spring's stone
  pieces want it too), faint on dark wood. A few terms in the existing pass: no extra
  pass and no setting to turn it off (the 3D board draws only on change).
- **Variation**: the roughness a little uneven across a piece, the worn edges duller, a
  faint difference in tone between pieces. The pieces stay matte turned discs: gloss and
  a wide round rim were tried and set aside (`agents/design.md`).

Tune with versions side by side: `tools/board_shot.goose` takes the strength and tint as
flags and shoots each season's looks at the rest angle, compared against the concepts at
the same crop.

Run the Mac tuner from `tools/` with `../build/piece_tune`. It opens on spring.
The Pieces slider previews Board default, Plastic (the previous smooth spring pair),
Jade or Wood on any board. Wood previews the existing autumn pair.
B or the scattering checkbox toggles piece scattering, preserving the cut,
roughness, wear and camera. Dark and light pieces have independent scattering strengths. The dark pieces also
have a brightness slider.
Texture and Roughness adjust each side. Drag outside the panel to orbit, scroll to
zoom, and press R to return to the rest angle.

Green jade has a deep green body and cloudy folded inclusions of varying strength.
White jade is milky off-white, with a faint cloud on some cuts. The dark pieces
follow the hue of the spring jade squares. Plastic uses the original smooth shader
with wear and scattering at zero. Both use local 3D coordinates
so each cut continues over the rounded side. For a matched spring stone shot,
use `board_shot --season spring --material stone` with profile 0 or 1.

## Built so far

- `looks::Theme` gains `light_scatter`, `dark_scatter` (sRGB tint, w strength) and
  `piece_wear` (x uneven roughness, y duller worn edges, z each piece's tone), with
  templates by material: `IVORY_SCATTER` (winter, the elven and amber stones, autumn's
  stones), `PALE_WOOD_SCATTER` (autumn, spring's birch, summer, winter's woods),
  `DARK_WOOD_SCATTER`, `DARK_STONE_SCATTER`, `JADE_SCATTER` (the elven and serpentine
  dark pieces), `WOOD_WEAR`, `STONE_WEAR`. First guesses, to tune.
- The shader: each channel's diffuse wrapped past the terminator by the tint times the
  strength (red furthest), only the light that adds counted, the shadow only on the lit
  side (past it the piece shadows itself), and light through the rounded rim
  where the key is behind the surface. The patches of roughness and the piece's tone come
  from the vertex shader (`v_wear`); the worn rim and foot per pixel.
- Set aside: a band round the terminator by the angle to the light alone. The key is
  high, so every vertical wall is near the terminator whichever way it faces: the whole
  side and the top's step glowed alike, as if lit from above (2026-11-17).
- Cost, a first look only (to settle after the look is chosen): the board pass on the Mac,
  `--board 3d --screen game --theme wood --bench 300` headless, 1.72 ms before, about
  1.81 ms after (medians of five). The bigger block and the varying cost nothing; the new
  fragment code does, more than its few instructions explain (register pressure, likely).

## Shoulder lighting experiment (2026-11-19)

On `piece-soft-light`, the rounded shoulder borrows some of the adjoining face's
diffuse light. Its six mesh segments carry the change, so the fragment shader only
adds an interpolated RGB value to the diffuse term. The cast shadow covers both.
The vertex shader also sets roughness from the existing wear controls.
The looks and autumn profile 1 use the same values as the first experiment.

At the rest angle, winter's ivory loses the pink band along the stacked king's seam.
Autumn profile 1 keeps a highlight on the walnut lip. The difference at playing size
is small, especially beside the untreated pieces. To reproduce the three-way crop,
shoot winter with `board_shot --before` and both branches' default winter, at
1600 × 1200, then crop 440 × 320 at (710, 660).

Mac, 1280 × 800, autumn game, headless. Median waited board pass in ms over three
runs of 300 frames each, rotating the order:

| Build | Median | Range |
| --- | ---: | ---: |
| Before task 094 (8151553) | 2.030 | 1.778–2.033 |
| First experiment (a6052bd) | 2.073 | 1.908–2.214 |
| Shoulder lighting | 1.870 | 1.724–2.019 |

A separate alternating run of 150 frames per sample gave 2.209 ms for the first
experiment and 2.105 ms for shoulder lighting (three samples each). The ranges
in the longer run overlap. The A33 tablet was unavailable over USB.

## Stone pieces and spring marble (2026-11-19)

The stone looks now give the pieces a figure through their whole volume. Winter stone,
summer’s amber granite and autumn’s porphyry use cloudy grain with finer inclusions.
Spring’s pale stone and jade, summer serpentine and autumn jasper use a bent seam.
Its placement varies by piece. The first spring stone and carved boards also caught light
on the rounded frame and soften the partially shaded edge of a cast shadow on pale
squares. Board scattering was set aside because its effect was too slight.

Mac, spring stone at 1280 × 800, three alternating 300-frame runs per build.
The median waited board pass was 1.847 ms with shoulder lighting alone
(range 1.593–2.275) and 1.819 ms with the mineral figure and board lighting
(range 1.144–2.410). This comparison resolves no timing difference.
The A33 was unavailable over USB.

## Material candidates for the next review

- Winter: try honed black slate for the dark men. Start with charcoal, a cool
  edge highlight, faint layering and no scattering. Compare with polished black
  onyx, whose smoother finish could separate it from the dark squares.
- Winter light men: try an ivory appearance, warm cream with very fine figure
  and a satin finish. Compare it with milky white jade on the same board.
- Spring: keep the olive jade and milky jade pair as the first stone set.
- Autumn: compare turned maple and walnut against the original smooth plastic.
  Plastic is the baseline for judging the new materials and starts with SSS off.

## Later review of winter and matching materials

After the spring materials are settled, review the winter board at playing size
and close up against the winter stone reference. Compare its rounded edge and
shadow boundaries with scattering on and off. Try a matching winter piece set
beside the current one.

For a future 3D piece-material preference, Auto follows the selected board.
An explicit material choice lets the player keep a preferred set when changing
boards. The picker is where to try those combinations first.

## Later experiment — wooden pieces

After visual approval of the stone pieces and board lighting, start the wood trial. Then try turned
wood for the wood looks, starting with pale maple and dark walnut on the autumn
board. Compare the grain on the face and cut side at playing size, with the current
autumn pieces alongside. Keep the grain visible at close range and quiet at a distance.

## Acceptance criteria

- [ ] The piece shader scatters light by the looks' strength and tint per material
- [ ] Roughness and tone vary across and between pieces, without banding from afar
- [ ] `board_shot` shoots versions with the values as flags; the chosen ones in the looks,
      with shots of each season before and after in this file
- [ ] No change to the frame's GPU time measurable on the Mac; the A33 checked at the end
