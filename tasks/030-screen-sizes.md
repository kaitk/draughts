# 030: Phones and other screen sizes

Status: in-progress (the survey and the layout fixes done; the density decision next)

The layouts were built and checked on one screen, the Galaxy tablet (1920 × 1200, 16:10)
and its Mac stand-in. Play lists the app for phones and tablets alike, so every screen
must work at other proportions and resolutions. At phone proportions home's menu already
runs off the bottom: Settings is cut off below Puzzles in portrait
(`~/Downloads/draughts-store/README.md`, "Caveats", and its
`screenshots/play/portrait-*-home-*` and `apple-iphone-6.9/` shots). Phones decided by the
user on 2026-11-08: fix the layout rather than list the app for tablets only.

## Work

- **Survey first:** every screen (home, both setups, the game with and without clocks
  and against the computer, settings, the win card, and puzzles once they exist) in both
  orientations at a set of sizes, in English and Estonian, with the Mac's `--size`:
  - phones: 9:16 (1080 × 1920), 9:19.5 (1080 × 2340), 9:20 (1080 × 2400), and a small
    one (720 × 1280);
  - tablets: 4:3 (2048 × 1536, iPad-like), 16:10 at 2560 × 1600 and higher, and
    3:2 (2880 × 1920);
  - foldables' near-square inner screen (about 2208 × 1768).
  Record what breaks: cut off, overlapping, too small to tap (88 dp is the floor for
  small hands), or wasting space.
- **Fix what breaks**, in the screens' own layout code: the scale is the shorter side /
  800 (`docs/architecture/rendering.md`), so a long thin phone has room to spare along
  one side and none along the other. Likely a scroll-free rearrangement for phone
  portrait (home's menu beside or under a smaller board, the setup's rows tighter) and
  a cap on the scale where a large screen makes tiles needlessly big.
- **Higher resolutions:** the baked text and the blurred backgrounds scale with the
  screen; check that text stays crisp, the photograph isn't upscaled past its source,
  and memory stays near the tablet's (261 to 263 MB) at 2560 × 1600 and above.
- **On a real phone:** the user's Pixel 7a (1080 × 2400, 20:9, developer mode and USB
  debugging on) once the survey's fixes are in on the Mac: the user swaps it for the
  tablet on the USB cable when asked. Check every screen in both orientations, the
  insets, and memory as on the tablet.
- **Insets:** notches, rounded corners, and gesture bars on phones (Android's display
  cutout and system bar insets); nothing that takes a tap under them.

## Survey (2026-11-08)

Every screen at every size below in both orientations, English and Estonian, from the
build at `f76cc63`: home, the friend's and the computer's setup, the game without a
clock (International), with one (`--clock 5+3`, Russian), and against the computer
(`--computer black`, International), settings, the win card (the Russian example of
`docs/development.md`, `--win 3`), the puzzles to pick from, and puzzle 21. 320 shots,
out of git, in
`/private/tmp/claude-501/-Users-kaitkasak-projects-personal-draughts/babe58e8-1877-410c-bc48-f7f8f48b403f/scratchpad/survey/`
as `<screen>-<real size>-<lang>.png`, with contact sheets in `../sheets/` and the
script in `../shoot.sh`.

On this Mac `--size` is in points and the PNG comes out at twice that; a window over
about 1098 points tall is shrunk. So most sizes were shot at their real pixels, and
five portrait ones at the same proportions, smaller (the layout depends only on them):

| Stands for | `--size` | PNG |
|---|---|---|
| 1080 × 1920, 1920 × 1080 | 540x960, 960x540 | real |
| 1080 × 2340, 2340 × 1080 | 450x975, 1170x540 | 900 × 1950, real |
| 1080 × 2400, 2400 × 1080 | 450x1000, 1200x540 | 900 × 2000, real |
| 720 × 1280, 1280 × 720 | 360x640, 640x360 | real |
| 1536 × 2048, 2048 × 1536 | 768x1024, 1024x768 | real |
| 1600 × 2560, 2560 × 1600 | 600x960, 1280x800 | 1200 × 1920, real |
| 1920 × 2880, 2880 × 1920 | 640x960, 1440x960 | 1280 × 1920, real |
| 1768 × 2208, 2208 × 1768 | 868x1084, 1104x884 | 1736 × 2168, real |

