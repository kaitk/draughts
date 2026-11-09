# 044: A plain background

Status: in-progress

A background without a photograph, as a choice in settings' Background row beside the
seasons and by the date (the user, 2026-11-09). On the Galaxy A33 a build without the
photographs showed the page color under the 3D board's blur and grading, a dark-to-brown
fade, and the user liked it. Its colors should suit the board it frames: each season's
board (its wood or stone, the flat board's squares) gets a plain gradient picked to match
it, rather than one brown for all.

Also lighter: no photograph decoded or uploaded, and the 3D board's backdrop has no blur
or harmonics to make, so its first switch is shorter.

## Acceptance criteria

- [x] A Plain tile in the Background row, its thumbnail the gradient, kept in the
      player's file: as place b, the Theme row's two-part switch, photograph or plain,
      kept as `background = photo|plain` (`test/shell/settings`)
- [x] A gradient per season's board, checked beside each board flat and 3D, in a
      prototype first (`prototypes/`): fade b, checked on the Mac flat and 3D
- [x] With Plain chosen, no photograph is decoded or held (memory measured on the Mac)
- [x] On the tablet: `dumpsys meminfo` at home with the photograph and with the fade,
      after the same frames (`agents/testing.md`): about 1 MB apart ("On the tablet")
- [x] On the tablet: the frame a switch between them takes (a theme change's 22 ms
      before), and the 3D board's switch, which runs only the photograph's steps: 22 ms,
      and one of 58 ms on some switches ("On the tablet")
- [ ] On the tablet and the A33: the fade's look, banding in the dark fade, and the
      switch's 58 × 68 dp halves under a child's finger

## Prototype

`prototypes/plain.html` (2026-11-09). The season still picks the board, so plain is an
on/off of its own beside the Background row rather than a sixth tile: a, a Picture row
(photo or plain); b, a two-part switch under the row's name; c, one Plain tile at the
row's end. Two takes on the fade per board (`&grad=`): a, what the 3D backdrop's grade
makes of the page color with no photograph (the A33 build's look), pale low down; b,
darker, the page to a deep tone of the frame with a faint light of the dark square in
the middle. The user chose b and b (below).

## Built (2026-11-09)

The user chose place b and fade b. Settings' row is now Theme (Teema), and its switch
sits under the name in its column where names are at the tiles' left, beside the name
where they are above (`docs/architecture/rendering.md`, "Settings" and "Scene and
glass").

- **The switch's size.** Under the name, two 88 dp halves don't fit: they need 180 dp
  across where the name's column has 120, and the look's group can't grow taller, since
  the tablet's landscape (1920 × 1200 with its 72 px bar) has 8 dp to spare before
  settings falls back to one group at a time (`test/shell/sizes`). The halves there are
  58 × 68 dp, inside the row's 88 dp, under the floor. Nearest fits that keep 88 dp,
  not built: the halves 88 dp tall with the name moved out of the column (onto the
  group's title line, or dropped in that layout), or the switch as a row of its own,
  which the tablet's landscape has no room for. Beside the name the halves are 88 dp
  square, and the line under the name grows from 28 to 92 dp: settings' board in
  portrait shrinks by about 60 dp (the tablet's 485 → 425 dp; the tightest phone tab,
  9:16 at 480 dp, 194 → 134 dp), and the tablet's portrait in Estonian with its bar keeps
  both groups with the gap under the switch at 4 dp (10 would have tipped it to tabs).
- **The 3D board's ambient** comes from the fade, painted 64 texels square on the CPU
  and taken as the photograph's harmonics are, then scaled to the brightness of the
  fixed ambient a theme without a photograph had (0.25, 0.17, 0.1): the A33 build the
  task began from. The fade's own light, unscaled, is several times darker.
- **Memory on the Mac** (headless build, 1920 × 1200, autumn, `footprint` 6 s in):
  home, flat: 97 MB with the photograph, 85 MB with the fade, graphics 52 → 34 MB.
  The 3D game: 833 → 813 MB. Settings and the 3D game read far higher headless (600 MB
  and more of graphics, falling over seconds) with either background, so only their
  difference means anything.

## On the tablet (2026-11-09)

A build beside the app (`--id-suffix bench`), main's head with the photographs embedded.

- **Memory at home, flat** (`--background photo|plain --board flat`, `dumpsys meminfo`
  12 s after the launch, three launches each, alternated): with the photograph total PSS
  140.6 to 141.0 MB, GL mtrack 36.6, the native heap's live bytes 39.5; with the fade
  139.7 MB (one launch 144.0, its EGL mtrack 2.4 MB higher), GL 36.2, the heap 36.7.
  About 1 MB of PSS apart: on Android the photograph is ASTC, 1.9 MB, not the Mac's
  16 MB RGBA, so the fade saves little memory here.
- **The switch's frames** (settings, `--screen settings`, SurfaceFlinger's
  present2present over each tap alone, three taps each way). Flat: to the fade one or
  two frames of 22 ms (one late at 90 Hz, as a theme change); to the photograph one of
  22 ms and, on two of three, one of 58 ms (the photograph's upload). On the 3D board:
  each way one frame of 22 ms or one of 58 to 66 ms, the rest at 90 Hz, so the
  photograph's steps keep the board moving.
