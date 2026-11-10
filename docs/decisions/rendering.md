# Rendering decisions

The decisions behind drawing, the UI, the look, the 3D board, and frames, dated, with
their reasons, what they rejected, and the measurements behind them. The headings follow
[Architecture: Rendering](../architecture/rendering.md), which says how it works now.

## Drawing

The screen's pass has no depth target, and in the Android build gfx never cycles the
screen (`patches/goose_gfx/0003`). Together they kept SDL from a second 64 MiB block after
the first rotation, about 70 MB of graphics memory on the tablet, before SDL's blocks
were sized to their resources ([GPU memory](#gpu-memory)).

## UI layer

The UI's shader is built three times, its base kinds, the icons, and the players' faces,
each drawn in runs in the quads' order (2026-11-10, task 063): one shader for all held 64
registers for every UI pixel, each of the three 32.

The quads are shaded only where they show (2026-11-10, task 063). With the three
pipelines, the UI drawn live costs half the GPU cycles it did on the Pixel 7a (0.61M →
0.30M a frame on the flat game), measured with `--keep off`. Tried and dropped: a glyph's
atlas place interpolated (malioc's fewer varyings read, nothing on the Pixel, which pays
for the varyings declared), the quads read from the storage buffer in the fragment shader
(4 load/store cycles a pixel), and `mediump` varyings. Not done: with the plain
background, glass works the fade out a pixel at a time (about 1.3 of glass's 4 cycles); a
texture of it would save that but smear its dither.

The UI is kept as a layer while it stands still (task 059): its quads were a quarter of
the 3D frame's GPU cycles on the Pixel 7a while only the board moved.

Layout stays rect-cutting with `gui::stack`. If it outgrows that (wrapping text, menus
like Snowtime's), copy [Clay](https://github.com/nicbarker/clay)'s model, a per-frame
layout tree with grow, fit, and fixed sizing, rather than link it: its API is C macros,
which Goose can't call directly. A Clay-like engine was weighed again in task 061
(2026-11-10) and left out, `gui::stack` covering what it would give.

### Screen sizes and the safe area

The density floor is 0.75 (2026-11-08). Without a floor a phone draws the tablet's layout
into its 64 mm short side: an 88 dp tap is 7.0 mm on the Pixel 7a against 16.3 on the
tablet, the 17 dp notes 1.4 mm. At 0.75 an 88 dp tap is about 10.5 mm on any phone and
the notes 2 mm. Going further buys nothing on the board, whose size the phone's width
fixes whatever the scale, and at 1 every layout would have to work 360 dp across. Going
less (0.69) leaves taps at 9.3 mm and still needs most of the same layout work.

Settings in landscape ends the look group's glass below its tiles over a bottom inset
(2026-11-09). Rejected: running it on to the screen's bottom edge, which left it mostly
empty below. Under a top inset in landscape the page's top padding gives up to 12 dp of
its 24 (2026-11-09), so the 13" and 11" iPad keep both groups.

### Small windows

iPadOS 26's resizable windows got the compact layout (2026-11-09, task 050). Headless, the
smallest window's 3D game board went from about 200 dp wide to about 350, and home's board
from none to about 160 dp. Settings' slim theme tiles fixed Board's foot, which had been
33 dp under its glass's (`test/shell/sizes`' last line).

- Compact's controls are under the 88 dp floor, accepted for compact only (2026-11-09).
- The gap under home's wordmark row is 12 dp, the gear's reach, so its 88 dp tap keeps
  off Continue's (2026-11-10); it was 8.
- No fling in scrolling lists (2026-11-09).
- No screen moves out of the way of iPadOS's window control (2026-11-09): back and the
  chip are large and still easy to tap beside the dots, and a control that steps aside in
  a window only is one that moves. A margin clear of the dots was built and taken out
  (task 050).

### Window resizing

A Mac window being resized shows the last frame scaled to fit over a cover of the
backdrop (task 058). Rejected:

- Drawing live during the drag: it needs the loop's body run from SDL's 60 Hz expose in an
  event watch, from inside gfx's own `frame()`, which Goose may not allow, and Metal's
  frame lags the window's size by one, so the edges wobble.
- A cover over the stretched frame, taken off after the next frame: it flickered on
  mouse-up and switched too suddenly.

Windows' modal size loop shows the last frame unscaled, black where the window grew, and
that is kept (2026-11-10): the Mac's look there would need a gfx patch presenting the
backdrop and the last frame from SDL's 60 Hz expose, the swapchain made again each tick.
An iPad's window (the 11" iPad Pro simulator, iOS 26.4) lays out live.

## Look

The HTML prototypes settled the look's values on 2026-11-07.

### Seasons and themes

The seasons' values come from the design boards (2026-11-07). Summer's sunset (2026-11-07)
takes the summer photograph's evening sky, where the design boards' sea greens were cold
against it and close to spring's sage.

{themes.rstrip()}

### Scene and glass

- Behind the flat game the photograph is blurred. Tried and set aside on 2026-11-07: the
  sharp photograph (busy behind the board), a plain painted tabletop, and generated
  tabletop pictures with a crafted board (task 016, cancelled).
- The 3D board floats in front of the scene with no room or table modelled. A painted
  backdrop with a real table comes later only if this falls short.
- ASTC in 6 × 6 blocks (2026-11-08): it looks the same as the JPEG and 4 × 4 side by side
  at the tablet's and a phone's size, sharp behind home and blurred, and is nearer the
  master than the JPEG (44 to 45 dB against 40 to 41, summer 40 against 37.5); 4 × 4
  (4 MB) buys nothing visible. Rejected: PNG, at about 5 MB a season, and AVIF, which
  needs libavif and an AV1 decoder on both platforms to save about 1 MB.
- Loading the photograph in the frame after the lit tile, after a `gfx::flush()`, took a
  season change's longest frame on the tablet from 54 to 66 ms to 22 ms.
- The JPEG and ASTC masters went into git on 2026-11-10.
- One size for every screen (2026-11-08): sizing the photograph by the screen's density
  (1024 to 1536 on a dense phone) would save at most 1 MB in SDL's shared block and needs
  several encodings or a choice at load.
- The plain background was added on 2026-11-09 (`prototypes/plain.html`, fade b).
- Glass is a pre-blurred copy, not a live blur: Snowtime measured live backdrop blur
  costing more than its weather animation, and switched to a copy of the background
  blurred once (its `docs/architecture/scene.md`).
- The blurred copies stay as they are (2026-11-08): smaller copies (a sigma-5.6 blur at
  512 keeps its look at 256 or 128), a dual-filter (Kawase) chain, sampling a mip of the
  photograph, and copies blurred offline and shipped compressed were weighed and dropped.
  The two copies are 1.25 MiB together inside SDL's shared 16 MiB block, so none would
  save measurable memory, and the blur runs only on a season change. The thumbnails as
  ASTC (0.4 MB) were dropped the same way.

### Light

The pieces' soft light from above and toward the top was chosen on 2026-11-07. A strong
light pool and, with the tabletops, a crafted board with a soft light were tried that day
and set aside.

### Controls

The prototypes `back.html`, `win.html`, `draw.html`, `gear.html`, `exit.html`,
`puzzles.html`, and `chip.html` were removed on 2026-11-10 once built or superseded; they
are in git history before that day.

**The game screen**

- `prototypes/game.html`, chosen 2026-11-07 over three other takes: each control a glass
  tile with an icon and a word, as on home, since icons alone (three arrows for undo,
  restart, and back) confused.
- Landscape only where the flat board fills at least about 2/3 of the height, else
  portrait (2026-11-09): a near-square window's landscape had a small board between
  square-ish panels.
- The flat game's controls are the 3D screen's (2026-11-09, task 054): the UI round the
  board only, the boards untouched. The board stayed as it was, and the flat screen's
  corner panels near square are no wider than the old panels, 192 dp.
- Landscape panels narrow to 192 px where the board would be under 720 px (2026-11-08).
  Rows are 88 px, the floor for small hands (2026-11-08). Portrait's bar tiles take each
  word's width and an even share of the rest where thirds don't fit (2026-11-08).
- The child's pieces are at the bottom against the computer, the board turned when the
  child plays black (2026-11-08).

**The way back** (`back.html`'s take b, chosen 2026-11-09 over a, the arrow alone): one
control on every screen that leaves. It replaced buttons named for where they went
("Home" on the game, "Puzzles" on a puzzle), which children read as different controls,
and a bare arrow on the puzzles and settings; take back became "Undo move" ("Võta käik
tagasi") so it says it is about the move, not the screen. On a phone in landscape
settings' title row is wider for it: the preview board went from 431 to 400 dp at 540 dp,
and from 285 to 219 in Estonian at 480 with the Pixel's insets.

**Clocks**: black's clock runs only after white's first move (2026-11-08), so a child can
settle before anything counts. The running clock's gold under a minute and red at 0:20
came on 2026-11-09.

**A draw** (`draw.html`'s take a, chosen 2026-11-09).

**Home**

- `prototypes/home.html`, chosen 2026-11-07 over the icon tiles and two other takes.
- The bare gear in portrait (`gear.html`'s take a, chosen 2026-11-08). Rejected: the
  88 dp quiet tile, which looked too big beside the wordmark, and the X's round glass
  button, which the X itself later left. The wordmark's letters close up where the gear
  leaves them too little room (2026-11-08).
- The menu's rows close up from 2 dp apart to about 1 where the gear's reach doesn't fit
  (2026-11-10): the Pixel 7a in landscape had overlapped Continue's tap.
- The X closes the app (`exit.html`'s take b, chosen 2026-11-08 as a round glass button;
  made a bare X, `gear.html`'s `x=d`, on 2026-11-09 to match the bare gear). Rejected: a
  quiet last row, which would take the portrait board's room and lengthen the sheet
  phones can't fit; a door, which reads less surely at 34 dp; and a power sign, which
  suggests turning the tablet off.
- The board keeps 40 dp above and below, down to 24 where a setup's tall sheet near
  square would leave it under 40% of the width (2026-11-08).
- The setups (2026-11-08): the child's colour against the computer, every tile 88 dp tall
  at least, two columns in a landscape too short for one, ending on one line, the
  draughts' tiles taking their names' width with an even share of the rest, and the
  setup's board switching at once rather than crossfading. Easy is the default level for
  a new player (2026-11-09).
- The language is only in settings (2026-11-07): kids who can't read yet don't need it on
  home, and a tablet set to one language can still play in another.

**Settings** (`prototypes/settings.html`, regrouped 2026-11-07)

- The tutorial's row (one tile, learn the moves) comes with the tutorial, taken out until
  then so the tablet's landscape shows both groups (2026-11-09).
- The privacy note's place, at the group's title row or the glass's foot, so it moves no
  layout (2026-11-09).
- The theme's tiles, by the date last, so the four seasons keep one row on a phone
  (2026-11-08). Every tile 88 px tall and wide at least (2026-11-08).
- Where the choices have 60 dp to spare (16:9 and wider), every name's column widens to
  the switch's 180 dp (2026-11-09): the board beside them went from 639 to 583 dp there.
- Near square the names go above the tiles and the column narrows (2026-11-08); where
  that fails, the board goes on top with the groups side by side under it, so a widening
  window goes from portrait to landscape without tabs between (2026-11-09, task 050).
- The tabs stand on glass (2026-11-09): a plain tile alone was hard to read over a bright
  photograph. In portrait a group's glass is its own height (2026-11-09): the game's
  glass as tall as the look's had ended in empty glass under its rows.
- Back over its word in portrait (2026-11-08, 2026-11-09): at 548 dp "Settings" had
  61 dp beside the worded back and the language, and "Seaded" 45 and was left out.

**The puzzle picker** (`puzzles.html`'s take a, a library list, chosen 2026-11-09).
Rejected: b's large theme tiles, which shrink long Estonian names and hold the fewest
themes a screen, and c's library beside the theme, which needs two scrolling panes.

- The library's rows are glass lit only while pressed (2026-11-09): a plain tile barely
  showed over the photograph.
- The rows' marks and stars, `prototypes/puzzle-set.html`'s take b (2026-11-09), its
  Continue row and "Next: Easy 3" left out.
- The draughts switch, `prototypes/puzzle-set.html`'s take a (2026-11-09). Rejected: b's
  name under the title opening a list, and c's setup tiles with the themes as a grid.
- The title is shadowed (2026-11-09), as it sat partly over spring's and autumn's birch
  bark at the tablet's and iPad's sizes; until the switch it was left out in landscape
  under 600 dp tall.
- In a tablet's landscape the rows take the whole width (2026-11-09); they had kept clear
  of back's column too, which pushed them against the right edge: 183 dp left of them, 27
  right at 16:9.

**A puzzle** (`prototypes/puzzle.html`, take c, chosen 2026-11-08). A selected piece's
targets never show (2026-11-08). The turn piece beside the goal in a short landscape panel
(`turn=a`, chosen 2026-11-09 over `turn=b`, beside everywhere, since over the goal the
tablet shows it as the game does).

**Players** (`prototypes/profiles.html`, take a, chosen 2026-11-09)

- The name on a glass pill (2026-11-09, `chip.html`'s take d), so it reads on a bright
  photograph.
- The chip mirrors the X (2026-11-09, after the tablet). This gave back the room first
  kept above the board for the chip (`badges.html?home=2`, where it stood above the
  board's top left corner): the tablet's landscape board is back at 120 dp from the top,
  the foldable's portrait went from 339 to 411 dp, 4:3's portrait 407 to 479, a 20:9
  phone's landscape at 480 dp 328 to 336 (291 to 299 with the Pixel 7a's insets, 346 to
  349 at 540 dp).
- A badge is home's king with its animal in the crown's place (2026-11-09, `badges.html`
  direction 1).
