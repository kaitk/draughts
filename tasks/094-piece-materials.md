# 094: The pieces' materials

Status: in-progress (in main, 2026-11-20: built; the A33 and the
before-and-after shots left)

Where it stands (2026-11-20): every look's pieces have their own material, scattering
and wear (`looks::Theme`), shown as settings' Matching pieces; Classic keeps the plain
pieces of before. Autumn's wood board has turned maple and walnut, winter stone ivory
and black marble on a Cloud breccia slab, spring's stone milk and green jade, and the
spring stone board scatters the key light on desktops. Each look compiles only its own
variant of the lit shader. The dated sections below are how it got there; the tools'
flags in them were current on their dates.

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
The Board and Pieces controls select independently. Board default follows the board.
Plastic is the original smooth spring pair. Jade, Wood, Slate and Marble preview the
experiments below. B toggles piece scattering while preserving the cut, roughness,
wear and camera. Tune selects which side’s scattering, texture and roughness to edit.
Dark pieces also have a brightness slider. Drag outside the panel to orbit, scroll to
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

## Directional comparisons (2026-11-19)

The picker’s **Key** control moves both the light and its shadow projection. From
`tools/`, this captures the spring stack with the controls hidden:

```sh
../build/piece_tune --size 640x400 --season spring --material stone --pieces Jade \
    --key left --scatter off --shot ../build/jade-left-off.png
```

Repeat with `--key left|right|game` and `--scatter off|on`. All six local PNGs in
`build/` are 1280 × 800 on the Mac. The jade comparison crops 134 × 141 at (629, 510)
from each full shot. Rows are left, right and game light. Columns are off, on and
absolute RGB difference multiplied by five (discard the screenshot alpha first). The camera, material and shadow are
identical within each row.

Each vertex samples just beneath the surface and traces toward the light to the first
intersection with the disc’s outer wall or cap. The entry angle and distance attenuate
the light. Both faces of a stack contact suppress it. The original jade colors and
figure carry through, including the nearly plain cuts of milk jade. Plastic starts
with scattering and wear at zero.

At playing size the lit side changes subtly, with the seam still visible. The left and
right flanks of the upper disc exchange places in the difference image. Two fixed
15 × 32 pixel patches at (645, 549) and (722, 549) gained about 5.5 and 1.7 grey
levels under the left key, then 2.1 and 4.6 under the right (8-bit scale). Under
the game key the change is easiest to see around the lip. The front contact at
(695, 626) stays at RGB (119, 119, 92) in both game-light shots. That is enough to keep
this as the jade candidate. It does not settle final scattering strengths.

The spring Stone board uses the weathered stone carving bake. Its cavity channel
marks open cuts. The board switch samples that channel a short distance toward the
key. A bank can receive light where there is a hollow upstream. Occlusion suppresses
the response inside the crack. Painted veins have no cavity. Sparse mineral pockets
use a separate volume field and a softer boundary. The switch only affects this board.

The reversed low keys pick up opposite banks of the branching crack on the near
edge. The interior remains dark and the surrounding pigment veins stay quiet.
The first mineral pass drew broad bright patches across the frame. Reducing its
strength from 0.095 to 0.016 leaves a softer, faint response beside the sharper
banks. At playing size this adds too little to keep on by default. Use
`--board-scatter off|on` on spring Stone to repeat it.

### Winter and wood

At the same game light on winter Stone, honed slate keeps a charcoal face and a
legible lip on the dark squares. The onyx face is darker and depends more on a
narrow reflection, especially on the back row. Keep slate with satin ivory as
the winter candidate. The first ivory was peach beside the local *Winter Stone
Checkers Board-2.png*. A cooler cream and less warm scattering bring it closer
to the reference. The white jade comparison still reads colder and milkier.

The reference has a fine steel-blue outline and subdued, felt-like squares. The
picker now gives winter a blue-grey rounded lip with a fine outer line. The
front edge is easier to follow. The frame remains wider and more visibly veined
than the reference, and the field catches a broad sheen on the left. The finish
is the larger remaining difference.

Under the autumn game light, walnut loses some separation from the brown squares
but the lip and side still define the man. Maple stays pale. Both sample growth
rings and pores in local 3D space across the face and turned side. The figure is
quiet enough that the wood pair reads mainly by color at playing size, particularly
on the maple face. Keep it as a picker trial. Plastic rendered identically with
the scattering switch in either position at its default strengths (zero differing
pixels across 1280 × 800).

The full matched PNGs and comparison sheets are local in `build/`:

| Comparison sheet | Contents |
| --- | --- |
| `jade-king-labeled.png` | Fixed stack under low left, low right and game light |
| `marble-labeled.png` | Near spring frame under both low keys, with the difference ×8 |
| `winter-reference-comparison.jpg` | Reference, slate and onyx |
| `winter-jade-ivory.jpg` | Winter board with jade and with slate and ivory |
| `autumn-review.jpg` | Autumn board with maple and walnut, then Plastic |

