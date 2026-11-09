# 015: The 3D board

Status: in-progress

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
../../build/board3d --theme spring --spring 1       # G switches spring's look: 0 the birch, 1 elven stone, 2 Baltic oak (task 041)
../../build/board3d --shot out.png --turn 180       # the board turned under the light, as the hot-seat turn
../../build/board3d --panel                         # the tuning panel shown (P toggles it, V prints)
../../build/board3d --summer 2 --panel              # summer's variant, 0 to 5 (S cycles; tasks 039, 041); the app takes --summer N too
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
  four marbles instead of the slate, `--marble N` and M (task 039). Spring has a second
  look, elven carved stone, `--spring N` and G (task 041).
- **Tuning panel** (2026-11-09; `poc/3d/panel.goose`, Mac only, a tool): P shows gfx
  ui's sliders over the board: the wood's model, varnish, sanding, grain contrast, ring
  scale and warmth (`looks::Finish`), and the marble, its veins' contrast, waviness,
  polish and tint (`looks::Marble`), and spring's look with its carving's depth, scale
  (repeats per side), moss, stone warmth and jade depth (`looks::Carving`, task 041,
  baked again through `render3d::carve`), and since the carved looks (task 041) the
  carving's motif, amber and lichen, each carved look with its own defaults
  (`looks::carving_for`). The values live in the look data
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

**Chosen** (the user, 2026-11-09): placement `a`, the column at the right edge (`b` stays
reachable by `&controls=b`); keep View (52.5° and 74°); Zoom in landscape only; the board
turns 180° in hot-seat games; 65° at rest in portrait (`&pp=65`, the default). Revised
after that: zoom frames the whole playing field, every square and the pieces' tops, as
large as fits the area clear of the panels and the button column (in the top view too);
the third button is a showcase mode, not a tilt: while on it is lit and a drag anywhere on
the board turns it (±35°) and tips it (35° to 80° down) instead of moving pieces, with no
spring back; pressing it again, or a move, eases back to rest in 0.6 s. Settled for the
app (the user, 2026-11-09): turning the showcase off keeps the angle and play goes on
through it; a new game or a hot-seat turn puts it back; while the board is off its rest
angle the view button wears a small gold dot and its tap eases back to rest first; the
buttons 56 dp with a 44 dp disc on a tablet, 48/40 on a phone in landscape, 52/42 in
portrait; the light stays put on screen through the hot-seat turn.

**Decided** (the user, 2026-11-09): Showcase only toggles dragging and keeps the angle; View is the reset (off rest a tap eases back, then top, then rest) with a gold dot on it while off rest; a new game or hot-seat turn resets the angle; buttons 56 dp touch / 44 disc on a tablet, 48 / 40 on a phone in landscape, 52 / 42 in portrait.

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
- **Portrait's camera** was `panel::PITCH_PORTRAIT`, 52.5°. Steeper (same test): on the
  tablet the board goes from 752 × 516 to 752 × 570 at 60° and 752 × 604 at 65° (the far
  edge 69% → 74% → 77%), the screen used 888 → 942 → 976 of 1280 dp; on a 20:9 phone at
  540 dp 337 → 373 → 395 dp tall. Width still holds the board; a steeper camera only
  fills more of the empty height. Now 65° (the camera controls, below).
