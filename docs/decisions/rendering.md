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

A desktop's window is laid out for a mouse by default (2026-11-11): the scale stops at
0.75 points a dp (`gui::DESKTOP_DP`), and `--touch on` gives a touch screen's sizes. With
the short side always 800 dp, a Mac window 800 points tall had 88-point rows and a full
screen larger still, sized for a hand on a screen a mouse uses; a desktop build (and a
Steam one later, with a controller) wants them the size of a desktop's controls. The
layouts already hold over 1600 dp, so a ceiling on the scale gives most of a desktop
layout at once. A second set of desktop sizes (44 dp rows, text that shrinks less than
the tiles) was rejected then, as it would double every layout's dp values (about 330 of
them, in 16 files); it is replaced (2026-11-11) by one desktop value each for the tap
and a tile's side room (below). At 1200 dp (0.67 points) the notes were 11 points, too
small.

On a desktop the landscape board, flat or 3D, and its corner panels stand in a frame
(2026-11-11): from margin to margin the board crowded a large screen. A frame round the
whole layout, not a smaller board alone, keeps the board's top level with the panels'.
The user found 85% of the full board the most pleasing on a large screen and 92% right
on a smaller one, so the frame grows with the window's height, from 4% of it a side up
to 1000 points to 7.5% at 1440. It is at most 1.45 times as wide as tall round the flat
board: on a 27" screen the panels at the window's edges stood small and far from the
board. Round the 3D board 1.7: at 1.45 its near edge, which must clear the panels, held
it, so it shrank, sat lower than the panels' tops, and pressed against them; from 1.7
its height holds it, its top level with theirs. The 3D board
is framed with its panels: framing the panels alone shrank it about as much, since its
near edge must clear them, and left the two boards' screens unlike.

Tuned by eye on the Mac and a 27" screen (task 068, the user, 2026-11-11):

- The ceiling grows from 0.75 points a dp at a 1000-point shorter side to 0.9 at 1440:
  at 0.75 the controls looked too small on a 27" screen, seen from further away. A
  MacBook's full screen moves only to about 0.78.
- Where the width holds the flat board (1280 × 800), its frame shrinks to the board's
  height and centers: the board, centered down a taller frame, sat 25 points below the
  panels' tops. Settings' preview moves up to the game group's top for the same reason
  (it was centered down the page beside groups that start under the title row).
- Home's menu and the setups start at the column's top, 440 dp wide at least: centered
  on a large window the menu floated in the middle, and the setup's choices were cramped
  in 360 dp.
- A desktop's tiles are 64 dp tall and keep 12 dp beside their words (2026-11-11, task
  069), where the ceiling on the scale alone left a touch screen's 88 and 16 looking
  fat under a mouse. One value each, `gui::tap()` and `gui::side()`, not a set of
  desktop sizes: the tap is named once and the panels' heights are sums of their rows,
  so no screen has a desktop branch. 72, 64, and 56 dp were shot at 1280 × 800, a
  MacBook's full screen, and 27"; 64 was picked. Tiles with their icon or picture over
  their word stay at 72 dp at least (`gui::stacked()`): at 64 undo move's word dropped
  to the small face on one line, and settings' seasons and kings ran over their tiles.
  The play's corner panel grows to hold the clocks over undo move rather than shrinking
  with the left column, where at 56 whose turn ran into the hint.
  Kept as tuned numbers, a few dp over their parts: a puzzle's play panel (504 dp, its
  parts 495) and a phone's narrow one (368, 362).
- The left corner's settings and start over are 20 dp apart, as from their glass's top
  and bottom (2026-11-11), on every screen: the glass was as tall as the play panel, and
  the 36 dp between them read loose. The left column is then 16 dp shorter than the play
  panel on a touch screen; the corners already differ in a puzzle and on a phone.

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

### Themes kept for later

Set aside, not rejected: candidates for another season's photograph, a theme setting, or
a later board. Values as in the table above.

