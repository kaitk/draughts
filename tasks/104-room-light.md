# 104: The board's light per season, and the window's shadow

Status: in-progress (on the branch `room-light`, 2026-11-20: the rooms, the cheap pattern, and the tuner; tuning next)

The 3D board on its table (task 095) is lit the same way in every season: one key light
from the upper left, a little warmer or cooler per look, and a dim ambient from the plain
fade. Light it as the room it would stand in, per season, after the manor's concept
frames (task 093, `design/manor/`, local), and try the concepts' sun streak: the window's
bars and curtain as a still pattern of light across the board, the pieces, and the table
(task 095's follow-ups, step 4).

Look development: right on the Mac first, tuning and device numbers at the end.

## The rooms (from the concept frames and the photographs)

| Season | Room and hour | Key | Fill and ambient |
| --- | --- | --- | --- |
| Autumn | The library, south-west, a mid-October afternoon (`library-table-01`, `library-autumn-01/02`) | Low sun (about 18°) from the left and behind, deep amber, strong; long shadows | Dim and warm: dark panelling and wallpaper; the window's sky a weak cool lobe from the left |
| Winter | The upper hall, north-east, a January morning, no sun (`hall-winter-table-01/02`) | The snowy doors on the left: broad, cool white, about 30°, weak, its shadow soft and faint | Strong cool light from the left, pale blue-grey plaster all round, a faint warm lamp far behind |
| Spring | The upper hall on a May morning (prompts 7) | Low clear morning sun (about 25°) from the left, near white, crisp | Bright and airy: a cool sky from the left, a little green from the trees, pale walls |
| Summer | The season's photograph: an evening by the sea | Low rose-gold evening sun (about 14°) from the left and behind, strong | Brighter than autumn's: a violet-blue sky lobe, warm walls |

The hall faces north-east, so its summer would be a morning (prompts 8); summer follows
its photograph's evening here instead, as there is no summer frame of the hall. To ask.

## Plan

1. **A room per season, as data** (`src/model3d/rooms.goose`, as `tables.goose` is): the
   key's direction (azimuth and height), color, strength, and how dark its shadow is;
   the fill, a broad lobe from the window's side; the ambient, the walls' and the
   ceiling's and the floor's light. The fill and the ambient become the nine harmonics
   the shaders already read (worked out on the CPU when the theme is put on), so they
   cost nothing a pixel. The room lights the board when it stands on its table; over the
   photograph or the plain fade the look's own light stays as it is.
2. **A first look per season**, shown before tuning anything.
3. **A tuner**, `tools/light_tune.goose` beside `taken_tune`: the season, the room's
   values on sliders, P printing the room as Goose.
4. **The window's shadow**, a still pattern on the key light that the board, pieces, and
   table take, multiplied into the key's shadow in `LIT_FRAG` and `TABLE_FRAG`. A point is
   traced along the key to the window's wall; where it meets it, in the window's own
   coordinates, says whether the sun came through glass, a bar, or the curtain, softer
   the farther the point is from the window (the sun's disc, the glass). Two takes:
   - Cheap: worked out in the shader, the window's panes and bars and the opening's
     edge, a few smoothsteps; no texture.
   - Rich: a map of the window baked at setup (bars, the lace curtain's edge and its
     pattern, the trees' leaves outside dappling the sun), sampled at a mip as soft as
     the distance asks.
   Nothing moves, so drawing stays on change; a turn (the light keeping its place on
   screen) turns the pattern with the light.
5. Tuning, then the tiers settled, then the device numbers.

## Tiers

The app's tiers (the user, 2026-11-20), not a switch per effect: the flat board; the 3D
board for low-end and midrange phones, tablets and the like; and a high mode meant for
gaming desktops and high-end Macs with a competent GPU, which could be chosen elsewhere
too. Where each effect lands is decided at the end. The look holds without the extras:
the room's light alone is the base of both 3D tiers.

| Effect | Cost | Tier it would sit in |
| --- | --- | --- |
| The room's key, fill, and ambient per season | none a pixel: data and nine harmonics on the CPU | 3D and high |
| The key's shadow strength (winter's faint one) | one mix a pixel | 3D and high |
| The window's pattern, cheap | a ray to a plane and a few smoothsteps a lit pixel, no texture | high; perhaps 3D on the stronger tablets, measured at the end |
| The leaves swaying in the wind | the 3D pass every frame while it shows (a moving board's cost, held), or at a reduced rate | high only |
| The window's pattern, rich | one texture tap a lit pixel, a small baked map (about 0.3 MB with mips), its bake once at setup | high |

Designed around a table of tiers: each effect, and its quality, on or off per tier in
one place (build or configuration time at first, the user, 2026-11-20), so a detailed
graphics menu on desktops could later set the same values; none is planned now. The high
mode doesn't exist yet: till it does, a development flag switches the pattern for
comparing, and the desktop has it on, as the stone board's scattering
(`render3d::scatter_allowed`).

The light's new direction may call for some materials to be tuned again; that waits till
the light is settled (the user, 2026-11-20).

## Done so far (2026-11-20)

- The rooms as data (`rooms::Room`, five takes: the library, the hall in snow light, the
  hall in winter sun, the hall in spring, the sea evening), put on by
  `render3d::put_room` when the board stands on its table. The key's shadow darkness is
  `Frame.room.x`.
- First look (the user): not bad; the shadows perhaps too dark for the light; the trees'
  shadow over the board wanted, as in the library frames; a sunny winter take beside the
  soft one (added: the sun at about 8°, `rooms::HALL_SUN`).
- The window's pattern, cheap (`shaders::LIGHT_FN`'s `window_light`): the key traced to
  the window's wall, the opening, its bars, a lace curtain's folded edge, and three
  octaves of value noise for the leaves beyond, each edge softer with distance. On with
  `--window on` in the app (`render3d::window_pattern`), on in the tuner (W).
- `tools/light_tune.goose`: the room take, season, board, and table; the sun's round,
  height, strength, shadow, and color; the fill, walls, ceiling, floor, and lamp; the
  window and the leaves; P prints the room as Goose into `build/light-tune.txt`.

- The leaves sway in the wind in the tuner (`rooms::Room.wind`, `render3d::wind_time`),
  the noise's coordinates bent by a few slow sines. In the app they stay still: a sway
  runs the 3D pass every frame, so if kept it is the high mode's, at a reduced rate.
- The floating board over the photograph or the fade keeps the look's old neutral light;
  the room's light is the table's. The user would keep the neutral light as an option on
  the table too (2026-11-20).

## Follow-ups

- The time of day or the light's mood may become a choice in the visuals some day (the
  user, 2026-11-20): to think through, as the settings are getting crowded.

## Acceptance criteria

- [ ] Each season's room light, matching its concept frame and photograph, on the Mac
- [ ] The light holds without the window's pattern, in every season
- [ ] The window's pattern tried cheap and rich, each placed in a tier
- [x] A tuner for the room's light and the pattern
- [ ] Shots of each season in this file; GPU time recorded on the Mac and the A33 at the
      end, against before
- [ ] `docs/decisions/rendering.md` and `docs/architecture/rendering.md` brought up to date