- **Wiring:** `settings::raised` (the Board row's 3D; the 3D tile now takes the tap) makes the game screen use `corners_in` and `view3d::pick`
  (`shell::game_layout`, `game::frame`); kings' auto is a stack there
  (`settings::raised_king_look`). `--board 3d` plays a run on it. In phase 1
  `src/app/draw3d.goose` was a stub drawing the flat board in the flat square.
  `test/game/corners` plays c3–d4 by projected taps and drags f6 to e5 through the
  shell. `--3d` and `show_board_row` stayed until 3D landed (below).
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
  `--marble N` (0 the slate, 1 to 4) pick the 3D board's wood with its
  finish and the winter frame's marble, to try 2 and 3 on the real board:
  `../../build/draughts --board 3d --wood 3`. `--spring N` likewise picks spring's
  look (0 the birch, 1 the elven carved stone, task 041):
  `../../build/draughts --board 3d --theme birch --spring 1`.
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
- **Memory** on the 3D board: the renderer's targets come on top of the flat board's, made
  once (the four baked surfaces with mips, about 85 MB, now 70, the shadow map, the
  4× target and its depth, and the kept image the screen's size), and the photograph is
  decoded a second time for its blur and harmonics. Measured on the Pixel 7a below.

### Measured on the Pixel 7a (2026-11-09)

Pixel 7a (Tensor G2, Mali-G710 MC7, Vulkan, Android 17), 2400 × 1080 landscape, the
display at 60 Hz (its setting; 90 Hz is off), the game on the 3D board in autumn
(`--board 3d --screen game --theme wood`), International and Russian. Each frame
figure the median of three launches, each launch's the median of 300 frames (the app's
`--bench 300`, docs/development.md, "Time the 3D board"); memory two launches each, 8 s
after the launch, `dumpsys meminfo`. Before is `e279c86` with only the bench added.

| | Before | After |
| --- | --- | --- |
| GL mtrack, 3D, International | 348 MB | 202 to 218 MB |
| GL mtrack, 3D, Russian | 340 MB | 210 MB |
| GL mtrack, the 2D board | 42 MB | 42 MB |
| EGL mtrack (the swapchain), both | 71 MB | 71 MB |
| Total PSS, 3D, International / Russian | 466 / 457 MB | 313 to 328 / 321 MB |
| Total PSS, the 2D board | 147 MB | 143 MB |
| The theme applied at launch (bake, photograph) | 2.57 s | 0.76 s |
| of which the bake, its pipeline made | 2.53 s | 0.71 s |
| The first frame, its pipelines made | 0.30 s | 0.31 s |
| Frame with the shadow map, waited: International / Russian | 16.3 / 14.0 ms | 15.8 / 14.0 ms |
| The pass alone, waited: International / Russian | 14.0 / 13.1 ms | 14.0 / 13.0 ms |
| Frame's CPU (scene and recording) | 0.3 to 0.5 ms | 0.3 to 0.5 ms |
| Presented, frame to frame | 16.6 ms | 16.6 ms |
| Idle at rest, 30 s (`scripts/idle_cpu.sh`) | | 0.03% CPU, 30 wakeups |

- **What changed**, International's GL mtrack after each step: the bake no longer clears
  its targets: SDL cycled each new, cleared surface into a second copy kept for good
  (348 → 262 MB). The 3D pass's depth 16-bit instead of 32 (enough between NEAR 2 and
  FAR 40, the marks still drawn), and the shadow map 1024² with its taps as far apart in
  the world as at 2048² (262 → 236). A mitred frame's map baked only over its four
  bands, 2048 × 1152 (236 → 218; its bake 75 → 43 ms warm). Bake time: the wood was
  compiled once per call site, four surfaces and three taps a texel for the normal;
  one call in a loop the compiler doesn't unroll took making the bake's pipeline from
  about 2.4 s to 0.6 s (warm bakes: the plan 100 ms, the frame map 43). Headless shots
  at 2400 × 1080 (autumn, winter, turned) against `e279c86`'s: the bake's change and the
  depth's identical (PSNR 87 to 97 dB, the maps texel for texel), the shadow map's 54
  dB with no difference visible in crops at 200%, the frame map's 84 dB.
- **The frame isn't faster**, and nothing glaring was found: what the pass costs, waited,
  International, each part left out once: all 14.3 ms; an empty pass (the clear and the
  resolve, the submit and the wait) 5.1; the backdrop alone 8.5; the board and pieces
  alone 13.8; without the pieces 12.0; without the shadow catcher 13.9; without the marks
  13.9. The lit meshes are the cost; the full-screen backdrop is mostly hidden under them
  (Mali's forward pixel kill). The waited figures carry about 5 ms of submit and wait, so
  the GPU's own time is under them; at 60 Hz the frame holds the vsync when the phone is
  cool. Warm (thermal status 2), presented frames rose to 18 to 25 ms before and after
  alike.
- **MSAA 4× against 1×**: 1× (`samples` 1, straight into the kept image) saved 47 MB at
  32-bit depth and no measurable time (the pass 14.3 ms either way). 4× stays: it is
  affordable here. SMAA wasn't tried.
- **Tried and left:** the plan's normal map in RG8 saved 11 MB but cost a second compile
  of the bake's pipeline (gfx makes one per set of target formats), 0.37 s at launch. The
  photograph's two blur intermediates freed after use changed nothing measurable (they
  sit in SDL's shared 16 MiB block). Specializing the bake per wood model saved 30 ms.
  Only the mips used: the levels below 256² hold under 2% of the memory.
- **Map sizes by screen:** not changed. The Pixel 7a's landscape board is about 1290 px
  across (656 dp at 1.97 px a dp), its field's near edge about 1120 px, so the 2048² plan
  is 1.8 texels a pixel there and 1024² would magnify it. A 720p phone would take 1024²
  (about 60 MB less); not measured, as there is no such device.
- **Rebased onto the 3D screens, summer's and spring's looks** (`e974ace`, Russian, two
  launches each): autumn GL mtrack 212 MB, the theme applied in 0.79 to 0.84 s (the
  bake 0.75 to 0.79, warm the plan 105 ms and the frame map 44); spring's carved stone
  (`--theme birch --spring 1`) 212 MB, 0.85 to 0.89 s (the bake 0.81 to 0.85, warm the
  plan 146 ms and the frame map 77). Headless shots of autumn, winter (marble 2), summer
  0 to 3 and spring 0 and 1 against `e974ace`'s: 53 to 55 dB each, the shadow map's
  difference, none visible in 200% crops of the frame's corner (the carving, the seams,
  the pickling, the marble all as before).