| | Sand and pine (2026-11-07) | Sea (the design boards' summer, until 2026-11-07) |
| --- | --- | --- |
| Light square | `#e6cfa6` | `#c7d5c6` |
| Dark square | `#56603f` | `#2e5546` |
| Frame | `#33361f` | `#1d3a30` |
| Light piece | `#f7efdf` | `#f6f1e4` |
| Dark piece | `#b5603f` (terracotta) | `#b56a57` (terracotta) |
| Crown on a light piece | `#56603f` | `#2e5546` |
| Glow | `#ffc67a` | `#86e7d3` |
| Glass tint | `#3a2a1e` at 50% | `#1e4a4a` at 40% |
| Glass copy dimmed to | 0.8 | 0.75 |
| Text | `#fbf3e6` | `#f4f8f2` |
| Page under the scene | `#1e1a12` | `#0d1c1c` |
| Square surface | soft mottling, like sand | plain sheen |

Sand and pine is warm sand with olive pine squares; it suits the summer photograph too,
but its olive sits nearer spring's greens than the sunset does.

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

- The tile under the mouse lights on a desktop (task 066, 2026-11-11), as a faint form of
  the chosen tile's glow (the glow at 8%, about a third of chosen's 22%, and a 1 dp
  border at 40%), whatever the tile's style, so the mouse shows in the theme's color
  everywhere and a child still tells the tile they picked from the one the mouse is
  over; a lit tile brightens its own glow instead. A fade of the press's 0.12 s, not a
  motion: growing or lifting would make the screen busy under a child's mouse and blur
  the press, the one thing that moves a tile, and a fade that short keeps a sweep along
  a row from flickering. The prototypes' white at 16% when hovered was a browser's
  `:hover`, never built. Never on Android or with `--touch on`: Android leaves the
  pointer where the last touch was, which would leave the tapped tile lit. The hovered
  tile is the topmost found over a frame, made hovered at the next frame's start,
  rather than the first `hold` the pointer is over, which flipped between a card and
  its tiles each frame (`shell/who.goose` holds the whole screen behind its card).
- The arrow keys move a focus and Enter presses it (task 072, 2026-11-11), built once in
  `gui` from what every control already declares, so each screen gets it without code
  of its own and a gamepad later feeds the same moves. Nearest that way by the controls'
  rects rather than the order declared, which suits a column and a grid alike (the
  setups, settings). The focus is ringed (2026-11-11, the user agreeing): a glow ring
  outside the control. The hover's light alone was too faint, and on a lit control
  (Continue, a chosen tile) showed nothing; a stronger fill would be taken for a
  chosen tile.
- Enter with nothing focused focuses the screen's primary and presses it at once
  (2026-11-12): on the board, the cursor's first piece is chosen. It used to do nothing,
  so a gamepad's first press, most often A, looked like the gamepad not working, even
  after a finger's tap had let the focus go (a PS5 pad on the tablet, and before on the
  Mac). This replaces focusing with the first press and pressing with the second, from
  earlier that day: the user found a second press for a control already shown odd. A
  blind first press on another screen presses its primary, a lit row as a rule.
- The board takes the keys as one grid control with a cursor (2026-11-11, task 072):
  the cursor goes over every square, light ones too, one at a time, and Enter is a tap
  on its square. Rejected: a cursor that jumps only between the pieces that can move and
  their targets, which is quicker but gives away which pieces must capture, as showing
  the count up front would (2026-11-09), and leaves no room for the mistakes a child
  learns from; a cursor on the dark squares alone, whose up and down have two squares to
  choose from and so need a rule to learn. Enter as a tap keeps one path through
  `board::press` for the finger, the mouse, and the keys.
- The board's cursor is a glow line just inside its square (2026-11-11, task 072; agreed
  with the user 2026-11-12), as the focus ring is round a control, rather
  than task 067's lit square, which the last move's tint already is. On the 3D board it
  is drawn with the marks over the kept image, so a move of it doesn't draw the board.
- Groups and Tab (2026-11-11): the game's screen is three groups, the way out, the
  board, and the play panel, which Tab and a gamepad's shoulder buttons step between,
  each coming back to where it was. Arrows alone would cross the board square by square
  to get from one panel to the other.
- A gamepad through SDL's gamepad API in the program's C (2026-11-11), as the safe area
  is read: goose_gfx has none (docs/goose-findings.md). It feeds the same moves as the
  keys, so the screens know nothing of it. B is back, as Escape and Android's back are.