### Board pass on the Mac

Spring Stone game at 1280 × 800, using the same Goose release and assets for
all three builds. The app arguments were `--size 640x400 --theme birch
--material stone --screen game --board 3d --bench 300`. The enabled measurement
uses a local copy of the renderer with the picker’s board uniform forced on.
Each value below is the app’s waited board-pass time from a 300-frame run.
The order rotated across the three rounds.

| Build | Runs (ms) | Median (ms) |
| --- | --- | ---: |
| `9cbc0ae` | 2.561, 2.522, 2.531 | 2.531 |
| Directional pieces, board scattering off | 2.647, 2.509, 2.648 | 2.647 |
| Directional pieces, board scattering on | 2.702, 2.754, 2.737 | 2.737 |

The default median rose 0.116 ms (4.6%), with overlapping ranges. Enabling the
board experiment added another 0.090 ms to the median. This run does not establish
cost parity with the baseline. The A33 did not appear in `adb devices`, so there
is no tablet timing or visual verdict.

### Jade picker revision

Dark jade starts at brightness 0.65 in the picker. The light jade uses the spring
light square’s sRGB color (0.875, 0.82, 0.77), with texture raised from 0.055 to
0.14. The figure still varies by cut. Board SSS is available on both spring jade
boards, including the default carved board. Its strength runs from 0 to 4 and
survives toggling the effect. It starts at 1 with the switch off.

Print (P) writes a picker command with the current material and lighting values to
the terminal. Copy that line into a session or run it from `tools/` to restore
those values. The Mac captures at 1280 × 800 are `build/jade-tuned-{0,1,4}.png`.
Relative to zero, strengths 1 and 4 changed the mean absolute RGB level over the
whole frame by 0.15 and 0.43 respectively. No tablet was attached.

### Accepted jade settings

The game, picker and board shot use dark brightness 0.65. Light jade keeps the
pale square color with roughness 0.109, figure 0.3 and scattering strength 0.435.
At 1280 × 800 on the Mac the default picker capture matched the selected command
exactly (zero differing pixels). No tablet was attached.

## Board scattering through the stone (2026-11-19)

Board SSS now lights the spring stone squares and frame from the stone's body, not
from its cracks. The Chaos article on V-Ray's SSS materials refused automated fetches
(HTTP 403), so the model follows V-Ray's documented split and the user's Corona jade and
milk dragons instead. In those, the shaded side fills with a saturated body color, the
relief stays legible at low contrast, and thin edges glow. The picker has three
independent controls, and Print writes all three:

| Control | Flag | Uniform | What it does |
| --- | --- | --- | --- |
| Board strength | `--board-strength 0..1` | `frame_map.w` | The fraction of the diffuse light that leaves the body instead of the surface (V-Ray's scatter amount) |
| Board radius | `--board-radius 0.02..0.6` | `frame_map.z` | How far that light travels sideways, in world units (a square is 1) |
| Board color | `--board-color 0..3` | `params.y` | How deeply light that travelled takes the stone's color: the body color to the power 1 + depth, luminance kept |

The squares' body color is the plan blurred over half the radius and seen through
the surface at half the radius deep, refracted. The figure therefore sits under a clear
skin. Each square is its own stone, so near a seam the body color returns to the
surface's. A vein that clearly differs from its blur, darker or paler, keeps its
pigment where the light leaves. The fine mottling keeps 0.4 of its contrast, so the
mean is unchanged. Sparse inclusions in a volume field carry light 60% further and
take a larger share. The spread samples the key's shadow on a 16-tap golden-angle
disc. Each channel weights a tap by its own reach, so the channels the body absorbs
least travel furthest. Light that left near where it entered keeps the body color.
Light from further away takes the deeper color. On the frame, light entering the top
leaves lower on the rounded edge and the side. Only deep occlusion darkens the
response: a piece's contact and the inside of a crack. The thin painted cracks carry no light
of their own. The crack-bank and pocket experiment is removed.

The first disc, 2 × 4 taps with no rotation, drew stepped copies of each shadow edge.
Rotating it per pixel by a hash turned the copies into a sandy grain. The kept form
gives each pixel of a 2 × 2 quad its own quarter turn and shares their results through
the derivatives. A faint grain remains only at radius 0.5 and above. Wider spreads would need a
blurred visibility map of the field, redrawn when the shadow changes, as the pieces'
occlusion is. A body color applied to all the light made the olive look flat and
bright, so the deeper color now applies only to the light that travelled. A
`min(surface / blur, 1)` pigment lost every light speck and darkened the pale squares
by 8%.

Candidate: strength 0.7, radius 0.3, color 1.5. Board SSS stays off by default.

```sh
../build/piece_tune --season spring --material stone --pieces Jade --key game --scatter on \
    --board-scatter on --board-strength 0.7 --board-radius 0.3 --board-color 1.5 --brightness 0.65 \
    --light 0.875,0.82,0.77,0.109 --dark 0.3,0.35,0.21,0.23 --figure 0.3,0.25,0.0,0.55 \
    --wear 0.4,0.6,0.05,0.0 --light-scatter 0.93,0.96,0.89,0.435 --dark-scatter 0.55,0.8,0.4,0.25
```

A printed command replayed at 640 × 400 (1280 × 800 on the Mac) matched its source shot
exactly. With the switch off, the board matched 47f85a6 within one pixel's rounding.
`build/board-sss-{left,right,game}-{off,on}.png` are the full boards at playing size.
`build/board-sss-crops.png` crops 420 × 290 at (140, 470), the front-left frame and
two shadowed squares. Its columns are off, on and on minus off ×5. Its rows are low
left, low right and game light.

- **Spread:** under a low key a warm amber fringe about a third of a square wide lines each cast
  shadow on the side away from the piece. Color 3 turned it orange. Color 0 left it a
  neutral lift.
- **Direction:** under the right key the fringes and the lit frame flank swap sides.
- **Game light:** the short shadows beside the pieces fill with olive. The frame's front
  side glows warm from the light through its top.
- **Dark areas held:** the darkest crack pixels on the frame front moved under 0.5 of a
  level (8-bit) under every key. The darkest 40 contact pixels at the front pieces rose
  2.1 levels under each low key and 0.7 under the game key. Lit square patches stayed
  within 0.5.
- **Lit squares:** under the low keys the lit pale squares brighten slightly. The surface
  term's micro-shadowing dims grazing light, and light leaving the body skips it.

`goose check` of the app and the ngfx build (`scripts/ngfx.py`, local slangc 2026.18.3)
both compile the shader.

Follow-up from the user: a sun-angle slider, when the board gets a tabletop and a
room around it (first a blurred skybox-like surround).

## Warmer milk jade in the board's palette (2026-11-19)

The user kept the board SSS candidate. Beside its peachy cream squares the milk jade read
cool and white: its face was (243, 224, 190) under the game key against the lit pale
square's (233, 209, 171). The look's light jade is now (0.875, 0.8, 0.735), with a warm
scattering tint (0.96, 0.88, 0.81) in place of the green-leaning (0.93, 0.96, 0.89).
The inclusions mix from olive cream (×0.84, 0.83, 0.72) to warm cream instead of
celadon and pink-white. The face now measures (243, 213, 173). A first try at
(0.875, 0.79, 0.68) went butter-yellow at (243, 211, 158).

The light Texture slider now runs to 1.0, and the inclusions' share stops at 1. Past
0.3 it adds the pale squares' thin olive-grey veins, so the approved default 0.3 keeps
its look. At 0.7 the veins read like the squares'. These values are the look's, so the
game, the picker and `board_shot` share them.

## Turned maple and walnut from the board's rings (2026-11-19)

The board's growth-ring generator (BAKE_FRAG's `rings()`, wood model 2) made the
autumn squares read as wood. The Wood pieces' own shells read as tinted plastic beside them.
`piece_wood` now runs the same model in each disc's 3D space:

- **Grain and pith:** the plank's grain lies at the piece's own angle, with the pith
  along it below the face. Quarter-sawn cuts draw near-straight lines, and flat-sawn
  ones lean and draw arches.
- **Rings:** the years are uneven and their radius wobbles, using the squares' ring
  widths (maple 0.05, walnut 0.06). About one year in eight is a dark year, so one
  ring can be followed from the face over the lip and down the side.
- **Fibres, pores and end grain:** fibres and pores run along the grain, and the end
  grain on the turned side takes the finish darker.
- **Color and distance:** the color darkens by Beer's law, as on the squares.
  Detail finer than a pixel fades to its mean.

Walnut has a thin, faint late band, and its rings wander as the walnut squares' do.
Its Texture default is 0.16 and maple's 0.3, scaled ×3 in the shader, so 0.33 is the
board's strength.

Two faults found on the way:

- With `e = 1.5 fwidth(t)` above 0.11, `smoothstep(0.84, 1 - e, ph)` had its edges reversed,
  which is undefined, and drew pale lines on the walnut at playing size.
- A late wood 0.06 smoother than the early wood mirrored the bright background in the
  glossy walnut as stripes. It is now 0.015 smoother.

`build/wood-review.jpg` shows, at playing size under the game key, Wood at 47f85a6,
the new Wood, the autumn board's own pieces and Plastic. `build/wood-closeup.jpg` is
a 760 × 560 crop at (20, 640) of 1920 × 1200 close shots under the game and low left
keys:

```sh
../build/piece_tune --size 960x600 --season autumn --material auto --pieces Wood --key game \
    --near 0.3 --pitch -12 --yaw 18 --shot ../build/wood-new-close.png
```