- **The carved looks** (task 041, 2026-11-09): the Mac's warm bake for elven and amber
  about 54 ms against the birch's 24, Baltic 35; the Pixel's not measured (not
  connected). The bake's pipeline is larger by the folk band's and the signs' SDFs.
- **The user's values (2026-11-09)**, now the looks' defaults (`src/render3d/looks.goose`):
  each look has its own wood model and finish, `--wood` and W still override. Summer
  (look 3) and its amber stone (`--summer 4`, look 7) wood 2 with `TUNED`; the amber's
  carving `AMBER_TUNED` (motif 2, scale 3, lichen 0.085); spring's default is now the
  Baltic oak (look 10, `SPRING_LOOK` 2, motif 2 amber signs) and the elven stone
  (look 9) the alternative, both wood 3 with `SPRING_FINISH` (varnish 0.335, sanding 1).
  Spring's flags: `--spring 0` the birch, 1 elven, 2 Baltic (the default); G cycles them.
  Winter (marble 2) and autumn (wood 2, `TUNED`) unchanged. Only winter's frame reads the
  marble (carved and wood frames don't), so the panel's marble lines don't matter for
  summer or spring.
- **After moves:** GL mtrack at rest after c3–d4 on Russian 219 MB against 210 at launch.
- **What's left:** the 3D board on top of the flat board's memory is still about 160 to
  175 MB: the surfaces 70 MB, the 4× target and its 16-bit depth about 60, the kept
  image 10, the rest the driver's and the photograph's. The lit shader's cost (16 shadow
  taps, the field's occlusion over 3 × 3 squares) is where frame time would come from.

### Phase 3: every screen (the `screens3d` branch off `3d-board`, 2026-11-09)

- **Home and settings' preview:** each screen gives the board a room (`home::frame`'s and
  `settings::frame`'s `room3d`): home across its stage less 40 dp each side (24 in
  portrait), as tall as the flat board below the chip's and the way out's row, or the
  flat square where that leaves under half of it; settings 94% of the page beside the
  choices. The shell fits the 3D view there, as large as it fits and in its middle
  (`shell::raise_in`), the flat square in the bounds' middle (`view3d::square`, which
  `panel::corners_in` uses too). On the tablet home's board is 760 × 521 dp (the flat one
  560 square), settings' 506 × 347 in landscape and 692 × 474 in portrait. Behind home and
  settings the sharp photograph, as the flat board has: the renderer now draws the board
  on clear (`render3d::draw`'s `backdrop` false), and the app lays the image over its own
  photograph (`draw::photo`) or the renderer's graded backdrop (`render3d::backdrop`,
  behind the game and a puzzle), `render3d::show` placing it.
