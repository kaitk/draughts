# 086: Better shadows for the 3D board at a phone's cost

Status: in progress

The pieces' shadows come from one 1024² 16-bit shadow map of the key light, drawn only
when the pieces move, and filtered in the lit shader on every pixel of every drawn frame:
9 hardware-compared taps over 5 × 5 texels on a tablet and a desktop, 4 over 3 × 3 on a
phone (task 081 and its decision in `docs/decisions/rendering.md`). On a phone the 4 taps
are a compromise the user accepted, but the session that made it judged stills only, and
the user found the shadows hard, blocky, and jagged in motion. The user's aim
(2026-11-13): shadows that are neither costly nor an aliased mess, judged in motion; a
technique general enough for chess pieces later (any mesh, not only discs), so an
analytic disc shadow can only be a complement or a phone-only path.

The scene: up to 40 flat cylindrical pieces (radius 0.44, height 0.29) on a flat field
(±4 in x and z, y = 0, a frame to ±4.6, 0.05 high), one directional key light about 53°
up (`looks::Theme.key`, turned with the board by `render3d::turn_light`), a camera that
mostly holds still or turns slowly in the showcase, and a renderer that draws only when
something changed. Budgets: the Galaxy A33 (Mali-G68, slowest) holds 60 fps with about
1 M cycles of headroom; the 9 taps cost it 1.5 to 2 M cycles a frame, the 4 about 0.8 M.

## What was found

- **The shadow map is stable already.** The light is fixed to the board, and the camera
  never enters the shadow map's projection, so a turning camera can't make the shadow
  swim: texel snapping (Valient) is moot here. What crawls is a moving piece's
  silhouette crossing texels, and the filter being too narrow for the texel size to hide
  that: the 4 taps' 3 texels show each step.
- **The map wastes texels.** `render3d::light` frames a square ±6.6 view along the
  light; the board's square projects into it turned and slanted, and the field, the main
  receiver, gets each texel stretched 1.25× along the light. Projecting along the light
  onto the board's plane (an oblique, affine map: a point's texel is where its light ray
  meets y = 0, its depth how far along the ray) fills the map with the board at one
  square texel size: 2.1× the texels on the field for nothing, any mesh casting as now.
  This is the plane-receiver case of fitting the light's frustum to the receivers
  (Stamminger and Drettakis's perspective shadow maps, Martin and Tan's trapezoidal ones,
  Wimmer et al.'s LiSPSM all aim at this for a view-dependent frustum; here the
  receiver is one known plane and the light fixed, so the fit is exact and constant).
- **Drawing on change lets the field's shadow be baked.** The field is a plane, as the
  pieces' occlusion map (`shaders::OCC_FRAG`) already exploits: its key-light visibility
  can be baked into a map over the plan each time the shadow map is drawn, filtered as
  generously as wanted (contact-hardening PCSS), and read by the field with one bilinear
  tap a pixel, on every frame, whatever the camera does. The pieces and the frame keep
  sampling the shadow map, a small part of the screen. This is the cached shadow map
  idea (static casters' maps kept between frames, as engines from Far Cry's to Unreal's
  virtual shadow maps do) taken one step further: cache the filtered result in
  receiver space.
- **Temporal filtering doesn't fit.** Draw-on-change shows a still frame for seconds;
  noise rotated per screen pixel and accumulated over frames (TAA, as interleaved
  gradient noise is meant for, Jimenez 2014) has no frames to accumulate over, and a
  turning camera slides screen-space noise over the board. Noise is fine only fixed to
  the board and blurred, as the bake does.
- **Mac timings could not be taken this session.** Another session's benches and a VM
  loaded the GPU: `board3d --bench 300 --size 2560x1600` waited 9 to 16 ms a frame for
  every way, against task 081's 1.65 ms for the pass, the spread far above any
  difference between the ways. Measure on a quiet Mac (`scripts/mac_gpu_time.py`'s way,
  Metal System Trace) and on the A33.

## Candidates

