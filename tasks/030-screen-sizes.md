# 030: Phones and other screen sizes

Status: in-progress (the survey, the layout fixes, the phone layouts down to 480 dp, the
insets, the density floor at F = 0.75, the Pixel 7a, larger tablets on the Mac, and the
tablet done, the top strip checked on the Pixel, and settings' bleed over the tablet's
navigation bar on the Mac; left: the tablet's own re-check of both when next attached)

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
   their tiles, and "Learn the moves" spill out of tiles
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

## Phone layouts (2026-11-08)

Every screen made to work down to a 480 dp short side at phone proportions, for the
partway scale the user chose (`max(short / 800, f × density)`, f about 0.75, not yet in
the app: checked through `--dp`). Every tap is 88 dp at least, on the tablet too.
Shots of every screen (home, both setups, the game without a clock, with one, and
against the computer, settings, the win, the puzzles, puzzle 21) at 9:16, 9:20, and
720 × 1280 in both orientations, English and Estonian, at 800, 600, 540, and 480 dp,
and the tablet and near-square sizes at 800, before and after, out of git, in
`/private/tmp/claude-501/-Users-kaitkasak-projects-personal-draughts/babe58e8-1877-410c-bc48-f7f8f48b403f/scratchpad/phone-layouts/`
(`before/`, `after/` as `<screen>-<real size>-<dp>-<lang>.png`, the tablet's as
`t1920x1200` and `t1200x1920`; `sheets/` for the comparisons below, made by
`final_sheets.sh`; `shoot.sh`, `all.sh`, `cmp.sh`). `test/shell/sizes` now also runs the 20:9 phone at 540 and 480 dp and a 9:16
phone at 480, both orientations and languages, and checks every tap at 88 dp: all in
place everywhere. Numbers below are its, in dp, from the test faces (a little wider than
the real font).

The prototype's list, by number:

1. **The computer's setup, landscape** (back, the title, and play off the screen at every
   candidate): where the column is taller than the screen less 32 dp, it becomes two
   columns of 330 dp side by side, back, the title, the draughts and the level in the
   first, the child's pieces, the clock, and play in the second (`home::paired`). The
   friend's setup does the same below about 530 dp (its column is 496 dp now, with 88 dp
   tiles). Board beside it, 20:9: 356 at 540, 223 at 480 (both setups); the 9:16 phone
   at 480 (853 × 480) has no room for one, so no board shows (below).
2. **Settings, landscape** (the look group off the bottom): where neither the names
   beside nor above the tiles fit the height, the names go back beside the tiles at the
   width they want unwrapped (a foldable); where even that doesn't fit, one group shows
   at a time, with two tabs, Game and Look (icon and title, the shown one lit) in the
   title row in place of the title. Board 431 at 540 and 305 at 480 on 20:9; 105 on the
   9:16 phone at 480.
3. **The game's and a puzzle's bar, portrait** (words spilling from 160 → 97 dp thirds):
   where a third of the bar would be under 170 dp, the bar is 128 dp and each icon
   stands over its word, the tiles as wide as their words and a share of the rest. At
   480 every word keeps the 24 dp heading face in both languages ("Alusta uuesti",
   "Ülesanded"), smallest tile 96 to 107 dp wide.