- **Puzzles:** the game's corners layout (`shell::puzzle_layout`), next the shorter tile
  in a corner panel (STACK_H; the tall one ran past the 352 dp panel), turned for black to
  move as the flat board is; taps and drags through the perspective, shared with the game
  (`game::touch`). The hint's glow ring and a win's are drawn in the field's marks pass
  from a second buffer a square (`view3d::Scene.lit`: x the ring, y a win's lit square).
  A captured piece and a wrong move's ghost now fade instead of shrinking: the fading
  instances go last and are drawn blended one at a time (`render3d`'s `fading` pipeline,
  Draw.z the alpha, Draw.w the instance), casting no shadow.
- **The win:** the dim in the frame's `screen.z`, the board and the pieces dimmed but the
  winning one, whose seed is `view3d::SEED_LIT` more (the shaders take it off again for
  its figure); the glow passing lights the squares and rings the pieces. The card is
  centered in the 3D bounds on screen and keeps clear of the winning piece's top as the
  perspective shows it (`game::card_area`, `game::winning_spot`); on the tablet it sits
  in the lower half, 304 × 269 dp.
- **Transitions:** the three the flat board has (home and settings, home and the game,
  the puzzles' tile and a puzzle) move one image. It is drawn once through the larger
  end's view (the game's, 898 wide, against home's 760) and then only moved and scaled
  between the ends' bounds (`shell.place`); a tile end fits the bounds into the tile's
  square and crossfades (`shell.fade`). The scene is filled on the drawn view's flat
  square, so it doesn't change while the image moves; `draw3d::frame` draws again during
  one only for another view or board (`hold`, `which`). Headless, `--go settings --hold
  0.5` drew the 3D board once in 3000 frames, `--go puzzle --hold 0.5` once in 2999. The
  UI's hole is the image's bounds (`shell.tall` its height).
- **Spring and summer** in `looks.goose`, from the theme table and `prototypes/boards.html`'s
  3D boards: spring's pale birch (a faint figure, rings and pores barely there) with the
  dark squares the same birch stained sage `#6b7f6a`, a green-stained frame, cream and
  dark green pieces, a cooler key; summer's peach and dusky rose squares under a satin
  lacquer (roughness 0.35, almost no figure, as the flat board's plain sheen), a red-brown
  frame, cream and plum pieces, a warmer, lower key. The app picks each season's look
  (`draw3d::look_of`); the prototype takes `--theme spring|summer`.
- **Hot seat** against a friend kept today's board then; the 180° turn came with the camera
  controls (below).
- **Tests:** `test/shell/screens3d` (home's board and settings' preview at eight sizes,
  inside the screen and clear of every tile; a puzzle's right move tapped through the
  perspective, a wrong move's ghost and flash, the hint's ring after two misses, a black
  puzzle turned; the win's card inside the 3D bounds and clear of the winning piece, the
  dim leaving one instance lit; home to the game drawn through one view with the flat
  layout steady; a tile to a puzzle fading in). `test/shell/settings` now shows the preview
  stacked and 3D where the row and 3D are chosen.
- **Checked** headless on the Mac at 1280 × 800 and 800 × 1280 (the local headless copy,
  never committed): home, settings in portrait, a puzzle in portrait, the win, the game in
  the four seasons. Not on the tablet.

### The camera controls (the `camera3d` branch off `3d-board`, 2026-11-09)

The user's decisions of 2026-11-09 (above, "Chosen"), built natively on the game screen
and a puzzle:

- **The camera as data** (`src/board/rig.goose`, `rig::Rig`): five eases (the view 0 to
  1, the zoom 0 to 1, the board's turn in degrees, the showcase's swing and tilt), each a
  value easing from one end to the other, cubic in and out, read at any moment; the
  buttons' taps, the showcase's drags (0.3° a dp, ±35°, 35° to 80° down), and the
  hot-seat turn (`rig::face`, 180° more each time over 0.7 s, put at once the first
  time) only set them. `view3d::Camera.turn` turns the board about the field's middle
  under a camera and a light fixed on screen (the camera spun the other way round,
  `view3d::spin`, exact at 0), apart from the showcase's yaw about the target.
- **Fitting it** (`panel::aim`, each frame from the shell's `game_layout` and
  `puzzle_layout`, and again after the screen's frame so a tap shows at once): at rest
  the rest view as `corners_in` made it; else the board at the view's angle and the turn
  placed as `corners_in` places it (the halving in landscape, so it shrinks mid-turn to
  clear the panels: 744 × 609 dp at 113° on the tablet against 898 × 616), the zoom
  blended in (k, c, and the rect, linearly), then the showcase's angle on top, keeping
  the fit. The flat square the board package plays on stays the rest view's: the shell
  keeps the screen's own layout at rest (`shell::raise`), the drawn view's square only in
  a transition. Picking goes through the drawn camera, as `test/board/view3d` checked at
  any angle.
- **The buttons** (`panel::camera`, `gui::floating`, the UI shader's `FLOAT` quad and
  icons 32 to 36): landscape a column of three under the play panel, 12 dp below it at
  the right edge, or a row where the column runs past the bottom margin (every phone in
  landscape); portrait two (view, showcase) between the board and the play at the right
  edge, a row where a column would shrink the board (the foldable, 4:3, the 9:16 phone).
  `corners_in` keeps the board clear of them; the tablet's landscape board is unchanged
  (898 × 616 dp), portrait's is now 752 × 604. A dot on the view button while off the
  rest angle, the showcase button lit while on. No accessible labels yet: the app has no
  accessibility layer to give them to, so none went into `strings/`.
- **Zoom**: the field's outline (`view3d::outline`'s `field`: its corners and a lifted
  king's top over each) as large as fits the box, bottom aligned, clear of the panels and
  the buttons by a quarter gap, found by halving (`panel::zoomed`); the column's strip
  isn't cut out of the room, or in the top view the zoom came out smaller than no zoom on
  the foldable. 1.15 times the scale on the tablet (the field 917 × 613 dp), 1.11 to
  1.19 elsewhere, in the top view 1.11 to 1.16.
- **Showcase**: while on, a press off the UI goes to the camera (`rig::drive`), never to
  the board; off keeps the angle; a move tapped through it plays (`test/game/camera`). A
  new game (`game::start`, `game::restart`) or a hot-seat turn eases it back.
- **Hot seat**: once a friend's move has shown (`!b.moving`, no piece held, no winner),
  `game::frame` faces the board to the side to move; the light turns with the board
  (`render3d::turn_light`, `light`), so it stays at the upper left of the screen, and the
  shadow map is drawn again on each frame of the turn. Against the computer `rig::face`
  is never called; the flat layout's turn keeps the child at the bottom.
- **Draw on demand**: the camera moving changes the view, so the 3D pass runs only while
  an ease runs (`game::animating`, `puzzle::animating` include `rig::moving`): the view
  button's 0.6 s drew 35 frames and then none, the move and the turn together 41.
- **Tests**: `test/board/rig` (the view cycle, the dot, the showcase's range and the angle
  kept, the zoom, the hot-seat turn and its put), `test/game/camera` (through the shell:
  the buttons, the view and its redraws, the zoom at rest and in the top view, a showcase
  drag moving no piece, the angle kept and a move through it, the turn for black and
  black's move tapped through it, a new game turning back, no turn against the computer,
  a puzzle's buttons), `test/game/corners` (the buttons at every size and inset inside
  the safe area and off the panels and the board, the zoom's field inside its room and
  clear, portrait at 65°, a drag through the turned board).
- **Checked** headless on the Mac (the local copy, never committed, with a temporary flag
  setting the rig): the tablet's landscape at rest, turned for black (`--fen B:...` faces
  it at once), the top view zoomed, a showcase angle with the dot, and portrait. Not on the
  tablet.

### The pulsing marks off the 3D pass (the `pulse3d` branch off `3d-board`, 2026-11-09)

A must-capture ring's pulse, a wrong move's flash, and a hint's pulsing ring changed the
scene every frame, so the lit, multisampled, shadowed pass ran on each frame they showed,
the most expensive thing the app does on a tiler.

- **Kept apart:** the board's pass draws only the marks that hold still (the field shader
  without `PULSE`); the pulsing ones are drawn each frame over the kept image, in the
  screen's pass right after `render3d::show` lays it, by the same shader with `PULSE`
  (`render3d::marks_over`): one additive quad over the field, through the camera's matrix
  moved and scaled with the image (so a transition carries them too). Their phases are a
  uniform (`view3d::Scene.pulse`: the rings' pulse phase, the flash's progress, the
  hint's square and strength); the field buffer only says where (a ring 1 pulsing or 2
  still, the flash's square). `view3d::changes` gives MARKS when only the phases moved,
  and `draw3d::frame` then just takes them: no fill of the GPU's buffers, no 3D pass. So
  the flat board does it: its flash's square and progress and the time are its pass's
  uniforms, and its pass is cheap.
- **Occlusion:** the screen's pass has no depth target and the multisampled depth is
  never stored (`0005`), so the board's pass, when marks pulse, also draws the board and
  the opaque pieces' depth into a kept 1x 16-bit target (vertices only, no shading; made
  the first time marks pulse, 5 MB at 2400 × 1080), which the shader tests at the pixel's
  middle. Drawing the rings in the image at a fixed phase and only modulating them would
  not do: the flash's ring grows as it flashes, and the image's alpha has no room for a
  mask. Four taps mixed as the 4x samples (nine fetches) matched the old rings worse than
  one test (150 pixels off by more than 4 levels against 300), so it is one.
- **Matching:** headless shots with the clock held (a local copy, never committed: the
  clock fixed until the taps, then a fixed lag), before and after, the ring and the flash
  mid-phase (`--fen W:Wc3,h2:Bd4,a7 --tap h2`, Russian, 1280 × 800): 293 pixels differ,
  143 of them by 1 to 4 levels (the ring added after the resolve rather than per sample),
  150 by more, all on the pieces' outlines where a ring passes behind (at most 112, one
  pixel). Settings' preview with its held flash: 28 pixels by more than 4. A transition
  held at 0.5 carries the ring with the image, hidden behind its piece as at rest.
- **Frames:** that run, 3000 frames while the ring pulsed: before, 3000 drew the 3D board;
  after, 1, and 2999 drew only the marks. `test/board/scene3d`: from the mistake to the
  pulse's end at 20 fps, 51 frames change only the marks and 2 draw the board (the
  flash's end and the pulse's; the flash's end drew twice before, its square and its
  progress compared apart). A hint's pulsing ring likewise, drawn in the board's pass
  once still.
