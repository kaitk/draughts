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
  Built and judged on the Mac first; measured on the Pixel 7a (the tablet is gone).
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

`poc/3d/` (2026-11-09), first step: the autumn board and the 3D reference's position
(one light king as a stack of two discs with the crown debossed on the upper, one light
piece selected), with the pipeline the method comparisons will hang off.

```sh
cd poc/3d
../../build/goose-v2026.4-macos-arm64/goose build -o ../../build/board3d board3d.goose
../../build/board3d                                 # a drag turns; Tab or a double click switches mode; R resets
../../build/board3d --shot out.png --size 1920x1200 [--yaw 20 --pitch 40]   # one frame, headless
../../build/board3d --bench 1000 --size 1920x1200   # frame timing, headless
../../build/board3d --frames 30                     # the window's loop hidden, a drag injected
```

It compiles `src/app/background.c` from where it is (`board3d.build`) for the photograph.

- **Frames:** the shadow map (2048², 16-bit, the board and pieces from the key light) only
  when the position changes; then one forward pass into a 4× multisampled RGBA8 target
  with depth, resolved into gfx's screen: the blurred photograph as a backdrop, the
  board's soft shadow on nothing (a catcher plane under it, distances to its rounded
  outline), the board and the pieces lit, the selection's glow ring added. No post pass,
  no discard, nothing temporal. Drawn only when the camera or the window changes.
- **Geometry**, built once at startup: a piece is a profile turned on a lathe (72 steps:
  a recessed inner disc, a groove at 63% of the radius, a raised lip, a flat ring, the
  edge rounded from 86%, the side, a round at the foot), with occlusion baked into the
  profile; the frame is a profile swept round the field (an inner wall, the top, a
  bullnose of 0.2 squares, the side). Pieces are 82% of a square (the reference's; the 2D
  board's are 78%), 22% of their diameter high. The pieces are one instanced draw from a
  storage buffer.
- **Wood**, baked once on the GPU at startup into albedo-and-roughness (sRGB) and normal
  textures with mips: a plan of the field (2048², maple and walnut squares each its own
  stretch of grain and tone, seams, the dark inlay) and a strip for the frame (4096 ×
  256, cherry, its grain along each side, mitred on the diagonals). Grain is noise
  stretched along it, no sines. Tuned to the user's swatch (maple, walnut, cherry, cream:
  `~/Downloads/Four-Way Wood and Cream Texture Swatch.png`): lit means and grain contrast
  at screen size close to the swatch's. The pieces' wood and cream are noise in the
  shader, not baked.
- **Shading:** GGX with Filament's correlated Smith and Schlick, wrap diffuse, Filament's
  specular antialiasing on every material, 16 hardware-compared shadow taps on a fixed
  grid, nine spherical harmonics of the blurred photograph for the ambient (computed on
  the CPU at load, half desaturated, specular through Karis's DFG fit), analytic
  occlusion (each piece in the 3 × 3 squares round as a cylinder, the frame's inner
  wall), micro-shadowing on the field only, the Khronos PBR Neutral tonemap.
- **Measured** on an M1 Pro, 1920 × 1200, headless: about 0.2 ms of CPU a frame, about 7
  ms a frame with a wait for the GPU after each (an upper bound, submission and wait
  included); setup 50 ms warm, 0.3 to 0.8 s cold.
- **Not yet:** the gfx store-op patch (the multisampled target is still stored and
  resolved with `RESOLVE_AND_STORE`, depth stored), SSAO, SMAA and analytic edges to
  compare, taps hitting squares, the tablet. The backdrop doesn't turn with the camera.

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
