# 059: Profile and rework the 3D renderer on the PC

Status: in-progress

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
- **The device to profile on is the Pixel 7a** (Mali-G710 MC7, the tablet's Valhall
  family, wider): Android GPU Inspector supports Pixels officially (Mali counters, each
  pass's time), and profiling wants a debuggable build, which may mean an uninstall the
  tablet's data rules out. The tablet takes only the usual build, to confirm the numbers.

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

## Tools (2026-11-10)

On the PC at the start: none of the profilers, `nvidia-smi` (the 4090 idling at 210 MHz,
3105 max), and the Vulkan SDK's `glslangValidator`. `scripts/shader_report.py` writes each
3D shader as `embed_shader` joins it into `build/shaders/`, checks it into SPIR-V, and
with `--core Mali-G615` (or G710, G68) prints the Mali Offline Compiler's report once Arm
Performance Studio puts `malioc` on PATH. A profiler on a phone that isn't rooted wants a
debuggable app: `scripts/android.py --debuggable` (aapt2's `--debug-mode`), installed on
the Pixel 7a (`run-as` works); never on the tablet, which keeps the usual build.

## The stack, reviewed (2026-11-10)

Read from `src/render3d/` and `src/app/draw3d.goose` after task 042's cuts, before any
capture. What a moving frame does:

- **The shadow map** (only when pieces move or the board turns): 1024² D16 from the key
  light, every opaque piece (2,208 triangles each) and the board, no culling.
- **The pass:** a 4× multisampled RGBA8 target and D16 depth the screen's size, cleared
  clear; the opaque pieces instanced, then the board (the field's one quad and the
  frame's sweep), the fading pieces blended one by one, the board's shadow catcher, the
  marks' quad when anything is marked; resolved into the kept image, the screen's size.
- **The screen's part** on every presented frame: the graded photograph full screen,
  the kept image laid over it, full screen, then the UI.
- **One lit fragment shader** for every lit pixel, branching on the material. Every
  pixel pays: two spherical-harmonics sums of nine terms (the irradiance and the
  reflection), GGX with Smith and Schlick, Karis's DFG fit, the normal's screen
  derivatives for specular antialiasing, the shadow's 9 hardware-compared taps behind a
  mat4, the tonemap, and `to_srgb`'s `pow`. The field adds two anisotropic (8×) reads of
  the plan and a 3 × 3 loop over the squares' storage buffer with an `asin` per piece;
  the frame two `textureGrad` reads and its mitre's branches; a piece two 3D value
  noises for a dark one (16 hashes), one for a light one, a 4-step loop over its top's
  height, and on a crowned king the crown's 11-edge distance three times. The pieces'
  path likely sets the register count for the field's pixels (task 042's candidate 4):
  the offline compiler will say.

What weighs most, as hypotheses for the captures to confirm or kill:

1. **How much of the "waited" frame is GPU work at all.** An empty pass waited took about
   5.1 ms on the Pixel 7a (task 015): a submit and a fence wait. The tablet's 10 ms
   waited and 12.8 presented hold a floor of unknown size, and the counters' active
   cycles per frame are the first number to read. If the floor is large, missing
   90 Hz is as much the frame's pacing as its shading.
2. **The shadow map, done analytically instead.** The light and the board stand still,
   and the pieces are discs on a plane: a disc's shadow on the field is the disc swept
   along the light (a stadium), softened by its distance from the piece, and the field
   already loops over the 3 × 3 squares round it for the occlusion. The pieces' shadows
   on the field then cost a few lines in that loop and no texture reads; the frame's on
   the field is a wall's, also analytic; a piece's on its neighbour's side is a ray
   against a few cylinders. With all three the shadow map and its pass go, so a moving
   frame costs what a turning one does, and every lit pixel loses 9 taps and a mat4.
   Look: the penumbra's shape changes (it could harden toward the contact, as the
   references' do); the edge cases are a lifted piece and a stacked king.
3. **A shader per material, without the bake.** Task 042's step 7 split the lit shader
   and baked the field's light in one commit, and was dropped for the bake's cost; the
   split alone was never measured. Cheap to try once the offline compiler shows the
   field's registers and cycles in the shared shader against a field-only one.
4. **The resolution:** the pass's targets the screen's size while the board covers about
   54% of the tablet's screen (898 × 616 of 1280 × 800 dp): the 4× target's tiles round
   it are still cleared and resolved, and the kept image read whole by the screen's
   part. A target sized to the board's bounds on screen, or a render scale of about
   0.8 on its pixels, is the largest lever if the frame is fill-bound.
5. **MSAA 4×** cost 3.2 ms on the tablet when a piece was 9,200 triangles, most of them
   edges; at 2,208 its cost is unmeasured. Read it again (`setup`'s `samples` 1) before
   weighing 2× or another edge treatment.
6. **Smaller arithmetic:** the reflection's harmonics at L1 (four terms) under a rough
   GGX; an sRGB target in place of `to_srgb`'s `pow`; the pieces' noise baked into a
   small texture; anisotropic filtering at 4× (at 52° down the field's anisotropy is
   about 1.6, so 8× may already cost nothing); fp16 where the offline compiler shows it
   pays (candidate 9). Each a few percent at most; worth only what the counters show.
7. **The screen's part** at rest and moving (task 042's candidate 8): the photograph's
   grade and the kept image are two full-screen layers on every presented frame.

## The Mali Offline Compiler's reports

Mali Offline Compiler 2026.5 (Arm Performance Studio 2026.6, driver r56p1), each shader
as `scripts/shader_report.py` joins it, 2026-11-10. Cycles are per thread on one core,
arithmetic (A), load/store (LS), texture (T); "longest" is the slowest branch's path. The
G615 is the tablet's, the G710 the Pixel 7a's, the G68 the Galaxy A33's. No shader uses
any 16-bit arithmetic.

| Shader | Core | Work registers | Spilled | A total | LS total | T total | A, LS longest |
| --- | --- | --- | --- | --- | --- | --- | --- |
| lit.frag | G615 | 64 (half occupancy) | 40 B | 23.84 | 10.50 | 1.88 | 14.90, 24.00 |
| lit.frag | G710 | 64 | 40 B | 46.11 | 15.00 | 1.88 | 28.98, 24.00 |
| lit.frag | G68 | 64 | 158 B | 55.25 | 27.00 | 3.75 | 34.50, 72.00 |
| marks.frag | G615 | 64 | | 5.55 | 9.00 | 0 | |
| marks_pulse.frag | G615 | 38 | | 3.05 | 5.00 | 0.12 | 6.87, 11.00 |
| backdrop.frag | G615 | 30 | | 1.65 | 1.00 | 0.12 | 0.94, 1.00 |
| catcher.frag | G615 | 9 | | 0.30 | 0 | 0 | |
| show.frag | G615 | 8 | | 0.10 | 0 | 0.12 | |
| bake.frag | G615 | 64 | 58 B | 117.70 | 20.40 | 0 | (once a theme) |
| lit.vert | G615 | 17 | | 0.38 | 4.00 (14 with varyings) | | |

The vertex shaders and the screen's part are small; the lit fragment shader is the
frame. Ablated (a scratch copy of lit.frag through malioc, each change alone: the
material fixed, so the compiler drops the other paths; a feature replaced by a
constant):

| lit.frag variant | G615 regs, spill | G615 A longest | G710 A longest | G68 regs, spill | G68 A, LS longest |
| --- | --- | --- | --- | --- | --- |
| As is (every material) | 64, 40 B | 14.90 | 28.98 | 64, 158 B | 34.50, 72.00 |
| The field's path | 64 | 8.19 (LS 9) | 15.95 | 64 | 19.50, 9.00 |
| The field without its occlusion loop | 32 | 3.26 (LS 0) | 6.35 | 32 | 9.52, 0 |
| The field without its shadow taps | 32 | 7.94 (LS 9) | | | |
| The field without the reflection's harmonics | 64 | 7.94 | | | |
| The field without specular antialiasing | 64 | 8.19 | | | |
| The field with none of the four | 32 | 1.80 | | | |
| The frame's path | 64 | 4.91 | | | |
| A piece's path | 64, 48 B | 14.42 (LS 26) | 28.03 | 64, 158 B | 34.25, 93.00 |
| A piece without the crown | 64 | 7.78 (LS 0) | 14.83 | 64 | 21.62, 0 |
| No occlusion loop and no crown, every material | 64 | 8.18 (LS 0) | 15.62 | 64 | 21.88, 0 |

- **The field's occlusion loop** (3 × 3 squares read from a storage buffer, an `asin` for
  each piece) is most of a field pixel: without it 8.19 → 3.26 cycles, 9 → 0 loads, and
  64 → 32 registers, which doubles the threads a core holds. The field is most of the
  board's pixels. It changes only when pieces move.
- **The crown** (its 11-edge distance three times, for its slope) holds the spill and
  half a piece's arithmetic, and every piece pays its registers, king or not; on the
  G68 a piece's longest path has 93 load/store cycles of spilling.
- The shadow's taps cost little arithmetic (0.25 cycles) but are the field's 32 extra
  registers' other half and most of its texture cycles (1.38 → 0.25); the reflection's
  harmonics and the specular antialiasing are each under 0.3 cycles: not worth the look.

## On the PC, the clocks locked

To come: Nsight Graphics and RenderDoc captures of a `--bench` frame.

## On the Pixel 7a

To come: Streamline or Android GPU Inspector on the debuggable build.

## Acceptance criteria

- [ ] Nsight and RenderDoc captures of the moving 3D board on the PC, the clocks locked:
      each pass's and the heaviest draws' GPU time recorded here
- [ ] The Mali Offline Compiler's report for each 3D shader, recorded here
- [ ] Android GPU Inspector or Streamline on the Pixel 7a: what bounds the moving 3D
      board's frame, confirmed on the tablet
- [ ] A ranked plan of changes, each with its expected win, measured cost, and what it
      does to the look (checked against the reference images, `agents/design.md`)
- [ ] The changes made, each measured on the PC and on the tablet, with the README's and
      the rendering doc's numbers updated
