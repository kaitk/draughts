# 042: The 3D board's frame cost

Status: todo

A moving 3D board (the camera turning, a hop, a capture) takes about 14 ms on the Pixel 7a
(Mali-G710) and on the tablet (Mali-G615 MC2, MSAA 4×), over the tablet's 11 ms at
90 Hz; at rest the app draws nothing (task 015's measurements). A read-only review of
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

**Fine as is:** back-face culling (counter-clockwise front faces) on the lit, fading, and
depth-only pipelines; 16-bit depth, the multisampled color resolved and neither it nor
its depth stored (`0005`); the shadow map drawn only when pieces move or the board
turns (the shadow pass culls nothing: `CULL_FRONT` would halve it and cut acne); fading
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

## The idle wakeup

The tablet's 3D board at rest wakes once a second, as the flat board does, but spends
about 2.7 ms CPU against 0.3 (task 015, "The release on the tablet"). `view3d::fill` and
`changes` compare about 13 KB, microseconds. Read draw3d's frame, draw, and pulse
counts over an idle 30 s: if draws climb, something in the scene differs each wakeup (a
time-dependent value, or the view's floats) and the whole pass runs once a second; if
not, profile the screen pass and the driver with simpleperf.

## Acceptance criteria

- [ ] Each candidate tried is measured on the tablet with `--bench 300` (task 015's
      method) and kept only for a measured win, with headless shots matching the look
- [ ] The tablet's moving 3D board within 11 ms, or 60 Hz chosen there while it moves
- [ ] The idle wakeup's cost explained, and fixed if it draws