- A gamepad at rest costs nothing (2026-11-12): SDL doesn't read the gamepads on its own,
  the program does when its loop runs, and on Apple's systems the GameController
  framework reads them, its change handler waking the loop. Rejected: SDL's own reading,
  every millisecond while one is open (5% of a core idle on the Mac with a PS5 pad); the
  loop waking 30 times a second on Apple's systems too (1.5%: each wake goes through
  AppKit). On Android too (2026-11-12): with SDL's HIDAPI off, Android reads the pad and
  hands each change to SDL as it happens, and the event that makes ends the loop's wait;
  a PS5 pad on a cable worked so on the tablet, plugged in mid-game and again later.
  Windows still wakes 30 times a second while one is connected: an Xbox pad's XInput can
  only be polled, and SDL reads a PS5 pad's reports in its own update; raw input, off by
  default, could wake the loop, to try there with its cost measured first.

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
- A puzzle on the flat board takes the game's corner panels in landscape too
  (2026-11-11), replacing its panels as tall as the board, which no screen uses now: the
  two screens looked unrelated, settings far from start over. Its play panel is as tall
  as what it holds, 504 dp, not the game's 352, at which the piece went beside the goal
  and next shrank.
- Landscape panels narrow to 192 px where the board would be under 720 px (2026-11-08).
  Rows are 88 px, the floor for small hands (2026-11-08). Portrait's bar tiles take each
  word's width and an even share of the rest where thirds don't fit (2026-11-08).
- The child's pieces are at the bottom against the computer, the board turned when the
  child plays black (2026-11-08).
- A tile's icon and word are centered on it, side by side or stacked, on every tile
  (2026-11-11). This replaces the landscape column's left-aligned layout (the icon 14 dp
  from the left, `gui::BESIDE`) for settings, start over, and the hint: under back, which
  was already centered, they looked misaligned.

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
- Continue's note says whose game it goes back to, "A friend" or "The computer · easy"
  (2026-11-11, issue 1, `prototypes/issue-1.html` take a). The row isn't shown while the
  game is one nobody set up (none kept: a fresh install, a new player) with no move
  played, as Quit isn't where it doesn't fit (2026-11-12, take b; it replaces a's dim row
  of 2026-11-11, which the user found weaker than none). Whether the game was set up is
  kept with it (`Saved.unset`, version 4), so a restart doesn't bring the row back; a
  version 3 image still reads, as a game set up, until that reading is dropped.
  Rejected for now: continue going back to a puzzle too (c), which the shell doesn't
  track and Puzzles already reaches.
- The X closes the app (`exit.html`'s take b, chosen 2026-11-08 as a round glass button;
  made a bare X, `gear.html`'s `x=d`, on 2026-11-09 to match the bare gear). Rejected: a
  quiet last row, which would take the portrait board's room and lengthen the sheet
  phones can't fit; a door, which reads less surely at 34 dp; and a power sign, which
  suggests turning the tablet off.
- On a desktop's landscape column the way out is a last row, Quit, under settings
  (2026-11-11, task 072), narrowing the decision above against a last row: a desktop's
  window is where a quit in the menu is expected, the landscape column has room for it,
  and a row is reached by the arrow keys in the menu's order where a corner X is not.
  The X shows only where the row doesn't (the portrait sheet, a column too short for it,
  a touch screen), as settings is the gear or a row, never both. Rejected: the row in
  the portrait sheet, for the reason above; both the row and the X at once.
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

- No draughts row (2026-11-11, issue 1, `prototypes/issue-1.html` take a): home's setup
  and the puzzles' library each choose the draughts, and here it read as if it changed
  the game in progress. The preview shows the player's draughts. Rejected: the row kept
  as "Draughts for new games and puzzles" (b), a third way to one choice; shown read-only
  as the game's (c), a row that takes no tap among rows that do.
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
- In landscape the groups go under the title row, the room left below them (2026-11-11),
  not centered down the column: on a large desktop window, with room to spare, they
  floated in its middle; the tablet's moved up a few dp.
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

### The lookout and the hint

`prototypes/coach.html`, round 3, take a, chosen 2026-11-09. In compact, the hint and undo
move go to icons alone with clocks and where the words would leave whose turn too little
room, for Estonian's undo move (2026-11-10).

### What each side has taken

Task 052, `prototypes/game-captured.html`'s take a in its `row` look, chosen 2026-11-09.

### The moves panel and the results screen

Task 074, `prototypes/history.html`, 2026-11-11 (proposed, the user to choose):

