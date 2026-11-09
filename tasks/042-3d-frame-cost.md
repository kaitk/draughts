# 042: The 3D board's frame cost

Status: in-progress

A moving 3D board (the camera turning, a hop, a capture) takes about 14 ms on the Pixel 7a
(Mali-G710) and on the tablet (Mali-G615 MC2, MSAA 4×), over the tablet's 11 ms at
90 Hz; at rest the app draws nothing ([rendering](../docs/architecture/rendering.md#the-3d-board-on-devices)). A read-only review of
`src/render3d/` and `src/app/draw3d.goose` (2026-11-09) found these, ranked by the
expected win, which comes from task 015's Pixel ablations (the pass 14.3 ms waited, an
empty pass 5.1, the pieces about 2.3, the board about 5.6). None is measured yet.

## Candidates

1. **The piece mesh is far too dense** (`mesh.goose`, `piece_profile` and `lathe_path(path,
   72)`): 65 profile rows (42 on the top) by 72 segments, about 9,200 triangles a piece,
   220k for 24, drawn in up to three passes. On a piece 120 to 140 px across most
   triangles cover 2 to 3 px, and MSAA shades each in 2×2 quads. The top's rings do no
   shading work: the lit shader rebuilds the top's normal and occlusion from `v_local`.
   About 8 top rows and 6 edge steps: 2.5 to 4× fewer triangles, about 1 ms. Small, low
   risk.
2. **The field's shadow and occlusion each frame:** a mat4, 16 shadow taps, and a 3 × 3
   occlusion loop per field pixel, none of which change while the camera turns. Bake
   shadow × occlusion into an R8 world-space texture (512 to 1024²) when the shadow map
   is redrawn; the field reads one texel. About 1.5 to 2.5 ms. Medium.
3. **Opaque draws back to front** (`render3d::draw_meshes`): the board before the pieces
   standing on it. Pieces first lets depth reject the 20 to 25% of the field under them.
   0.3 to 1 ms, trivial.
4. **One lit shader for field, frame, and pieces:** the pieces' path (noise, the crown's
   SDF, the loop) sets the register count for every field pixel. Compile it per material
   with defines, as `PULSE` does, and draw the field quad apart; check registers and
   cycles with Arm's Mali Offline Compiler. 10 to 25% of the board's cost if the shared
   one is over 32 registers. Small to medium.
5. **16 shadow taps:** a 9-tap weighted bilinear filter over 5 × 5 texels gives a like
   penumbra with 44% fewer fetches. About 0.5 ms; the penumbra's shape changes slightly.
6. **The shadow catcher:** a 32 × 32 blended quad without a depth test, drawn before the
   board and shaded under all of it. After the opaque meshes, depth-tested without
   writes, and about ±8 units. About 0.3 ms.
7. **The marks quad** runs 9 storage-buffer reads per field pixel with nothing marked.
   Skip it when nothing is marked or selected. Up to 0.4 ms.
8. **The screen pass** blends two full-screen layers on every presented frame (the
   backdrop at opacity 1 with two `pow`s, then the kept image). At rest, bake the
   backdrop into the kept image and lay it with one opaque copy. 0.3 to 0.5 ms; medium,
   the crossfade stays.
9. **Full precision everywhere:** Valhall runs fp16 at twice the rate. `mediump` for the
   albedo, harmonics, tonemap, and noise; positions, shadow coordinates, and GGX's
   denominator stay full. 10 to 20% of the arithmetic; watch for banding.

Also, not from the review: a lower render scale for the 3D pass (about 0.75, scaled up
in the screen pass), the largest lever on a fill-bound frame; and asking for 60 Hz on
the tablet while the 3D board moves, where 90 Hz misses and alternates.

**Later: a low-quality mode for weak phones** (the user, 2026-11-09; not built yet):
when the moving 3D board stays under about 30 fps, cut the 3D pass's render resolution
first, then its geometry, until it reaches 30. A data point: a Galaxy A33 5G (Mali-G68
MP4, 1080 × 2400) draws the moving board in about 36 ms waited (about 28 fps), at
thermal status 3.

