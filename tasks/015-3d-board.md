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

`poc/3d/` (2026-11-09), a first step and a second look pass: the autumn and winter
boards and the 3D reference's position (one light king as a stack of two discs with the crown debossed on the upper, one light
piece selected), with the pipeline the method comparisons will hang off.

```sh
cd poc/3d
../../build/goose-v2026.4-macos-arm64/goose build -o ../../build/board3d board3d.goose
../../build/board3d                                 # a drag turns; Tab or a double click switches mode; R resets
../../build/board3d --theme winter                  # T or a long press switches the theme
../../build/board3d --shot out.png --size 1920x1200 [--yaw 20 --pitch 40]   # one frame, headless
../../build/board3d --bench 1000 --size 1920x1200   # frame timing, headless
../../build/board3d --frames 200                    # the window's loop hidden, a drag, T and a long press injected
../../build/board3d --bench 300 --samples 1 --shadow-every   # 1× MSAA, the shadow map every frame
cd ../.. && scripts/android.py poc/3d/board3d.goose --run       # on the tablet, beside the game (its own id)
adb shell am start -S -n io.github.kaitk.draughts.board3d/io.github.kaitk.draughts.DraughtsActivity --es args "'--bench 300'"
```

It compiles `src/app/background.c` from where it is (`board3d.build`) for the photograph.

- **Frames:** the shadow map (2048², 16-bit, the board and pieces from the key light) only
  when the position changes; then one forward pass into a 4× multisampled RGBA8 target
  with depth, resolved into gfx's screen: the blurred photograph as a backdrop, the
  board's soft shadow on nothing (a catcher plane under it, distances to its rounded
  outline), the board and the pieces lit, the selection's glow ring added. No post pass,
  no discard, nothing temporal. Drawn only when the camera or the window changes.
- **Geometry**, built once at startup: a piece is a profile turned on a lathe (72 steps:
  a top sampled from one smooth height function, a recessed inner disc, a soft cove at
  60 to 67% of the radius rising to a low crest at 70%, a flat ring, the edge rounded
  from 86%, the side, a round at the foot); the frame is a profile swept round the field
  (an inner wall, the top, a bullnose of 0.09 squares, the side down to 0.7 under the
  field). Pieces are 88% of a square across and 27% of their diameter high, measured on
  the 3D reference at the same framing (the 2D board's are 78%). The pieces are one
  instanced draw from a storage buffer.
- **Surfaces**, baked on the GPU into albedo-and-roughness (sRGB) and normal textures
  with mips, at startup and again on a theme change: a plan of the field (2048², the
  light and dark squares each its own stretch of grain and tone, seams, the dark inlay)
  and a frame map (2048² over 10.4 world units). Grain is noise drawn out along it, no
  sines; stone is the same noise round (a mottling, no veins). The pieces' figure is
  noise in the shader, not baked.
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
- **Themes** are data (`poc/3d/theme.goose`): a flat struct of colors, roughness, figure,
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

Show settings' Board row again: remove `Settings.show_board_row` (`src/shell/settings.goose`)
and the `--3d` flag (`src/app/draughts.goose`, `docs/development.md`), make the board follow
`Settings.board`, and update `docs/architecture/rendering.md`' Settings paragraph and
`test/shell/settings.goose`.