- The moves panel under the play panel in landscape (take a), where at least four rows
  fit: the play panel and the way out stay as built. Take b (under the left panel) had
  290 dp beside what each side has taken; take c (the play panel grown) moved hint and
  undo to the column's foot.
- On the 3D board the panel is five rows, as wide as the play panel, with the camera's
  buttons in a row under it; the board clears both as it clears the panels, about 11%
  smaller at the tablet's landscape. With the setting at off the board is as before.
- No panel in portrait or on a phone in landscape yet: the prototype found under four
  rows' room there.
- The panel scrolls through the whole game (2026-11-12): showing only its last five
  rows on the 3D board left no way to see the rest (the user). On a desktop it runs on
  where that costs the board nothing, and the 3D frame widens to 2.0 while it shows:
  the board was cut by its zoom or shrank while the window had room at the sides.
- The setting is a Move list row in settings' game group, under move hints (2026-11-12),
  since issue 1 took the draughts' row out; it replaces the results screen as its place
  (2026-11-11, when a third row there left the preview board at 0 dp at several sizes).
  The tablet's settings are unchanged; where the game group shows alone its board is
  smaller: a 16:9 phone in portrait 366 to 248 dp (282 to 163 with insets), the 4:3
  tablet's landscape 402 to 305, a foldable's 373 to 242; a 20:9 phone at 540 dp, none.
  The results screen keeps its three tiles too until the user has seen both.
- The results screen is a row on home's menu (2026-11-12; the user: nobody would look in
  the players' card), and stays a tile beside the pencil in who's playing. Where the row
  would cost the board its size, the menu keeps its height and scrolls, the next row
  showing faded at the foot, rather than shrinking the board (on the iPhone 13 mini
  310 dp to about 220). Replaces 2026-11-11's who's-playing only. A screen with no inset
  at its foot gives up 28 dp of board so the next row's word shows (a tablet in
  portrait, 479 to 451 dp).
- The results screen is named Results, Tulemused in Estonian (2026-11-12): Games, Mängud,
  blurred with home's rows that start a game. A Gemini review of the Estonian picked it
  too; History (Ajalugu) left out the rating, Statistics was dry for a child, and Progress
  (Areng) read as a school report. Its string keys are `results.*`.