**Fine as is:** back-face culling (counter-clockwise front faces) on the lit, fading, and
depth-only pipelines; 16-bit depth, the multisampled color resolved and neither it nor
its depth stored (`0005`); the shadow map drawn only when pieces move or the board
turns (the shadow pass culls nothing: `CULL_FRONT` peter-pans, step 5 below); fading
pieces blended after the opaque ones without depth writes; the crown's SDF only on
kings.

## Tried on the Mac (the `perf-3d-frame-cost` branch, 2026-11-09)

Each step headless on the M1 Pro (a local copy of the app opening `gfx::open_headless`,
never committed, `agents/testing.md`), 1920 × 1200, Russian, autumn: `--bench 300`, the
median of three launches, each launch's the median of 300 frames, waited. The Mac's
figures are a proxy only; the tablet's are to come. Shots before and after of autumn,
winter, summer, and spring (a selected piece, a stacked king), the board turned for
black and swung 40°, swung and tipped low, and zoomed (pieces about 140 px across, the
largest on any screen): PSNR and pixels off by more than 4 levels of 255, and 200% crops.
Two runs of one build are byte-identical.

| Step | Pass, waited | With the shadow map | Look |
| --- | --- | --- | --- |
| Before (`2e2f634`) | 2.48 ms | 2.51 ms | |
| 1. The piece mesh | 1.71 ms | 1.73 ms | 54 to 58 dB, 40 to 90 pixels |
| 2. Pieces before the board | 1.72 ms | 1.71 ms | identical |
| 3. The shadow catcher | 1.67 ms | 1.68 ms | 84 to 98 dB, none |
| 4. No marks quad with nothing marked | 1.44 ms | 1.50 ms | identical |
| 5. `CULL_FRONT` in the shadow pass | left | | peter-pans |
| 6. 9 shadow taps instead of 16 | 1.41 ms | 1.48 ms | 50 to 56 dB, 80 to 310 pixels |
| 7. The field's light baked, a shader per material | 1.12 ms | 1.43 ms | 67 to 74 dB, 0 to 5 pixels |

1. **The piece mesh:** the top's 42 rows down to 9 (`mesh::TOP_ROWS`, dense only round
   the step), the edge's arc 12 steps to 6, the foot's 5 to 3, and the lathe's 72
   segments to 48 (the silhouette off a true circle by 0.15 px on a 140 px piece, 0.07
   before). 9,216 triangles a piece to 2,208, 221k to 53k for 24 pieces. The pixels that
   differ are along the step's ring and the edge, and the shadows round the pieces (the
   shadow map's geometry); no difference visible at 200%, the low view's silhouettes
   included.
2. **Pieces before the board** (`render3d::draw_meshes`, all three passes that use it):
   the field under the pieces fails the depth test before it is shaded. Pixel for pixel
   the same; nothing on the Mac, whose GPU removes hidden surfaces by itself. Mali's
   forward pixel kill does only part of that, so the tablet is where it can show.
3. **The shadow catcher** after the opaque meshes (and the fading pieces), depth-tested
   without writes, so nothing under the board is shaded, and its quad only as large as
   its shadow reaches (QUAD_VERT: 0.3 round the board, 1.6 round it moved along the
   light): about 12.4 × 13 units instead of 32 × 32. Within the Mac's noise.
4. **No marks quad with nothing marked** (`render3d::place` sets `Gpu.marked` from what
   the still marks shader draws: a selection, a last move, targets, stops, a still red
   ring, glow rings, lit squares). The bench's start position has none, so its frames
   leave the quad out; a frame with a selection draws it as before (the four seasons'
   shots, pixel for pixel).
5. **The shadow pass with `CULL_FRONT`: left.** It peter-pans: a lit sliver opens under
   every piece's foot on the side away from the light, and along a stacked king's seam
   (35 to 44 dB, 500 to 2,100 pixels; plain at 200%). The pieces' undersides lie in the
   field's plane, so with only back faces in the map nothing occludes the field right at
   the foot. Not measured, as the look didn't hold; the map is drawn only when pieces
   move anyway.
