# 115: The room on a tablet

Status: in-progress (measured 2026-11-24; what to drop or rework is for a later session)

The manor room (the epic 107) has only run on desktops. This runs the light tuner's room on
the Galaxy Tab A11+ (SM-X230, MediaTek MT6878, 1920 × 1200) to see what it costs there and
which effects cost the most, so task 110 can choose what to drop, rework, or tier. Lower
render resolution is the last resort, not the first fix (the user, 2026-11-24).

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

## Next (task 110)

- [ ] Choose for each costly part: drop it on phones, make it cheaper, or bake it
- [ ] Measure again after each change with the bench