The shorter side is always 800 dp, so the phones (9:16 to 9:20) have more dp than the
tablet along the long side, never less: nothing is cut off on a phone. What breaks at
phone proportions is size on the hand; what breaks in dp is at the near-square end, 4:3
(1067 × 800 dp) and the foldable (1000 × 800 dp). In order of importance:

1. **Everything is less than half size on a phone.** The scale has no density in it
   (`app/draughts.goose`, `scale = min(size.x, size.y) / 800.0`; `game/panel.goose`'s
   `layout` repeats it), so a phone draws the tablet's layout into its 64 mm short side.
   One dp is 0.080 mm on the Pixel 7a (6.1", 1080 px across) and 0.185 mm on the Tab
   A11+ (11", 1200 px across), 43%. The 88 dp floor is 7.0 mm there (16.3 on the tablet),
   under Android's own 48 dp (7.6 mm); the labels' 30 dp face is 2.4 mm, the notes' 17 dp
   1.4 mm ("medium", "0 / 90", "+3 s a move"), and a 10 × 10 square of the portrait game
   (75 dp) 6.0 mm. Every screen, every phone size. The text itself is crisp: it is baked
   at the screen's scale (crops at 1280 × 720 and 2400 × 1080).
2. **Settings, landscape, foldable: the look group runs off the bottom.** The choices
   are capped at 55% of the page (515 dp), so their rows wrap (Russian, the fifth
   season, Stack under Auto and Crown), and the two groups come to about 820 dp in the
   752 dp the page has: Stack (Virn) sits outside its glass, its lower 30 dp off the
   screen, in both languages. 4:3 wraps the same rows and only just fits.
   `shell/settings.goose`, `frame`: `min(want, 0.55 * page.z)`, and nothing checks
   `game_h + look_h` against `side.w`.
3. **The puzzles, portrait, foldable: the last tier is cut.** Portrait tiles are sized
   from the width alone, 122 dp, so the three tiers take 898 dp plus 156 for back and the
   margins: 1054 dp. The foldable's 999 cuts the shield tier's second row by about 55
   dp; 4:3 (1067) leaves 13. `shell/picker.goose`, `frame` (`side`).
4. **The puzzles, landscape: tiles under 88 dp at 4:3, 3:2, and the foldable.** Ten in
   a row take what the width leaves, `(width - 390) / 10` dp: 68 at 4:3, 81 at 3:2, 61 on
   the foldable (89 at 16:10, 96, the cap, on phones). Two rows of five, as portrait has,
   fit the height there at 88 dp (3 × 222 + 40 = 706 of 752). Same function.
5. **The game and a puzzle, landscape near square: a small board between full panels.**
   The panels keep 232 dp each, so the board is 507 dp at 4:3 and 440 on the foldable
   (10 × 10 squares of 51 and 44 dp), with 290 to 360 dp of the height unused.
   `game/panel.goose`, `layout`: `width - 2.0 * side - 4.0 * gap`.
6. **The game's top bar, portrait foldable: "Alusta uuesti" fills its tile.** The bar's
   three tiles are a third of the board's width less gaps, 177 dp on the foldable (200 at
   4:3), and `gui::labelled` centres icon and word with no room kept at the sides and no
   smaller fallback: the icon touches the left edge and the word the right. Puzzles'
   "Ülesanded" fits. `game/panel.goose`, `leave`; `gui/gui.goose`, `labelled` (`MIDDLE`).
7. **The win card hides the winning piece where the board is small.** The card is
   356 × 300 dp whatever the board, so on the 440 dp board (foldable landscape) it covers
   81% of the width, at 4:3 and 3:2 landscape and foldable portrait the piece that won
   sits half under it; on the 752 dp boards it takes 47% and the piece shows beside it.
   `game/game.goose`, the card's `gui::center(area, 356.0 * u, 300.0 * u)`; it goes with
   (5).
8. **Settings, landscape at 1280 × 720: the fifth season wraps, at 1920 × 1080 it
   doesn't.** The choices' width is exactly their widest row's, so a rounding difference
   in `lay` (`x + w > r.z`) sends the row's last tile to a line of its own. Both
   languages. `shell/settings.goose`, `group_width` and `lay`.
9. **The setups, portrait near square: a small preview.** The computer's setup sheet is
   728 dp tall, leaving the board 259 dp at 4:3 and 191 on the foldable; everything fits.
   `shell/home.goose`, `frame`.
10. **Under 88 dp on every screen size** (the same dp everywhere, so worst on phones):
    home's portrait settings button 48 dp, the setup's back 56, settings' tiles 56 tall
    (seasons 70, kings 72) and its language tiles 48, the setup's choices 76, the game's
    panel tiles 72.
11. **Room to spare on long phones.** Portrait home leaves 315 dp over its 640 dp board;
    the portrait game 363 dp above its bar and below its play at 9:20; landscape, the game
    uses 1312 of 1778 dp and the puzzles' rows stop at 96 dp tiles halfway along their
    glass. Nothing breaks; a density-aware scale (1) would use it.

Fine at every size, in both languages: home (the store caveat's "Settings cut off
below Puzzles" is the portrait menu as designed, settings being the gear by the
wordmark; Puzzles ends 32 dp above the bottom); both setups in landscape and on phones;
the game and a puzzle in portrait and in landscape from 3:2 out; the clocks; settings in
portrait. Home's X is clear of the board at every phone size in both orientations: the
board's top is at least 120 dp down in landscape and 137 dp at 9:16 portrait, against the
X's 112; the tightest is 4:3 landscape, 14 dp. Whether it clears the gesture areas waits
for the insets and the Pixel 7a. Not checked here: the photograph's upscaling and memory
at high resolutions (the sharp photograph is a 2048 px texture, so 2400 to 2880 px
screens stretch it 1.17 to 1.41 ×), which take the tablet.

The fixes this suggests, most important first:

- A scale with a floor in physical size, from the display's density (SDL's display
  content scale): for example `max(short side / 800, density)`, which keeps the tablet
  as it is if its density is 1.5 (`adb shell wm density`) and gives the Pixel 7a 411 dp
  across. That is the real phone work: every screen then needs a layout for a short side
  of 360 to 420 dp, and how far to go (all the way, or a factor under 1) is a decision
  to take first, with a prototype.