- Before the first move the panel says "No moves yet", "Käike veel pole" (2026-11-12,
  the user, after GoDraughts' panel), dim where the first row will be. It replaces row one waiting, from
  earlier that day (its number and a faint glow where the first move would stand), which
  read as an empty stub. Rejected: no panel until the first move (the board would shrink
  and shift as it is made).

### Board and pieces

**The flat board**

- The lip, the pieces' flat tops with one groove, and the wood theme's warm tones and calm
  grain follow the close-up boards chosen on 2026-11-07, which read better than the first
  design boards' frameless board and two-ringed pieces.
- Kings in a 3D board are a stack of two plain discs, as kings are in Estonian play
  (2026-11-07). A stack's selected or must-capture ring goes round its foot (2026-11-08).

**The 3D board**

- The game screen round it, `prototypes/game3d.html`'s `corners` (2026-11-09). The flat
  game takes the same panels (task 054).
- The portrait camera at 65° down (2026-11-09), and the camera buttons,
  `prototypes/game3d.html`'s placement `a` (2026-11-09).
- The pieces' occlusion of the field into a map only where squares changed (task 059):
  a texel a field pixel reads instead of the loop; the dropped bake drew shadow and
  occlusion with every shadow map.
- A dark king's crown gold (`#e9c46a`) on the 3D board too, as on the flat one, rather
  than the look's crown color, a deeper tone of the piece that was hard to see on the
  dark kings on the tablet (2026-11-12).
- The crown into a 256² map drawn once at setup (task 059): evaluated three times a pixel
  for its slope, it was a third of a frame with 16 kings on the Pixel 7a.
- The renderer's backdrop kept as an image (task 059): its grade each frame was 7% of the
  Pixel 7a's GPU cycles.
- With the plain fade, the board's ambient is scaled to the dim ambient a theme without a
  photograph had: the look the Galaxy A33's build without photographs showed, which the
  plain background comes from.
- Getting ready a step a frame (task 042). The old image eased toward grey while a new
  theme bakes (2026-11-09).
- Spring's default 3D look is `looks::elven`, chosen on the tablet on 2026-11-09. The
  defaults of `--wood`, `--marble`, and `--summer` were settled the same day (task 039),
  the other models kept beside them.
- Against a friend the board's 180° turn keeps its size and eases on a sine over 0.7 s
  (2026-11-12, tried on the tablet). It was a cubic ease, refitted at each angle: it
  crept, then swung through the middle at 390° a second while shrinking to keep its
  corners clear of the panels and growing back, which drew the eye. Fitted as at rest,
  its corners pass over the panels for a moment. 1.1 s and 0.8 s were tried and felt
  long once the size held still.
- A friend's game doesn't turn the board by default, on either board, and on the 3D
  board begins in the top view, zoomed (2026-11-12, the user). Two players sit at either
  side of the tablet, so a board that turns every move makes the far one watch it spin,
  and the top view reads alike from both sides where the angle at rest favours the near
  one. Turning is settings' Turns with a friend, a third tile in the Board row, which
  adds no row (a third row in the game group had left the preview board 0 dp at some
  sizes, above); on a 20:9 phone at 540 dp the wider Board row puts settings in its two
  tabs, its board 237 to 447 dp. Rejected: a fourth camera button for it, which every
  layout round the 3D board would have had to make room for in friend games.
  Replaces the turn on every friend game on the 3D board, from task 015.

**States and captures**

- Prototype `game.html?count=a`'s pips for a capture's count. Rejected: take b, a badge
  with the number, which needs a child who reads digits.
- Before 2026-11-09 nothing said how far a capture went (reported 2026-11-09: a child's
  lone king on the turned board with a capture of four), and then the 3D board drew no
  pips, as its scene never read `ring.z`; both fixed that day. The count shows on mistakes
  only from a mistake while a capture is due (2026-11-09); it showed whatever the hints
  before, which gave the capture away.
- The must-capture pulse ends once a move is played (2026-11-09). It ran on through the
  move and rang the next side's capturers, so after a child's capture on the turned board
  the computer's man beside the child's pieces pulsed red as if it were the child's to
  move (reported 2026-11-09, two pieces each taking one).
- A capture of many jumps is never played by itself in a game either (2026-11-09). Until
  then a game played a capture once only one went on from the stops made, so a child whose
  first jump played the whole of it never learned the way. Before that (reported
  2026-11-09, International, a black man's capture over a far-row square it only passes,
  the board turned), the piece went back to its square with the stop ringed, and picked
  up again it forgot the stop: dropped, such a capture was made only by its last square.
- The 3D board lights a missed capture's next stops (2026-11-09); it never showed them
  before.
- A puzzle's board makes captures by hand with none of the game's help (2026-11-08).
- Issue 1 (2026-11-11), the board's taps:
  - A capture made stop by stop may take any of its ways (`rules::ways`), not only the one
    the move list keeps for each end and pieces taken: a king's other way was a miss and
    cost a puzzle's stars. The move plays along the way tapped.
  - An empty square the piece passes on its way to a next stop (a king's flight, or
    squares past a jumped piece before the one it must land on) is no stop and no mistake:
    a tap there does nothing (`board::passes`). Rejected: moving the piece there, which
    the rules don't have as a stop.
  - A last square further on plays the capture when every way going there takes the same
    pieces, one move whichever way, as before (2026-11-12: the user kept that; a stricter
    rule of one way alone, tried on 2026-11-11, is dropped).
  - A tap on a stop shows the piece hopping there over the move's hop (`board::hop`); it
    jumped before, on both boards (the issue saw the flat one, where taps are the way;
    the 3D board fills from the same lists). A drop needs none.
  - A tap on the selected piece puts it down (released without a drag), as Enter on it does. A tap on a piece
    waiting on a stop still does nothing, so a child who taps the piece before each jump
    keeps the stops.

## Fonts

Libertinus Sans, the face of a reference liked for its look (arXiv 2611.07289), in the
style of Optima. Tenor Sans, Belleza, and Marcellus were compared with it in Estonian
text; all four have õ ä ö ü š ž. Tenor Sans, which the proof of concept uses, is the
runner-up: clean and wide, but one weight only. Marcellus has small serifs, further from
Optima. If titles want more character, Tenor Sans could set them and Libertinus the rest;
one face is the default, for one atlas.

The title and the figures hold only their characters, as those two faces were 71% of the
atlas's area with every glyph. With one byte a texel and only the rows used, the texture
went from power-of-two RGBA to R8:

At 1024 texels wide, the texture's size by scale:

| Screen (scale) | Before: every glyph, RGBA, power of two | R8, the rows used |
| --- | --- | --- |
| A 720 × 1280 phone at low density (0.9) | 1024 rows, 4 MiB | 261 rows, 0.25 MiB |
| The Galaxy tablet; a 720 × 1280 phone at xhdpi (1.5) | 2048 rows, 8 MiB | 630 rows, 0.62 MiB |
| The Pixel 7a (1.97) | 4096 rows, 16 MiB | 1023 rows, 1.0 MiB |
| 2880 × 1920 (2.4) | 8192 rows, 32 MiB | 1482 rows, 1.45 MiB |

## GPU memory

Large allocations are their own size (`patches/SDL/0003`). Upstream rounds them up to
64 MiB blocks that later large resources share: on the tablet the screen (9.6 MiB) and
the photograph (16.3) would take a whole 64 MiB block.

`gfx::flush()` between short-lived small resources took the tablet's GL mtrack at home
from 60.7 to 36.4 MB, and after three season changes from 57.3 to 40.9.

Exact allocations, not rounded to 4 or 8 MiB (2026-11-08): the count of allocations is
  the same either way, one per large resource, and rounding wastes half a step each on
  average (about 10 or 22 MiB on the tablet). It would pay only if a freed block were
  kept and taken by a later resource of nearly its size, but SDL makes the new screen or
  photograph before it releases the old one, so the old block is still in use when the
  new one wants it; and keeping freed blocks for reuse is how a large block stays alive
  for a small tenant, the 64 MiB blocks' trouble. A smaller fixed block shared as
  upstream does (16 or 32 MiB) still needs its own for anything larger (the largest
  tablet's screen, a 3D MSAA target) and stays alive while any tenant lives; SDL has no
  `VK_KHR_dedicated_allocation` plumbing, and an exact plain allocation already gives
  the memory back.

Not done: drawing straight into the swapchain, dropping gfx's screen copy, which would
save only the screen's 9.6 MiB for a large gfx patch; and halving the computer's worker's
tables, which would save about 3 MB, not worth checking what it costs in strength.

Giving back what malloc keeps after the launch (`mallopt(M_PURGE_ALL, 0)`) took the
native heap at home from 42.6 to 26.7 MB.

The 3D bake stopped clearing its four surfaces (2026-11-09): each had kept a cycled second
copy, 85 MB on the Pixel 7a.

The 3D board gives back what only drawing it needs at rest (task 071, 2026-11-11): the
pass's targets, the kept backdrop, and the kept depth, a second after the pass last drew.
The 3D game at rest in winter: the Mac (1280 × 800 window) 356 → 225 MB on gfx and 311 →
226 on ngfx; the iPhone 13 mini 243 → 152 on gfx and 223 → 160 on ngfx. The cost is the
first draw after a rest: +4 ms on the M1 Pro, +13 ms on the iPhone (one 60 Hz refresh
late, at the start of a response, never inside an animation). A second, not at once:
a hover or a drag draws again within it. A flat marble frame's normal map, constant,
is a 4 × 4 (22 MB). Not done: the plan's normal as RG8 (it would need a second bake
pipeline, the frame's normal uses all four channels), the plan and frame maps without
their top level (the anisotropic filter samples it on the tilted board), the photograph's
two 512² working copies (2 MB). Apple's memoryless storage for the MSAA targets would
remove them for good without the first draw's cost, but SDL picks the storage mode, not
gfx.

gfx keeps 4× MSAA as the 3D board's antialiasing, and SMAA stays a choice for comparing
(`--aa smaa`, the A key; task 071, 2026-11-11). The two look alike: SMAA differs from
MSAA by 4 to 5 of 255 at the edges and by 0.1 elsewhere, and side by side at 4× on a
27" screen neither was clearly better. MSAA is the cheaper on every GPU measured: at full
screen on the M1 Pro 3.05 ms of GPU a frame against SMAA's 3.49, and on the Pixel 7a's
Mali 11.4 ms a frame waited against 12.5 (none: 11.5), where 4× MSAA stays on the tile
and SMAA's three passes each store a full-screen target. SMAA's one gain, half the
pass's memory while drawing (49 MB against 98 at 2560 × 1600), mostly went with the
targets given back at rest. The ngfx build keeps SMAA, as goose-ngfx has no MSAA.

## The 3D board on devices

The measurements as they were taken, kept here as the architecture keeps only the
current ones. Taken with the app's `--bench 300`, `scripts/idle_cpu.sh`, and
`dumpsys meminfo` on 2026-11-09; the three Android devices again on 2026-11-10 with
`scripts/device_perf.sh`, the release built from 1aaf406; the iPhone with
`scripts/ios_perf.py`, its development build from 1c25f33, the same app code with
`--rest`. The tablet again from 4d50eb2's release, after task 059 (its 3D memory 30 MB
more: the kept backdrop and UI layers, 9 MB each, and the occlusion and crown maps). The
release's frames and the idle table were taken on 2026-11-10.

Measured with the app's `--bench 300` ([development](../development.md#time-the-3d-board)),
idle with `scripts/idle_cpu.sh`, memory with `dumpsys meminfo` at rest (2026-11-09; the
three Android devices again 2026-11-10 with `scripts/device_perf.sh`, the release built
from 1aaf406; the iPhone with `scripts/ios_perf.py`, its development build from 1c25f33, the
same app code with `--rest`, which counts its own CPU time and footprint). The tablet
again from 4d50eb2's release, after task 059 (its 3D memory 30 MB more: the kept
backdrop and UI layers, 9 MB each, and the occlusion and crown maps).