- **Measured** on the M1 Pro headless, 1920 × 1200, `--bench 300` (a fourth phase: a
  ring round every piece): a pulsing frame was the pass, 3.0 ms waited, and the screen's
  part, about 0.5; now the screen's part with the rings, 0.75 ms waited (0.49 without
  them), and the kept depth, 0.84 ms waited, only on the frame the board is drawn. Not
  measured on a device: the tablet was attached, not the Pixel 7a.

### Open

- The rule that only `app/` imports `gfx`: the shared renderer is a package that does.
- The drag threshold is measured on the flat layout, near the screen's pixels in the
  board's middle only.
- The pulsing marks' frame time on a device: the Pixel 7a wasn't attached when they moved
  out of the 3D pass (the tablet was), so only the Mac's numbers are in.
- Between screens the switches that aren't transitions (settings and the game or a
  puzzle) draw the board again through the other view, once.
- Spring's and summer's looks were judged headless only, against the prototype's 3D
  boards, not beside the user's reference images or on the tablet.

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

Landed in main on 2026-11-09, once the user said merge: settings always shows the Board
row and every screen follows `Settings.board` (`settings::raised` is `s.board ==
RAISED`); `Settings.show_board_row` and the `--3d` flag are gone, `--board 3d` opens a
run on the 3D board; the docs and the settings tests count the Board row's tiles.
`poc/3d/` (its keys W, M, S, G, T, K, P, V and panel), the looks' flags, and the HTML
prototypes stay.

