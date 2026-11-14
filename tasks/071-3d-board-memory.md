# 071: Where the 3D board's memory goes

Status: in progress (the tablet's and the A33's memory numbers not yet)

The 3D game at rest held about 200 MB more than the flat one on both renderers. This
breaks the 3D board's share down and takes what it can from it, for both builds. gfx
changes go to `main`; the ngfx build's twins follow on the `ngfx` branch.

## What was found and kept (2026-11-11)

The list (winter, MB at 1280 × 800 / 2560 × 1600): the pass's targets 24.6 / 98.3 (gfx's
4× MSAA), the kept image and backdrop 4.1 / 16.4 each, the kept depth 2.0 / 8.2, the
plan's and the frame map's baked albedo and normal with mips 44.7 each, the photograph's
layers 3.1, shadow map, occlusion and crown 2.5. The baked surfaces are the largest share,
then the pass's targets.

Kept:

- The pass's targets, the kept backdrop, and the kept depth given back a second after the
  pass last drew (`render3d::rest`); the next draw makes them again. The first draw after
  a rest costs more (gfx on the iPhone 23 ms against 9.9), at the start of a response,
  never inside an animation.
- A flat marble frame's normal as a 4 × 4 (22.4 MB with mips).
- gfx keeps 4× MSAA: SMAA (`--aa msaa|smaa|off`, the A key) halves the targets but costs
  about 1.1 ms more on the Pixel 7a and 0.4 ms more on the M1 Pro, and looks the same at a
  normal size (`docs/decisions/rendering.md`, GPU memory). SMAA's weights pass is
  depth-tested to edges only, on both builds.

| 3D game at rest, `--rest 25` | before | after |
| --- | --- | --- |
| gfx, Mac 1280 × 800 window | 356 MB | 225 MB |
| ngfx, Mac | 311 MB | 226 MB |
| gfx, iPhone 13 mini | 243 MB | 152 MB |
| ngfx, iPhone 13 mini | 223 MB | 160 MB |

The look is the same to the pixel at 3% in headless shots of every theme.

Not done: the plan's normal as RG8 (a second bake pipeline), dropping the maps' top level
(the anisotropic filter samples it), the photograph's working copies (2 MB); Apple's
memoryless MSAA targets need SDL to choose the storage mode (a note for the user).

## Left

The tablet's and the A33's numbers before and after (neither attached when measured).

## Acceptance criteria

- [x] The 3D board's textures and buffers listed with sizes, summed by purpose, against
      `footprint`, on both builds
- [x] Each saving tried measured at rest, its look checked against the build before
- [ ] The kept savings on both builds, with the Mac's, the iPhone's, and the A33's
      numbers before and after recorded here
