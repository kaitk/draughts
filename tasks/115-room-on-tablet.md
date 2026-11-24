# 115: The room on a tablet

Status: in-progress (measured 2026-11-24; what to drop or rework is for a later session)

The manor room (the epic 107) has only run on desktops. This runs the light tuner's room on
the Galaxy Tab A11+ (SM-X230, MediaTek MT6878, 1920 × 1200) to see what it costs there and
which effects cost the most, so task 110 can choose what to drop, rework, or tier. Lower
render resolution is the last resort, not the first fix (the user, 2026-11-24).

The target on a weak tablet like this one (the user, 2026-11-24): 60 fps (16.7 ms) would be
fine, a steady 30 (33.3 ms) acceptable, with room left for the device warming. The board
alone, without the room, asks for more.

## How it runs

- `scripts/android.py tools/light_tune.goose --run` builds the tuner as its own app
  (`io.github.kaitk.draughts.light_tune`), beside the app's. On Android it starts in the
  touch walk (`--touch on` elsewhere): no panel, the screen's left half a stick to walk, the
  right half a drag to look, Up and Down at the right edge. One finger at a time: goose_gfx
  gives touches as the mouse.
- The touch walk takes the phone's tier: no SSAO or GTAO, no floor mirror, no HDR (so no
  glow, haze or dust), 4 shadow taps. The floor's and metals' box reflection (`SHARP_BOX`),
  4× MSAA and the window's pattern stay on. `--tier full` gives the desktop's.
- `python tools/perf/tablet_room_bench.py` times agents/perf.md's four views, each with one
  part left out or changed: each run starts the tuner with `--fps-seconds 22` and takes the
  median of the counter's last half. The base runs again at the end, for drift.
- No GPU counters: the device's perfetto has no `gpu.counters` source (only
  `android.gpu.memory`), so the profile is the part-by-part split below. The CPU's time in
  the loop is about 3 ms of every frame, so the GPU is what limits it.

## Results (2026-11-24, ms a frame, median of the steady half)

| Variant | Down | Corner | Room | Menu |
|---|---|---|---|---|
| the phone's tier, native 1920 × 1200 | 43.2 / 44.7 / 47.2 / 52.9 | 54.6 / 55.7 / 55.2 / 56.5 | 49.8 / 48.9 / 49.9 / 48.7 | 45.9 / 45.0 / 46.1 / 45.2 |
| `--scene-scale 0.75` | 29.5 | 36.9 | 32.7 | 32.5 |
| `--scene-scale 0.5` | 13.9 | 22.4 | 19.6 | 19.6 |
| `--window off`: no window pattern (bars, curtain, leaves) | 30.1 | 39.4 | 36.4 | 37.9 |
| `--box off`: no sharp box reflection on the floor and metals | 29.5 | 43.5 | 40.0 | 43.1 |
| `--aa off`: no 4× MSAA | 44.8 | 46.2 | 42.1 | 36.3 |
| `--aa smaa` | 45.9 | 47.2 | 45.1 | 39.0 |
| `--books off` | 46.7 | 51.5 | 50.6 | 45.6 |
| `--outside off`: no view out | 48.1 | 54.2 | 48.6 | 44.6 |
| `--wind-kind still` | 46.7 | 56.2 | 51.1 | 45.6 |
| `--shell off`: the old panelled wall, not the library | 21.0 | 14.5 | 12.5 | 13.2 |
| `--room-surfaces off`: board and table alone | 11.0 | 11.0 | 11.0 | 11.0 |
| no pattern, no box, no MSAA together | 22.5 | 27.6 | 26.8 | 28.4 |
| `--tier full`: SSAO/GTAO, mirror, HDR | 44.3 | 68.8 | 62.0 | 58.9 |

The base ran four times in each view (two rounds, start and end): it drifts by up to 10 ms in the
straight-down view (43 to 53) and about 2 ms in the others, so differences under about 3 ms are noise.
The views are agents/perf.md's; the walk's field of view is 60°. `no-room` sits at the display's
90 Hz (11.1 ms). The CPU's time in the loop is 2.9 to 3.3 ms throughout (0.8 without the room).