### The release on the tablet (2026-11-09)

The release (`--release`, the upload key) installed over the tablet's
`io.github.kaitk.draughts`, its player's profile kept and on the flat board; the test
builds `.threed` and `.board3d` uninstalled. A game (Russian, c3–d4, the camera turned to
black's side) and a puzzle (21) drew on the 3D board with `--board 3d`, which leaves the
profile's files alone. Idle 30 s with `scripts/idle_cpu.sh`, memory with `dumpsys
meminfo` at rest:

| SM-X230, 1920 × 1200 | Idle program thread | Wakeups | GL mtrack | EGL mtrack | Total PSS |
| --- | --- | --- | --- | --- | --- |
| 2D, home | 0.03% | 30 | 37 MB | 60 MB | 145 MB |
| 3D, a game | 0.27 to 0.30% | 30 | 193 MB | 32 MB | 287 MB |
| 3D, a puzzle | 0.27% | 30 | 179 MB | 46 MB | 286 MB |

The 3D board's idle wakeup, once a second as the flat board's, costs about 2.7 ms of CPU
against 0.3: not yet looked into (perhaps the scene filled and compared each wakeup).

The same release on the Pixel 7a (after uninstalling its debug-signed build and the old
`com.kaitk.draughts`, the user's call), a Russian game on the 3D board after c3–d4,
idle 20 s and memory at rest: landscape 0.05% with 20 wakeups, GL mtrack 227 MB, EGL
73 MB, Total PSS 345 MB; portrait the same, 347 MB. Portrait shows the view and
showcase buttons, landscape zoom as well.