| Way | Look | Per-frame cost | Extra memory, passes | Raised piece | Any mesh |
| --- | --- | --- | --- | --- | --- |
| Now: 9 or 4 Castaño taps | 5 or 3 texels of fixed blur; 4 taps' steps crawl | 9 or 4 compare taps a lit pixel | none | as sharp as at rest | yes |
| Fitted map (plan projection) | same filter, 2.1× the texels: steps smaller, blur narrower | none added | none | same | yes |
| Wider Castaño (7 × 7 in 16 taps) | softer, steps hidden | 16 taps a pixel: too dear on the A33 | none | same | yes |
| PCF on a rotated Poisson or Vogel disc per screen pixel | soft, but noise that slides as the camera turns, no TAA to hide it | 16 to 32 taps | none | with PCSS, softer | yes |
| PCSS (Fernando 2005) per pixel | contact hardening, the best look | blocker search + PCF: 30 to 50 taps | none | softer the higher | yes |
| VSM (Donnelly and Lauritzen 2006) | prefiltered once on change, 1 tap a pixel; light bleeds where shadows overlap (a raised piece over another) | 1 bilinear tap and a little ALU | RG16F or RG32F map and a blur on change | fixed blur unless mips | yes |
| EVSM (Lauritzen and McCool 2008) | VSM with the bleeding mostly gone | 1 tap | RGBA32F (16 MB at 1024²) to be safe; RG16F's exponent too small; Mali may not filter 32-bit floats | as VSM | yes |
| MSM (Peters and Klein 2015) | four moments, little bleeding, 16-bit quantized and filterable everywhere | 1 tap and a 3 × 3 solve | RGBA16 (8 MB) and a blur on change | as VSM | yes |
| Baked field visibility (fitted map, PCSS in a bake over the plan) | contact hardening on the field, smooth, nothing slides | 1 bilinear tap on the field; the pieces and frame keep 9 or 4 taps | R8 1024² (1 MB) and a 1 MB temporary; a bake when the pieces move | softer the higher, as PCSS | yes: any mesh casts into the map |
| Analytic discs on the plane (a disc's or cylinder's soft shadow along the light, per field pixel, the pieces from the squares buffer) | exact, very soft, contact darkening | a loop over nearby pieces a field pixel, as OCC_FRAG's | none | exact | no: discs only |
| Projected blob per piece (a precomputed soft disc texture) | soft, cheap; wrong shape for chess | 1 tap per overlapping piece | a small texture | scale and fade with height | no |
| SDF or capsule shadows (Iwanicki 2013, Aaltonen's Claybook 2018, Quilez's sphere and SDF soft shadows) | soft and correct for proxies | a few proxies a pixel | proxies per piece kind | yes | per mesh kind, by hand |
| Screen-space contact shadows (Bend Studio's, Aldridge 2023) | fills the contact line under a mesh | a short ray march a pixel | needs depth | n/a | a complement |

Notes on the table: VSM, EVSM, and MSM spend a blur over the whole map on every change
and keep a 4 to 16 MB map, against the bake's 1 MB and a bake only where shadows are;
they would also serve the pieces as receivers with one tap. They are the fallback if the
pieces' own 9 or 4 taps turn out to matter (they are a small share of the screen). The
analytic disc stays an option for the phone alone, and the existing occlusion map
(`OCC_FRAG`) already gives each piece its contact darkening.

## Recommendation

1. **Fit the map to the board** (`render3d::plan_light`): free, any mesh, 2.1× the
   texels on the field; with it the 4 taps' steps are smaller, and a phone could keep 4
   taps on the pieces.
2. **Bake the field's shadow** from the fitted map when the pieces move, PCSS with a
   smoothing pass, the field reading one texel: the field gets contact hardening and a
   raised piece's shadow softens as it rises, at less per-frame cost than now on every
   device (one tap in place of 9 or 4 on most of the board's pixels). The bake's own
   cost on the A33, on frames a piece moves, is the open question; it can be cut as the
   occlusion map's is, to the squares a moving piece's shadow covers, and its search
   ends at once where no blocker is found (most texels).

## The prototype (removed)

`poc/3d/board3d.goose`'s **H** key and `--shadows now|fit|baked` cycled the ways (commit
91bed8f): `now` the square view, `fit` the map fitted to the board, `baked` that with the
field's shadow baked from it (PCSS, 16 blocker taps and 32 Vogel taps turned by
interleaved gradient noise fixed to the board, a 9-tap smoothing pass, into an R8 1024²
map; `SOFT` 0.12, `SEARCH` 0.18). Once the user picked `fit`, the ways went and the app
draws `fit` alone; that commit has the bake's code if it is wanted again.

## Sources

- R. Fernando, "Percentage-Closer Soft Shadows", SIGGRAPH 2005 sketch (NVIDIA).
- I. Castaño, "Shadow Mapping Summary, Part 1", The Witness blog, 2013: the filter
  `shadow()` uses.
- J. Jimenez, "Next Generation Post Processing in Call of Duty: Advanced Warfare",
  SIGGRAPH 2014: interleaved gradient noise.
- W. Donnelly and A. Lauritzen, "Variance Shadow Maps", I3D 2006.
- A. Lauritzen and M. McCool, "Layered Variance Shadow Maps", GI 2008 (the exponential
  warp EVSM uses); T. Annen et al., "Exponential Shadow Maps", GI 2008.
- C. Peters and R. Klein, "Moment Shadow Mapping", I3D 2015.
- M. Valient, "Stable Rendering of Cascaded Shadow Maps", ShaderX6, 2008.
- M. Stamminger and G. Drettakis, "Perspective Shadow Maps", SIGGRAPH 2002; T. Martin
  and T.-S. Tan, "Anti-aliasing and Continuity with Trapezoidal Shadow Maps", EGSR 2004;
  M. Wimmer, D. Scherzer, W. Purgathofer, "Light Space Perspective Shadow Maps", EGSR 2004.
- M. Iwanicki, "Lighting Technology of The Last of Us", SIGGRAPH 2013: ellipsoid and
  capsule occluders for soft character shadows.
- S. Aaltonen, "GPU-Based Clay Simulation and Ray-Tracing Tech in Claybook", GDC 2018:
  signed-distance soft shadows.