The release at rest, idle 20 to 30 s:

| Device | Board | Idle program thread | GL mtrack | EGL mtrack | Total PSS |
| --- | --- | --- | --- | --- | --- |
| Galaxy Tab A11+, 1920 × 1200 | 2D, a game | 0.04 to 0.08% | 37 MB | 55 to 60 MB | 133 to 141 MB |
| Galaxy Tab A11+ | 3D, a game | 0.28 to 0.32% | 210 MB | 32 MB | 295 MB |
| Pixel 7a, 2400 × 1080 | 2D, a game | 0.08% | 45 MB | 73 MB | 159 MB |
| Pixel 7a | 3D, a game | 0.04% | 215 MB | 73 MB | 324 MB |
| Galaxy A33 5G, 2400 × 1080 | 2D, a game | 0.04% | 35 MB | 43 MB | 116 MB |
| Galaxy A33 5G | 3D, a game | 0.04% | 197 MB | 29 MB | 275 MB |
| iPhone 13 mini, 2340 × 1080 | 2D, a game | 0.08% | | | 59 MB footprint |
| iPhone 13 mini | 3D, a game | 0.08% | | | 204 MB footprint |

- **The tablet's frame** while the board moves (the first baseline, 1920 × 1200 at 90 Hz):
  the forward pass alone 10.9 ms at 1×, the whole budget; MSAA 4× adds 3.2 ms (6.3 ms
  and 72 MB more without `patches/goose_gfx/0005`, which keeps the samples and the depth
  from being stored); the shadow map 2 ms on the frames that draw it; the CPU's part
  about 0.4 ms. It renders as the Mac does. After task 042's cuts (2026-11-10): the
  frame with the shadow map, as while a piece moves, 10.5 ms waited, the pass alone
  (the camera turning) 9.9, presented 12.8 ms frame to frame; 90 Hz kept. The release, 2026-11-10, 1000 frames: waited P50
  10.6 / P99 12.7 ms, the pass alone 10.0; the compositor counts 17% of the frames on
  screen for two refreshes, 78 fps on average, 45 at the 1% low (task 055). The flat board's
  whole frame (`bench2d`) 10.2 ms waited, and no frame dropped (`scripts/device_perf.sh`).
  After task 059's four changes (2026-11-10, debuggable test builds of fab1757 and c7d23bf
  beside the app, two runs each): waited P50 10.6 to 10.9 → 9.2 to 9.4 / P99 12.8 to 12.9
  → 10.9 to 11.2 ms, the pass alone 10.0 to 10.3 → 9.0 to 9.1, presented 12.9 → 11.0 ms
  frame to frame; the compositor counts 90 fps at the 1% low and no frame dropped (17%
  before). With 16 crowned kings 12.2 → 9.0 ms waited, 31% dropped → none. The release
  from 4d50eb2, 1000 frames: waited P50 9.22 / P99 12.13 ms, the pass alone 8.96, 90 fps
  on average and at the 1% low, none dropped; the flat board's 9.39 ms waited, none dropped. The GPU's clock
  stays near its top (1047 MHz) in both, so the frame times show the work. Baking the
  field's shadow and occlusion into a map with the shadow map was dropped
  (2026-11-09): it took the camera's turn to 8.4 ms but every frame that draws the
  shadow map to 11.5.
