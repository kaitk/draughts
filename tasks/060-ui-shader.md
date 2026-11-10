# 060: The UI's shader made fast in itself

Status: in-progress

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

## Plan

1. Three variants of FRAG from one source with defines (as `MARKS_PULSE` does): the base
   kinds, the icons (2), the faces (8); `draw_quads` draws the quads in runs of one
   pipeline, in order (`gfx::draw`'s first instance), so the blending order holds.
2. Fewer flat varyings where a kind needs fewer (the glyph's uv from the vertex shader).
3. Check shots against the build before; measure GPU cycles a frame on the Pixel
   (Streamline, `agents/testing.md`'s "GPU profiling") and `--bench 1000` on the tablet,
   both with `--keep off`, test builds beside the app (`--id-suffix`).

## Acceptance criteria

- [x] Every UI pipeline at 32 registers or fewer on the G615 and G710 (and the G68)
- [ ] The look the same as before (headless shots)
- [ ] GPU cycles a frame on the Pixel and `--bench 1000` on the tablet, before and after,
      with `--keep off`, recorded here
