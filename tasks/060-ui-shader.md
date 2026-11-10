# 060: The UI's shader made fast in itself

Status: done

The UI's uber-shader (`widgets::FRAG`) holds 64 registers for every UI pixel, half
occupancy on Mali, and cost 1.45M GPU cycles a frame on the Pixel 7a when the UI changes
(task 059; `docs/architecture/rendering.md`, "The 3D board on devices"). Make the work
itself fast, measured with the kept layers off (`--keep off`), not hidden behind them. It
helps the flat board too.

## Found so far (2026-11-10)

`--keep off` (`src/app/flags.goose`): the UI and the 3D backdrop drawn as they come each
frame, never kept as layers (`widgets::prepare`, `render3d::keep_backdrop`), for the bench.

The Mali Offline Compiler (`scripts/shader_report.py`, then a scratch copy of `ui.frag`
with `kind` fixed or kinds' branches cut out), Mali-G710:

| Kinds in the shader | Work registers | Longest path, A cycles |
| --- | --- | --- |
| All (as shipped) | 64, 50% occupancy | 2.83 (G615) |
| 0 glass alone | 32 | 3.92 |
| 1 tile alone | 31 | 3.71 |
| 2 icon alone | 32 | 4.35 |
| 4 glyph alone | 25 | 1.09 (V-bound, 1.12) |
| 8 face alone | 32 | 4.94 |
| 0, 1, 3, 4, 5, 6, 7, 9 (all but icon and face) | 32, 100% | 3.97 |
| the same with 8 | 57, 50% | 5.59 |
| the same with 2 | 64, 50% | 5.15 |
| 1, 2, 3, 4 | 32 | 4.55 |

So every kind alone fits 32 registers; the icons' and the face's paths together with the
rest push it to 64. Also, every UI pixel pays about 1.1 varying cycles for four flat
`vec4`s, which bounds the glyphs.

## Step 1: three shaders (2026-11-10)

FRAG is built three times from one source (`widgets::BASE`, `ICONS`, `FACES`), and
`widgets::draw_quads` draws the quads in runs of one pipeline, in their order
(`gfx::draw`'s first instance; `gl_InstanceIndex` counts from it on Vulkan and Metal).
malioc: each at 32 registers, full occupancy, on the G615, G710, and G68
(`scripts/shader_report.py` reports the three). Headless shots on Windows at 1280 × 800
and 800 × 1280 (home, its plain fade, the game, a clocked game, settings, both setups, the
puzzles, a transition held halfway, the 3D game): byte-identical to the build before but
settings, whose preview moves and differs between two runs of either build.

**On the Pixel 7a** (2026-11-10): debuggable test builds beside the app, `uibefore`
(4e5864e's single shader) and `uiafter` (49cb335), the flat game (Russian, wood, autumn,
1080 × 2400), `--bench 1000`, Streamline's counters over 12 s of the presented phase (720
frames at 60 Hz), thermal status 0 at each start. "Kept" is the after build without
`--keep off`, so the UI's live cost is a column less the kept one.

| A frame | Kept layers | One shader, live | Three shaders, live |
| --- | --- | --- | --- |
| GPU active | 3.28M cycles | 3.89M | 3.81M |
| The UI's part (less kept) | | 0.61M | 0.53M (−13%) |
| Fragment active (shader cores) | 13.7M | 18.4M | 18.1M |
| All-register (64) warps | 56.6k | 176.0k | 56.5k |
| Instruction issue starvation | 2.32M | 2.57M | 1.33M |
| FMA instructions | 7.46M | 10.52M | 10.50M |
| 32-bit varying slots | 2.00M | 5.60M | 6.20M |
| Waited P50 (the Pixel's clock moves) | 10.84 ms | 14.11 ms | 13.22 ms |

So the split works as meant: the UI's 64-register warps are gone (119k a frame) and the
cores starve half as often, but the UI's cost falls only 13% on the flat board, as its
arithmetic (3M FMA a frame) and varyings (3.6M slots, 4.2M after: more draws, each
interpolating its own) are the same or more. Registers were not the main cost; the next
cuts are the work itself: the glass's shadow margins (48 dp round each panel, shaded
for a shadow that is mostly 0) and the varyings each pixel interpolates.

## Step 2: each quad only as large as its shadow, and glass and tiles in parts (2026-11-10)

The vertex shader's margin round a quad is now what its shadow reaches on each side, and
a pixel for the edge: glass 6 dp above, 18 to the sides, 30 below (48 all round before), a
tile 0, 6, and 12 (20). Glass and tiles then shade a pixel outside them as the shadow
alone, and one more than 3 dp inside as the fill alone: the highlight, border, edge, and
shadow are exactly 0 there. Shots: within 1 level of 255 on at most a few hundred pixels
along panels' edges (the compiler's rounding), the 3D game as two runs of one build.

