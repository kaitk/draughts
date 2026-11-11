# 071: Where the 3D board's memory goes

Status: todo

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

- [ ] The 3D board's textures and buffers listed with sizes, summed by purpose, against
      `footprint`, on both builds
- [ ] Each saving tried measured at rest, its look checked against the build before
- [ ] The kept savings on both builds, with the Mac's, the iPhone's, and the A33's
      numbers before and after recorded here