- Settings in landscape: give the choices more of the page, or fall back to the
  portrait arrangement, when the wrapped groups don't fit; and a little slack in `lay`.
- The puzzles: tile size from the height too in portrait, and two rows of five in
  landscape when ten in a row would be under 88 dp.
- The game's panels narrower near square, so the board takes the height, and the win
  card sized to the board.
- `labelled` keeps room at its sides and stacks icon over word, or drops to a smaller
  face, when a word doesn't fit.
- The small controls (10) up to 88 dp, once the density decision says how big a dp is.

## Fixes (2026-11-08)

The survey's layout faults that don't wait on the density decision, numbered as there,
in dp, on the Mac. Before and after shots of every screen at every size, out of git, in
`/private/tmp/claude-501/-Users-kaitkasak-projects-personal-draughts/babe58e8-1877-410c-bc48-f7f8f48b403f/scratchpad/fixes/`
(`before/`, `after/`, `shoot.sh`). `test/shell/sizes` checks every screen at the
foldable, 4:3, and a 20:9 phone in both orientations and languages: every tile on the
screen, none overlapping another or the board, the puzzles' tiles at least 88 dp; run
on the code before these fixes it reports settings' last tile off the screen and the
puzzles' tiles cut or small.

- (2) **Settings, landscape near square:** where the wrapped rows would run past the
  page's foot, each setting's name goes above its tiles, as in portrait, and the column
  narrows to its widest row (`shell/settings.goose`, `frame`). Foldable: Stack's tile
  30 dp off the screen → everything on it, the board 373 → 420 dp (431 in Estonian);
  4:3: 402 → 484 dp.