## Step 3: fewer varyings, tried and undone (2026-11-10)

malioc said a pixel pays about 0.06 varying cycles for each flat component it reads (a
`vec4` 0.25), so the glyph's atlas coordinate was interpolated in the vertex shader
(`v_uv`, 2 components read instead of 8; malioc 1.12 → 0.75 varying cycles for a glyph)
and the style read only by tiles and icons (f36ee1c). On the Pixel it changed nothing:
GPU active 3.575M → 3.576M a frame, the 32-bit varying slots 5.21M both, so the hardware
pays for the varyings declared, not those a path reads. Undone.

Also left: the quad read from the storage buffer by a flat index (malioc: 4 load/store
cycles a pixel against 1.12 varying ones), and the color and extra as `mediump`
varyings (1.12 → 1.00, less precise). Half precision for the colors' math: not worth it
after step 2, as a glass or tile pixel's work is now the edge's distances, which must
stay 32-bit.

**On the Pixel 7a**, as above (12 s of the presented phase, a frame):

| | Kept | One shader | Step 1 | Step 2 | Step 3 (undone) |
| --- | --- | --- | --- | --- | --- |
| GPU active | 3.28M | 3.89M | 3.81M | 3.58M | 3.58M |
| The UI's part (less kept) | | 0.61M | 0.53M | 0.30M | 0.30M |
| Fragment active | 13.7M | 18.4M | 18.1M | 15.2M | 15.2M |
| FMA instructions | 7.46M | 10.52M | 10.50M | 8.58M | 8.58M |
| 32-bit varying slots | 2.00M | 5.60M | 6.20M | 5.21M | 5.21M |
| Rasterized quads | 2.17M | 1.99M | 1.99M | 1.88M | 1.87M |

**Steps 1 and 2 together: the UI's live cost 0.61M → 0.30M GPU cycles a frame (−51%)**,
its fragment cycles 4.69M → 1.54M (−67%), and the flat frame drawn live 3.89M → 3.58M
(−8%). On the Pixel the cool-down check is skin under 30 °C: its overall thermal status
stayed at 1 with every sensor at 0 and the skin at 23 °C.

## The 3D board on the Pixel 7a (2026-11-10)

`--board 3d`, the same game, `--bench 1000`; the presented phase found from the log
(`onResume` to `presenting` and `presented`, placed at the capture's first GPU activity),
14.7 s of it, a frame: the single shader (`uibefore`) and steps 1 and 2 (`uistep2`)
drawing the UI and the backdrop live, and `uistep2` with them kept.

| A frame | Kept | One shader, live | Steps 1 and 2, live |
| --- | --- | --- | --- |
| GPU active | 5.22M | 6.76M | 6.21M |
| The live layers' part (less kept) | | 1.54M | 0.99M (−36%) |
| Fragment active | 19.5M | 28.3M | 25.4M |
| FMA instructions | 9.53M | 16.10M | 14.07M |
| All-register warps | 81.0k | 205.2k | 80.8k |
| Waited P50 with the shadow map | 11.29 ms | 13.04 ms | 12.98 ms |

The live layers' part holds the backdrop's grade too (0.43M, task 059), which this task
left alone, so the UI's own falls from about 1.1M to 0.56M, about half, as on the flat
board.

## Left

- The plain background's glass works the fade out a pixel at a time (about 1.3 of
  glass's 4 cycles in malioc); a texture of it would save that but smear its dither, and
  pays only while the UI changes with the plain background: not done (the user agreed,
  2026-11-10).
- The tablet's `--bench 1000`: skipped for now (the user, 2026-11-10).

## Acceptance criteria

- [x] Every UI pipeline at 32 registers or fewer on the G615 and G710 (and the G68)
- [x] The look the same as before (headless shots: within 1 level of 255, step 2)
- [x] GPU cycles a frame on the Pixel, before and after, with `--keep off`, recorded
      here: the flat and the 3D board; the tablet's bench skipped (the user, 2026-11-10)
