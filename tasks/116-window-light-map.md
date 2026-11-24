# 116: The window's light map

Status: in-progress (built and checked on the Windows PC 2026-11-24; the tablet's bench next)

The shell's sun through the windows (the casements' bars, the arches, the lace's edge and
pattern, the tree's shadow) was traced a pixel in the room's shaders (`LIGHT_FN`'s
`shell_open`): 9 to 16 ms of a 45 to 56 ms frame on the Galaxy Tab (task 115), and the
phone tier's floor paid twice, its sharp box reflection (`room_seen`) tracing it again at
the reflected point. This bakes it into the window's light map (a light cookie in graphics
terms): the pattern baked in the window wall's plane and projected along the sun.

## How it works

- **The map** (`render3d::window_map`, `render3d_gpu::window_map_pass`,
  `shaders::WINDOW_MAP_FRAG`): RGBA8, 2048 × 832 with its mips (6.8 MB, 9 MB with them),
  over the strip of the window wall's inner face that holds the three windows and 0.2 m
  round their niches, 7.7 m by 3.15 m, a texel about 3.8 mm (`shaders::window_map_place`).
  A texel is where the sun's ray from a point crosses that face; its channels are what
  `shell_open` gave there without the niche's outline: r the casements' light through the
  lace's shadow, baked for a point just past the lace; g the casements' light at the face; b
  the tree's light at the face (1 where none is baked); a the lace's outline's share of what
  it scatters on. A full-screen pass, on the GPU, whenever the sun, the shell, the tree's
  map or whether the tree is in changes (`window_map_key`), never because of the wind; then
  its mips.