- **The Pixel 7a** (60 Hz): the pass 14.0 ms waited for International, 13.0 for Russian,
  presented every 16.6 ms; 2026-11-10, 1000 frames: waited P50 13.5 / P99 16.0 ms, and the
  compositor counts 1 of 995 frames on screen for two refreshes (the flat board's none, its
  frame 11.8 ms waited); the theme applied at launch in 0.76 s (the bake, its
  pipeline made), the first frame 0.31 s.
- **The Galaxy A33** (90 Hz, thermal status 3): the pass 36 ms waited at first, about
  28 fps while the board moves; after the frame cost's first cuts the pass 19.3 ms and
  about 39 fps (25.7 ms frame to frame); the theme applied in 1.66 s, the first frame 0.35 s. Its Mali-G68 lost the device
  on a texture's mip level 0 pixels high ([findings](../goose-findings.md)); the bake's
  mips now end at the shorter side's 1 pixel (`render3d::baked`). 2026-11-10, 1000
  frames: the 3D frame waited P50 23.2 / P99 26.0 ms (the pass alone 17.1), on screen for
  two refreshes every other frame, a steady 60 fps; the flat board's 15.6 ms waited, and
  no frame dropped.
- **60 Hz for a slow 3D board** (task 056): on Android, once 60 frames of the ready 3D
  board average over 1.25 refreshes of a display faster than 60 Hz, the app asks for 60
  Hz on its surface (`ANativeWindow_setFrameRate`, `src/app/display.c`) whenever the 3D
  board draws, and for the display's own rate otherwise: 60 frames on a 90 Hz display
  show two refreshes and one in turn. A device that holds its display's rate keeps it.
  The Galaxy A33 ignores it: its "High" motion smoothness holds 90 Hz whatever an app asks.
  The tablet's frames fit its 90 Hz since task 059 (they averaged about 1.15 refreshes
  before, and it kept 90, chosen over an even 60); the Pixel 7a's display is at 60 already.
