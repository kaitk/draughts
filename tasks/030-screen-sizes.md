# 030: Phones and other screen sizes

Status: in-progress (the survey done; the fixes next)

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

## On the Pixel 7a (smoke test, 2026-11-08)

1080 × 2400 at 420 dpi (2.625 px a dp), gesture navigation, a punch-hole camera 118 px
(45 dp) deep at the portrait top. The APK installs and runs. It didn't turn: SDL locked
the activity to the orientation it started in (`SENSOR_PORTRAIT`) because the window
wasn't resizable; the tablet turned anyway, as large screens ignore that lock. Fixed by
opening the window resizable too (`docs/development.md`); both orientations then drew
home and a clocked game. Home 4 s after a cold start: PSS 289 MB, of it 244 MB graphics
(172 GL, 73 EGL), against the tablet's 261 to 263 MB.

## Acceptance criteria

- [x] A survey of every screen at each size above, with what broke (screenshots local)
- [ ] Every screen fits and stays tappable on phones in both orientations, in English
      and Estonian
- [ ] Larger tablets checked and anything broken fixed; memory at 2560 × 1600 recorded
- [ ] Nothing under a cutout or the gesture bar
- [ ] Checked on the Pixel 7a in both orientations, with its numbers
- [ ] Tests cover the layouts at a phone size in both orientations