- **The tap** (`shell_open` with `WINDOW_MAP`): the nearest niche's arched outline at the
  face (as before, analytic and sharp), times the map where p's ray crosses the face: g, or
  past the lace r. The penumbra widens with the distance past the face (`soft = 0.03 +
  widen × t`), so the tap's mip is chosen by how much softer an edge is at p than as baked,
  matching the variances (a level's box and bilinear tap spread `(2^L texel)² / 4`, a
  smoothstep `s² / 5`: `window_map_lod`). The lace's scattered light takes a's outline at a
  mip of its own, its cone widening faster, times the casements' glazing traced at p
  (the map can't blur a product of two outlines as each blurs alone). The tree takes b at
  the mip its own blur grows to past the face (`tree_light`'s lod). On the sashes' faces past
  the inner glass the outer casement is traced, as the map doesn't hold it.
- **The leaves** (`render3d::window_map_tree`): where the wind is still, the tree's light is
  in the map (b). While the leaves move, the desktop's shaders (`WINDOW_MAP_LEAVES`) light
  them a pixel with `tree_light` and the map leaves the tree out. The phone tier's shaders
  have no leaves of their own: they are baked at the wind's phase when the map was baked, or
  left out (`render3d::phone_leaves`, the tuner's `--phone-leaves static|off`, static by
  default).
- **Where**: the room's floor, walls, paint, sills and metals (and so the sharp box
  reflection's second trace) in the phone tier, the standard tier and the HDR target. The
  map takes the lace mask's slot, which those groups read only through `shell_open`, so no
  texture slot is added. Not the glass and the lace (they read the lace's mask), the floor's
  mirror, the tuner's views and switched shaders, the board, the table, the dust and the
  haze, which trace the windows as before. The ngfx renderer bakes no map and traces as
  before.
- **The switch**: `render3d::window_map_on`, the light tuner's `--window-map on|off` (on). Off,
  the room's pipelines are the old ones: its shots are byte-identical to the build before.
  `--leaves-moving on` lights the desktop's leaves a pixel in a shot too.

## Look (2026-11-24, Windows PC, 1920 × 1200, the map against `--window-map off`)

Pixel differences in levels (mean over the channels, the largest, pixels over 8 and 24 of
2.3 million). Shots in `build/perf/cookie/` (local).

| View | Desktop, still (tree baked) | Desktop, leaves a pixel | Phone, leaves baked | Phone, no leaves |
|---|---|---|---|---|
| Down | 0.83 / 47 / 77 134 / 6 809 | 0.66 / 47 / 56 140 / 6 474 | 0.83 / 46 / 77 089 / 6 739 | 2.98 / 168 / 194 832 / 110 914 |
| Corner | 0.54 / 121 / 49 641 / 5 835 | 0.45 / 121 / 37 343 / 5 249 | 0.57 / 112 / 51 849 / 6 173 | 2.12 / 196 / 137 054 / 82 603 |
| Room | 0.33 / 126 / 27 194 / 2 962 | 0.29 / 126 / 21 727 / 2 836 | 0.36 / 118 / 29 541 / 3 322 | 1.04 / 167 / 67 865 / 36 384 |
| Menu | 0.04 / 136 / 1 007 / 232 | 0.04 / 136 / 1 014 / 234 | 0.03 / 136 / 888 / 327 | 0.03 / 136 / 971 / 349 |

- The patches' edges near the window are a little softer: a two-step edge where the frame
  meets the glazing (a plateau a few millimetres wide on the floor 2 m away) becomes one ramp,
  as the map's texel is 3.8 mm. The largest differences are single pixels on such edges.
- On the far wall (the hall's door, 10 m past the window) the bars' stripes are softer than
  traced. A smaller spread factor (0.7, 0.55 for 0.894) sharpened them toward the traced look
  but made every view's differences larger; 0.894, the variances' match, stays.
- The tree's dapple matches once it has its own channel and mip; baked into the casements'
  channels it was blurred away (the bars' penumbra is wider than its flecks).
- The lace's glow round the patches matches once the glazing is traced apart (as one baked
  product it was 4 of 20 levels too dark in the shade beside a patch).
- No leaves on the phone tier drops the tree's shadow from the patches (the right column).
- Menu: the table and the board fill the view and trace as before, so little changes.

## Speed (2026-11-24, Windows PC, RTX 4090, headless)

Ms a frame (1000 over the mean fps of `--fps-seconds 10`'s steady intervals), two rounds
alternating builds, the desktop at 3840 × 2160, the phone tier (`--phone-tier`) at 1920 ×
1200. `build/perf/cookie/bench.txt` (local).

| View | Desktop still, before | Desktop still, map | Desktop wind, off | Desktop wind, map + leaves a pixel | Phone, off | Phone, leaves baked | Phone, no leaves |
|---|---|---|---|---|---|---|---|
| Down | 1.03-1.12 | 1.08-1.49 | 1.21-1.25 | 1.20-1.23 | 0.34-0.37 | 0.37-0.38 | 0.34-0.35 |
| Corner | 1.31-1.47 | 1.41-1.57 | 1.39-1.65 | 1.34-1.44 | 0.35-0.36 | 0.34-0.36 | 0.35-0.35 |
| Room | 1.06-1.32 | 1.17-1.33 | 1.31-1.34 | 1.35-1.40 | 0.35-0.36 | 0.35-0.35 | 0.35-0.35 |
| Menu | 1.12-1.36 | 1.07-1.56 | 1.20-1.44 | 1.32-1.40 | 0.35-0.35 | 0.35-0.36 | 0.35-0.35 |

- The 4090 doesn't tell them apart: every case lies in the same 1.0 to 1.6 ms (desktop) and
  0.34 to 0.48 ms (phone tier), and the two rounds of one case differ more than the cases do.
  The frame is bound by the loop and the present, not the room's shading, and headless gfx
  has no GPU timer. The cost the map saves is the tablet's to measure (Next).
- The bake runs only when its key changes (the tuner's first frame, a sun or season change);
  it is not in these steady frames.

## Next

- [ ] The tablet's bench (`tools/perf/tablet_room_bench.py`) with the map on and off, and
  the phone's leaves static and off
- [ ] Decide whether the board and the table take the map too (their shaders bind the lace's
  mask at their own slots), and the glass and the lace
- [ ] If the edges near the window want to be sharper: the three windows' tiles side by side
  (5.1 m of texels in place of 7.7 m), or a larger map on desktops

## On the Pixel 7a (2026-11-24)

The phone's tier, native 2400 × 1080 landscape, 4× MSAA, cool (thermal status 0 to 1), two
alternating rounds, ms a frame (`tools/perf/tablet_room_bench.py --variants base,map-off,leaves-off`):

| Variant | Down | Corner | Room |
|---|---|---|---|
| the map, leaves static | 19.2 / 19.3 / 19.6 / 20.4 | 22.4 / 24.2 / 22.6 | 22.4 / 22.5 / 26.4 / 26.5 |
| `--window-map off` (traced per pixel) | 23.4 / 27.9 | 32.5 | 27.5 / 27.6 |
| `--phone-leaves off` | 22.8 / 19.4 | 22.3 / 22.6 | 22.5 / 26.2 |

The map saves about 4 to 8 ms straight down, 9 in the corner and 1 to 5 in the room's view,
a quarter of the frame at most. Leaving the leaves out saves nothing more: static leaves cost
nothing once baked. Still to run on the Galaxy Tab.