- I. Quilez, "Soft shadows in raymarched SDFs" and "Sphere soft shadow", iquilezles.org.
- G. Aldridge, "Bend Studio's screen space shadows", 2023.
- Arm, "Mali GPU Best Practices": depth comparison samplers for hardware PCF, 16-bit
  depth.

## Measured on the A33 (2026-11-13)

A throwaway app build beside the Play app (`--id-suffix shadows`, `draw3d::set_up` reading
`--shadows now|fit|baked` and calling `set_shadow_way`; not committed), `--board 3d
--screen game --theme wood --bench 300`, a phone's 4 taps (the field's and the pieces'
in `now` and `fit`, the pieces' in `baked`), the ways alternated, thermal status 0
before and after every run. Cycles are the waited P50 × the GPU clock sampled through
that phase. "Moving" is the bench's first phase (the shadow map, and in `baked` the
bake, drawn every frame); "at rest" its second (the board pass alone).

| Way | Moving | At rest | Moving's P99, presented 1% low |
| --- | --- | --- | --- |
| now | 16.77, 17.41 ms: 10.24, 10.64 M | 15.43, 16.03 ms: 9.43, 9.80 M | 19.4, 20.2 ms; 52, 57 fps |
| fit | 15.33 at 702 MHz, 16.80 ms: 10.76, 10.26 M | 14.26, 15.38 ms: 10.01, 9.40 M | 17.3, 21.0 ms; 57, 55 fps |
| baked | 29.42 to 29.48 ms: 17.98 to 18.01 M (3 runs) | 15.10 to 15.18 ms: 9.22 to 9.27 M | 32.1 to 33.6 ms; 32 to 35 fps |

- `fit` costs what `now` does, as it should: the same taps on another projection.
- `baked` saves 0.2 to 0.5 M cycles at rest on a phone: the field's 4 taps were cheap
  already. On a tablet or desktop, the field's 9 taps go, so more.
- The whole-map bake costs about 8.7 M cycles, 14 ms at 611 MHz, on every frame a piece
  moves: a move would play at about 34 fps. Before it can ship, the bake has to shrink to
  about the shadow map's own cost (1 to 1.3 M): only the squares a moving piece's
  shadow covers (old and new, about 1/16 of the field for one sliding piece), and fewer
  texels or taps (a 512² map, a cheaper blocker search).

## The user's look on the Mac (2026-11-13)

`baked` looks best but costs too much as it is; `fit` with the phone's 4 taps not much
better than `now`, its edge harsher; `fit` with the desktop's 9 looks good. Two flaws
seen there were bugs of their own, fixed in the app and the prototype:

- **A dark patch under a jumping piece, in every way** (the jump at 0.25): the field's
  occlusion was centered on the square a piece is over, so a moving piece's snapped from
  square to square, here onto the light square beside d4, and its 3 × 3 squares cut it
  off in a straight line. Now centered where the piece is, over 5 × 5 squares
  (`view3d::Scene.squares` two float4s a square).
- **A light dot in the raised piece's shadow, in `fit`** (the jump at 0.23 and 0.24): the
  shadow pass culled back faces (task 084), and the light leaked through a texel where
  the top curves away from it. Both faces drawn, as ngfx did; the same leaks were 500 to
  800 single pixels of the full board's shot in `now` too. On the A33 the shadow map's
  share of a moving frame grew 0.81 to 0.84 M → 0.96 to 1.01 M cycles (`now`, 4 taps,
  three runs against the two above).

## Taken into the app (2026-11-13)

The user's pick: `fit`, seen in motion on the Mac (9 taps) and the A33 (4 taps), against
`now` on each: "a bit too sharp but not too bad, and while moving there is a ton less
artifacts". `render3d::light` projects with `plan_light` on both renderers (it is shared
code), the 9 and the 4 taps as they were, the depth bias unchanged: shots at 2560 × 1600
(wood and winter's slate, the board at rest and the jump at 6 units) and 1080 × 2400
with 4 taps showed no acne. `baked` and the square view are gone from the code. The
decision is in `docs/decisions/rendering.md`.

## What is left

- An ngfx build's shot of the 3D board, once task 085's session, working on ngfx in the
  same checkout, is done: ngfx shares `render3d::light`, so it should match gfx's.
- The user found `fit` a bit sharp. If that is to change: wider taps in texels on a
  tablet and a desktop, where the 9 cost the A33 nothing (they don't run there), or an
  analytic soft disc on a phone's field.
- The quiet Mac's timings were never taken (the Mac stayed busy); the A33's decided it.

## Acceptance criteria

- [x] The candidates weighed for this scene, with sources (2026-11-13)
- [x] The best prototyped in poc/3d behind H and `--shadows`, the app's default unchanged
      (2026-11-13)
- [x] GPU timings of each way on the A33, recorded here (2026-11-13; the Mac stayed busy)
- [x] The user's pick from the ways, seen in motion on the Mac and the A33: `fit`
      (2026-11-13)
- [ ] The pick in the app on both renderers, phones included, its decision recorded
      (gfx done 2026-11-13; ngfx shares the code, its shot left)