- (3) **The puzzles, portrait near square:** the tiles take the height into account too
  (`shell/picker.goose`). Foldable: the last tier cut by about 55 dp → all in, tiles
  122 → 113 dp; 4:3 and the tablet unchanged (122).
- (4) **The puzzles, landscape:** two rows of five where ten in a row would be under 88
  dp, and each tier's glass as wide as its tiles, centered. Tiles 68 (4:3), 81 (3:2), 61
  (foldable) → 96 dp; the phones' glass now ends with their tiles instead of halfway
  past them; 16:10 unchanged (ten of 89).
- (5) **The game and a puzzle, landscape near square:** where 232 dp panels leave the
  board under 720 dp (the tablet's at 16:10), they narrow, down to 192 dp, and the left
  panel's tiles put their icon over their word in 96 dp rows when a word doesn't fit
  beside it (`game/panel.goose`, `layout`, `leave`). Board 507 → 587 dp at 4:3, 440 →
  520 on the foldable, 640 → 720 at 3:2. The turn's words and a puzzle's stars fit the
  narrower panel (`gui::fitting`, moved from `shell/puzzle.goose`).
- (6) **The portrait game bar:** thirds while each word fits, else each tile as wide as
  its word and an even share of the rest; `gui::labelled` keeps 8 dp at least at the
  sides and takes a smaller face for a word still too wide. Foldable, Estonian: "Alusta
  uuesti" in a 177 dp tile edge to edge → 224 dp, 24 dp either side (Koju 141, Seaded
  166); English and the tablet unchanged.
- (7) **The win card:** on a board under 720 dp it shrinks with the board, all but its
  buttons' height, the buttons no narrower than 88 dp (`game/game.goose`, `celebrate`).
  Foldable landscape: 81% of the board's width (356 of 440) → 52% (271 of 520); 4:3
  landscape 49%, foldable portrait 49% (299 of 603).
- (8) **Settings at 1280 × 720:** a row may pass its width by half a pixel without
  wrapping (`lay`, `SLACK`): the fifth season back on its row.
- (9) **The setups, portrait near square:** the board's margins above and below go from
  40 dp down to 24 where the sheet would leave it under 40% of the width
  (`shell/home.goose`): 259 → 291 dp at 4:3, 191 → 223 on the foldable.

The tablet's 16:10 shots (960 × 600 and 600 × 960, all ten screens, both languages)
are unchanged: byte-identical but for settings, whose pixels differ only in the
preview's flash, in the same box as between two runs of the old build, and the win,
whose shots differ between two runs of the old build too and match the second one
exactly. The win's `--frames` shots vary from run to run over the whole board; compare
them against a second run, not the first (`agents/testing.md`).

## On the Pixel 7a (smoke test, 2026-11-08)

1080 × 2400 at 420 dpi (2.625 px a dp), gesture navigation, a punch-hole camera 118 px
(45 dp) deep at the portrait top. The APK installs and runs. It didn't turn: SDL locked
the activity to the orientation it started in (`SENSOR_PORTRAIT`) because the window
wasn't resizable; the tablet turned anyway, as large screens ignore that lock. Fixed by
opening the window resizable too (`docs/development.md`); both orientations then drew
home and a clocked game. Home 4 s after a cold start: PSS 289 MB, of it 244 MB graphics
(172 GL, 73 EGL), against the tablet's 261 to 263 MB.