The picker now takes `--yaw`, `--pitch` and `--near` and prints them when the camera
has moved.

- **Close-up:** the front maple piece's late-wood lines run straight over the face and
  the lip and down the turned side, where the end grain darkens them a little.
- **Between cuts:** grain angles, ring density and the occasional arch differ from
  piece to piece.
- **Walnut on walnut squares:** the walnut pieces are close in tone to the walnut squares.
  The lip, the shadow and the wandering dark lines separate them.
- **Distance:** the grain holds at playing size without banding. Maple reads mainly by
  its color and a faint line.

## Winter slate, onyx and satin ivory (2026-11-19)

On the winter Stone board under the game key, beside the local *Winter Stone Checkers
Board-2.png*, all three read as plastic. The slate was the worst: a uniform grey disc
whose face measured (80, 83, 92) against the reference's charcoal at about (59, 70, 82).
The ivory was white at (239, 235, 230) against the reference's cream at about
(229, 222, 208). The onyx was glossy black plastic. `piece_winter` now gives each
material its own figure and finish in the disc's space:

- **Honed slate:** cleavage layers at 20 to 35 degrees to the face, each piece its own
  way, so the face shows soft tide marks and the turned side slanting strata.
  Level layers drew even rings on the side, close to the tyre look set aside earlier.
  It also has finer laminae and a fine grain. Dark (0.17, 0.195, 0.225), roughness 0.6,
  Texture 0.3. The face now measures (69, 74, 83).
- **Polished onyx:** a few wide, faint curved bands round an axis off the piece, sampled
  0.02 below the surface along the refracted view, so they lie under the polish. Dark
  (0.09, 0.1, 0.115), roughness 0.13, Texture 0.25. The first bands, 38 to a unit and
  bright, drew thin white streaks.
- **Satin ivory:** cream (0.87, 0.835, 0.75), roughness 0.4, with a fine uneven growth
  figure along the slab, drawn out along it and warmer where darker, and a faint cloud.
  Texture 0.08. The face now measures (236, 228, 214).

`build/winter-review.jpg` shows the reference, both pairs at 47f85a6, Plastic, and the
new pairs, at playing size under the game key. `build/winter-closeups.jpg` crops
420 × 320 at (1290, 780) and (330, 110) from 1920 × 1200 shots taken from the dark side:

```sh
../build/piece_tune --size 960x600 --season winter --material stone --pieces Slate --key game \
    --near 0.5 --pitch -5 --yaw 180 --shot ../build/winter-Slate-dark-close.png
```

At playing size the ivory is now the reference's cream, and its figure shows only up
close. The slate is the nearest to the reference's charcoal, and its layering shows
mainly on the side. The onyx separates best from the dark squares but is glossier than the
reference's matte men. Keep honed slate with satin ivory as the winter candidate.
Plastic stays the smooth control.

## Board pass on the Mac, board SSS off and on (2026-11-19)

Spring Stone game at 1280 × 800 with the earlier arguments (`--size 640x400 --theme
birch --material stone --screen game --board 3d --bench 300`), on three builds made
with `scripts/mac.py` from `git archive` trees: 47f85a6, HEAD (0d0291a) with board SSS
off as shipped, and HEAD with `frame_map.zw` and `params.y` forced to the candidate
(radius 0.3, strength 0.7, color 1.5). There were six rounds in rotating order. Each
value is the waited board pass alone from one 300-frame run, in ms:

| Build | Runs | Median |
| --- | --- | ---: |
| 47f85a6 | 5.352, 6.483, 4.030, 3.340, 1.975, 2.485 | 3.685 |
| HEAD, board SSS off | 5.453, 5.684, 5.994, 5.523, 2.108, 2.747 | 5.488 |
| HEAD, board SSS on | 5.911, 2.121, 5.756, 3.924, 3.882, 2.287 | 3.903 |