4. **Home, landscape** (the menu cut at 480): below about 590 dp tall, settings becomes
   the 88 dp gear beside the wordmark, as in portrait, and the column widens to 440 dp;
   the wordmark's letters close up where the gear leaves them too little room. The menu
   is then 448 dp tall. The board moves down under the X or narrows to its left where it
   would reach it (it sat under the X's corner at 411 and on the 9:16 phone): 336 at 480
   on 20:9, 253 on 9:16.
5. **The puzzles** (tiles 58 to 82 dp, stars spilling): where all three tiers would leave
   the tiles under 88 dp (every phone candidate in both orientations), one tier shows at
   a time: the three marks as 88 dp tiles on glass, the shown one lit, left of the tier
   in landscape and in a row under back in portrait, and that tier's ten in rows of five,
   or of four (4, 4, 2) where five don't fit (portrait under about 560 dp). It opens on
   the tier of the puzzle last played, else of the next to solve. Tiles 88 to 96 dp, the
   stars inside them. Unchanged on the tablet and near square (byte-identical shots).
6. **Settings, portrait** (the title under the language from 480): the title takes a
   smaller face or none where it doesn't fit beside the language; where the groups side
   by side would leave the board under 45% of the width (every phone, and 4:3 and the
   foldable now that the tiles are 88), one group shows at a time across the width,
   the tabs in a row under the title row. Board 271 at 540 and 279 at 480 on 20:9.
7. **The win card**: where it would cover the winning piece (a phone's board, and the
   foldable's), it moves into the half of the board away from it, as near the middle as
   clears the piece. On the tablet it doesn't move.
8. **The computer's setup, portrait** (a thumbnail board): two columns don't fit 480 dp
   across, so the sheet stays one column; on 20:9 the board is 244 at 540 and 192 at 480
   (187 before). On the 9:16 phone at 480 the sheet would reach the X: back and the title
   leave it for the top left, level with the X, back on glass as in settings, and no
   board shows.
9. **Under 88 dp, everywhere**: home's rows 80 → 88 (2 dp apart, so their pitch is the
   same) and portrait gear 48 → 88; the setup's back 56 → 88, choices 76 → 88, play 80 →
   88, the draughts' tiles 88 wide at least; settings' tiles 56 to 72 → 88 tall, the
   seasons' 74 → 88 wide, the language's 48 → 88 (the title row 88 → 100); the game's
   and a puzzle's panel tiles 72 → 88, portrait take back and next 80 → 88. The clocks
   (72) take no tap and stay.
10. Also: a landscape panel under 420 dp tall (a phone's) has its bottom tile 96 dp
    instead of 132, so a puzzle's stars clear next at 480 on 9:16.

**On the tablet (16:10, 1280 × 800 and 800 × 1280 dp)**, all from the 88 dp floor;
shots side by side in `sheets/tablet-<screen>.png` (before left, after right):

- Home: landscape the same but the lit and pressed rows 8 dp taller (menu 550 → 554,
  its words 2 dp higher);
  portrait the gear 48 → 88, overhanging its row 8 dp each side; the board unchanged
  (560 landscape, 620 portrait).
- The setups: back, the choices, and play 88 tall; landscape the column 664 → 740 (the
  computer's) and 444 → 496 (a friend's), the board unchanged (560); portrait the board
  472 → 396 (the computer's) and 620 → 568 (a friend's).
- The game and a puzzle: landscape the left panel's rows 72 → 88; portrait the bar 104 →
  120 and the play 196 → 204, take back and next 80 → 88, the board unchanged (752) and
  4 dp lower.
- Settings: every tile 88 tall, the seasons 88 wide, the language 88, the title row
  100; landscape the same arrangement, the groups taller and the column wider (the five
  seasons at 88), the board about 550 → 505 (measured in the shots); portrait the groups
  taller, the board 632 → 530.
- The puzzles and the win: unchanged.

Near square, 800 dp at 4:3 and the foldable: no screen cut or overlapping. Settings
landscape keeps both groups with the names beside unwrapped and a small board (305 at
4:3, 242 on the foldable, test faces); settings portrait shows one group at a time (board
371 and 307). The game portrait's board 671 → 647 (4:3) and 603 → 579 (foldable).

**For the user to look at** (design choices taken, closest to the current look):

- **Tabs** where a screen's groups don't fit: settings (Game and Look,
  `sheets/choice-settings.png`) and the puzzles (the three marks,
  `sheets/choice-puzzles.png`). The other ways (a scrolling list, smaller taps) break
  "scroll-free" or the 88 dp floor.
- **Two setup columns** on a short landscape (`sheets/choice-setup.png`).
- **No board where there is no room**, rather than a thumbnail: both setups in
  landscape on a 9:16 phone at 480 dp, the computer's setup and settings in portrait
  there (`sheets/choice-noboard.png`); settings in landscape there keeps a 105 dp one. A
  board under 96 dp isn't drawn.
- **Back and the title over the photograph** in the computer's setup on a 9:16 phone at
  480 dp portrait (in `sheets/choice-noboard.png`).
- **The portrait bar's icons over their words** on phones (`sheets/choice-bar.png`).
- **Home's gear beside the wordmark** in a short landscape (`sheets/choice-home.png`),
  and **the win card moved off the winning piece** (`sheets/choice-win.png`).
- **Settings with the Board row** (`--3d`, task 015): its three look rows don't fit
  beside the game's in a landscape 800 dp tall, so with it the tablet too shows one
  group at a time. `test/shell/settings` lays out at 900 dp to keep both on screen for
  its taps.

Left open: the scale itself (`max(short / 800, f × density)`) and its check on the
Pixel 7a; the near-square settings' small board (242 to 305 dp) may want its own look;
the phones' insets (done on the Mac below).

## Insets (2026-11-08)

Every screen lays out its taps and words in the window's safe area, the photograph and
glass that runs off the screen reaching its edges
([rendering](../docs/architecture/rendering.md#screen-sizes-and-the-safe-area)).

- **Where they come from:** goose_gfx exposes neither the safe area nor the display
  scale, and a gfx patch can't add a function the program calls (the program compiles
  against the release's `gfx.goose`, and a Mac run uses the gfx built into goose), so
  the program's own C asks SDL (`app/display.c`, every frame; [findings](../docs/goose-findings.md)).
  On this Mac, a 960 × 540 window: `SDL_GetWindowSafeArea` all of it (insets 0),
  `SDL_GetWindowDisplayScale` 2.0 (`SDL_GetWindowPixelDensity` 2.0 ×
  `SDL_GetDisplayContentScale` 1.0). On Android, from SDL's source: the display scale is
  `densityDpi / 160` (2.625 expected on the Pixel 7a, 1.5 on the tablet), the safe
  area the window's insets in pixels; SDL sets `LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS`
  from Android 11, so the app draws behind the cutout and the window is the whole display.
  SDL counts the back gesture's side strips (`systemGestures`) in the insets too, which
  would take tens of dp from a portrait phone's width for no tap's sake;
  `patches/SDL/0002` leaves them out, and `scripts/android.py` now compiles SDL's Java
  from the patched copy (it compiled the submodule's before, so a Java patch did
  nothing). The APK builds; not yet run on a phone.
- **Layout:** `gui::Gui.insets` holds them in pixels; `shell::frame` hands each screen
  `gui::safe` (home, the setups, settings, the puzzles, the game and a puzzle through
  `panel::layout_in`), so transitions, which ease the board between two layouts made in
  the same rect, line up as before; home's column and sheet bleed to the screen's edges
  (`gui::bleed`). The scale stays the whole short side's, so it is the same in both
  orientations: the cutout falls on the long side in portrait and the short side in
  landscape, and a scale from the safe rect would rebake the text and resize every tap
  on turning. With the density floor on, a phone's scale is the floor's anyway. A
  change of insets or scale is a change, like a resize: the loop draws again (SDL's
  `SDL_EVENT_WINDOW_SAFE_AREA_CHANGED` wakes it).
- **What the safe area broke:** a 9:16 phone at 480 dp less a 52 dp cutout at a side
  and a 21 dp gesture bar leaves 801 × 459 dp, under the 480 the phone layouts were made
  for. The game's and a puzzle's panels, as tall as the board, which the width held to
  321 dp, had tiles over each other and the stars over next: they stay 372 dp tall at
  least (`panel::PANEL_LEAST`), centered beside the board. The setups' two columns met
  the X: they narrow from 330 dp down to 290 where the second would reach it. Home's
  gear, reaching 8 dp over the wordmark's row, poked 3 dp over the top in landscape: the
  menu keeps 8 dp from the top there.
- **`--inset L,T,R,B`** (dp of the layout) stands for a phone's insets on the Mac
  (`docs/development.md`). `test/shell/sizes` runs the 20:9 phone at 540 and 480 dp and
  the 9:16 at 480 with the Pixel's 118 px cutout (top in portrait, either side in
  landscape) and a 48 px gesture bar (84 px since the Pixel, below), both languages: every tile and the board inside
  the safe area, every tap 88 dp. Boards, English, against the same phone without
  insets: 20:9 at 540 landscape, home 378 → 361, the setups 378 / 356 → 297, the game
  492 → 468, settings 431 → 375; portrait home 432 (the same), the computer's setup 244 →
  233, settings 271 → 418 (one group at a time now, the board larger), the game 492 (the
  same); 9:16 at 480 portrait, the game's bar 352 dp wide, its words in the smaller face.

Shots of every screen and three transitions (home ↔ settings, home → the game, the
puzzles → a puzzle) at 540 dp, 20:9, portrait (top 59 dp, bottom 24 dp: the Pixel's 118
and 48 px at 2 px a dp) and landscape (59 dp at the left, then at the right, bottom 24),
and at 480 dp on 20:9 and 9:16 (52 and 21 dp), both languages, out of git, in
`/private/tmp/claude-501/-Users-kaitkasak-projects-personal-draughts/babe58e8-1877-410c-bc48-f7f8f48b403f/scratchpad/insets/`
(`inset-shots/`, `sheets/` with the insets tinted red, `shoot.sh`, `all.sh`, `sheets.py`,
`cmp.sh`). Nothing that takes a tap or reads sits under an inset in any of them. The
tablet's 960 × 600 and 600 × 960 shots (all the screens and the three transitions, both
languages) are byte-identical to the build before, but settings' preview flash, and so
are the phones' without insets but for the two defects below.

**Two defects from the phone layouts:**

- The computer's setup, portrait, 9:16 at 480 dp: back and the title sat over the
  photograph beside the X, the title running into it; with insets the sheet's top ran
  under them too. Now, where the sheet would reach the X, the sheet takes the height, 8
  dp under its top at least, its margins shrinking from 32 dp to fit, and back, the
  title (smaller where it must be), and the X share its first row. No board, as before.
- Settings, 9:16 at 480 dp: a board about 105 dp beside the Game tab's group in landscape
  (and about 110 in portrait, English only, from the real font's narrower words). One
  rule for every board beside controls now, `board::SMALLEST`: under 128 dp it isn't
  shown (squares under 13 dp on 10 × 10, too small to read), so both go, as Estonian's
  already had; the foldable's portrait computer setup keeps its 147.

**The density floor:** `gui::scale_of` is `max(short / short_dp, F × display scale)`
with `gui::DENSITY_FLOOR` (F) 0, so nothing changes until F is picked. The app sets the
display scale on Android only; on the Mac it stays out, since Retina's 2.0 with F = 0.75
would floor the scale at 1.5 px a dp, so any window under 600 points tall would lay out
fewer than 800 dp (960 × 540: 720 dp) and the shots would depend on the Mac's screen.
`--density-floor F --display-scale S` tries it on either (`--size 1200x540
--density-floor 0.75 --display-scale 2.625` is what the Pixel would show in landscape,
548 dp across), and `--dp N` turns the floor off unless `--density-floor` is given too,
so `--dp` shots stay what they say. The user picked F = 0.75 on 2026-11-08, and
`DENSITY_FLOOR` is set to it.

**Left for the Pixel 7a:** log once what `draughts_display` returns in both orientations
(the insets, and the display scale, expected 2.625) and check that the patched safe area
has no side strips in portrait with gesture navigation; then every screen in both
orientations with nothing under the camera or the gesture bar, turning the phone with a
screen open (the layout must follow the insets at once), and the tablet's own insets
(none expected but perhaps a bottom gesture bar, which would lift its layouts a little).

## Larger tablets on the Mac (2026-11-08)

The user has no larger device, so this is the Mac's check (decided 2026-11-08). Every screen
(home, both setups, the game without a clock, with `--clock 5+3`, against the computer,
settings, the win card, puzzles, puzzle 21) in both orientations, English and Estonian, at
16:10 (2560 x 1600), 3:2 (2880 x 1920), 4:3 (2048 x 1536) and the foldable (2208 x 1768):
160 shots, local, in
`/private/tmp/claude-501/-Users-kaitkasak-projects-personal-draughts/babe58e8-1877-410c-bc48-f7f8f48b403f/scratchpad/large-tablets/`.
Real pixels (`--size` is in points, the PNG 2x): all landscape sizes (1280x800, 1440x960,
1024x768, 1104x884) and portrait 4:3 (768x1024). Portrait 16:10, 3:2 and the foldable at
the same proportions, smaller (600x960 = 1200 x 1920, 640x960 = 1280 x 1920, 868x1084 =
1736 x 2168), as the layout depends only on them.

- **What broke: nothing new.** The earlier survey's near-square findings (settings' look
  group, puzzles' tiles and last tier, the small board, the top bar's "Alusta uuesti", the
  win card) show fixed at 4:3, 3:2 and the foldable in both orientations and both
  languages. At 16:10 and 3:2 the layouts are the tablet's, scaled: nothing cut off,
  overlapping, or wasted, and no tile needlessly huge (the scale is the shorter side /
  800, so the layout is the same in dp at every size). Judged from the shots; tap sizes in
  dp are the tablet's. No code changed.
- **Crispness** at real 2560 x 1600 (settings, a 900 x 500 crop): the baked text and the
  glass edges are sharp.
- **The photograph** is cover-cropped by the long side from a 2048 px texture, so it is
  stretched by long side / 2048: 2560 px 1.25 x, 2880 px 1.41 x, 2208 px 1.08 x, 2048 px
  1.0 x. Behind home, settings and the puzzles it is the sharp one and reads as soft
  foliage at 1.25 x; behind the game it is blurred anyway.
- **Mac memory** (footprint, 6 s in, `--size` in points): 1280x800 (2560 x 1600 px) 215 MB
  on home and in a game (rss about 133 MB); 960x600 (1920 x 1200) 160 MB on home, 159 MB
  in a game (rss about 135 MB). The 55 MB difference is graphics (100 MB against 65 MB,
  the screen-sized buffers). This is the Mac's, not Android's (other allocator, drivers,
  unified memory): it shows only that the cost grows with the pixels, not what the
  tablet's PSS would be.
- **Open:** a device's PSS at 2560 x 1600 waits for a device; the tablet's 261 to 263 MB at
  1920 x 1200 is the number to compare with.

## On the Pixel 7a (2026-11-08)

Android 17, 1080 × 2400, gesture navigation, the density floor on (F = 0.75), from
`ec288c0`. A temporary log of `draughts_display` and the layout scale (removed after):

| Orientation | Insets L, T, R, B (px) | Display scale | Layout scale |
|---|---|---|---|
| Portrait (`user_rotation 0`) | 0, 150, 0, 84 | 2.625 | 1.969 px a dp |
| Landscape, camera left (1) | 118, 74, 0, 84 | 2.625 | 1.969 |
| Landscape, camera right (3) | 0, 74, 118, 84 | 2.625 | 1.969 |

So the Pixel lays out 549 × 1219 dp, the safe area 549 × 1100 in portrait and 1159 ×
470 in landscape. No side strips (`patches/SDL/0002` works). The top is more than the
camera: with the system bars hidden, `mandatorySystemGestures` still holds the strip at
the top where a swipe pulls the bars down, 150 px (57 dp) in portrait, deeper than the
camera's 118, and 74 px (28 dp) in landscape; the gesture bar at the bottom is 84 px
(32 dp), not the 48 the Mac's `--inset` stood for. Landscape thus has 470 dp of height,
under the 480 the phone layouts were made for; every screen still fits (below). The top
strip is left to taps since (a tap there reaches the app; only a swipe pulls the bars):
see "The top strip" below.

When the phone turns, the insets and the new size come a frame or two apart (the insets
first); the layout follows each, and a shot 1.2 s after turning with settings or the
computer's setup open shows the new orientation's layout.

Checked, with the shots kept locally in
`/private/tmp/claude-501/-Users-kaitkasak-projects-personal-draughts/babe58e8-1877-410c-bc48-f7f8f48b403f/scratchpad/pixel-final/`
(`shots/`, `sheets/` with the insets tinted red, `back/`, the `back-*.png` sheets,
`shoot.sh`, `few.sh`, `back.sh`, `sheets.py`, `pairs.py`): every screen of the survey in
portrait in English and Estonian and in landscape (camera left) in English; the game and
settings in Estonian landscape; home, the computer's setup, settings, and the game with
the camera on the right. Nothing that takes a tap or reads lies under an inset, nothing
is cut off or overlapping, and the taps measure about 88 dp (173 px). Nothing broke on
screen. Settings in portrait shows the tabs in English and both groups side by side in
Estonian, as on the Mac. Back on every screen: task 035, which fixed back on home's menu
finishing the activity on Android 17.

Memory 5 s after arriving, portrait: home PSS 291 MB, of it 252 MB graphics (180 GL, 73
EGL); the game (International) 292 MB, graphics 252. Near the smoke test's 289 MB and
the tablet's 261 to 263.

## The top strip (2026-11-08)

The user chose to stop reserving the top strip, which cost 28 dp of landscape height.
`patches/SDL/0002` (renamed `-safe-area-without-system-gestures`) now makes the safe
area `systemBars | tappableElement | displayCutout` (the bars count only while shown)
and of `mandatorySystemGestures` only its bottom, the gesture bar. Expected on the Pixel
7a: portrait 0, 118, 0, 84 px; landscape 118, 0, 0, 84 and 0, 0, 118, 84; so 549 × 1116
dp in portrait and 1159 × 506 in landscape. The APK builds; not yet run on the phone.

On the Mac, `test/shell/sizes` and `--inset` stand for the 84 px bar now, not 48 (at 540
dp `--inset 0,59,0,42`). At 480 dp in landscape that leaves 443 dp of height, under the
gear-beside menu's 444 plus the gear's 8 dp over the wordmark's row, so the gear went
off the top: the gap under the wordmark shrinks from 14 dp down to 4 there
(`home::mark_gap`). The other changes with the deeper bar: the 20:9 phone at 480 dp in
portrait shows the computer's setup with no board (its sheet takes the height), and the
9:16 at 480 the game's board 352 → 336 dp, its bar's tiles 96 → 91 dp wide.

**On the Pixel 7a**, after the Samsung fix below (`dd98bb2`, the same combination for
the Pixel): `draughts_display` gave 0, 118, 0, 84 px in portrait, 118, 0, 0, 84 with the
camera at the left and 0, 0, 118, 84 at the right, display scale 2.625, layout 1.969 px
a dp, as expected. Home's X closes the app from a tap at its centre in portrait and from
one 62 px from the screen's top in landscape (inside the old 74 px strip:
`wm_finish_activity ... finish-activity`); a swipe down from the top still shows the
bars (`mShowingTransientTypes=statusBars navigationBars`). Home, the game, settings, and
the computer's setup in English, portrait and landscape (camera left): nothing that
takes a tap or reads lies under the camera or the gesture bar, and the title rows sit
24 dp from the screen's top in landscape. Shots, sheets with the insets tinted red, and
the scripts in
`/private/tmp/claude-501/-Users-kaitkasak-projects-personal-draughts/babe58e8-1877-410c-bc48-f7f8f48b403f/scratchpad/phone-topstrip/`.

## On the tablet (2026-11-08)

The Galaxy Tab A11+ with everything up to `d7dbccc` (the top strip left out). It uses
three-button navigation, hidden while the app runs. A temporary log of
`draughts_display` and the layout scale (removed after), the same before and after
`d7dbccc`:

| Orientation | Insets L, T, R, B (px) | Display scale | Layout scale |
|---|---|---|---|
| Landscape (`user_rotation 1`) | 0, 45, 0, 72 | 1.5 | 1.5 px a dp (800 dp) |
| Portrait (0) | 0, 45, 0, 72 | 1.5 | 1.5 |

The floor's 1.125 is below 1.5, so the layout is 800 dp as before. The 72 px (48 dp)
bottom is the hidden navigation bar. The top 45 px (30 dp) stays after `d7dbccc`: on this
Samsung the hidden status bar's strip is reported as `tappableElement` as well as
`mandatorySystemGestures` (`dumpsys window`: `tappableElement frame=[0,0][1920,45]
visible=true`), and the patch keeps `tappableElement`. So the safe area is 1280 × 722 dp
in landscape and 800 × 1202 in portrait. On turning, one frame has the new insets
against the old size (insets 0, 45, -720, 792), then both agree, as on the Pixel.

Shots of home, both setups, the game (International, and Russian with `--clock 5+3`),
settings, and puzzle 21 in both orientations in English, and the computer's setup and
settings in Estonian, kept locally in
`/private/tmp/claude-501/-Users-kaitkasak-projects-personal-draughts/babe58e8-1877-410c-bc48-f7f8f48b403f/scratchpad/tablet-final/`
(`shots/`, `tinted/` and `sheets/` with the insets tinted red, `shoot.sh`, `all.sh`,
`sheet.sh`, `bands.sh`). Nothing that takes a tap or reads lies under an inset, nothing
is cut off or overlapping, and the 88 dp floor's changes look as on the Mac.

- **What changed: landscape settings shows tabs.** Its two groups side by side fill the
  800 dp height with about 10 dp to spare; any inset beyond that tips it to one group at
  a time with the Game and Look tabs (on the Mac, `--size 960x600 --screen settings`
  shows both groups with `--inset 0,0,0,8` and tabs with `0,0,0,48` or `0,30,0,0`). On
  the tablet the bottom bar alone does it, in both languages, so the tabs show there on
  any tablet with a navigation bar. Portrait keeps both groups. The user chose to keep
  both groups: see "The Samsung strip and settings' bleed" below.
- **Back** (`input keyevent KEYCODE_BACK`, landscape): the computer's and the friend's
  setup, the game, and settings opened from home go to home's menu; puzzle 21 goes to
  the puzzles. On home's menu the launcher shows, the process stays (the same pid), the
  activity isn't finished, and starting the app again brings the task back with home
  pixel-identical to before. Home's X finishes the activity and removes the task
  (`wm_finish_activity`, `wm_task_removed`), the process cached as task 035 says.
- **Idle**, home in landscape, 60 s untouched: the program thread 0.03 s, the process
  1.26 s, 60 voluntary switches (1.25 to 1.5 s before).
- **Lifecycle memory**, 20 cycles of home, resume, and rotation: PSS 273 MB at the start,
  then 259 to 264 MB, native heap 27 MB, graphics 211 to 215 MB with the same two 2 MB
  steps as before; one process, no errors.

## The Samsung strip and settings' bleed (2026-11-08)

The user's two decisions after the tablet check:

- **The top strip on Samsung:** `patches/SDL/0002` now takes `tappableElement` only at
  the sides and the bottom, as it does `mandatorySystemGestures`: the safe area is
  `max(systemBars | displayCutout, (tap.left, 0, tap.right, max(tap.bottom,
  gestures.bottom)))`. A status bar while shown still counts, through `systemBars`.
  Expected on the tablet 0, 0, 0, 72 px in both orientations; the Pixel's are
  unchanged (above).
- **Settings in a tablet's landscape:** the two groups' fit counts up to 38 dp of a
  bottom inset (the page's 24 dp foot and the look group's 14 dp bottom pad), so the
  tiles end above the inset and at least as far from the screen's edge as with none.
  Where the groups then run past the page, they lay out from its top and the look's
  glass runs on to the screen's bottom edge (`gui::bleed`, which every group's glass
  now goes through, a no-op elsewhere). With no inset nothing moves: every
  `test/expected` line stayed, and the Mac's 960 × 600 settings shot without an inset
  matches the build before but for the preview's flash (6 px). On the Mac at 960 × 600
  with `--inset 0,0,0,36` and `0,0,0,48` (the tablet's 48 dp), the build before showed
  the tabs and this one both groups, the Kings row's tiles above the inset. The Pixel's
  landscape, 506 dp tall, keeps the tabs. `test/shell/sizes` runs the 16:10 tablet at
  1920 × 1200 and 1200 × 1920 with a 72 px bottom inset in both languages: every tile
  inside the safe area, settings with its 17 tiles (both groups) in both orientations;
  without the change, landscape had 11 (one group and the tabs). Mac shots in
  `/private/tmp/claude-501/-Users-kaitkasak-projects-personal-draughts/babe58e8-1877-410c-bc48-f7f8f48b403f/scratchpad/phone-topstrip/mac/`.

**Left for the tablet**, the next time it is attached: log `draughts_display` for 0, 0,
0, 72 px in both orientations, and look at settings in landscape (both groups, the
Kings row above the hidden bar) in both languages.

## Acceptance criteria

- [x] A survey of every screen at each size above, with what broke (screenshots local)
- [x] Every screen fits and stays tappable on phones in both orientations, in English
      and Estonian
- [x] Larger tablets checked and anything broken fixed, on the Mac (a device's memory at
      2560 × 1600 waits for one)
- [x] Nothing under a cutout or the gesture bar
- [x] Checked on the Pixel 7a in both orientations, with its numbers
- [x] Tests cover the layouts at a phone size in both orientations