## Phone scale prototype (2026-11-08)

The user chose to go partway toward the tablet's physical size on phones, prototyped
first: `scale = max(short side / 800, f × density)`, density from SDL's display content
scale (Android's density / 160: the Pixel 2.625, the tablet 1.5, so any f up to 1 leaves
the tablet as it is). The development flag `--dp N` (`gui::scale_of`, now the one place
the scale is computed: the app, `panel::layout`, and the tests' helpers) makes the
shorter side N dp instead of 800, so a candidate can be shot on the Mac now and tried on
the phone later (`--es args "'--dp 540'"`).

Every screen of the survey at the Pixel 7a's proportions in both orientations, English
and Estonian, at five short sides (200 shots, portrait as `--size 450x1000`, landscape at
the real 2400 × 1080), with contact sheets, and for home, the game, and the computer's
setup a sheet of the tablet beside the Pixel at each candidate at one mm a pixel, in
`/private/tmp/claude-501/-Users-kaitkasak-projects-personal-draughts/babe58e8-1877-410c-bc48-f7f8f48b403f/scratchpad/phone-scale/`
(`compare/`, `contact/`, `shots/`; `shoot.sh` and `sheets.py` make them).

On the Pixel 7a (6.1", 63.6 mm across), portrait; the tablet for reference:

| Short side | f | 1 dp | 88 dp tap | Label (30 dp) | Note (17 dp) | Square 8 × 8 | 10 × 10 | A 360 dp phone gets |
|---|---|---|---|---|---|---|---|---|
| 800 (today) | 0.51 | 0.080 mm | 7.0 mm | 2.4 mm | 1.4 mm | 7.3 mm | 5.8 mm | 800 dp |
| 600 | 0.69 | 0.106 | 9.3 | 3.2 | 1.8 | 7.2 | 5.7 | 525 |
| 540 | 0.76 | 0.118 | 10.4 | 3.5 | 2.0 | 7.1 | 5.7 | 472 |
| 480 | 0.86 | 0.132 | 11.7 | 4.0 | 2.3 | 7.0 | 5.6 | 420 |
| 411 | 1.00 | 0.155 | 13.6 | 4.6 | 2.6 | 6.9 | 5.5 | 360 |
| Tablet, 800 | | 0.185 | 16.3 | 5.6 | 3.1 | 17.0 | 13.6 | |

The scale grows the controls and the words, not the board: in portrait the board is the
width less 2 × 24 dp whatever the scale, so its squares stay at 7 mm (8 × 8) and under 6
mm (10 × 10), a little smaller as the margins grow. The same holds for what is sized
from the width: the puzzles' portrait tiles get physically smaller (9.7 mm today, 8.7,
8.2, 7.7, 7.0). Any f also sets the floor every layout must work at: a 360 dp phone gets
360 / f dp across.

What breaks, worst first (both languages unless named; today's 800 has none of it):

1. **The computer's setup, landscape: back, the title, and Play off the screen** at every
   candidate. Its column is 664 dp tall, centered in the height less 96: at 600 back and
   Play are cut about 32 dp each, from 540 down they are gone (62, 92, 127 dp off each
   end). The friend's (444 dp) fits down to 480, cut 16 dp each end at 411.
   `shell/home.goose`, `frame` (`content_height`, the landscape `center`).
2. **Settings, landscape: the look group runs off the bottom** at every candidate (600
   the kings' row, 480 all its rows; at 411 it lies over the game group). The choices are
   capped at 55% of a page with half its width unused. `shell/settings.goose`, `frame`;
   the same as the survey's (2), now much worse.
3. **The game's and a puzzle's top bar, portrait: words spill out of their tiles.** The
   three tiles are `(N − 120) / 3` dp, 160, 140, 120, 97 (227 today): "Alusta uuesti"
   from 600, "Start over" from 540, "Settings" and "Ülesanded" from 480, all three run
   into each other at 411. `game/panel.goose`, `leave`; `gui::labelled` (`MIDDLE`), the
   survey's (6).
4. **Home, landscape: the menu is cut.** 550 dp tall: fits at 600 (into the margins),
   touches the edges at 540, the wordmark and Settings row cut 35 dp each end at 480 and
   gone at 411. `shell/home.goose`, `frame` and `content_height`.
5. **The puzzles' tiles under 88 dp, and their stars spill.** Portrait `(N − 188) / 5`:
   82, 70, 58, 45 dp; landscape `(2.22 N − 390) / 10`: 94, 81, 68, 52. The three stars
   (70 dp portrait, 58 landscape) touch the tile's edges at 540 and spill over from 480
   (portrait) and at 411 (landscape). `shell/picker.goose`, `frame` and `tile`.
6. **Settings, portrait: the title row and, at 411, the preview.** The title runs under
   the language glass from 480 ("Seaded" and "Settings"); at 411 the groups take the
   whole height, the preview board is gone (its size negative) with the kings' pieces on
   their tiles, and "crown flat, stack raised" and "Learn the moves" spill out of tiles
   capped at the group's width. `shell/settings.goose`, `head`, `frame`, `lay`.
7. **The win card hides the winning piece.** 356 × 300 dp on a portrait board of 552, 492,
   432, 363 dp: 64% to 98% of its width, the piece beside it covered from 600 on (beside
   it today); landscape alike. `game/game.goose`, `celebrate`; the survey's (7).
8. **Previews shrink to thumbnails.** The computer's setup in portrait keeps its 728 dp
   sheet: the board is 453, 320, 187, 105 dp (48, 38, 25, 16 mm; 51 mm today). Home's
   portrait board holds its 51 mm to 480 and drops to 253 dp (39 mm) at 411.
9. **At 411 only:** home's wordmark "Draughts" runs into the gear (229 dp of room);
   home's X sits over the board's corner in landscape (home and both setups: the board is
   0.7 of the height, its top 61 dp down); a puzzle's stars touch Next in landscape.
10. **Still under 88 dp** at every candidate, as today in dp but now larger in mm: the
    setups' tiles 76 dp (8.9 mm at 540), the game's panel tiles 72, settings' 56 to 72.

Fine at every candidate in both languages: the game and a puzzle in landscape (the board
552 to 353 dp between full panels), the clocks in both orientations, the friend's setup
down to 480, home's portrait menu, and the goal and stars of a puzzle in portrait.

**Recommendation: f = 0.75** (the Pixel about 550 dp across, a 360 dp phone 480). An 88
dp tap is then 10.2 mm on the Pixel and about 10.5 on any phone (0.75 of Android's
nominal 0.159 mm dp), about a child's fingertip and well over Android's 48 dp (7.6 mm);
the label's face is 3.5 mm and the smallest notes 2.0 mm, readable without strain. Going further buys nothing where it
matters most, the board, which the phone's width fixes, and at f = 1 every layout would
have to work at 360 dp, where home, settings, and the game's bar break outright. Going
less (0.69) leaves taps at 9.3 mm and still asks for most of the same layout work, since
small phones would reach 525 dp. So: design for a short side down to 480 dp, which the
list above makes concrete (1, 2, 4 need a phone landscape arrangement; 3, 5, 6, 7 fixes
that also help the near-square tablets), then switch the scale to
`max(short / 800, 0.75 × density)` and check it on the Pixel.

## Acceptance criteria

- [x] A survey of every screen at each size above, with what broke (screenshots local)
- [ ] Every screen fits and stays tappable on phones in both orientations, in English
      and Estonian
- [ ] Larger tablets checked and anything broken fixed; memory at 2560 × 1600 recorded
- [ ] Nothing under a cutout or the gesture bar
- [ ] Checked on the Pixel 7a in both orientations, with its numbers
- [ ] Tests cover the layouts at a phone size in both orientations
