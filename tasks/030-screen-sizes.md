# 030: Phones and other screen sizes

Status: todo

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

## On the Pixel 7a (smoke test, 2026-11-08)

1080 × 2400 at 420 dpi (2.625 px a dp), gesture navigation, a punch-hole camera 118 px
(45 dp) deep at the portrait top. The APK installs and runs. It didn't turn: SDL locked
the activity to the orientation it started in (`SENSOR_PORTRAIT`) because the window
wasn't resizable; the tablet turned anyway, as large screens ignore that lock. Fixed by
opening the window resizable too (`docs/development.md`); both orientations then drew
home and a clocked game.

## Acceptance criteria

- [ ] A survey of every screen at each size above, with what broke (screenshots local)
- [ ] Every screen fits and stays tappable on phones in both orientations, in English
      and Estonian
- [ ] Larger tablets checked and anything broken fixed; memory at 2560 × 1600 recorded
- [ ] Nothing under a cutout or the gesture bar
- [ ] Checked on the Pixel 7a in both orientations, with its numbers
- [ ] Tests cover the layouts at a phone size in both orientations
