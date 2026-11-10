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

Nsight Graphics 2026.4's GPU Trace (the user ran it from Nsight's window: its command line,
`ngfx.exe`, fails to start Qt when launched from the agent's shell, in its sandbox or out
of it), 2026-11-10: `--size 1920x1200 --board 3d --screen game --theme wood --variant
russian --bench 3000`, from frame 400, 5 frames, every action timed, the clocks at base
(2235 MHz). Saved locally as `build/nsight/bench3d.ngfx-gputrace`.

- Each frame 0.92 to 0.95 ms apart (the bench's waited phase), **the GPU busy 0.25 to
  0.29 ms of it**: the whole moving 3D frame is a quarter of a millisecond on the 4090.
- The shaders' samples are FP32 arithmetic mostly; their stalls are on texture fetches
  (47.5%) and FP32 rounding (28%).
- At this size the 4090 shows the frame's shape and nothing finer: the Pixel's own
  counters and timeline (below) rank the passes and the draws.

## On the Pixel 7a

The debuggable build (`--debuggable`, 2026-11-10, `3d9ecd4`'s code), `--bench 1000` (the
3D game, Russian, autumn, 1080 × 2400, MSAA 4×), thermal status 0. Streamline 9.9.1's
gatord run by hand (`streamline_me.py`'s headless run didn't keep the capture, and
`Streamline-cli -generate-config` rejects every template), 42 G710 counters and the Mali
timeline, read back with `Streamline-cli -report -timeline` and `-cam`:

```sh
adb shell "cd /data/local/tmp && ./gatord --android-pkg io.github.kaitk.draughts \
  --android-activity .DraughtsActivity \
  --activity-args \"--es args '--board 3d --screen game --theme wood --variant russian --bench 1000'\" \
  --stop-on-exit yes --max-duration 100 --output /data/local/tmp/b.apc --gpu-timeline auto -c configuration.xml"
```

(`configuration.xml` lists `ARM_Mali-G710_<COUNTER>` lines and `MaliTimeline_Perfetto`;
the IDs are in gatord's binary; `streamline_me.py` pushes gatord and the layers first.)
The bench in that run: waited P50 13.47 ms, the pass alone 12.88, presented 16.65 ms frame
to frame; without the profiler 12.75 to 12.94, 12.65 to 12.77, 16.65 to 16.73.

**The GPU's clock:** sampled from `/sys/class/misc/mali0/device/cur_freq` through a
bench run, 351 to 471 MHz, a mean of 360 to 400 MHz in every phase (the G710 reaches
about 850). The governor runs it as slow as keeps up, and the GPU is busy nearly all
the time at that clock (393M active cycles a second). So the Pixel's frame time is the
work at a low clock; **GPU cycles a frame are the measure**, and cutting work lowers the
clock (battery) as much as the time.

**Each pass** (the Mali timeline, the median over 840 to 900 frames a phase):

| Pass | Fragment | Vertex |
| --- | --- | --- |
| The 3D pass (4× MSAA color and depth, 3 draws: pieces, board, catcher) | 6.86 to 6.89 ms | 0.43 to 0.46 ms |
| The screen pass (4 draws: the backdrop, the kept image, the UI's two) | 4.58 ms | 0.10 ms |
| The shadow map (1024², 2 draws), on the frames that draw it | 0.40 ms | 0.42 ms |
| The screen pass with the backdrop and the kept image alone (the bench's pulse phase) | 2.38 ms | |

So the waited frame is GPU work, about 12 ms at 360 MHz, with no large fixed part
(hypothesis 1 is out). **The screen pass is 40% of it**: its two full-screen layers
2.4 ms and the UI about 2.2 ms.

**The counters, per frame** (the pass alone; with the shadow map in brackets):

| Counter | Per frame | Reading |
| --- | --- | --- |
| GPU active | 6.23M cycles (6.84M) | the shadow map adds 10% |
| Fragment queued / tiler active | 5.41M / 0.20M | fragment-bound; geometry is done |
| Fragment warps; all-register (64) warps | 690k; 195k | the lit shader's 28% run at half occupancy |
| Full warps | 667k (97%) | small triangles waste little |
| Quads rasterized; partial | 2.74M; 180k | 4.2 a screen's quads: the screen pass's two full-screen layers are most |
| Early ZS tested; killed | 335k; 44k | little overdraw to reject |
| FMA / CVT / SFU instructions | 15.9M / 5.8M / 2.1M | arithmetic |
| Texture filtering active; its stalls | 4.05M; 11.5M | the texture unit waits 3× as long as it filters |
| Varying slots, 32-bit; 16-bit | 6.7M; 0 | no 16-bit varyings |
| External reads; writes | 458k; 180k beats (about 7 and 3 MB) | 0.6 GB/s: not bandwidth-bound |
| Tiles; unchanged tiles killed | 9.7k; 19.3k | transaction elimination drops most writes |

**The screen's shaders** (`scripts/shader_report.py`, the G710; the G615 about half):

| Shader | Registers | A longest | A total (every branch) |
| --- | --- | --- | --- |
| backdrop.frag (full screen) | 30 | 1.87 | 3.27 |
| show.frag (full screen) | 8 | 0.20 | 0.20 |
| ui.frag (the UI's quads) | 64 | 5.59 | 58.20 |
| board2d.frag (the flat board, full screen) | 32 | 10.11 | 15.58 |
| piece2d.frag (the flat pieces) | 64 | | 15.18 |

The UI's shader holds 64 registers for every UI pixel, whatever it draws; the flat board
pays the same UI, so its frame (11.8 ms waited on the Pixel) gains from the same change.

## The plan, ranked (2026-11-10, before any change)

The Pixel's 3D frame is about 12 ms of GPU work at its governor's 360 MHz: the 3D pass
6.9, the screen pass 4.6, the shadow map 0.8 when drawn. Expected wins are in the
Pixel's milliseconds at that clock, from the counters and the offline compiler; the
tablet's are to be measured. Each is checked with headless shots against the build
before (`agents/design.md`) and measured with `--bench` on the tablet.

1. **The field's occlusion into a small map, drawn when pieces move.** The 3 × 3 loop
   over the squares is most of a field pixel (G710: 16.0 → 6.4 cycles, 64 → 32
   registers, 9 → 0 loads). Draw it into a 256² R8 map over the field (64k texels, a
   sixteenth of task 042's dropped 1024² bake; 31 texels a square for a falloff a
   piece's radius wide) when the pieces stand differently, and read one bilinear texel.
   **Expected 1.5 to 2.5 ms** of the 3D pass's 6.9, less on a moving frame by the small
   pass. Look: the same (a smooth function, filtered); check the dark ring at a piece's
   foot at 200%.
2. **The screen's still layers kept, the board laid in its own rect.** The backdrop and
   the kept image are two full-screen layers (2.4 ms) and the UI 2.2 more, every frame,
   while only the board moves. Draw the backdrop into a kept screen image when the
   theme, size, or blur changes, and lay the 3D image only over the board's bounds (it
   is clear round them): one opaque full-screen copy and a board-sized quad. **Expected
   1 to 1.5 ms.** Look: the same; transitions and the fade keep their own path.
3. **The UI's shader under 32 registers:** split by what a quad draws (glass, icons,
   text), or its rare branches moved out. Half occupancy on every UI pixel today, on the
   flat board too. **Expected about 1 ms** on both boards. Look: the same.
4. **The crown into a texture.** Its distance evaluated three times holds the lit
   shader's spill (40 bytes; the G68's 158) and half a piece's arithmetic, for every
   piece. A 128² distance map of the crown, made once, read once with its slope from
   the texel's derivatives. **Expected 0.3 to 0.8 ms**, more on the G68. Look: the same
   at a piece's 140 px; check the crown's edge at 200%.
5. **The shadow map's pass when pieces move, 0.8 ms**, and its 9 taps on every lit pixel
   (most of the field's texture cycles): analytic shadows of the discs on the field (the
   stadium a disc sweeps along the light), sharing item 1's map, and the map only for
   piece on piece. **Expected 0.8 ms on moving frames plus some of the texture stalls.**
   Look: the penumbra's shape changes, a choice to show the user.
6. **fp16 (`mediump`)** for colors, the harmonics, the tonemap, and the varyings that
   allow it, once 1 and 4 are in: Valhall's FMA runs fp16 at twice the rate and the
   varying unit packs 16-bit slots (6.7M 32-bit slots a frame now). **Expected 10 to 20%
   of what arithmetic remains.** Look: watch for banding in the dark wood.
7. **MSAA 4× read again** (`setup`'s `samples` 1, measuring only): partial quads are 6.6%
   of all, so its cost now is likely small; if it is, nothing changes.
8. **Resolution, last:** the 3D pass is fragment-bound, so a render scale of 0.8 takes
   about 36% of its pixels (**about 2.5 ms**) but softens the board. Only if 1 to 6
   leave the tablet over 11.1 ms.

Not worth it, from the counters: bandwidth (0.6 GB/s), geometry (the tiler 3% of the
GPU's time, 97% full warps), early-depth order (44k quads killed of 335k tested), the
reflection's harmonics and the specular antialiasing (under 0.3 cycles each).

## The changes, measured

### 1. The field's occlusion into a map (2026-11-10)

`shaders::OCC_FRAG` draws the pieces' occlusion of the field (the 3 × 3 loop of
cylinders the lit shader ran per field pixel) into a 512² R8 map over the plan's extent
(`render3d::occlusion`): all of it for a new board or size, otherwise only the squares
that changed and one round them, scissored. The lit shader reads one bilinear texel and
keeps the frame's inner wall analytic (`wall_occlusion`, too sharp for the map). One
pipeline more to make while getting ready (39 steps).

- **The look:** the seven headless scenes at 1920 × 1200 (the four seasons at the
  start, a middlegame with kings, portrait, International) against the build before: no
  pixel more than 4 levels off, 47 to 70 dB; the build before against itself differs as
  much (at most 3 levels, 47 to 64 dB), so the change is within run-to-run noise.
- **The Pixel 7a** (Streamline, the same 1000-frame bench, 8 to 52 s of it): the 3D
  pass's fragment work 6.86 → 6.03 ms (median), **GPU active 7.01M → 6.54M cycles a
  frame (−7%)**, the shader cores' fragment cycles 30.0M → 27.8M, the texture unit's
  stalls 12.0M → 11.0M. The bench's waited time 12.77 → 12.17 ms for the pass alone
  (the governor's clock moves it as much as the work). The map's pass: 0.05 ms for a
  move's few squares, 2.1 to 2.4 ms for the whole map (a new game or size, one frame).
- Below the 1.5 to 2.5 ms the plan expected: the field is about a tenth of the frame's
  fragment warps (64k of 729k), and the loop's loads overlapped other work.
- **Tried and dropped:** the field drawn alone in a variant of the lit shader with its
  material a constant (the board mesh's first 6 indices), 32 registers and full
  occupancy against the shared program's 64 (malioc, the G710: 6.6 cycles). On the
  Pixel it gained 1% of the fragment cycles and none of the GPU's (6.54M → 6.59M), and
  the all-register warps stayed at 206k a frame in all three captures: the field's
  warps were never among them, so the driver's real register count for the field isn't
  what malioc reports, or occupancy doesn't limit it. Not worth a pipeline more.
- **The tablet** (2026-11-10, debuggable test builds beside the app, each commit as
  its own id; the same 1000-frame bench, thermal status 0, the screen kept on; the GPU's
  clock from `/sys/kernel/gpu/gpu_clock`, near its 1047 MHz top throughout, so unlike
  the Pixel the frame times show the work; Streamline isn't on the Mac): the build before
  (fab1757) waited P50 10.86 and 10.59 / P99 12.92 and 12.78 ms, the pass alone 10.30 and
  10.03, presented 12.92 ms frame to frame, 172 frames of 994 (17%) on screen for two
  refreshes, 45 fps at the compositor's 1% low. With the map (b9536de): **waited P50
  9.79 / P99 12.14 ms**, the pass alone 9.13, presented 11.99 ms, 9% dropped.

### 2. The backdrop kept (2026-11-10)

First, what each of the screen's two full-screen layers costs, from two throwaway
builds on the Pixel (Streamline, the same bench): the backdrop cut to a plain texture
copy took GPU active from 6.54M to 6.11M cycles a frame and the screen pass from 4.57
to 3.28 ms; the 3D image's layer left out took it only to 6.47M (−1%). So laying the
image over the board's bounds alone isn't worth doing (the layer is 8 registers and
0.2 cycles); the backdrop's grade, vignette, and fade (30 registers, 1.9 cycles on the
G710) is the cost.

`render3d::keep_backdrop` draws the backdrop at full opacity into an RGBA8 image the
screen's size before draw()'s passes when what it is drawn from changed (the size, a
photograph step, the grade, the tint, the plain fade's brightness and colors), and
`render3d::backdrop` lays it with `shaders::KEPT_FRAG` (a texel fetch, 6 registers),
blended at the same opacity; when the image isn't current (a photograph changed, no 3D
draw since) it grades live as before, so a frame is never wrong. Two pipelines more to
make while getting ready (12 warm steps); 10 MB more on the Pixel (1080 × 2400 × 4), 9
on the tablet.

- **The look:** the seven scenes against the build before: no pixel more than 4 levels
  off, 52 to 71 dB; four of them now differ only inside the board's box (the
  full-screen 1 to 2 levels the builds showed against themselves came from the live
  backdrop).
- **The Pixel 7a:** **GPU active 6.54M → 6.06M cycles a frame (−7%)**, the screen
  pass's fragment work 4.57 → 3.03 ms (median), FMA instructions 16.1M → 12.9M a frame.
  The pass alone waited 12.17 → 11.78 ms; the screen's part of a pulsing frame without
  rings 3.29 → 2.07 ms waited.
- **Both items so far:** GPU active 7.01M → 6.06M cycles a frame (−14%).
- **The tablet:** waited P50 9.79 → **9.15** / P99 12.14 → 11.05 ms, the pass alone 9.13
  → 8.52, presented 11.99 → 10.99 ms; **no frame dropped, 90 fps at the 1% low**: the
  moving 3D board inside 11.1 ms at 90 Hz from here on.

### 3. The UI kept while it stands still (2026-11-10)

The plan's item 3 was the UI's shader under 32 registers, about 1 ms. First its whole
cost, from a throwaway build without `widgets::frame` on the Pixel: GPU active 6.06M →
4.61M cycles a frame, **the UI 24% of the frame** (1.45M cycles for 479k quads, 0.74
of a screen, with glass's 48 dp shadow margins), and 125k of the 206k all-register
warps. A leaner shader would cut part of that on every frame; not drawing what didn't
change cuts nearly all of it on the frames where only the board moves, which are most.
(The uber-shader's 64 registers for every kind is still a cost on the frames where the
UI changes: split by kind if those measure heavy.)

`widgets::prepare` (before the frame's passes, in place of `upload`) compares the
frame's quads (bytes, up to 32 KB), view, theme, and texture ids with the last frame's,
and a re-baked glyph atlas marks it stale. Changed: the quads are uploaded and
`widgets::frame` draws them as before. The same a frame later: they are drawn once into
an RGBA8 layer the screen's size, cleared, premultiplied, and `widgets::frame` lays it
(`COMPOSE_FRAG`, a texel fetch) until they change. The layer has the screen's format,
so the UI's pipeline needs no second compile. Item 2's warm step for the backdrop on an
RGBA8 target goes for the same reason (11 steps; 39 to prepare).

- **The look:** the seven scenes against item 2's build: at most 2 levels off (the
  8-bit layer's rounding), 51 to 68 dB.
- **The Pixel 7a:** **GPU active 6.06M → 4.70M cycles a frame (−22%)**, the screen
  pass's fragment work 3.03 → 1.57 ms (median), all-register warps 206k → 81k; within
  2% of the build without any UI. The waited times barely move (12.08 ms the pass
  alone): the governor lowers the clock as the work falls, so the saving is battery.
- **The three items:** GPU active 7.01M → 4.70M cycles a frame (−33%).
- **The tablet:** waited P50 9.15 → 9.23 / P99 11.05 → 10.98 ms, the pass alone 8.52 →
  9.00, within run to run (the GPU's clock near its top at both; the build before and
  main 85% and 83% busy at 1024 and 975 MHz on average); the bench's own presented 1% low 69 → 77 fps, still none dropped.
  Main (with c7d23bf's pacing, which a board that keeps up leaves at 90 Hz) in two runs:
  9.35 and 9.18 / 10.92 and 11.24 ms, the pass alone 9.15 and 8.98. **The four items
  on the tablet: waited P50 10.6 to 10.9 → 9.2 to 9.4 ms, dropped frames 17% → 0.**
- **The user's view (2026-11-10):** prefer making the work fast over caching slow work,
  which can hide slowdowns that cascade; caches stay where nothing changes for long.
  The live paths behind items 2 and 3 cost what's measured above (the backdrop's grade
  0.43M cycles a frame, the UI 1.45M): the uber-shader's own speed is a separate session,
  measured with the caches off.

### 4. The crown into a map (2026-11-10)

The crown's signed distance (`shaders::CROWN_FN`, the 11-point polygon, three balls and
the bar) is drawn once at setup into a 256² R16F map over ±0.6 of the piece's radius
(`render3d::crown_map`, a texel 0.7 px on a piece 140 px across, 128 KB); the lit
shader's `crown()` is a bilinear fetch, three of them for the slope as before.

- **The offline compiler, the lit shader:** the spill gone on all three cores (no
  stack, LS 0 on the longest path; it was 24 on the G615 and 72 on the G68), the longest
  path 28.9 → 17.1 cycles on the G710 and 34.5 → 23.9 on the G68. Still 64 registers.
- **The look:** the middlegame with crowned kings (`kings = crown` in the PC's player
  file for the shot, restored after) at 1920 × 1200: 7 pixels more than 4 levels off, at
  most 9; at 3840 × 2400, 33 of 9.2M, at most 17, all where a ball meets its point (the
  neck a hair softer from the map's filter). At 400% and 800% the crowns are the same,
  the points and balls sharp, no stepping. Crops in the session's scratchpad.
- **The Pixel 7a, 16 crowned kings** (`--fen` with every piece a king, `kings = crown`):
  **GPU active 6.24M → 4.12M cycles a frame (−34%)**, the 3D pass's fragment work 8.99
  → 7.53 ms (median), fragment cycles 25.1M → 17.8M. The crown, three distance
  evaluations with a spill in every king's top pixel, was a third of the frame there.
- **The start position (no kings):** 4.70M → 4.77M, within run-to-run noise.
- **The tablet, 16 crowned kings:** the build before 12.22 / 14.44 ms waited, 31%
  dropped; item 3's build 10.62 / 12.53, 9% dropped; with the map **9.05 and 9.03 /
  10.79 and 10.50 ms, the pass alone 9.2 and 8.8, none dropped**: the kings now cost no
  more than the start position.

### The look on the tablet (2026-11-10)

Screenshots (`adb exec-out screencap`) of the build before and main, 1920 × 1200: the
game at each season's theme (stone, birch, sunset), settings, a transition held halfway
(`--go home --hold 0.5`), and 16 crowned kings on wood. All but the kings at most 7
levels off, 48 to 57 dB; the kings 114 pixels more than 8 levels off (at most 43), on
the dark rim where a ball meets its point, the same at 400%. A season changed live
wasn't filmed.

## Acceptance criteria

- [ ] Nsight and RenderDoc captures of the moving 3D board on the PC, the clocks locked:
      each pass's and the heaviest draws' GPU time recorded here
- [x] The Mali Offline Compiler's report for each 3D shader, recorded here
- [ ] Android GPU Inspector or Streamline on the Pixel 7a: what bounds the moving 3D
      board's frame, confirmed on the tablet
- [x] A ranked plan of changes, each with its expected win, measured cost, and what it
      does to the look (checked against the reference images, `agents/design.md`)
- [ ] The changes made, each measured on the PC and on the tablet, with the README's and
      the rendering doc's numbers updated
