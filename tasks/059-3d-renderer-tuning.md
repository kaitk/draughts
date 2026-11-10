# 059: Profile and rework the 3D renderer on the PC

Status: todo

Find where the 3D board's frame goes with real GPU tools on the Windows PC (RTX 4090,
Vulkan), then look over the lighting, shadow, and shader stack as an engine developer
would (Sebastian Aaltonen's way: measure, then the cheapest technique that keeps the
look): could 90% of the look, or all of it, come from much faster techniques? The goal
is the phones and the tablet: the moving 3D board inside 11.1 ms on the Galaxy Tab A11+
at 90 Hz (task 042 has its cost and a ranked list of candidates; 055 the locked rate),
and the Galaxy A33's 23 ms down toward 16.7.

## The PC is a lens, not the target

The 4090 is an immediate-mode desktop GPU about 50 times the tablet's Mali-G615 MC2,
which is tile-based. What carries over from the PC: the passes and draws and what each
costs relative to the others, shader arithmetic and texture fetches, overdraw, and
whether a cheaper technique still looks right. What doesn't: bandwidth, tile memory,
MSAA's resolve, register pressure, and fp16's double rate, which only the Mali shows.
So each change is judged on the PC and confirmed on the tablet (`scripts/device_perf.sh`).

- **The PC:** Nsight Graphics (a frame capture: each pass and draw's GPU time, the
  shaders' hot spots, and their warp stalls), RenderDoc (passes, overdraw, the textures
  and their formats), and PresentMon (`scripts/windows_perf.py`). Lock the GPU's clocks
  when timing (Nsight's lock to base, or `nvidia-smi --lock-gpu-clocks`, as admin): at
  this load it falls to idle clocks, and its 2 ms busy time a frame (2026-11-10) measures
  the power state as much as the work. A capture wants a frame that draws the 3D pass: a
  `--bench` run, or a moving board.
- **The Mali, from this PC with the tablet over USB:** Arm Performance Studio's Mali
  Offline Compiler (each shader's registers, cycles per unit, and spills, offline: the
  cheapest first step, task 042's candidate 4), and Streamline for the tablet's counters
  (fragment-bound or vertex-bound, bandwidth, tile overflows). RenderDoc also captures
  Android's Vulkan.

## Directions to weigh

From task 042's review and beyond it, none measured yet:

- **The light and the board stand still while the camera turns.** Whatever depends only
  on them can be baked into textures when they change: the field's shadow and occlusion
  (042's candidate 2), and possibly all of the board's diffuse light, leaving the
  specular, which depends on the view, for each frame.
- **Pieces are discs.** Analytic shadows and occlusion (a disc's or a capsule's soft
  shadow on the plane, as engines do for characters' contact shadows) could replace the
  shadow map's 16 taps for the pieces on the board, and its redraw when pieces move.
- **Geometry:** a piece of about 9,200 triangles at 120 to 140 px (042's candidate 1); a
  lower-detail piece, or a normal map in place of the rings.
- **Resolution:** the 3D pass at a lower render scale, upscaled in the screen pass, the
  largest lever on a fill-bound frame; MSAA 4× against a cheaper edge treatment.
- **Precision and shader variants:** fp16 where safe and a lit shader per material
  (candidates 4 and 9), checked in the offline compiler.

## Acceptance criteria

- [ ] Nsight and RenderDoc captures of the moving 3D board on the PC, the clocks locked:
      each pass's and the heaviest draws' GPU time recorded here
- [ ] The Mali Offline Compiler's report for each 3D shader, recorded here
- [ ] Streamline on the tablet: what bounds the moving 3D board's frame
- [ ] A ranked plan of changes, each with its expected win, measured cost, and what it
      does to the look (checked against the reference images, `agents/design.md`)
- [ ] The changes made, each measured on the PC and on the tablet, with the README's and
      the rendering doc's numbers updated
