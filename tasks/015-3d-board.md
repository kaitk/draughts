# 015: The 3D board

Status: todo

A 3D board from the same game state (`docs/product.md`, after the MVP: Looks), on the
title menu first and as a setting for play. Start simple: the board floats in front of
the season's scene with a soft shadow under it, with no room or table to model
([rendering](../docs/architecture/rendering.md#scene-and-glass)). The scene photographs
already exist (task 014 sharpens them).

## Prototype first (the user, 2026-11-08)

A small prototype before anything in the app: one program, the board and a fixed
position, a camera that a drag can turn for inspection, nothing of the shell. It should
look good, not merely work.

- **Where:** native Goose and goose_gfx on the Mac (`poc/3d/`, as `poc/` keeps task 001's
  and 005's programs), so its shaders and passes are what ships and it runs on the
  tablet early to measure. Not WebGL: nothing of it would carry over.
- **The look:** the 3D reference (`~/Downloads/ChatGPT Image Nov 7, 2026, 08_19_31
  PM.png`, `agents/design.md`) and the close-ups beside it: good materials (wood, the
  pieces' satin and gloss), specular where it belongs, soft shadows and self-shadowing
  (the pieces' lips and the crown's deboss), ambient occlusion, and antialiasing.
- **No temporal effects** (no TAA, no temporal accumulation or upscaling): the best
  that a single frame can do. The app draws only on change, so a static frame must be
  clean by itself, with nothing to converge.
- **Methods to weigh in the prototype**, measured on the tablet:
  - Ambient occlusion: a modern SSAO (GTAO-style, with a spatial-only denoise) against
    the analytic disc and frame occlusion planned below. The geometry is known exactly
    (discs on a plane), so analytic is exact and cheaper; SSAO earns its place only for
    detail analytic misses.
  - Antialiasing, the cheapest that looks clean, as options to compare: analytic edges
    (the 2D board's SDF coverage, carried to the few silhouettes: pieces, the frame),
    SMAA 1× (single frame), or MSAA 4× (cheap on a tile-based GPU, resolved in tile
    memory, but maybe overkill here); check which holds up. Not FXAA (the user,
    2026-11-08: too blurry, not modern). Specular antialiasing (roughness
    widened by the normal's variance) either way, so highlights don't shimmer.
  - Shadows: a soft shadow map (PCF or PCSS) for the pieces, drawn only when the position
    changes, since the scene is static between moves.
  - Few full-screen passes: mobile GPUs pay for bandwidth, not math.
  - Surface detail: normal and roughness maps for the wood (grain, pores, the late wood
    catching the highlight differently) and the pieces' satin. Real depth (the seams,
    the inlay, the pieces' recess and lip, the crown's deboss) as geometry or parallax
    occlusion mapping; tessellated displacement wouldn't show at this distance.
- **Code and methods reference:** Spartan Engine (github.com/PanosK92/SpartanEngine, open
  source, C++) for clear rendering code and current methods; a desktop engine with
  global effects, so its ideas, not its frame structure. The bar: Carmack should be
  pleased, not horrified. Flat data, fixed buffers, nothing allocated per frame, every
  pass justified by a measurement.
- **Further references** (more from the user to come):
  - Filament (google/filament) and its "Physically Based Rendering in Filament": a PBR
    renderer built for mobile; shading model, specular antialiasing, image-based light.
  - Wicked Engine (turanszkij/WickedEngine) and its blog: open source, clean, each
    technique explained.
  - GTAO: Jimenez et al. 2016, "Practical Realtime Strategies for Accurate Indirect
    Occlusion".
  - Íñigo Quilez's articles on analytic occlusion and soft shadows of simple shapes.
  - Specular antialiasing: Kaplanyan and Tokuyoshi's normal-variance roughness.
  - Karis 2013, "Real Shading in Unreal Engine 4": split-sum lighting from an
    environment (the season's photograph).
  - Sebastian Aaltonen (sebbbi), a primary source (the user, 2026-11-08): his years on
    HypeHype's renderer for low-end Android phones (what potato GPUs have and need:
    bandwidth, tile memory, few passes, which features to rely on), his writing on a
    graphics API without the API (the idea behind goose-ngfx), and Petafab, his SDF game
    on it (high-end, so its ideas, not its requirements). Before the prototype starts,
    dig through his posts on X and elsewhere, his blog, and talks for what applies here:
    a small static scene, single-frame quality, mobile first. Record what was taken and
    from where.
  - The user's own digging into his work, mostly unpushed: the local repos
    `~/projects/goose/goose-ngfx` and `~/projects/goose/goose-nogfx` (their notes), and
    the Claude Code sessions about them from about October 2026, in Claude Code's
    project folders for `goose-ngfx`, `goose-nogfx`, and `goose-nogfx-prototype` (some
    may be under another Claude account; ask). Read these first.
  - Arm's Mali best practices for MSAA resolved in tile memory.
- The user has more to add later; the prototype starts with these (2026-11-09).

### Settled before building (the user, 2026-11-09)

- **Kings:** a stack whose upper disc carries the debossed crown; a plain stack and a
  crowned single disc become options later. The prototype starts with whichever is
  easier.
- **Background:** the season's photograph blurred, as behind the 2D game now.
- **Scope:** autumn wood, 8 × 8, first; winter stone in the same prototype once autumn
  looks half decent.
- **Camera:** two modes to try: an inspection range around the default view, and a free
  turn round the board. (In the game later, the board may turn by itself for hot seat
  play.)
- **Budget:** about 11 ms a frame at native resolution, and a 4× MSAA target's memory
  is acceptable. Visuals first, tuned afterwards; a rough baseline on the device early.
  Built and judged on the Mac first; measured on the tablet (the Pixel 7a was
  briefly in its place).
- **MSAA needs a gfx patch to be cheap:** goose_gfx stores all of a multisampled target's
  samples and its depth when a pass resolves (`gfx_draw.c`), about 74 MB written per
  frame at 1920 × 1200. A patch resolves without storing the samples and discards the
  depth. SDL already resolves inside the render pass, but its targets take real memory
  (no transient attachments).
- **Research** (sebbbi's HypeHype talks, Arm, Filament, the user's goose-ngfx notes):
  analytic occlusion first; MSAA 4× with shader-side edges for the seams and the crown;
  Filament's specular antialiasing; one 16-bit shadow map with hardware PCF, drawn on
  change; one forward pass with the tonemap in it, no depth prepass and no post pass;
  SH9 and a prefiltered octahedral map from the photograph; no `discard`. If GTAO is
  compared, use HypeHype's: half resolution, 12 samples, a 4 × 4 bilateral blur and
  upscale.

## Prototype

`poc/3d/` (2026-11-09), a first step and three look passes: the autumn and winter
boards and the 3D reference's position (one light king, one light piece selected), with
the pipeline the method comparisons will hang off. The app will show a king one way or
the other, never both (the user, 2026-11-09): a plain stack of two discs, the default,
or one disc with the crown debossed in its recess; `--king stack|crown` and K switch.

```sh
cd poc/3d
../../build/goose-v2026.4-macos-arm64/goose build -o ../../build/board3d board3d.goose
../../build/board3d                                 # a drag turns; Tab or a double click switches mode; R resets
../../build/board3d --theme winter --king crown     # T or a long press switches the theme, K the king
../../build/board3d --wood 3 --theme winter --marble 1   # W cycles the wood, M the winter frame's marble
../../build/board3d --panel                         # the tuning panel shown (P toggles it, V prints)
../../build/board3d --shot out.png --size 1920x1200 [--yaw 20 --pitch 40]   # one frame, headless
../../build/board3d --bench 1000 --size 1920x1200   # frame timing, headless
../../build/board3d --frames 200                    # the window's loop hidden, a drag, T, K and a long press injected
../../build/board3d --frames 40 --panel --theme winter   # the panel worked by injected input instead
../../build/board3d --bench 300 --samples 1 --shadow-every   # 1× MSAA, the shadow map every frame
cd ../.. && scripts/android.py poc/3d/board3d.goose --run       # on the tablet, beside the game (its own id)
adb shell am start -S -n io.github.kaitk.draughts.board3d/io.github.kaitk.draughts.DraughtsActivity --es args "'--bench 300'"
```

Since phase 2 of the integration (below) the program is a thin one over the renderer the
app shares, `src/render3d/` (meshes, shaders, themes as `looks`, the bake, the shadow map,
the pass); it keeps the camera, the input, the fixed position, and the bench. It compiles
`src/app/background.c` from where it is (`board3d.build`) for the photograph.

- **Frames:** the shadow map (2048², 16-bit, the board and pieces from the key light) only
  when the position changes; then one forward pass into a 4× multisampled RGBA8 target
  with depth, resolved into gfx's screen: the blurred photograph as a backdrop, the
  board's soft shadow on nothing (a catcher plane under it, distances to its rounded
  outline), the board and the pieces lit, the selection's glow ring added. No post pass,
  no discard, nothing temporal. Drawn only when the camera or the window changes.
- **Geometry**, built once at startup: a piece is a profile turned on a lathe (72 steps:
  a top sampled from one smooth height function, as the reference's pieces: a flat band
  from where the edge rounds at 89% of the radius in to 69%, one step down of 0.02,
  crisper at its top with a narrow cove at its foot, which gives the reference's dark
  and light lines round the inner disc, the flat inner disc inside 63%; the side, a
  round at the foot); the frame is a profile swept round the field (an inner wall, the
  top, a bullnose of 0.09 squares, the side down to 0.7 under the field). Pieces are 88%
  of a square across and 33% of their diameter high, their side as tall as the
  reference's at the same framing (column profiles through a near piece: 21 pixels
  against 22; the 2D board's are 78% across). The pieces are one instanced draw from a
  storage buffer.
- **The crown** (`--king crown`): a polygon of eleven points and three balls traced from
  the reference's king, in units of the radius, 1.06 across and 0.86 tall, centred in
  the recess, filled with the crown's color, its walls sloping in, a thin lighter lip
  round it. Its distance's derivatives are taken over the whole top: a branch on the
  radius left specks where a pixel quad straddled it.
- **Surfaces**, baked on the GPU into albedo-and-roughness (sRGB) and normal textures
  with mips, at startup and again on a theme change: a plan of the field (2048², the
  light and dark squares each its own stretch of grain and tone, seams, the dark inlay)
  and a frame map (2048² over 10.4 world units). Grain is noise drawn out along it, no
  sines; the autumn frame adds open pores (dense fine dashes along the grain) and thin
  dark late-wood lines near the screen's pixel at the default view, roughest in them,
  with stronger relief, so it no longer reads like modelling clay; finer pores than
  that vanish in the mips. Stone is the same noise round, a calm clouding with a few
  faint veins (lighter in dark stone, darker in pale), its roughness following them.
  The pieces' figure is noise in the shader, not baked.
- **The frame's two constructions**, per theme (the user, 2026-11-09): mitred, four
  pieces glued at 45°, each with the grain along its side and its own band of the map,
  a thin joint on each diagonal through the top, the edge and the side; or one solid
  block with the field carved out, the figure running along x over the whole board.
  Either is mapped from the world position (along, and how far out plus how far down),
  so the figure runs on unbroken over the top, the rounded edge and the side and round
  the corners. v1 took the sweep's UVs, whose length along the path shrinks to nothing at
  the inner wall: at the corners the grain fanned into arcs and broke at the side
  switch, the artefacts on the right front corner. Autumn is mitred (the reference reads
  like mitred cherry), winter one block of stone.
- **Themes** are data (`src/render3d/looks.goose`, first `poc/3d/theme.goose`): a flat struct of colors, roughness, figure,
  the frame's construction and edge, the key light, the pieces' bounce, the ambient and
  the backdrop's grade, read by the one bake and shaders. `--theme autumn|winter`; T, or
  a press held 0.6 s within 12 pixels for touch (gfx has no multi-touch events), switches:
  the surfaces rebaked into the same targets, the other photograph decoded, blurred into
  the same target and its harmonics taken, about 40 ms, nothing allocated per frame.
- **Shading:** GGX with Filament's correlated Smith and Schlick, wrap diffuse, Filament's
  specular antialiasing on every material, 16 hardware-compared shadow taps on a fixed
  grid, nine spherical harmonics of the blurred photograph for the ambient (computed on
  the CPU at load, part way to grey by theme, specular through Karis's DFG fit),
  analytic occlusion (each piece in the 3 × 3 squares round as a cylinder, the frame's
  inner wall), micro-shadowing on the field only, the lit board's light on the pieces'
  sides, the Khronos PBR Neutral tonemap with its toe halved (it crushed the darks'
  blue). A piece's top takes its normal and occlusion from its height function at the
  object-space radius, not from interpolants: with MSAA and no `centroid`, those
  extrapolated past small triangles and left specks in the old groove.
- **Backdrop:** the blurred photograph graded per theme (gain, saturation, bright
  patches lifted into bokeh, a lift toward a tint low down, where the reference has a
  surface under the board).
- **The whole picture** (a pass on the reference's overall look): the dark pieces' turned
  sides take the finish darker than their faces, near black as in both references; the
  shadow taps spread wider for softer shadows; the frame a satin sheen (roughness 0.52)
  and less saturated; less ambient against the key for more contrast; a soft vignette
  on the backdrop so the board stands out, under the lift low down. The board's contrast
  is still under the reference's (a luma spread of 45 against 60).
- **The third pass** (the user's notes, 2026-11-09): the pieces' profile and the crown
  above; the autumn frame rougher (0.7, its pores and lines rougher still), its rounded
  edge polished smoother (0.3 less), so the sheen gathers on the right edge's curve, not
  over the flat top, its color kept at the reference's (front top 165, 85, 37 against
  172, 88, 32); the key light from the upper left and further behind (z -0.4, winter
  -0.55), as the reference's shadows fall, which also lights the step's far wall as
  there; less of the board's bounce on the light pieces' sides. Winter's stone is
  honed and softly polished (roughness 0.32 to 0.45), its dark squares and dark pieces
  darker than the reference's, toward the 2D board's (the dark pieces' faces 55, 61,
  80 against the reference's 71, 79, 92 and the 2D #2b3440; the dark squares about 60,
  70, 88 against 64, 81, 102), autumn's dark pieces darker and less orange (98, 56, 28
  on the face); the pale line on winter's frame edge left out after a side by side, the
  steel-blue round kept. Cost unchanged: 4.9 to 5.7 ms a frame against 4.8 to 5.7
  before, interleaved, the same measure as below (the GPU's clocks make it noisy).
- **The fourth pass** (the user's notes, 2026-11-09): the jaggies on the pieces' step
  were shading aliasing, not geometry: MSAA shades once per pixel and triangle, and the
  step, a function of the object-space radius, turned its normal sharply inside a
  pixel (a 2× supersampled render had none). The step's slope is now averaged over the
  pixel's footprint in the radius (1.5 × its screen derivative, four pieces of it), its
  occlusion too, and the four normals' spread widens the roughness (Toksvig's 1 − r over
  r, added to Filament's variance term), which also took the glints off the far dark
  pieces' step; the crown's wall tilts only its share of a pixel and widens the
  roughness the same way. No more rings or sample-rate shading needed. The autumn
  frame's late wood is now furrows: two contours of a noise drawn out along the grain,
  each a groove 2 to 4 pixels across at the default view (at least a texel soft in the
  2048² bake), with finer, shallower ones between, broken into lengths, rougher and
  darker inside, deeper relief, and a cavity occlusion baked into the normal map's
  blue; its alpha holds the normal's y, so the mips' shortened normal widens the
  roughness at a distance. The mitred pieces' texture gradients now follow each piece's
  own axes (the sides' were taken along the wrong one). Cost: 5.0 to 5.2 ms a frame
  against 5.0 to 5.1, interleaved; the bake about 30 ms either way.
- **Wood models:** growth rings with pores replaced the noise drawn out along the grain;
  task 039 compares four, switched with `--wood N` and W. Winter's frame can be one of
  four marbles instead of the slate, `--marble N` and M (task 039).
- **Tuning panel** (2026-11-09; `poc/3d/panel.goose`, Mac only, a tool): P shows gfx
  ui's sliders over the board: the wood's model, varnish, sanding, grain contrast, ring
  scale and warmth (`looks::Finish`), and the marble, its veins' contrast, waviness,
  polish and tint (`looks::Marble`). The values live in the look data
  (`src/render3d/looks.goose`), per wood model and per marble, so the app bakes the
  same; `render3d::tune` bakes again only what they show on (the wood's surfaces where
  the look has wood, the frame map where its frame is stone), when they settle: on the
  slider's release, or after 0.35 s held still. Drawn only while shown and only on
  input or a change: the board goes into the kept image, and the panel's frames cost
  its copy and the ui. Print (or V) writes the values as Goose literals to stdout, to
  paste into `looks::finish` and `looks::marble`; Defaults takes the model's own again,
  Plain the finish off. `--panel` opens with it shown; `--plain` starts without the
  finish; `--save-maps PREFIX` writes the baked frame map and plan to PNGs, to see a
  figure flat. Checked through `--frames 40 --panel` (P twice, a drag on varnish and its
  release, one bake, Print, M); `panel_frames.png` in the session's shots.
- **Camera:** 52.5° down, a 31° field of view, 14.75 away, fitted to the reference's
  field corners, so the board fills the height of the frame as there.
- **Tuned** against the references with patch means at the same framing (`--size
  1448x1086`, the references' size): squares, frame, pieces and backdrop within about
  10 of the references' sRGB means in autumn and winter, except the backdrops, which
  are other photographs.
- **Measured** on an M1 Pro, 1920 × 1200, headless: about 0.2 ms of CPU a frame, about 7
  ms a frame with a wait for the GPU after each (an upper bound, submission and wait
  included); setup 50 ms warm, 0.3 to 0.8 s cold. After the second pass (the frame
  map, the themes): about 7.3 ms against v1's 6.7 on the same measure, setup 50 ms.
- **Not yet:** the store-op patch on the Mac (its prebuilt gfx still stores the samples
  and the depth; Android's gfx has `patches/goose_gfx/0005`), SSAO, SMAA and analytic
  edges to compare, taps hitting squares. The backdrop doesn't turn with the camera.

### Measured on the tablet (2026-11-09)

Galaxy Tab A11+ (SM-X230, Mali-G615 MC2, Vulkan), 1920 × 1200 landscape at 90 Hz, the
default view, autumn, the first pass. A first rough baseline before any tuning; each figure the median
of three launches (one for 1× without the patch), each launch's own figure the median
of 300 frames.

| Frame, the camera turning | CPU | CPU + GPU, waited | Presented, frame to frame |
| --- | --- | --- | --- |
| MSAA 4× (as built) | 0.42 ms | 14.0 ms | 13.9 ms |
| MSAA 1×, into the screen | 0.39 ms | 10.9 ms | 11.0 ms (the 90 Hz vsync) |
| 4×, the shadow map every frame | 0.56 ms | 16.0 ms | 15.8 ms |
| 4× without `0005` | 0.42 ms | 17.2 ms | 17.1 ms |
| 1× without `0005` | 0.40 ms | 11.1 ms | 11.0 ms |

| At rest, after launch (`dumpsys meminfo`) | GL mtrack | EGL mtrack | Total PSS |
| --- | --- | --- | --- |
| MSAA 4× | 234 MB | 67 MB | 392 MB |
| MSAA 1× | 182 MB | 67 MB | 341 MB |
| 4× without `0005` | 306 MB | 67 MB | 466 MB |

Startup: the wood's bake 0.68 s (making its pipeline included), the photograph 42 ms
(the ASTC upload, the shrink and two blurs, the read back and the harmonics), setup 0.73
s in all; the first frame 0.21 s, nearly all of it making the pipelines; the shadow map
about 2 ms.

- **How:** `--bench 300` on Android opens the full-screen window, draws 30 frames to let
  it settle, then times 300 frames with the yaw stepping each frame: `clock()` round
  `draw` (the CPU's recording) and round `draw` plus `gfx::flush()` (a submit and a wait
  on its fence: the GPU's time plus the submission's, since the GPU idles while the CPU
  records), then 300 frames through `gfx::frame()` as the loop draws while dragged.
  `--samples 1` draws straight into gfx's screen with a single-sampled depth;
  `--shadow-every` redraws the shadow map each frame. Without `0005`: the APK built once
  with the patch set aside in a copy of the build's patches. GPU counters weren't read:
  `gfxinfo` sees only Java views (`agents/testing.md`).
- **What costs:** the forward pass itself, 10.9 ms at 1×, already the whole budget of
  about 11 ms; MSAA 4× adds 3.2 ms, the shadow map 2 ms on the frames that draw it.
- **`0005` measurably helps on this Mali:** without it MSAA 4× costs 6.3 ms instead of
  3.2 (the samples and the depth written out, about 74 MB a frame), and it holds 72 MB
  more, the multisampled targets cycled into a second copy. 1× is the same with or
  without it.
- **Renders as on the Mac:** a screenshot of the default view matches the Mac's 4× shot
  (shadows, the crown's deboss, the glow, no banding or artefacts); nothing failed only
  on Android.
- It installs as `io.github.kaitk.draughts.board3d`, beside the game (`scripts/android.py`
  gives a program other than the app its own id).

### The game screen round the 3D board (2026-11-09)

`prototypes/game3d.html` draws the board in WebGL2 with the native camera under the
game's UI, its image scaled and shifted in clip space so the perspective stays the
native one at every size. In perspective the board's bounds are about 1.45 times as wide
as tall and its far edge about 70% of its near edge, so game.html's square, made for the
2D board, leaves a band above and below it. The board's bounds per take, in CSS px:

| Take | 1280 × 800 | 800 × 1280 | 412 × 915 | 915 × 412 |
| --- | --- | --- | --- | --- |
| `now`, game.html's layout | 720 × 495 | 752 × 517 | 376 × 258 | 376 × 258 |
| `steep`, the camera 65° down | 720 × 580 | | 376 × 303 | |
| `top`, one column in landscape, the board up in portrait | 944 × 649 | 752 × 517 | 376 × 258 | 547 × 376 |
| `corners`, the panels beside the far edge | 985 × 677 | 752 × 517 | 376 × 258 | 547 × 376 |
| `bleed`, sized by the field, the frame off screen | 914 × 594 | | 400 × 260 | 579 × 376 |

In landscape the corners take nearly doubles the board's area (1.9× on the tablet, 2.1×
on a phone) and keeps the two panels, home and start over on the left and the play on
the right, now short glass panels in the top corners. In portrait the width holds the
board in every take, so pushing it up only moves the empty band below it; a steeper
camera (about 60 to 65°) is what fills the height there. Not yet: a phone's cutout in the
safe area, the clocks, and the board's glass under a panel.

**Chosen** (the user, 2026-11-09): the current UI doesn't suit the game screen round a 3D
board, though it is fine on the other screens, where nobody touches the pieces. The game
screen takes `corners` in landscape. Portrait is still open; the steeper camera is the
proposal.

**Camera controls** (asked 2026-11-09, prototyped on `game3d.html?take=corners`): round
48 dp buttons with no panel for the view (52.5° or 74° down), zoom (to 1.3×, the far rows
under the panels) and tilt (a drag on the button, springing back), the board refitting
each frame, placed two ways (`&controls=a`, `b`), with `&pp=` for portrait's angle and a
hot-seat turn of 180° in 0.7 s; for the user to choose.

## Integration (on the `integrate3d` branch, off `main` until the game is solid)

### Phase 1: what doesn't depend on the renderer (2026-11-09)

- **Camera and picking** in `src/board/view3d.goose`, a file of the `board` package: the
  code layout keeps the 3D board's math in `board/` (docs/architecture/README.md), and it
  is the 3D counterpart of `board::hit` and `board::center`, working on the same
  `board::Board` and `board::Layout`. `view3d::View` is the prototype's camera (52.5°
  down, 31°, 14.75 from (0, -0.15, 1.1)) with its fit in pixels: a point at view x, y,
  depth d lands at c + k (x / d, -y / d), the prototype's clip-space scale and shift;
  `view3d::matrix` gives the clip matrix for any screen size. The field is always 8
  world units across, so 10 × 10's squares and pieces are 0.8 of 8 × 8's. A turn
  (`view3d::turned`) keeps the fit. `view3d::pick` turns a tap into a point on the flat
  layout the board package plays on: a ray against each piece as a cylinder (top and
  side; the selected piece lifted and grown, a stack two discs high, a piece waiting on
  its stop), else the field's plane; while a piece is held, the plane of its lifted top,
  the finger's offset kept (`game::Game.grab`), so a drag carries it under the finger.
  The world follows the flat layout's x and y, so a turned board (`Layout.flip`) turns
  the 3D one with the light kept on screen. `test/board/view3d`: five taps on every dark
  square (its middle and near its corners) on 8 × 8 and 10 × 10, at rest, turned 20°,
  at 75° turned -35°, and turned round, all on their squares; just inside the field's
  corners and on its edges; just off it no square; a lifted man's face and a stacked
  king's top picking their square where the field under the tap is the light square
  behind (0.72 and 0.87 squares behind), turned round too; the matrix against the
  projection.
- **The scene from the game's state:** `view3d::fill` maps the flat board's draw list
  (`board::fill`, after `game::cheer`) to the prototype's storage buffer, two float4s an
  instance (foot and scale; dark, crown or upper disc, selected or lower disc, seed), a
  stack as two; a parallel `state` buffer carries what the prototype's position lacked
  (opacity, must-capture ring, glow ring, selected glow, then `board::Piece.win`); the
  field's occlusion squares (top, foot, radius, occupied); the last move, targets, stops,
  and flash in the world's grid; the selected piece's foot and radius for the glow ring;
  the win's dim. A 2D lift maps by 1.1% of the board to 0.07 (the selected lift), a
  radius by the disc's 0.39 of a square. So moves, hops, drags, fades, and the win
  animate as in 2D. `test/board/scene3d`.
- **The `corners` layout** in `panel::corners_in` (`src/game/panel.goose`, beside the
  flat layout it replaces; the task asked for `gui`, but the game screen's layout lives
  in `game/panel` and `gui` has no board): landscape panels 232 × 352 dp in the top
  corners (192 wide under 600 dp), the board's largest share of the safe area less the
  margin, at its bottom, whose outline (the hull of the frame's corners and kings' tops)
  clears both panels by 12 dp, found by halving. The panels' tiles are the flat game
  screen's; take back keeps its tall tile in a short corner panel but on a phone. In
  portrait the flat order, the board as wide as the safe area less 24 dp each side. The
  board package plays on a flat square of the bounds' height in their middle
  (`panel::Layout.board`), what the 3D world maps to. Numbers (`test/game/corners`, dp):
  the tablet landscape 898 × 616 (the prototype's 985 × 677, whose panels were 16 dp
  shorter and gap measured less strictly), 876 × 600 with its navigation bar; portrait
  752 × 516; a foldable 628 × 430 landscape; 4:3 693 × 475; a 20:9 phone at 540 dp 718 ×
  492, 656 × 450 with the Pixel 7a's cutout; at 480 dp 620 × 425; a 9:16 phone at 480 dp
  414 × 284 (346 × 237 with insets), all 1.46:1, the far edge 69%, every tile in its
  panel and the safe area at 88 dp, the board inside the safe area off the panels.
- **Portrait's camera** is `panel::PITCH_PORTRAIT`, 52.5°. Steeper (same test): on the
  tablet the board goes from 752 × 516 to 752 × 570 at 60° and 752 × 604 at 65° (the far
  edge 69% → 74% → 77%), the screen used 888 → 942 → 976 of 1280 dp; on a 20:9 phone at
  540 dp 337 → 373 → 395 dp tall. Width still holds the board; a steeper camera only
  fills more of the empty height. Open with the user.
- **Wiring:** `settings::raised` (the Board row's 3D with `--3d`; the 3D tile now takes
  the tap) makes the game screen use `corners_in` and `view3d::pick`
  (`shell::game_layout`, `game::frame`); kings' auto is a stack there
  (`settings::raised_king_look`). `--3d --board 3d` plays a run on it. In phase 1
  `src/app/draw3d.goose` was a stub drawing the flat board in the flat square.
  `test/game/corners` plays c3–d4 by projected taps and drags f6 to e5 through the
  shell. `--3d` and `show_board_row` stay.
- **Draw on demand:** `view3d::changes` against the last scene drawn: DRAW when anything
  the 3D board shows differs (view, instances, state, marks, flash, occlusion, dim),
  SHADOW too when the instances do (a piece moved, lifted, appeared or went). The app
  draws only on change already; the 3D pass is the expensive part of a frame (about 11 ms
  on the tablet), so a frame that changes only the UI (a clock's second, a pressed tile)
  should not draw it (phase 2 below).

### Phase 2: the renderer in the app (2026-11-09)

- **`src/render3d/`**, a package the app and the prototype share: `mesh.goose`,
  `shaders.goose`, and `looks.goose` (the prototype's `theme.goose`, renamed so its
  namespace doesn't meet the app's `theme`) moved from `poc/3d/` as they were;
  `render3d.goose` holds what `board3d.goose` did: setup, a theme applied (the bake, the
  photograph and its harmonics, the frame's block), the pieces placed, the shadow map
  and the forward pass drawn into gfx's screen or a kept image. It is the one package
  besides `app/` that imports gfx (docs/architecture/README.md). `poc/3d/board3d.goose` is
  now its camera, input, position, and bench over it; its default frame is the same as
  before the move but for 30 pixels of the selection's ring (headless shot against
  `b4024b5`'s, `magick compare`), now drawn by the field's marks pass.
- **Any board size:** the field is 8 world units across on 10 × 10 too; the bake's plan
  takes the squares per side (`Bake.mode.z`), the field's occlusion too
  (`Frame.params.w`), so 10 × 10 is the same board with smaller squares and pieces.
- **The field's marks**, as the flat board draws them, in one additive pass over a quad
  covering the field, after the lit meshes and tested against their depth, from a
  storage buffer a float4 a square (`view3d::Scene.field`, filled with the scene): the
  last move's squares tinted, a target's dot, a stop's ring, the must-capture ring
  (pulsing every 1.4 s, its strength worked out on the CPU so the scene changes while it
  pulses), and a wrong move's red flash twice; the selected piece's glow ring round it,
  wherever it is. The red rings sit at 0.52 of a square, out from the 0.44 piece, so each
  pixel looks at the squares round it; their width comes from the grid's own derivative,
  not the ring's distance, which jumps at the squares' edges and drew bright seams there.
  The prototype's GLOW_FRAG gave way to it.
- **Choosing the wood in the game** (2026-11-09): the app's `--wood N` (0 to 3) and
  `--marble N` (0 the slate, 1 to 4), beside `--3d`, pick the 3D board's wood with its
  finish and the winter frame's marble, to try 2 and 3 on the real board:
  `../../build/draughts --3d --board 3d --wood 3`.
- **In the game** (`src/app/draw3d.goose`): set up the first time the 3D board shows,
  its look from the app's theme (stone the winter stone, the rest autumn wood for now)
  and the photograph the theme's own, baked again on a theme or board size change. Each
  drawn frame fills the scene; when `view3d::changes` says so, or the size or theme
  changed, the pieces are placed (a captured piece fading shrinks into its square, the
  pass being opaque) and the board drawn into the kept image, the shadow map only when
  the pieces moved; then the screen's pass copies the image and the UI and its pieces
  are drawn over it as on the flat board (`draw::pieces_over`). A frame that changes only
  the UI costs the copy. A `--frames` run of the app prints how many frames showed the
  3D board, drew it, and drew the shadow map: a selection and its targets at rest drew it
  once in 200 frames.
- **Checked** headless on the Mac (a local copy of the app opening `gfx::open_headless`,
  never committed; `agents/testing.md`): the selection and targets at 1280 × 800, a
  must-capture ring and a wrong tap's flash, 10 × 10 in winter stone and in portrait at
  800 × 1280, round the corners panels. Not on the tablet yet.
- **Memory** behind `--3d`: the renderer's targets come on top of the flat board's, made
  once (the four 2048² baked surfaces with mips, about 85 MB, the 2048² shadow map, the
  4× target and its depth, and the kept image the screen's size), and the photograph is
  decoded a second time for its blur and harmonics. To measure on the tablet.

### Open

- Portrait's camera (above).
- The rule that only `app/` imports `gfx`: the shared renderer is a package that does.
- The win's card is placed on the flat square, not the 3D bounds; the drag threshold is
  measured on the flat layout, near the screen's pixels in the board's middle only.
- Home, settings' preview, puzzles, and the transitions into and out of the game still
  show the flat board; a transition switches between the two boards at its ends.
- Not drawn in 3D yet: the win (the dim, the lit squares, the winning piece's lift are
  in the scene, not in the shaders), a hint's glow ring, the ghost of a piece slid back
  (it shrinks as a captured piece does).
- The seasons without a 3D look (spring's birch, summer's sunset) take the autumn wood.

## Later, only if the floating board falls short

- **A painted backdrop and a real table.** The camera barely moves (about 50° down), so a
  full 360° sphere isn't needed: one blurred backplate of a room or forest, made for a
  fixed camera, and a table mesh in the foreground with a generated wood texture. A
  sphere only if the camera comes to orbit.
- **The look of the 3D design board**, studied 2026-11-07:
  - Light: a warm key from the upper left and behind, short soft shadows to the lower
    right, a cool ambient fill, rim highlights on the pieces' top bevels, a low-contrast
    warm grade.
  - Board: veneer squares (light maple with fine straight grain, dark walnut with wavier
    figure), each square its own grain sample, thin dark seams, a satin finish (roughness
    about 0.5); the playing surface recessed inside a dark inlay border.
  - Frame: cherry or oak with a rounded bullnose edge, its grain following each side,
    about 1/18 of the board's width.
  - Pieces: cream and matte (about `#f1ddb8`), height about 22% of the diameter, rounded
    edges, a recessed inner disc at about 65% of the radius with a raised lip; dark
    pieces walnut and a little glossier. A king is two discs with a visible seam and the
    crown debossed in its face.
  - Shading: a contact shadow ring at each piece's base and along the inner frame edge;
    the selection an emissive ring on the board, targets emissive dots.
  - Camera about 50° down, field of view 30 to 35°, the background blurred.
- **How to draw it cheaply**: forward rendering with one directional light and an ambient
  taken from the background; one soft shadow map for the pieces (the board is static);
  analytic disc shadows instead of SSAO, with occlusion baked into the meshes; lathe
  meshes for pieces and an extruded frame profile; procedural wood (ring distance plus
  turbulence) into an albedo, roughness, and normal atlas at build time or startup;
  GGX specular with wrap diffuse; glows as additive decals, no bloom pass; a mild
  tonemap.

## Acceptance criteria

- [ ] The 3D board drawn natively from the game state, floating in front of the scene
      with a soft shadow, with the theme's colors and the key light
- [ ] Taps hit the right squares through the perspective
- [ ] Draws nothing while idle, as the 2D board

## When 3D lands

Still needed after phase 2: the open points above (home, settings' preview, puzzles,
and the transitions with the 3D board, or a decision that they stay flat; the win in 3D;
looks for spring and summer; the card on the 3D bounds), the tablet's frame times and
memory with the game on the 3D board, and draw-on-demand checked there with
`scripts/idle_cpu.sh`. Then show settings'
Board row again: remove `Settings.show_board_row` (`src/shell/settings.goose`)
and the `--3d` flag (`src/app/draughts.goose`, `docs/development.md`), make the board follow
`Settings.board`, and update `docs/architecture/rendering.md`' Settings paragraph and
`test/shell/settings.goose`.
