# 071: Where the 3D board's memory goes

Status: in progress (the SMAA on gfx question next; the tablet and the A33 not yet)

The 3D game at rest holds about 200 MB more than the flat one on both renderers: on the
M1 Pro in a 1280 × 800 window (2560 × 1600 pixels), 358 MB against 115 on gfx and 315
against 118 on ngfx; on the iPhone 13 mini, 204 MB against 59 (gfx) and 42 (ngfx)
(task 065, 2026-11-11). The renderers themselves are now close: nearly all of it is the
app's own textures and targets, the same design on both. Task 032 brought memory down
before the 3D board grew to what it is; this breaks the 3D board's share down and takes
what it can from it, for both builds.

## What to do

1. **The list.** Every texture and buffer the 3D board makes and keeps at rest, with
   its size, format, mips, and samples, summed by purpose: the shadow map, the
   antialiasing's targets (gfx's 4× MSAA and its resolve, ngfx's SMAA edges and
   weights, or FXAA's), the kept image and its mips, the depth kept for the pulsing
   rings, the occlusion map, the theme's baked textures, the photograph's layers. A
   temporary print in `render3d` (`src/render3d/` for gfx, `src/ngfx/render3d/` for
   ngfx) does it; compare the sum with `footprint`'s graphics rows (`vmmap -w` tells GPU
   heaps from mapped memory, `agents/testing.md`). Headless runs are steady enough to
   compare (`agents/testing.md`, memory experiments).
2. **What can go**, each measured at rest and checked against the look (headless shots
   against the build before, `magick compare`):
   - targets the board needs only while drawing it, given back once it is at rest, if
     drawing it again doesn't then cost a visible hitch;
   - targets that can share memory, being used at different times in a frame (task
     065's "Later": SMAA's edges and weights with other per-frame targets);
   - formats or mip chains larger than what is drawn needs (RGBA16F where RGBA8 or
     RG11B10F looks the same, mips no draw samples);
   - SMAA in place of 4× MSAA on the gfx build too (task 065: half the targets' memory,
     the look within 0.1 to 0.25 of 255), if its frame time allows on the tablet and the
     A33 (memory: A33 is the profiling target).
3. **Record** the list, what was taken, and the numbers before and after on the Mac,
   then on the iPhone and the A33 for what changed; `docs/architecture/rendering.md`
   where it describes the 3D board's targets.

gfx changes go to `main`; the ngfx build's twins (`src/ngfx/`) follow on the `ngfx`
branch.

## Acceptance criteria

- [x] The 3D board's textures and buffers listed with sizes, summed by purpose, against
      `footprint`, on both builds
- [x] Each saving tried measured at rest, its look checked against the build before
- [ ] The kept savings on both builds, with the Mac's, the iPhone's, and the A33's
      numbers before and after recorded here

## Done so far

### 2026-11-11: the list, and what goes at rest

Winter (the stone frame, its map 2048 rows), the 3D game; MB at 1280 × 800 pixels
(headless) and at 2560 × 1600 (the Mac's 1280 × 800 window); a temporary print in
`render3d`:

| purpose | gfx | ngfx (SMAA) | 1280 × 800 | 2560 × 1600 |
|---|---|---|---|---|
| the pass's targets | 4× RGBA8 + 4× D16 | RGBA8, RG8 edges, RGBA8 weights, D16 | 24.6 / 12.3 | 98.3 / 49.2 |
| the kept image | RGBA8 | RGBA8 | 4.1 | 16.4 |
| the kept backdrop | RGBA8 | RGBA8 | 4.1 | 16.4 |
| the kept depth (once marks pulsed) | D16 | D16 | 2.0 | 8.2 |
| the plan, albedo and normal, mips | 2 × 2048² RGBA8 | the same | 44.7 | 44.7 |
| the frame map, albedo and normal, mips | 2 × 2048² (mitred 2048 × 1152: 25.2) | the same | 44.7 | 44.7 |
| the photograph, blurred and its two copies | 3 × 512² RGBA8 | the same | 3.1 | 3.1 |
| shadow map, occlusion, crown | D16 1024², R8 512², R16F 256² | the same | 2.5 | 2.5 |

gfx headless: 128 MB listed, against "owned unmapped (graphics)" 152 MB in the 3D game and
18 in the flat one (134 more); the buffers, the pipelines, and the driver's alignment
take the rest. The baked surfaces are the largest share, then the pass's targets.

Kept:

- **The pass's targets, the kept backdrop, and the kept depth given back at rest**
  (`render3d::rest`): a second after the pass last drew, at a frame that draws nothing,
  with a wake for it, and a flush, as a released texture is freed only after the next
  submit. The next draw makes them; frames drawn meanwhile grade the backdrop live.
  Given back at once, a hover or a drag would make them again each time.
- **A flat marble frame's normal as a 4 × 4**: winter's frame map normal is one value
  (BAKE_FRAG writes it so), 22.4 MB with mips; made full again to bake into.

At rest, `--rest 25`, the same session each:

| 3D game at rest | before | after |
|---|---|---|
| gfx, Mac 1280 × 800 window | 356 MB | 225 MB |
| ngfx, Mac | 311 MB | 226 MB |
| gfx, iPhone 13 mini | 243 MB | 152 MB |
| ngfx, iPhone 13 mini | 223 MB | 160 MB |
| gfx headless 1280 × 800 | 198 MB | 134 MB |
| ngfx headless | 177 MB | 139 MB |

The flat game's windowed footprint moves 72 to 115 MB run to run on ngfx and 95 to 100 on
gfx, untouched. The iPhone's "before" is above task 065's 204 MB: that was another
season (a mitred frame map), these winter's.

- **The look**: headless shots at `--frames 20000` with a frame drawn after the rest (the
  backdrop graded live), the four seasons, the plain fade, a season switched mid-run and
  back, and ngfx's `--aa fxaa|off|ssaa`: 0 pixels apart at 3% on both builds (ngfx's
  against its build before outside the left corner's panel, which main's layout changes
  moved).
- **The first draw after a rest**, the pass with the GPU waited: gfx on the M1 Pro at
  2560 × 1600 6.3 ms against 2.3; gfx on the iPhone 23 ms against 9.9; ngfx on the iPhone
  20 against 11 (8 of it the CPU making the textures). The rest of it is the GPU's first
  touch of new memory. It comes at the start of a response after a second still, a
  refresh late on the phone, never inside an animation.
- **Not done**: the plan's normal as RG8 (a second bake pipeline; the frame's normal uses
  all four channels); dropping the maps' top level (the anisotropic filter samples it on
  the tilted board); the photograph's two working copies (2 MB). Apple's memoryless
  MSAA targets would remove them without the first draw's cost, but SDL chooses the
  storage mode (a note for the user, not a patch).

Left: SMAA on the gfx build, its look against MSAA and its GPU cost on the Pixel 7a and
the A33, with a key to toggle them; the tablet's and the A33's numbers (neither attached).