This run settles nothing. A Virtualization-framework VM (Docker's, by its helpers),
up for 16 days, held a core at 100% throughout. The picker built against the release gfx was
also open and presents every frame. Each build ranged from about 2 to 6.5 ms, against
2.4 to 2.8 ms in the earlier quiet runs. The difference between builds is far smaller than the
spread. One SSS-on run (round 4) stopped after loading the photograph. Two reruns
completed, and the table uses the first (3.924). Repeat the series with the VM and the
picker closed before judging the cost. The board SSS adds 16 shadow taps, two
`textureLod` reads and a hash per board pixel only while it is on. The shipped looks
leave it off. The logs are `build/094-sss-{base,head,on}-{1..6}.log`.

The A33 was not attached (`adb devices` listed nothing), so there is no tablet timing
or verdict.

## Board SSS fixes from the first review (2026-11-19)

The user liked the jade, the white pieces most of all, and asked for their Texture at
0.8. It is now 0.8 in the look. Two board faults:

- **Smears inside every square at a low angle.** The body seen below the surface was
  offset by the view's slope over its height (clamped at 0.25), so at a grazing view it
  reached 0.4 of a square into the next one. It now follows the view refracted into
  the stone (index 1.55), which leans at most 40 degrees, 0.85 of the depth. The deep
  point is also clamped inside its own square.
- **The top looked pasted onto the frame.** The light through the top switched on in
  full where the geometric normal dropped below 0.9, in the deeper tint. It now fades
  in over the rounded edge (normal y 0.98 to 0.55). It starts in the body's own color
  and takes the deeper tint only a radius down.

`build/board-sss-low-angle.png`, before above and after below, and
`build/board-sss-frame-edge.png`, off, before and after, come from
`--size 960x600 --pitch -28 --near 0.62` with the candidate values. The frame crop is
900 × 260 at (0, 930).

## Board SSS on in the game on desktops (2026-11-19)

The user wants the board SSS on for desktops if performance allows. A quiet series:
the VM was still running, but the picker was closed. HEAD with SSS off against HEAD
forced on, eight alternating rounds, `--bench 300` at 1280 × 800 on the Spring Stone game:

| Build | Board pass waited, ms | Median | Frame P50 median |
| --- | --- | ---: | ---: |
| SSS off | 5.39 5.54 5.35 5.15 5.34 5.55 5.46 5.61 | 5.424 | 5.575 |
| SSS on | 5.61 5.78 5.83 5.58 5.76 5.54 5.97 5.92 | 5.771 | 5.910 |

That is +0.35 ms, about 6%. The spread within each build is now 0.5 ms, smaller than the
difference. The logs are `build/094-sss2-{head,on}-{1..8}.log`. The elven spring
look carries `board_scatter {0.7, 0.3, 1.5}` (strength, radius, color), and the
game turns it on only on a desktop (`render3d::scatter_allowed = !mobile`). Phones,
tablets and iOS keep it off until it is timed on them. The picker opens with the look's
values, and `--board-scatter off` or the checkbox turns it off. The app's spring stone
capture at 1280 × 800 differs from an SSS-off build in 6900 pixels, against 300 between
two runs of one build. The strength and radius are still to be tuned by the user. A
printed command's three values go into `board_scatter`.

## Wood pieces with the board's streaks and a varnish coat (2026-11-19)

The user's review of the turned wood: the squares look real and their varnish
natural. On the pieces, the shine was plastic, and some of the added textures didn't
belong on a polished piece. Changes in `piece_wood` and the lighting:

- **The board's streaks.** The fibres are now three widths like `rings()`. The middle
  one (40 a unit across, long along the grain) is the streaking the squares show at
  playing size. Each width fades to its mean below a pixel.
- **Softer, wavier rings.** Maple's late wood starts at 0.6 of the year (was 0.74) and
  is 0.4 dark (was 0.55). It rises less steeply. A finer wobble, as in `rings()`, bends
  each line. The dark years are milder (×0.5 to 2, was up to ×2.15). Walnut's rings
  are fainter (0.3), and its figure is now 0.3 so the streaks carry it, as on the
  walnut squares.
- **Pores filled by the varnish.** They are fainter and no longer rough.
- **Relief under the varnish.** The late wood, the streaks and the pores are sunk by up
  to 1.2/1000 of a unit. This tilts the wood's own sheen through `bumped()`, Mikkelsen's
  derivative bump with no tangents. Its strength is `piece_fig.w`, the picker's Relief.
- **The varnish coat.** A clear coat at index 1.5 and roughness 0.16 lies on the smooth
  shape, with its own lobe and environment term. What it reflects is taken from the wood
  under it, whose own lobe is 0.6 weaker. Its strength is `piece_fig.z`, the picker's
  Varnish. The wood's roughness is now 0.5 for both maple and walnut.

At playing size there is no sparkle at 1:1. Under the low key the highlight on the lip is
crisp, and the figure breaks the satin sheen below it. The preset is `--figure 0.3 0.3
0.6 1`. The images are `build/wood-varnish-{game,left,near}.png`, with before on the left
and after on the right:

```sh
../build/piece_tune --season autumn --pieces Wood --key game
../build/piece_tune --season autumn --pieces Wood --key left --pitch -28 --near 0.45 --yaw 20
../build/piece_tune --season autumn --pieces Wood --key game --near 0.3 --pitch -12 --yaw 18
```

## Winter in black granite, and granite pieces in place of onyx (2026-11-19)

The user's review of winter: the onyx aliased and was bland; the slate was better. They
asked for the board itself in a more complex, lifelike, blacker polished stone, such as
the "black granites", with pieces inspired by it.

- **The granite in the bake.** A stone surface whose ring has a w now carries granite
  crystals (`figure()` in BAKE_FRAG, `crystal()`): Worley cells about 0.018 across, with
  finer ones between them, each crystal its own tone.
  - **Dark stone:** three quarters are black, a fifth are grey feldspar with a soft
    translucent halo, and 3% are bronze flecks, as in black galaxy granite.
  - **Pale stone:** mostly pale, with grey quartz and a few black specks.
  - **Relief:** each crystal's face tilts a little and is flush at its edges, so the
    polish breaks into glints. The rest of the stone's relief is polished away. Before
    that, it mirrored the snowy sky as a grey cloud over the frame.
  - **Grain boundaries:** a thin darker line.
- **`looks::WINTER_GRANITE`** (`winter_granite()`), on winter's photograph and light:
  - polished black granite squares (0.12 sRGB, roughness 0.1)
  - a black granite frame with a polished black rounded edge (it takes its own figure,
    not the chosen marble)
  - pale grey granite squares, honed
  - satin ivory and black granite pieces.

  For now it is the picker's fifth board, granite; it isn't in the app's menus.
- **Granite pieces** (frame_map.y -3, the picker's Granite) replace the onyx. They use
  the board's tones in the disc's 3D space: feldspar with a halo, finer specks, and
  bronze flecks a little glossier. Each fades to its mean below a pixel. Roughness is
  0.18, up from the onyx's 0.13. The 1:1 crops at playing size show no shimmer on the
  lip or groove.

Verdict: the granite board reads as black stone, speckled, its frame and dark squares one
stone. Granite pieces on it are calm black at playing size and speckled up close.
Slate pieces on the granite board are the other good pairing. The slate board is
unchanged. Both renderers build (`goose check`, and `scripts/ngfx.py` with the
goose-ngfx checkout).

`build/winter-granite-review.jpg`: the slate board and the granite board, each with
Slate and Granite pieces, at the game key. `build/winter-granite-closeups.jpg`: the
granite board close under the game and the low left key.

```sh
../build/piece_tune --season winter --material granite --pieces Granite --key game
../build/piece_tune --season winter --material granite --pieces Slate --key game
../build/piece_tune --season winter --material granite --pieces Granite --key left --pitch -28 --near 0.45 --yaw 20
```

## Denser walnut, and black marble in place of the granite (2026-11-19)

The user liked the maple pieces. For the walnut, the relief was too coarse; they wanted it
denser, with the brightness nearer 0.6. They didn't like the granite on either the board
or the pieces. Instead they asked for versions of winter's own board material, in the
look of the black marbles sold as "black granite": a black ground with white veins that
crack and branch (their reference sheet of countertop images).

- **Walnut.** Its streaks are now 80 a unit across (maple keeps 40), so the figure and
  its relief under the varnish are twice as dense. `model3d::dark_brightness` is 0.6 for
  turned wood (mineral -1), which the picker's Wood set starts with. No look in the
  game uses that mineral. `build/wood-walnut-dense.jpg` shows before on the left and
  after on the right.
- **What winter's board is.** The squares are honed slate: pale grey-blue, and dark
  slate with a calm clouding and a few faint veins. The frame is one solid block of
  marble 2, a polished dark grey with soft, wavy, cloudy veins, tinted toward the
  board's steel blue. Its rounded edge is steel blue.
- **The granite is gone:** the crystals in the bake, the look, and the granite pieces.
- **Fracture veins** (`fractured()` in BAKE_FRAG, chosen by `looks::Marble.cracks`, the
  bake's `fracture`). The veins run along cracks, which are the edges of Worley cells in
  a field warped by noise.
  - The cells are stretched about 2:1, 30 degrees off the board's x, so the veins run on
    and branch rather than closing into polygons.
  - There are three sizes, each sparser and thinner than the last, each finer one more
    jagged: the main veins, with a width varying along them and a soft halo; a broken
    finer network; and hairlines.
  - The black has broad soft clouds, and now and then a pale patch where veins gather.
- **Four new marbles:**

  | Marble | Look |
  | --- | --- |
  | 6 | Bold white veins that branch, with a network between them |
  | 7 | A fine grey web with hairlines (Anhara's) |
  | 8 | Cloudy black with soft halos round crisp white veins |
  | 9 | Clear black with a few thin sharp veins, far apart |

  The existing flowing marbles are 1, Nero Marquina, 3, blue-black, and 4, threads.
- **`looks::WINTER_MARBLE`**, the picker's fifth board (marble). Its dark squares and
  frame are cut from the chosen marble, each square its own slab, so the veins break at
  the seams as tiles' do (a stone surface's `ring.w`). The pale squares are winter's
  honed stone. The pieces are satin ivory and black marble.
- **Marble pieces** (frame_map.y -3, the picker's Marble). They use the same fracture
  veins as a sheet through the disc: the face's plan, leaning a little, so a vein runs
  straight on down the side. Each line is at least a pixel wide, fainter where narrower.
- **The picker's Marble slider** (`--marble N`, printed) shows on winter's boards and
  bakes the board again.

Verdict: 6 and 9 come closest to the references; 8 is the softest, and 7 the busiest. At
playing size the veins are sparse enough not to fight the pieces. At 1:1
(`build/winter-marble-1to1.png`) there is no shimmer on the frame's veins or the pieces'.
Spring stone and the winter slate board are unchanged (0 differing pixels). Both
renderers build. The ngfx bake now takes the shown marble (`marble_of`, `stone_of`) and
the carving's pattern, as the gfx bake does: it had passed the chosen marble and 0.

`build/winter-marble-review.jpg` shows marbles 6 to 9 at the game view, and
`build/winter-marble-close.jpg` the same up close.

```sh
../build/piece_tune --season winter --material marble --pieces Marble --marble 6 --key game
../build/piece_tune --season winter --material marble --pieces Marble --marble 9 --key game
../build/piece_tune --season autumn --pieces Wood --key game --pitch -28 --near 0.45 --yaw 20
```

## The marble board set aside, marble pieces kept (2026-11-19)

The user kept the denser walnut. The marble board didn't convince them, and the board
material goes to a separate attempt, with the user's reference sheet saved locally as
`build/black-marble-references.png`. Winter's board is back to its slate and marble 2
frame, pixel-identical to before. Removed: `looks::WINTER_MARBLE`, marbles 6 to 9, the
fracture bake (`fractured()`, the bake's `fracture`), and `Marble.cracks`. Commit d2f5f85
still holds them. Kept: the ngfx bake passing the shown marble and the carving's pattern,
and the picker's Marble slider for the winter frame (marbles 0 to 4).

**Marble pieces, tuned on the slate board.** Each piece now has its own share of veins,
and some are nearly clear. The main veins jitter at a finer scale, so they kink as cracks
do. Each vein has a faint halo, so it lies in the stone rather than on it. The finer
veins appear only near a main vein, in short lengths. This replaces the even network
that read as cracked glass up close. `build/winter-marble-pieces.jpg` shows playing size
and the close view:

```sh
../build/piece_tune --season winter --material stone --pieces Marble --key game
../build/piece_tune --season winter --material stone --pieces Marble --key game --pitch -28 --near 0.45 --yaw 200
```

The user then asked for the veins to be much fainter. The Marble set's dark Texture
starts at 0.2, down from 0.5, so the veins are about 40% as bright. The image was taken
again at 0.2.

## Handover (2026-11-19)

Winter pieces candidate for now, the user's (honed slate with a lower roughness, ivory):

```sh
../build/piece_tune --season winter --material stone --pieces Slate --marble 2 --key game --scatter on --board-scatter off --brightness 0.6 --light 0.87,0.835,0.75,0.4 --dark 0.17,0.195,0.225,0.305 --figure 0.08,0.3,0.0,1.0 --wear 0.4,0.6,0.05,0.0 --light-scatter 0.93,0.9,0.83,0.24 --dark-scatter 0.62,0.6,0.62,0.0 --yaw 51.348 --pitch -5.016 --near 1.0
```

It is not yet in `looks::winter()`, which still shows mineral 1 pieces. Open, for the
next session: the winter board material in the look of black marbles, see the
section above; marble pieces with sliders for how their veins are made, and the user
found Texture 0.9 better there; and alabaster for the light pieces.

## Winter black marble slabs (2026-11-19)

The Marble slider has four more positions for winter stone. Each dark square cuts
the same stone at its own angle and offset. The frame takes one continuous cut.
The bake lays a narrow branch alongside a kinked seam, opening the gap between
them and tapering both. Grey shoulders give the wider mineral pockets depth.
The width of a bake texel sets the coverage of the finest threads.

| Marble | Verdict at the board |
| --- | --- |
| 5 · Calcite forks | Closest to the large reference. Small white pockets punctuate the front rail, and the thin branches leave room for the pieces. |
| 6 · Silver web | Best for play. Grey forks remain visible through the middle ranks without competing with the ivory men. The close view shows the finer crossings. |
| 7 · Cloud breccia | Broad, smoky pockets with dark slivers inside. The richest close view, though the pale patch on the right draws the eye during play. |
| 8 · White lightning | The sparsest cut. A few sharp white seams stand out across nearly clear slabs. The branching is easiest to see up close. |

From `tools/`, these commands reproduce both views for each numbered stone.
Omit `--shot` to open the picker. The local contact sheet is
`build/winter-marble.jpg`, in slider order with playing size on the left.

```sh
for n in 5 6 7 8; do
  ../build/piece_tune --season winter --material stone --pieces Marble --key game \
    --marble "$n" --size 960x600 --shot "../build/marble-$n-game.png"
  ../build/piece_tune --season winter --material stone --pieces Marble --key game \
    --marble "$n" --size 960x600 --pitch -20 --near 0.6 --shot "../build/marble-$n-close.png"
done
```

The Mac saved 1920 × 1200 pixels for the 960 × 600 window. The 1:1 center crops in
`build/crops.png` show the thin branches fading into the ground and the darker
inclusions inside the broad seams. Against the parent commit, ImageMagick's AE was
0 pixels for default winter stone and 0 for spring stone, both with Marble pieces
and the game light. The app passed `goose check` and the ngfx app built with Slang.
The USB tablet check is pending. `adb devices` listed no device.

### Tuning the slabs

Select winter stone and Marble 5 through 8 to tune the frame and dark squares
together. Base brightness changes the black ground. Vein strength changes the
contrast of the whole pattern, down to plain stone at zero. Spacing and width
control the distance between seams and their thickness. Branch strength adjusts
the crossing veins, Cloud pockets adjusts the pale deposits, and Polish adjusts the
finish. The Pieces selector stays available above the board controls.

The picker remembers each slab separately until it closes. Reset marble restores
the selected preset. Press P to print the command with all seven settings. A Mac
capture replayed from a printed custom Silver web command matched at AE 0, as did
the untouched Silver web preset against its original playing-size shot.

### Winter stone default (2026-11-19)

Winter stone now uses the tuned Cloud breccia with ivory and slate pieces (black marble
pieces since 2026-11-20, "In the game" below). The dark pieces have roughness 0.3. The
picker opens on the board sliders; choose Dark or Light to edit the pieces.
From `tools/`, this opens the chosen setup at the saved viewing angle:

```sh
../build/piece_tune --season winter --material stone --pieces Slate --yaw 7.594 --pitch 4.068
```

At 960 × 600 points the default and the explicit settings with dark roughness
0.3 matched at AE 0. The local capture is `build/winter-chosen.png`.

The Mac game benchmark used three runs per build, 300 frames per measurement,
at 1280 × 800 physical pixels with shadows. The command arguments were
`--size 640x400 --theme stone --material stone --screen game --board 3d --bench 300`.
The change includes the new live piece shader as well as the baked board.

| Waited frame time | Previous winter | Cloud breccia and slate |
| --- | --- | --- |
| P50 per run, ms | 3.47, 3.28, 3.34 | 3.31, 3.33, 3.03 |
| P99 per run, ms | 5.72, 7.88, 6.38 | 7.41, 6.59, 7.00 |

Median frame time stayed within the run-to-run spread. The tail was noisier.
No USB tablet was connected for this measurement.

The edge review found two independent effects. Winter board scattering was already
zero. The ivory pieces now have zero scattering too. The frame had a steel-blue
edge tint and a pale line around the top. Both are off so the marble continues
around the curve. The Mac comparison is `build/winter-rim-comparison.jpg`, with
the revised frame on the right. Vein strength still starts at 0.55 for mobile
review. No USB device was attached.

## Acceptance criteria

- [x] The piece shader scatters light by the looks' strength and tint per material
- [x] Roughness and tone vary across and between pieces, without banding from afar
- [ ] `board_shot` shoots versions with the values as flags; the chosen ones in the looks,
      with shots of each season before and after in this file
- [ ] No change to the frame's GPU time measurable on the Mac; the A33 checked at the end

### In the game (2026-11-20)

Settings' Pieces row on the 3D board chooses each look's own pieces ("Matching", "Laua
moodi") or the pieces as before this task ("Classic", "Tavalised"; `looks::smooth`).
Winter stone's own are the Marble set, ivory and black marble with faint veins
(`looks::marble_pieces`), chosen over the honed slate; autumn's wood board's the turned
maple and denser walnut (`looks::turned`).

### Getting ready on a phone (2026-11-20)

With the pieces' materials, winter's slab and the table, the Pixel 7a took 3.0 s to get
the 3D board ready (main: 1.6 s), nearly all of it in two compiles: the bake pipeline
1.4 s (main 0.85) and the lit pipelines 0.45 + 0.41 s (main 0.09 + 0.08). Mali compiles
every branch, and LIT_FRAG had gone from 3 `noise3` call sites to 36. Now each look
compiles only its own variant (`docs/decisions/rendering.md`), and the table's bake
bands are skipped without a table. Pixel 7a, two runs each, the steps' time in all:

| | Before | Now |
|---|---|---|
| Autumn, wood pieces | 3.0 s | 1.9 s |
| Autumn, classic pieces | | 1.8 s |
| Winter stone | 2.9 s | 1.85 s |
| Spring stone | | 1.9 s |
| Autumn on the table | 3.5 s | 2.8 s |
| Winter stone on the table | 3.2 s | 2.8 s |

The bake's compile is back to main's 0.85 s; the lit pipelines take 0.15 to 0.19 s each
for the wood pieces, 0.13 and 0.09 for the classic. The table adds its bake's compile
(0.7 s) and its bands. Mac shots of every look are within 3 levels of 255 of before.