## What it says

- **The room is the whole cost**: board and table alone draw at the display's 90 Hz (11 ms);
  the library's shell takes it to 45 to 56 ms, where the old panelled wall cost 13 to 21.
- **Pixels**: half the side (a quarter of the pixels) takes 45 to 56 ms to 14 to 22, so the
  frame is mostly fragment work. Per-pixel cost is what to cut.
- **The window's pattern, 9 to 16 ms**, the largest single part: the bars', curtain's and
  leaves' light on every lit pixel. Still wind saves nothing, so it is the pattern's shading,
  not its animation. Off, the sun's patches go entirely (the look changes), so it wants
  reworking, not dropping. On phones and tablets it is to be baked in the end (task 114; the
  user, 2026-11-24). Task 116 bakes it into the window's light map.
- **The floor's and metals' box reflection, 3 to 15 ms**, most where the floor fills the
  screen (straight down 15, corner 11, room 9, menu 3). On a phone the walls' broad
  reflection may do; it was still on in the first tries on the tablet.
- **4× MSAA, 1 to 10 ms**, most in the views with the room's edges (corner 9, menu 10).
  SMAA in its place costs only 1 to 3 ms more than no smoothing at all, so swapping to it
  wins most of that back. It is cheaper, not better looking: it smooths the finished image,
  so thin lines (the window's bars, the frames) may shimmer more as the view moves; to be
  judged by eye on the tablet.
- **Together** (no pattern, no box, no MSAA): 22 to 28 ms, about 36 to 45 fps.
- **Small**: the books about 3 ms in the corner view, the view out, and the wind under the
  noise. The full tier (SSAO or GTAO, the mirror, HDR) adds 12 to 14 ms where the walls show, none
  looking straight down.
- Obvious next measurements: the window pattern's parts (bars, leaves by tree or noise), the
  room's surfaces one shader at a time (the paper, the wainscot, the paint), and the
  shadow taps.

## SMAA as the room's default (the user, 2026-11-24)

The user leans to SMAA as the default: the look is close to 4× MSAA's, and MSAA's cost grows
with the shader under every edge pixel, a trap as the room's shaders grow. To validate on the
Pixel 7a, the Galaxy Tab again, and the Mac by eye. The 4090 at 5120 × 2880 (unsynced, two
rounds, ms a frame):

| View | 4× MSAA | SMAA | none |
|---|---|---|---|
| Down | 2.50 | 2.48 | 2.28 |
| Corner | 2.96 | 2.79 | 2.58 |
| Room | 2.78 | 2.57 | 2.40 |
| Menu | 2.77 | 2.58 | 2.40 |

Those desktop runs are skewed: HDR (glow, haze, dust) was drawn only with MSAA, so the SMAA
and no-AA runs also skipped HDR's passes. Fixed after (SMAA runs after the tonemap with HDR);
to measure again. The phones' runs are fair: the phone's tier has no HDR either way.

The Pixel 7a (Mali-G710 MP7, 2400 × 1080 landscape, cool: thermal status 0 to 1), native,
alternating runs (ms a frame; the first round's first runs lost):

| View | 4× MSAA | SMAA | none |
|---|---|---|---|
| Down | 22.9 / 23.3 / 22.9 | 24.3 | 22.9 |
| Corner | 25.9 / 25.8 / 31.0 | 23.4 | 24.2 |
| Room | 26.2 / 31.2 / 26.3 | 23.4 | 22.1 / 26.1 |
| Menu | 25.4 / 25.2 / 25.3 / 26.5 | 22.4 / 24.3 | 21.0 / 21.1 |

SMAA 1.5 to 3 ms cheaper but straight down, where the two are even. Warm (thermal status 3,
skin 45 °C) the Pixel ran 32 to 49 ms, as slow as the tablet: a split on a phone wants it cool
and runs alternated. At 0.5 scale everything sat at its 60 Hz cap.

## The split again, with the light map and SMAA (2026-11-24, room-light 523362fa)

Cool (thermal status 0 before and after), ms a frame, one run each, the base twice:

| Variant | Down | Corner | Room |
|---|---|---|---|
| base: SMAA, the light map, leaves static | 39.5 / 36.5 | 41.5 / 40.2 | 37.8 / 39.0 |
| `--box off` | 27.2 | 33.4 | 32.3 |
| `--books off` | 35.7 | 39.4 | 39.0 |
| `--outside off` | 37.0 | 39.3 | 36.8 |
| `--wind-kind still` | 38.8 | 40.0 | 37.2 |
| `--scene-scale 0.75` (the last resort) | 24.8 | 27.9 | 24.9 |
| `--shell off`: the old panelled wall | 25.0 | 15.5 | 13.4 |
| `--room-surfaces off` | 11.0 | 11.0 | 11.0 |

- The floor's and metals' sharp box reflection is now the largest part: 6 to 11 ms. Its
  window rectangles, bars and the view out (`room_seen`) trace per floor pixel still.
- The shell's surfaces cost 13 to 25 ms over the old wall's: the shaders themselves, to be
  ranked with the Mali Offline Compiler (cycles and registers per shader) and tried at half
  precision.
- The books, the view out and the wind 1 to 3 ms each.
- The target (a steady 30, about 28 ms with room to warm) is within the box's saving and a
  few ms of the shaders'.

## The room's shaders by the Mali Offline Compiler (2026-11-24, room-light 1a0b1a9d)

`tools/perf/shader_report.py --core Mali-G615 --table --only room_` (malioc 2026.5, driver
r56p1), the phone's tier as `make_room_tier` makes it: no screen maps, the window's light map,
the sharp box on the floor and metals. Cycles a pixel on the longest path, arithmetic / load-store;
spill the stack's spill region and the bytes it moves:

| Shader | G615 A / LS | G710 A / LS | G68 A / LS | Spill (G615) | Bound |
|---|---|---|---|---|---|
| floor, with the box | 43.9 / 168 | 82.3 / 168 | 116 / 166 | 150 B / 848 | LS |
| floor, no box | 26.2 / 53 | 49.4 / 53 | 69.5 / 65 | 8 B / 16 | LS (G68 A) |
| walls (paper, books' cases) | 23.0 / 50 | 43.3 / 50 | 61 / 53 | 12 B / 60 | LS (G68 A) |
| paint | 23.0 / 43 | 43.1 / 43 | 61 / 40 | 12 B / 60 | LS (G710, G68 A) |
| sill | 22.9 / 44 | 43.1 / 44 | 61 / 61 | none | LS |
| metals, with the box | 39.5 / 190 | 74.1 / 190 | 105 / 170 | 182 B / 860 | LS |
| metals, no box | 21.6 / 46 | 40.7 / 46 | 58 / 47 | 12 B / 24 | LS (G68 A) |
| table | total 42 / 73 (a loop) | | | 174 B / 744 | LS |
| glass, lace | total 31 / 16 and 30 / 11 | | | glass 66 B | A |
| view out | 9.4 / 0 | 17.5 / 0 | 25.8 / 0 | none | A |

Every room shader uses all 64 work registers (half occupancy), all 128 uniform registers, and no
16-bit arithmetic. Texture and varying cycles are 1 to 7, never the limit.

- **Uniform loads are the bound.** A Valhall Mali keeps 128 32-bit uniform components in
  registers; each vec4 read past them is about one load/store cycle a pixel (scratch tests: 96
  vec4s whole cost 64 LS cycles, their `.x` alone none). The room's shaders read 56 to 63 vec4s
  of `Frame` (31: the sun, the window's panes, the wind and tree, `sh[9]`) and `Surfaces` (25 to
  32), the metals 102, the table 116. With `Surfaces` as constants in a scratch copy, the sill's
  LS fell 44 → 1 and the floor's 168 → 3, its spill 150 B → 2 and its arithmetic 43.9 → 19.3
  (the constants fold into the math). The room's shell would be bound by arithmetic at about
  half its cycles now.
- **The sharp box** adds 115 to 145 LS cycles and the spills on the floor and metals: mostly the
  same loads, the window's geometry read again per traced ray, and registers it holds.
- **FP16 waits on that.** Arithmetic isn't the G615's or G710's limit yet; it is the G68's (the
  A33), where it and the loads are about even.
- The ways to cut the loads: the shell's fixed numbers as constants in the app's shaders, made
  from the tuned values at build time, the tuner keeping uniforms; or a small packed block per
  material group with only what it reads (fewer folds, no build step). The user chose the
  constants (2026-11-24).

### The block as constants on the tablet (2026-11-24, room-light 05758174)

`--room-fixed on` gives the phone tier's room shaders the whole `Surfaces` block as constants
(`src/render3d/room_fixed.goose`, made by `scripts/room_fixed.py` from the tuner's
`--dump-room-block` in the phone tier). `Frame` and the table's blocks stay uniforms. The
picture is the same: on the PC, one pixel of the room view 9 levels off, the rest within 2.
Cool (thermal status 0 throughout), ms a frame:

| View | base | fixed | saved |
|---|---|---|---|
| Down | 35.5 / 36.9 / 35.7 / 35.9; quick 37.4 | 27.4 / 27.4; quick 27.4 | 8.6 |
| Corner | 41.1 / 41.0 / 39.2 / 41.6; quick 39.7 | 32.9 / 33.0; quick 33.0 | 7.4 |
| Room | 37.6 / 38.7 / 38.4 / 37.4; quick 37.7 | 32.0 / 31.9; quick 31.8 | 6.1 |

A steady 30 now in every view, from the uniforms alone. Not yet the default: some members
depend on the tuner's switches and the room's state (the baked light, the light map, the
tint), so the real version keeps those uniform, or makes the constants for each state the app
shows. `Frame` (31 vec4s the room reads) is next by the same means, then ngfx's parity.

The bench's `--quick` (5 s of frames a run, no base at the end) took 1 min 37 s for these
six runs, the full runs about 7 min, with the same figures within 2 ms.

### The split with the constants by default (2026-11-24, room-light 733a308c)

The state's members uniform (`KEEP`), the rest constants, the default. The quick bench, cool,
ms a frame:

| View | base | no books | no outside | AA off | wind still | no shell | 0.75 scale | leaves off |
|---|---|---|---|---|---|---|---|---|
| Down | 28.2 | 28.2 | 28.7 | 25.7 | 28.2 | 25.0 | 18.6 | 28.2 |
| Corner | 33.4 | 32.3 | 32.3 | 30.5 | 33.3 | 15.4 | 22.8 | 33.3 |
| Room | 32.2 | 32.1 | 31.1 | 29.5 | 32.2 | 13.6 | 21.9 | 32.1 |

The shell is still most of the frame (18 to 19 ms of the corner's and room's).

### Half precision (2026-11-24)

`mediump` throughout the room's fragment shaders (74% of the math in FP16 by malioc) left the
cycles where they were: the conversions (CVT) rose as the multiply-adds fell. Set aside; the
item below is ticked as tried.

### The box's map (2026-11-24)

The sharp box reflection's baked light (the probes' irradiance on the box's six faces, where
the floor and the metals' reflected rays end) is a texture now: `render3d::box_map`, a texel
each 4 cm in RGBA16F, baked when the probes, the sun, the window's light map or the box's
surfaces change, read in one tap. What has sharp edges is still worked out per pixel: the
surface there (`box_albedo`: the doors, the bookcases, the wainscot) and the sun's patches
through the windows (`box_sun`); a first version that baked those too blurred the sun's edges
under a tilted floor and the doors' outlines (60 levels in 1500 pixels). The windows on the
window wall are traced as before.

On the PC the four views match (`--box-map off` against on): at most 4 levels, but for 6
pixels of the room view. The faces' cells are sized with half a texel to spare, since a face
a whole number of texels long put `ceil` on its edge and the constant-folded shader and the
CPU disagreed by one texel. Cool, the quick bench, ms a frame (two rounds):

| View | traced (`--box-map off`) | map | saved |
|---|---|---|---|
| Down | 28.3 / 28.3 | 26.5 / 26.5 | 1.8 |
| Corner | 33.4 / 33.4 | 32.7 / 32.9 | 0.6 |
| Room | 32.2 / 32.3 | 31.8 / 31.9 | 0.4 |

Malioc (G615): the floor 22.02 to 21.34 cycles, the metals 18.41 to 17.25 (and their spill
gone); the bake 7.47 a texel, once.

### Where the floor's cycles go (2026-11-24, malioc ablations)

The floor's phone shader (`room_floor_boxmap_fixed`, longest path 21.34 cycles on the G615)
with one term at a time replaced by a constant: the sharp reflection 7.1, the table's shade
3.0 (`table_shade`, the branch the table's map skips at run time), `window_open` 1.5,
`case_shade` 0.7, the baked light 1.0, the sun's highlight 0.5, the normals' variance 0.25,
the scratches 0.07, the corners' map 0. The materials' detail costs next to nothing, so
phone-tier materials would buy under a cycle; the reflection is the cost.

The reflection's windows: only the window nearest where the ray meets the wall is worked out
(the loop did all three). The picture is identical on both tiers; malioc's floor 21.34 to
19.53, the metals 17.25 to 15.35; the tablet within its noise (26.7 / 32.5 / 31.7 ms), since
the loop's early-out already skipped the windows a ray misses.

## The iPhone 13 mini (2026-11-24)

The iPhone 13 mini (A15, 2340 × 1080 landscape, 60 Hz), native, the phone's tier with 4× MSAA,
2026-11-24 (`scripts/ios.py --device tools/light_tune.goose`): every view (down, corner, room,
menu) held its 60 Hz cap, 16.7 ms a frame, the worst half second 17 to 19 ms, the loop's own
work 1.0 to 1.4 ms. iOS presents at the display's rate even with `--no-vsync`, and there is no
GPU timer there, so its headroom isn't known.

## Next (task 110)

Aim: about 45 fps (22 ms) on this tablet, every second refresh of its 90 Hz; a steady 30 the
least (the user, 2026-11-24). Lower resolution stays the last resort on a tablet: its screen shows it. On a phone's small
screen 0.75 to 0.8 of the side may be fine, and anywhere the room can't hold 30 (the Galaxy
A33 likely: its Mali-G68 MP4 is older and no faster, at 2400 × 1080's 13% more pixels) it
steps down, measured as task 081's 2× MSAA fallback is (the user, 2026-11-24).
The approaches agreed, in order:

- [x] Rank the room's shaders with the Mali Offline Compiler (cycles, registers and the bound
      unit per shader, for the G615 and G710), no device needed
- [x] Half precision (FP16) for colour, light and BRDF math in the dearest shaders; positions
      and depth stay full (tried: no gain, above)
- [ ] The sharp box reflection cheaper on phones: its windows, bars and view out from the
      light map or a small baked texture, not traced per floor pixel (its baked light is a
      map now, above; the windows still traced)
- [ ] Phone-tier versions of the materials: what doesn't read at tablet size dropped (the
      second sheen lobe, the paint's relief, the floor's scratches and slow noise, grime);
      measured on the floor at under a cycle (above)
- [ ] Detail faded by screen size in the shader (`fwidth`): small surfaces skip normal and
      relief detail
- [ ] Smooth terms (the baked light's taps) shared over a 2 × 2 quad, if the devices'
      Vulkan offers fragment subgroup quad operations
- [ ] The books' cheaper shader (task 110), the indirect light baked (task 114)
- [ ] Measure again after each change with the bench