6. **9 shadow taps instead of 16** (LIT_FRAG's `shadow`): Castaño's 5 × 5 filter, nine
   bilinear compares placed and weighted by where the point falls in its texel. The 16
   taps 1.25 texels apart covered the same 5 texels, so the penumbra keeps its width;
   the pixels that differ are on the pieces' shaded sides by their feet, by a few levels,
   alike at 200%. 44% fewer shadow fetches for every lit pixel. `Frame.params.y` (the
   old spacing) is unused now.
7. **The field's light baked, and a shader per material** (candidates 2 and 4, one
   commit: the field's own shader is what reads the baked map). `FIELD_LIGHT_FRAG`
   bakes the key's shadow and the occlusion into a 1024² RG8 map over the plan's extent
   (2 MB) after the shadow map is drawn, or when the squares' occlusion changes without
   it (a captured piece fading); RG, not one channel of shadow × occlusion, because
   the shader uses them apart (the shadow under the micro-shadowing, the occlusion in
   the ambient). The bake takes the field's normal as up; its normal map still shades
   each pixel. LIT_FRAG is built three times (`LIT_FIELD`, `LIT_FRAME`, `LIT_PIECE`),
   each binding only what it reads, and the pass draws the opaque pieces, the frame
   (the board mesh's indices from `mesh::FIELD_INDICES`), then the field quad. A
   field pixel is now three texture reads and the lighting: no shadow taps, no loop over
   the squares, none of the pieces' noise or crown in its registers. Turning the camera
   (the pass alone) 1.39 → 1.12 ms; a frame that draws the shadow map is even (1.43),
   the bake's 1M texels paying for what the field saves. Four pipelines instead of one
   (three lit and the bake) are made at the first frame: on the Mac 6.5 ms against 5.8;
   the Pixel's first frame (0.3 s, mostly pipelines) is worth reading again.

## The idle wakeup

The tablet's 3D board at rest wakes once a second, as the flat board does, but spends
about 2.7 ms CPU against 0.3 ([rendering](../docs/architecture/rendering.md#the-3d-board-on-devices)). `view3d::fill` and
`changes` compare about 13 KB, microseconds. Read draw3d's frame, draw, and pulse
counts over an idle 30 s: if draws climb, something in the scene differs each wakeup (a
time-dependent value, or the view's floats) and the whole pass runs once a second; if
not, profile the screen pass and the driver with simpleperf.

**On the Mac (2026-11-09): the app's loop doesn't draw at rest.** A headless copy of the
app logging every loop iteration that draws, after the first 3 s, with draw3d's frame,
draw, shadow, and pulse counts: none in 10 to 15 s, on the 3D board's default game,
after c3–d4 in a friend's game (the board turned for black), and on puzzle 21, nor on
the flat board. Headless the loop doesn't wait for events (the release's gfx, without
`0002`), so it spins, and an iteration that draws nothing costs the same on both boards:
about 16,500 a second, about 60 µs, nearly all in `gfx::frame()`. So the tablet's extra
2.4 ms a wakeup is outside the app's own work: in the patched `frame()` (a wakeup
presents and submits if anything called `gfx_cmd` since the last frame, `gpu_work`) or
in SDL's and the driver's Vulkan work on the program thread. To check on the tablet: in
a build copy, `SDL_Log` in `frame()` whether `drew` held and whether a command buffer
was submitted, and per-thread CPU (`agents/testing.md`) for 3D against 2D; simpleperf
can't sample there.

## The first switch to 3D (2026-11-09)

The user, on the Pixel 7a: the first tap on the Board row's 3D shows nothing happening for
2 s or more; later switches are at once. It is the one-time setup: on the Pixel by task
015's numbers the theme 0.76 s (the bake 0.71, most of it making its pipeline, which the
driver compiles on first use; warm it is 0.15), the first frame 0.31 s (its pipelines),
and the setup and targets; about 1.1 s, the rest of the 2 s unaccounted for. Before the
change, on the Mac (1920 × 1200, Russian, autumn) the switch's first 3D frame took 99 ms
(setup 2.7, the theme 88 with its bake's pipeline made, the draw).

**What it does now (the user's plan, 2026-11-09):** nothing is made before the 3D board is
needed, and nothing kept for a flat player. Wherever it is needed and not ready (3D
chosen in settings, a launch with 3D saved, home, the game, a puzzle), `draw3d::frame`
takes one step of getting ready a frame instead of drawing (`draw3d::prepare`), the
shell shows a still mark in the board's place (`gui::waiting`: the words alone,
"Setting up the board…", "Panen kabelauda paika…" in Estonian, no glass, as it shows only a
moment, 2026-11-09; `strings::BOARD_PREPARING`; `sh.ready3d` and `sh.shown3d` set by the
app) and leaves taps on the board alone (the panels answer), and once ready the board
fades in over 0.3 s (the renderer's backdrop with it). Settings' 3D tile is lit at once.
A new season or board size on 3D takes the theme's steps again with the old image shown
and no mark, taps waiting. Back to flat, everything is given back (`render3d::release`).
`test/shell/wait3d` checks the mark in both languages, nothing animating for it, the taps
left alone, a panel tile still answering, and the tap selecting once ready.

The mark was a spinner first; on the Galaxy A33 it stood still for about 1 s (the bake's
compile, one driver call) and again about 0.5 s (the lit pipelines'), which looked
broken, so the user chose a mark that doesn't move. A thin bar filled by the steps done
was shot beside it (it moves only as a step completes); the words were kept, as the
user's first choice and at home in the glass the screens are made of, in English and
Estonian alike.

**Measured on the Galaxy A33 5G** (Mali-G68 MP4, 1080 × 2400, by the main session with
this branch, 2026-11-09): the moving 3D frame with the shadow map 38.6 → 25.5 ms waited,
the pass alone 35.9 → 19.3 ms, presented 25.7 ms frame to frame (about 39 fps); getting
ready about 3.0 s in all over its steps, the setup 84 ms; the first frame once ready
64 ms (350 before); no device lost on any transition; idle 0% at rest.

**The steps** (41), each waited for (`gfx::flush`) so its GPU work stays in its frame. The
budget: about 16 ms of the Pixel 7a's and 35 of a Galaxy A33's (whose bake takes 1.6 s
cold against the Pixel's 0.7), which by task 015's ratios is about 2.5 ms of the M1 Pro's.
On the Mac headless, two runs:

| Step | M1 Pro, ms | The Pixel's, scaled or from task 015 |
| --- | --- | --- |
| Setup (meshes, buffers, pipeline objects, the surfaces' targets) | 3 to 5 | unmeasured |
| The theme's start (the frame map's targets) | 0.3 to 0.5 | small |
| The bake's pipeline made, drawing one row | 2.6 to 3 | about 0.55 s: one compile, can't be split |
| The plan, 16 bands | 1.2 to 3.1 each | about 10 to 20 each |
| The frame map, 6 bands | 1.6 to 3.9 each | about 10 to 25 each |
| The photograph's pipelines | 0.5 | a compile each, small |
| The photograph decoded and shrunk | 17 (the Mac decodes the JPEG) | the ASTC upload, a part of task 015's 42 ms |
| Blurred across; blurred down, read back, harmonics, the theme's end | 0.4; 0.8 to 2.1 | a part of the 42 ms |
| 12 pipelines, each bound alone in a pass on 4 × 4 targets | 0.3 to 1.6 each | the first frame's 0.31 s over 12 frames |
| The first 3D frame once ready (the targets the screen's size, the draw) | 3.3 to 3.8 | |

The Mac's driver keeps compiled shaders across runs, so its compile steps look cheap;
the Pixel's largest step stays the bake's compile (about 0.55 s, the A33's about 1.3 s),
during which nothing on screen can change. Nothing splits a single compile without a pipeline cache
(`docs/goose-findings.md`).

**What each part holds** (by arithmetic; the device's GL mtrack to check): the plan's
two 2048² RGBA8 maps with mips 43 MB; the frame map 24 MB mitred (2048 × 1152) or 43 MB
solid; the photograph and its two blur targets 3 MB; the shadow map 2 MB; the field's
light 2 MB; at 2400 × 1080 the 4× color 40 MB, its 16-bit depth 20 MB, the kept image
10 MB, the kept depth (once marks pulse) 5 MB; the meshes and buffers under 1 MB. About
150 to 170 MB in all, none of it held on the flat board.

**Not on a thread:** the work is the GPU's (compiles on first use, the bake), on the
thread that owns it; goose_gfx's tables aren't thread-safe, and the CPU's part (the
meshes, the harmonics' 4,096 samples) is microseconds, so neither a worker nor NEON
would buy anything measurable.

**Checked headless:** the 3D board once ready against `ea2c726`'s: zoomed autumn 76 dB,
spring 73, winter 58, summer 41 to 45, turned and low 64 to 65, nothing off by more than
4 levels when shot one at a time. Four runs at once on the GPU, or the old build shot at
its very first frame, gave lower figures from timing. Shots of the waiting state: the
mark in the board's place on the game, home (spring), and settings (winter, the 3D tile
lit), in English and Estonian.

**To check on the device:** each step's time (a `--frames` run prints `3D board prepared
in 41 steps, each waited, ms: ...`; `--bench` prints their count, sum, and the longest),
the mark's look and the fade, and GL mtrack on 3D and after going back to flat.

## Left open by task 015

- The pulsing marks' frame time on a device: only the Mac's numbers are in (they moved
  out of the 3D pass while the Pixel 7a wasn't attached).
- Between screens the switches that aren't transitions (settings and the game or a
  puzzle) draw the board again through the other view, once.
- The drag threshold is measured on the flat layout, near the screen's pixels in the
  board's middle only.

## A season changed on the 3D board (2026-11-09)

The user, on an iPhone 13 mini: a new season's photograph shows within two frames, but
the board keeps the old season's image for a second or two, until the theme's steps are
done. **What it does now:** while they run, the old image eases over 0.2 s towards grey
and dimmer (saturation 0.15, brightness 0.8, a uniform of the shader that lays the
image, `shaders::SHOW_FRAG`), and the new theme's first image eases back to full color
over 0.3 s (`draw3d::grey`; `docs/architecture/rendering.md`, "Getting ready"). Saturation
0.35 and brightness 0.88 still read as the old wood, washed out; 0 and 0.7 as switched off.
Checked headless on the settings preview (autumn to winter, summer to spring on the plain
fade) and the game: a first appearance mid-fade, at rest, and the end of a change are
byte-identical to the build before. Found on the way: the frame after the last step
wasn't drawn unless something else was changing (a pulsing ring), so on the game the old
board stayed until a tap; `draw3d::Drawer.fresh` now keeps the app drawing for it.

**The steps a season change takes** (a temporary build printing past `prep_ms`'s 48;
headless, M1 Pro, 1920 × 1200, the game; four changes, autumn to winter, winter to spring,
spring to summer, summer to autumn): **28 steps, one a frame, 66 to 95 ms of work in
all.** The photograph decoded and shrunk is the largest step (17 to 22 ms, the Mac
decoding the JPEG); the bake's pipeline 0.8 to 2.2 (compiled already); the plan's and the
frame map's bands 1.3 to 6.7 each, most about 2; the rest under 2.6. So on a fast device
the wait is the frame count, not the work: 28 frames are 0.47 s at 60 Hz however quick
each step is, and the Mac's work would fit in about 5 frames.

**An idea for later, not built:** fewer, larger steps on fast devices. Run steps back to
back within a frame while the frame's time spent stays under a budget (say 8 ms, each step
still waited for, so a slow device keeps one a frame), the bake's compile and the
photograph's decode still a frame each. On the Mac's numbers above an 8 ms budget takes
the 28 frames to 9 to 15 (0.15 to 0.25 s at 60 Hz). The iPhone 13 mini's and the Pixel's
step times are unmeasured: print them there (`3D board prepared in ... steps`) before
choosing the budget. A first preparing (41 steps with the setup and the 12 pipelines)
would gain likewise.

**Unexplained, noted:** a theme prepared again over another differs from the same theme
prepared at launch by up to 11 levels of 255 over the whole screen, the renderer's
backdrop included (PSNR 38 dB, autumn after summer on the game); the same before this
change. Something of the old theme's state (its harmonics, its look's choice) may carry
over.

## Acceptance criteria

- [ ] Each candidate tried is measured on the tablet with `--bench 300` (task 015's
      method) and kept only for a measured win, with headless shots matching the look
- [ ] The tablet's moving 3D board within 11 ms, or 60 Hz chosen there while it moves
- [ ] The idle wakeup's cost explained, and fixed if it draws