- **Where the moving 3D frame goes** (task 059, Streamline on the Pixel 7a, after its
  four changes): GPU active 7.01M → 4.70M cycles a frame, fragment-bound (the tiler 3%
  of the GPU's time), not bandwidth-bound (0.6 GB/s), little overdraw. The lit fragment
  shader still holds 64 registers (half occupancy on the G615). The UI's live cost was
  1.45M cycles a frame, 24%, paid only when the UI changes now that it is kept
  (`widgets::prepare`), and the backdrop's grade 0.43M when it changes; after task 063
  the two together 1.54M → 0.99M (the moving 3D game with `--keep off`: 6.76M → 6.21M a
  frame, 5.22M kept), the UI's part about halved. Ranked and not yet tried: the pieces' shadows on the field analytic (a disc's stadium along the light) in place
  of the shadow map's pass and its 9 taps on every lit pixel; fp16 for colors, the
  harmonics, the tonemap, and the varyings (no shader uses 16-bit yet); MSAA 4× read
  again at 2,208 triangles a piece; a lower render scale for the 3D pass, last.
- **Open:** at rest the tablet's 3D board spends about 2.7 ms CPU a wakeup against the
  flat board's 0.3, outside the app's own work, as the Mac shows no draw at rest.

## When a frame reaches the screen

goose_gfx records a frame and its blit into the window's image in one command buffer.
Submitting the frame before the wait and the blit apart was measured worse: the window
has 3 surfaces and the compositor holds two, so the blit waits for one and the frame
after it for the blit.

## Frames and battery

- The idle table and the Mac's and Windows' footprints were taken with `--rest 25` on
  2026-11-10.
- A drop that leaves a piece waiting draws the frame after too (2026-11-08): a puzzle's
  next stayed dim on the Pixel 7a, as a drop is a finger's last event.
- The wake timer for a running clock (2026-11-08): measured on the tablet, the clock was
  drawn 6 ms later each second, up to a second late, and skipped a second every two and a
  half minutes.
