# Rendering decisions

The decisions behind drawing, the UI, the look, the 3D board, and frames, dated, with
their reasons, what they rejected, and the measurements behind them. The headings follow
[Architecture: Rendering](../architecture/rendering.md), which says how it works now.

## Drawing

The screen's pass has no depth target, and in the Android build gfx never cycles the
screen (the fork's `screen-without-depth`). Together they kept SDL from a second 64 MiB block after
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

On 2026-11-13 the prototypes were cut to one plain page per screen as built, a base to
copy for a new idea, because the takes, switches, and option panels had piled up and made
the pages slow and buggy. Every take these decisions name (`badges.html`, `boards.html`,
`coach.html`, `first-start.html`, `game-captured.html`, `game3d.html`, `history.html`,
`issue-1.html`, `plain.html`, `profiles.html`, `puzzle-set.html`, and the takes and
parameters of the old `game.html`, `home.html`, `settings.html`, and `puzzle.html`) is
in git history at 086f47d.

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
- Fullscreen by Alt and Enter or F11 (2026-11-12), the keys Windows' and Linux's games
  and browsers use, borderless at the desktop's resolution (the fork's `set_fullscreen`),
  so switching changes no display mode. Enter with Alt is fullscreen's only, not a press
  as well. A setting for it waits (task 064).
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
  On Windows (2026-11-12) nothing outside the program says a pad was used (an Xbox pad's
  XInput can only be polled, and SDL reads a PS5 pad's reports in its own update), so
  goose_gfx's idle wait reads the pads every 16 ms while the window has focus and ends
  the wait only on a press or a stick moved a quarter of its way (the fork's
  `gamepad-idle-wait`, since folded into `gamepad-wake`): 0.4 to 0.6% of a core idle with a PS5 pad, the loop waking once a
  second. Rejected: the loop waking 30 times a second to read it (4.3%: each wake runs the
  whole loop); the same wait on Apple's systems and Android, where the system wakes the
  loop for nothing.
- goose_gfx owns the gamepad (2026-11-12), and `src/app/pad.c` is gone: this replaces
  2026-11-11's gamepad in the program's C, and the program's half of the entry above
  (its hints, its reads, its event watch, its GameController handler). The fork's gfx
  already opened the pads and read them in its idle wait, so the pad was read twice. Now
  gfx reads them each frame on every platform and keeps a press let go between frames
  as its edges; its idle wait reads them every 16 ms unless the system wakes it, which
  it does with the open flag `SYSTEM_GAMEPADS` (the fork's `gamepad-wake`): SDL's HIDAPI
  off on Apple's systems and Android, and on Apple's a GameController change handler
  ending the wait when a button changes or a stick leaves or comes back to the middle.
  `host::keys` reads gfx's gamepad functions, declared in `keys.goose` as the release's
  `gfx.goose` lacks them, and keeps the stick as the D-pad and its hysteresis: a menu's
  wish, not gfx's, as a game reads the stick as a stick. The flag isn't gfx's default
  either: the system's drivers know fewer pads and give less of them (a PlayStation
  pad's touchpad, motion, and light bar), which a game may want; without it the 16 ms
  read works everywhere for about 0.5% of a core. Windows idle with a PS5 pad, `--rest
  25`: 0.56%, the loop waking once a second, as before.

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
- On a desktop, quitting asks first (2026-11-12, the user): a card over home dimmed,
  "Quit Draughts?" with cancel and quit, quit the keys' first choice, for Quit, the X,
  and Escape or a gamepad's B on the menu, which had closed the window at once and was
  easily pressed by a gamepad going back. It narrows the X's "at once, asking nothing" to
  touch screens, where the X sits apart in a corner, Android's own back doesn't ask, and
  the game is kept anyway. Rejected: asking on touch screens too, a dialog for a child
  who meant to close it.
- A desktop's menu rows stand 56 dp under the wordmark rather than 34 (2026-11-12, the
  user): at a desktop's smaller scale 34 read as the rows crowding the title.
- The board keeps 40 dp above and below, down to 24 where a setup's tall sheet near
  square would leave it under 40% of the width (2026-11-08).
- The setups (2026-11-08): the child's colour against the computer, every tile 88 dp tall
  at least, two columns in a landscape too short for one, ending on one line, the
  draughts' tiles taking their names' width with an even share of the rest, and the
  setup's board switching at once rather than crossfading. Easy is the default level for
  a new player (2026-11-09).
- The language is only in settings (2026-11-07): kids who can't read yet don't need it on
  home, and a tablet set to one language can still play in another.
- One New game row, the opponent chosen in the setup (2026-11-13, task 080,
  `prototypes/new-game.html` take c). It replaces the A friend and The computer rows of
  2026-11-07 and the setups of 2026-11-08: a friend's game on a tablet is rare (it was the
  only way to play before the computer player), and two rows made the rarer choice as
  prominent as the common one. The setup's first row is whom to play, A friend, Easy,
  Medium, Hard, the computer's level folded into it, so the two opponents' setups have
  the same rows (the pieces, or the board's turning for a friend) and the column never
  jumps; the opponent is kept (`opponent = friend|computer`), so a child who always plays
  the computer taps New game and Play. New game notes the kept opponent, as the
  computer's row noted its level, and is outlined under Continue, lit in its place on a
  first run. The column widens to 400 dp so the four tiles are a tap wide each. Where it
  is too short, the choices scroll with Play pinned under them, and in a phone's
  landscape Play moves into the head row in the title's place: it replaces the two
  paired columns of 2026-11-08, which a 400 dp first row doesn't fit. Rejected: take a,
  an Opponent row of its own over the level's, which made the column overflow the
  tablet's landscape; take b, the opponent as a two-part switch in the head row beside
  back, crushed on a phone's landscape where Play needs that row.
- Whether a friend's game turns the board is the setup's (2026-11-13, task 080), its
  last-but-one row for a friend, Stays "for both" or Turns "to who plays", Stays the
  default as before and, since 2026-11-13 (the user), the first of the two. It replaces settings' Board row's third tile (2026-11-12): the
  turning is a choice about that game, not a look, and in settings it read as if it
  always applied. The setup's board turns once round when Turns is chosen, as settings'
  preview did. Settings' Board row is flat or raised again, which on a 20:9 phone at
  540 dp in portrait puts both groups back on one page (the preview 228 dp) where the
  wider row had needed the tabs.

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
- One list that scrolls, no tabs (2026-11-13, task 080, `prototypes/settings-takes.html`
  take b): Look (Background, Theme, Board, Kings), then Game (Move hints, Move list), then
  the privacy note, under back, the title, and the language pinned above it, fading at its
  foot as home's menu does. In landscape a 480 dp column at the left whose glass runs off
  the screen's edge, the preview the rest; in portrait the preview a band at the top, 40%
  of the height on a tablet and 30% on a phone, the list under it. It replaces the two
  glass groups (2026-11-07) and every layout made to fit them: the names at the tiles'
  left, the groups side by side, the phone's Game and Look tabs (2026-11-09), the slim
  theme tiles of a small window, the look group's glass ending over a bottom inset, and
  the preview levelled with the game group on a desktop. A list
  that scrolls where scrolling is plain to see packs nothing behind tabs, and the preview
  needn't be large to show the look. Rejected: take a, a Material row under Board shown
  only while the board is raised, a row that comes and goes; take c, the seasons' tiles
  as their boards with a material per season, which hid the photographs the theme is
  chosen by.
- The board's material folded into the Board row (2026-11-13, take b): Flat, Raised (the
  season's own, tagged "auto"), Wood, Stone, Carved, each a picture of the theme shown's
  board, the materials' pictures its near left corner close up (a frame's grain or
  carving, where the whole board at 76 × 50 dp showed none), Raised's whole to set it
  against Flat. No row that means nothing on a flat board.
- The photograph or the plain fade is a Background row of two pictures, first in Look
  (2026-11-13), replacing the switch beside the theme's name (2026-11-09) and its
  halves under the 88 dp floor in a name's column.
- The language is a button in the title row, the globe as it was (`GLOBES.a`), its code,
  and a chevron, opening a small list (2026-11-13). It replaces the languages' tiles on
  glass in the title row (2026-11-07), which took its width from the title as languages
  are added, and a Language section at the list's foot (the prototypes' `langui=foot`),
  out of sight below the fold. Tried in the app the same day and set back: a wireframe
  globe (`GLOBES.b`), a languages icon after Lucide's (`GLOBES.f`, a glyph and an A), and
  the Earth (`GLOBES.c`, a ring round three continents). Rejected in the prototype: the
  codes as two tiles in the title row (`langui=seg`), a globe in a ring (e), a speech
  bubble with an A (d), and the glyphs in two bubbles (g) or with arrows between them
  (h).

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

### How to play

Task 026, `prototypes/tutorial.html`, 2026-11-13 (replaces task 019's first start,
`first-start.html`: which draughts, learn the moves or just play, then the tutorial, on
pages of their own before home):

- A new player is asked "Do you know how to play?" right after their sheet's done, on
  the card (take a), with two answers: Show me and I know how. The tutorial teaches the
  player's own draughts (International for a new one) rather than asking which first
  (take b put the setup's draughts row on the card, take c a card of its own after Show
  me): one question, and the library's switch reaches the others. A fresh install's first
  player is asked the same way, so there are no pages of a first start apart from it.
- How to play lives in two places (entry b): lit in continue's place on home while a
  player asked hasn't learned their draughts, nor said they know how, nor begun a game,
  and always as the puzzles' library's first row, across the columns. A row on home
  always (entry a) cost a row for something done once; the library alone (entry c) hid
  it from a new player. Settings' tutorial row, taken out on 2026-11-09, doesn't come back:
  the library's row, switched by draughts, is it.
- Each step is played on the board, the moves shown, and next lights once it is played.
  The first step has the other side answer and the child move again, so the turns show. The end hands over to the puzzles' Learn theme or a new game.
- The icon is a finger tapping with a ring over its tip (take `tap`), chosen over a
  piece's dotted path, the diagonal arrow, a graduation cap, and a question mark: it is
  the gesture the steps ask for, reads without words, and isn't the Learn puzzles' book
  nor the hint's bulb.
- Russian draughts' tutorial has its own steps where its rules differ: any capture may be
  chosen, and a man crowned in the middle of a capture goes on as a king.

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
- Who's playing loses its tile of three rising bars (2026-11-13; the user: it makes no
  sense there now): the games are home's row, at every size, and the card is about who
  plays. Replaces 2026-11-12's tile kept beside the pencil.
- The results screen is named Results, Tulemused in Estonian (2026-11-12): Games, Mängud,
  blurred with home's rows that start a game. A Gemini review of the Estonian picked it
  too; History (Ajalugu) left out the rating, Statistics was dry for a child, and Progress
  (Areng) read as a school report. Its string keys are `results.*`.
- Before the first move the panel says "No moves yet", "Käike veel pole" (2026-11-12,
  the user, after GoDraughts' panel), dim where the first row will be. It replaces row one waiting, from
  earlier that day (its number and a faint glow where the first move would stand), which
  read as an empty stub. Rejected: no panel until the first move (the board would shrink
  and shift as it is made).
- "No moves yet" is centered, in the panel across its first row and in a phone's moves'
  line, and the line has no chevron and takes no tap until the first move (2026-11-13,
  the user: the arrow opened an empty list). Replaces 2026-11-12's words at the left.
- The moves' line in landscape and the moves panel have a head, "Move list" over a
  rule, the line's with its chevron at the right (2026-11-13, the user's pick of three
  tried on the Mac). It replaces the chevron alone in the line's top right corner, which
  sat apart from everything in it. Rejected: the chevron beside the last move (the
  rows lost its width, and white's mark ran into black's move).
- In landscape the way out's three tiles stand alone, each on its own glass, as wide as
  the column, 12 dp apart (2026-11-13, the user: back stood wider than the two in the
  panel under it, and those looked lighter). It replaces 2026-11-09's back over a panel
  of settings and start over; back is still the same control in the same corner on
  every screen. The column is 288 dp, not 336. A phone's moves' line has the same glass.
- A tile standing without a panel (back on every screen, the way out in landscape, the
  moves' line) sits on glass's tint alone, `gui::under_tile`, with no border, highlight,
  or shadow of the glass's (2026-11-13, the user: such tiles looked too glassy). On full
  glass it was edged twice and shadowed twice; now it looks as a tile on a panel does.
- A panel only where it holds what isn't a tile (2026-11-13, the user): the portrait
  bar loses its panel, its three tiles each on glass's tint as in landscape, the game's
  row under them (what each side has taken, the moves' pill) a strip of glass of its
  own, 42 dp, showing once it holds something. The bar is 32 dp shorter: the 4:3
  tablet's portrait board grows from 670 to 710 dp, a foldable's from 586 to 626; the
  others move up. A small window's compact bar keeps its panel, its icons and catches
  sharing it.
- The moves panel stands under the way out on a tablet and a desktop (2026-11-13, the
  user: the screen was right-heavy, and moves usually sit at the left), 16 dp under its
  tiles, 24 on a desktop. It replaces task 074's take a, the panel under the play panel;
  take b, rejected then for its 290 dp beside what each side has taken, has the column's
  freed 48 dp now. What each side has taken goes under the play panel on the flat board
  while the moves panel shows, and the 3D board's camera buttons stay a column at the
  right, so the board is larger (the tablet's 802 to 832 dp across in the transition).
  A phone keeps its moves' line.
- On every touch screen in landscape, a tablet's as a phone's, the way out is back and
  settings side by side over start over, each its icon over its word, a column 204 dp
  tall (2026-11-13, the user: the board fits better). The desktop keeps the three under
  each other, its tiles shorter. With the moves panel the tablet's 3D board is about
  861 dp across, 898 without it, where the three under each other left 830.
- A tablet squarer than 3:2 in landscape (4:3, a foldable) takes a phone's narrow
  panels, 192 dp, on the 3D board (2026-11-13, the user: its board looked small). Its
  board is held by the width between the panels, not the height: 4:3's grows from 693
  to 762 dp, a foldable's from 628 to 697. Measured and set aside: the play panel only as
  tall as it holds (+6 dp) and the camera buttons in a row (none). The camera buttons
  keep a tablet's size.
- There the moves panel stands above the 3D board (2026-11-13, the user: tons of room
  there), between the corner panels and level with their tops, down to the board at
  rest, which keeps its size, at least three rows; what each side has taken shows as
  counts at its head's right, as a phone's short moves' line has them. Where three
  rows don't fit it goes under the way out as on other tablets. It stops a row short of
  the board at rest where the top view's board reaches higher (2026-11-13, the user), so
  that view shrinks less; sized to clear the top view entirely, it fell back to the left
  on 4:3.
- In portrait the camera buttons are always a row at the right edge under the board
  (2026-11-13, the user: a column there, beside nothing, looked like wasted space). It
  replaces a column wherever the board kept its width beside it; the board keeps its
  size, the screen's stack centered down the safe area 32 dp higher or lower.
- The move list's setting is settings' alone (2026-11-13, task 078; the user: once is
  enough), replacing 2026-11-12's three tiles kept on the results screen too. There its
  words alone (Off, Moves, Marks) didn't say what each shows, so a line under the
  chosen one says it ("The moves, each marked by how good it was"), in the small face
  and dim as the privacy note: beside the tiles, centered down them, where the group's
  width leaves room (the look's rows are wider, so most landscapes), else under them.
  Under them always cost the stacked landscapes their preview board (the tablet's
  242 to 137 dp), so beside is first. The results screen's freed panel shows the levels'
  results on a phone in landscape too, where the move list's row had crowded them out.
- The results screen's draughts tiles stand on one glass, 4 dp round them and between,
  as the puzzles' draughts switch does (2026-11-13, task 078): alone they were faint
  glass on a bright photograph (a phone in landscape over winter's snow). The same fix
  as settings' tabs, each on glass (2026-11-09).
- A past game replays on a screen of its own, opened by a touch anywhere on its results
  row, its `??` count too (2026-11-13, task 078's C, from the prototype's `view=replay`).
  The row's count opening a tip instead was rejected: a row with two targets is a miss
  waiting to happen for a child, and a key at the column's head is to say what `??`
  counts (task 078's B).
  - Landscape puts the steps in a column of four taps at the board's left, the column at
    its right for back, the title, and the list (chosen from the prototype); under the
    board would cost it a tap's height on a phone. Portrait puts them in a row under the
    board. The board gives way only where the column would be under 300 dp (a 9:16
    phone's landscape: 329 dp) or the glass under 220 dp in portrait (a 9:16 phone at 480
    dp: 284; 300 dp, the prototype's, left it 204).
  - It opens at the game's end, its list at its foot as the moves panel's is: the row
    stands for the game as it ended. Opening at the start was rejected as a step away
    from what was tapped.
  - The list's moves are 34 dp taps, under the 88 dp rule: a miss only shows the
    neighbouring move, which the steps put right, and 88 dp rows would show four moves
    on a phone. They are drawn as the moves panel's rows, no tiles, so `test/shell/sizes`
    counts the steps and back as the screen's taps.
  - The keys: Left and Right step the moves from anywhere, as a chess site's replay does,
    rather than moving the focus by the controls' rects, which left them dead ends from
    the column of steps (`gui::claim_sideways`). The focus on a move shows it, so Up and
    Down in the list step a whole move.
  - It counts for nothing: it has a board and moves of its own, never the game's, so no
    flag is needed to keep it out of the history, the ratings, or the game to continue.
    A step on plays the move on the board as the game does; a jump shows its position at
    once, as playing every move between would take seconds.
  - The board is the flat one even with the 3D board chosen, as the prototype has it:
    the replay is a page for reading moves, and a 3D board would leave less room for the
    list. The positions are played out with the rules once, as the replay opens, from
    the moves the history keeps; the file keeps no positions, as the moves give them.
  - The game's line goes under the title where it fits beside nothing else, else at the
    top of the glass; the prototype's card on the tablet (result, opponent, date, side,
    "Rating then: 1031 → 1023") was left out for now, as the results row says the
    rating's change already.
- A replay plays on from any move (2026-11-13, task 078, the user's correction): "my
  whole point was to let the game be replayed at any point and THAT doesn't count and
  isn't stored or used for AI toughness changes or rating". This replaces the replay's
  own "Doesn't count" pill by its title (2026-11-13, task 078's C): the replay only
  shows, so it needs no label; the game played from it is what doesn't count, and says so.
  - Play from here stands in the replay's head, at its right end, as back stands at its
    left: one row the screen already has, which costs the board nothing and the list a
    line at most (the game's line then heads the glass). On a phone the title, then back's
    width, give way before the button leaves the head; on the tablet's narrow column it
    is a row over the glass, which has rows to spare (26 moves in view to 20). A row on
    every screen, over or under the list, was rejected: tried first, it took a 9:16
    phone's landscape at 480 dp from 6 moves in view to 2 and its portrait board from 284
    to 184 dp. By the steps there is no room on a phone, whose column of steps already
    spans the board.
  - The game from it keeps everything of the past game a player would expect: draughts,
    opponent, level and skill, side, the side to move. No clock, since the history keeps
    no clock setting; recording one was more than this needed.
  - Start over goes back to the replay's position, not the draughts' start: trying a line
    again is the point of playing from a move, and leaving is one tap on back.
  - Back goes to the replay, not home: the game was opened from there, and the replay
    keeps the move it showed, so another line can be tried from the next move.
  - The game in progress is set aside rather than replaced: the game screen, the worker,
    and the app's 3D board all read `shell.game`, so the game from the replay takes that
    place and the other waits in `shell.parked` (the saved image, 15 KB, with its hints
    and marks, 53 KB in all), which `shell::save` writes in its place. A second
    `game::Game` (132 KB) or a second game screen was rejected for its size and for every
    reader it would have to learn about.
  - "Doesn't count" sits on the way out's top edge, half in the margin over it (replaced
    the same day by the replay's note, below): the way out is the same rect in every
    layout, so the label needs no room of its own and moves no panel. White ink on the light glow colors (winter's) read faintly; dark ink,
    as the replay's mark discs have, reads on all of them. In the play panel's whose-turn
    line it would have crowded a panel tuned to what it holds; a row of its own would
    have cost a phone's moves' line or the portrait board.
  - Its moves are numbered on from the replay's (`Game.ply0`): "16." from move 30 reads as
    the same game. Doing so made the moves panel number a game by where it began
    (`game::first_ply`) rather than by its first note's side, which also numbers a game
    whose undo history dropped an odd number of moves right.
- "Doesn't count" is a note on the replay, under play from here (replaced the same day by
  a card behind an info sign, below), no longer a pill on
  the game screen's way out (2026-11-13, task 078, the user: "no need to put the
  'doesn't count' on the back button, IMO confusing. Rather as an info bulletin next to
  the button that triggers the replay run"). This replaces the pill on the way out's top
  edge, from earlier that day: on back and settings it read as being about those
  buttons, and the note belongs where the choice to play on is made, before the game
  starts. The game itself still counts for nothing, as before.
  - At the glass's top, right under the button in landscape: one rule for every layout,
    and the head has no room beside the button on a phone. Its full text says why (not
    saved, no rating changed), in the small face and dim as settings' notes, with an info
    sign, a faint disc with an "i", as the gui has no info glyph.
  - It leaves the list the rows it had, up to three (the move shown and one either side:
    with fewer the list's scroll hides or fades the move shown); in portrait the board
    gives way for it down to 300 dp, as the portrait glass was already at its least.
    Where the list would lose rows, the short text takes the game's line's place, as the
    results row it was opened from says what the game was; the short text over the list
    left a phone's landscape two faded rows. Rejected: dropping it on small phones (the
    iPhone 13 mini's landscape would have had none), and in the head in place of the
    title (about 110 dp on a phone, five lines).
- Why a game from the replay doesn't count is a card behind an info sign beside play
  from here (replaced the same day by a line under the board, below), no longer a note at
  the glass's top (2026-11-13, task 078, as the user agreed). This replaces the note under the button from earlier that day: on the Pixel
  7a in landscape it left the list about three rows of moves, and its short form took
  the game's line's place on small phones. The card costs the list nothing.
  - The sign is an 88 dp tap of its own at the button's right (a 28 dp disc drawn in
    it), not a spot on the button: a tap on the button always plays. It takes its width
    from the head, so on a phone the title, back's width, and then the button's icon
    give way first; where none of that fits, the button and the sign share a row, as the
    button did alone. A sign on the button's corner, its tap over the button's, was
    rejected for the taps it would take from the button; one at the glass's corner was
    tried and dropped, as the game's line beside it ran under the sign on a small phone.
  - The card is the mark tips' (`game::card`): the same glass, disc, head, and wrapped
    line, and the same dismissal (the mouse on a desktop; on touch the next tap only
    closes it), so the app explains things one way. It hangs under the sign's tap, not
    its disc, to leave the button's word in view, and widens for its head where 320 dp
    would shrink it.
  - The game's line is back everywhere. In portrait the board takes back what it gave
    the note (the tablet 729 to 752 dp, the Pixel 472 to 492).
  - Rows in view in `test/shell/replay` (its faces, wider than the font), before and
    after: the Pixel 7a's landscape 3.3 to 4.6, its portrait 3.0 to 3.6 (the board 472 to
    492 dp), the tablet's landscape 7.9 to 9.7, its portrait 3.0 to 3.1 (the board 729 to
    752), the iPhone 13 mini's landscape 3.1 to 2.9 (the sign takes the title's room,
    and the game's line, back from the short note's place, heads the glass).
- A game from the replay not counting is a line under the board (replaced the same day
  by a line over it, below), no longer a card behind an info sign (2026-11-13, task
  078). This replaces the info sign from earlier that day:
  the user disliked the sign and the head it crowded (on the Pixel 7a's landscape in
  Estonian back shrank to its arrow over its word, play from here to its words alone on
  two lines, the title went, and the open card covered the board), and a line by the
  board needs no tap to be read.
  - One line in the small face, dim as settings' notes, as wide as the board and centered
    under it: why (not saved, no rating changed) where that fits on the line (the
    tablet), else only that it doesn't count (the phones). Under the board rather than
    over it: over, it would sit between the head and the board in portrait and read as
    the head's; under, it reads as a caption of the position a game would start from.
  - The board gives way for it, not the list: in landscape by the line's 26 dp (the Pixel
    7a at 540 dp 450 to 424 dp, the tablet 752 to 726, the iPhone 13 mini 422 to 396), in
    portrait by 14 dp, the line taking the 12 dp gap over the steps (the Pixel 492 to 478,
    the tablet 752 to 738). The list keeps every row the sign's removal gave it.
  - The head is back as before the sign (back, the title, play from here with its icon),
    with two changes so its tiles look right in Estonian: play from here keeps back's
    room at its sides (it had 8 dp, its word against the tile's right edge while the
    icon's own margin widened its left), and the two tiles go the same way, both icon
    beside word or both stacked, the title giving way before either stacks. Rejected:
    keeping the title and stacking the button beside a wide back (the tablet's column),
    which made the two tiles look unrelated; there the button takes a row over the glass
    again.
- The replay's line is over the board, not under it, everywhere (2026-11-13, task 078;
  the user: "it absolutely must be above (in fact I'd put it above everywhere I
  think)"). This replaces the line under the board from earlier that day, whose reason,
  that over it would read as the head's in portrait, the user weighed the other way: the
  line is read before the board, as what the position shown is for.
  - It costs what it did: in landscape the board gives way by its 26 dp, the two
    centered in the height; in portrait it takes the 12 dp gap under the head, the board
    giving 14 dp. Boards and rows in view (`test/shell/replay`) are unchanged by the move
    alone: the Pixel 7a's landscape 424 dp, 4.6 rows, its portrait 478, 3.6; the tablet's
    landscape 726 and portrait 738, 3.1 rows; the iPhone 13 mini's landscape 396, 2.9.
  - Where the title has given way, back and play from here fill the head with 12 dp
    between them (the user, of the gap the title left: "there is a bit too much space
    there, if it's an easy fix let's do it"): in halves where the button's word fits in
    its half, else the button as wide as its word needs and back the rest, both still the
    same way and a tap tall. Halves everywhere would set the button's word in a
    smaller face in Estonian while back had room to spare. With the room the gap held,
    the iPhone 13 mini's landscape now has its tiles icon beside word, as the Pixel 7a's
    portrait in Estonian has.
  - Play from here never takes a row of its own (the user, of the tablet's landscape:
    "agree this is odd, why can't the replay info be below it instead?"): it shares the
    head with back everywhere, stacking with it where side by side they don't fit, as on
    a phone, and the game's line heads the glass where the title has no room. This
    replaces the tablet's row over the glass from earlier that day. The tablet's 356 dp
    column fits both side by side in its font; its list goes from 9.7 to 12.6 rows in
    view in the tests' faces (10.6 to 12.6 in English), the foldable's and 4:3's
    landscape 9.7 to 12.6.
- A phone's moves, where the panel has no room (2026-11-13, task 078's A, the user's
  choice from `prototypes/history.html`'s take d), replacing 2026-11-11's no panel in
  portrait or on a phone in landscape:
  - Landscape (`fit=row`, as directed 2026-11-12): back and settings side by side over
    start over free 132 dp of the left column, so what each side has taken stays under
    it and a line a tap tall or more fits at the foot; the board keeps its size. The
    other fit, `slim` (the column as built, the line as tall as the 47 dp left under it,
    the catch as counts in it), was under a tap on the Pixel 7a and moved the catch to
    the 3D board's top. Where the catch has no room (the iPhone 13 mini at its points,
    354 dp tall) the tiles are a tap high and the catch counts at the line's head, as
    prototyped; at its density floor (470 dp) it isn't needed.
  - The line opens a sheet over the screen's left part, to the board's edge, rather than
    a screen of its own: the board stays whole and playable beside the list.
  - Portrait (`port=bar`): only the last move, in the bar's row between the catches,
    costing the board nothing. The strip under the play row (`port=strip`) showed more
    moves but took the iPhone's board from 256 to 192 dp. It applies to a tablet's
    portrait too (task 074's open question 3): no panel had room there either, and it
    costs nothing. The sheet rises from the foot to the board's middle under a dim layer,
    which takes the taps above it: the board half hidden shouldn't be played.
  - The catches beside the portrait line are pieces where both fit their side at 70%,
    the least a row takes them, else counts: at full size, as prototyped, a tablet's
    late game turned to counts though its pieces fit.
  - Pieces over the UI draw over everything, the dim layer too: those under the sheet are
    left out, those above it kept whole. Faded with the layer, a catch's pieces showed
    each other through.
- Marks explained (2026-11-13, task 078's B, the user's choice: both). A legend at the
  foot of a list one opens (the phone's sheet, the replay): nothing to find or dismiss,
  for a child who doesn't know a mark can be touched, at the cost of one or two rows. A
  tip on the always-shown panel (a tablet's, a desktop's): there a legend would take
  rows from a panel that is always on screen. The tip's touch is the whole move, under
  the 88 dp rule as the rows take no other tap, and it names the move it explains, so a
  miss is plain; the next tap only closes it, so a tap meant to close it never plays or
  presses something under it. No new strings: the tip's name is its `mark.*_tip` text up
  to the colon. The tip isn't in the sheets or the replay for now (their legend says it).

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
  `prototypes/game3d.html`'s placement `a` (2026-11-09). Their row in landscape
  centered under the play or moves panel, on the game and puzzle screens alike
  (2026-11-13, the user): flush right it hung off the panel's edge; the column, where
  it fits, stays at the right edge.
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
- The raised board's material is one choice for every season (2026-11-13, task 080):
  Auto, the season's own look as before (autumn's wood, winter's stone, spring's carved
  stone, summer's wood), or Wood, Stone, or Carved, each season's board in it
  (`looks::of`, the table in task 080's 03), kept as the player's `material`. One
  choice is simpler to show and to say. Rejected: a material per season, each season remembering its own,
  which settings would have had to show as each season's boards (take c), and which
  matters only to a child who likes one season's stone and another's wood. The seasons'
  flags still pick a look over it, for tuning. Replaces task 045's list of every
  alternative look to choose from.
- Settings' board pictures are shots of the 3D board baked into one 640 × 420 atlas in
  git (2026-11-13, `scripts/board_thumbs.py`; 81 KB as JPEG, 117 KB as ASTC), loaded with
  the seasons' thumbnails into their texture. Rejected: drawing each thumbnail with the
  renderer at run time, which would bake every season's look in every material, and a
  second texture for them, a binding more in the UI's shader and its ngfx root.
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
  Replaces the turn on every friend game on the 3D board, from task 015. (The tile moved
  into home's setup on 2026-11-13, under **Home**.) The flat
  board's turn fades its pieces out and in, 0.15 s each way: at once it was too quick to
  follow. Rejected for now: the pieces swinging round the middle on arcs (a quarter turn
  puts them over light squares), and the board shrinking and growing (it moves the board).

**States and captures**

- Prototype `game.html?count=a`'s pips for a capture's count. Rejected: take b, a badge
  with the number, which needs a child who reads digits.
- Before 2026-11-09 nothing said how far a capture went (reported 2026-11-09: a child's
  lone king on the turned board with a capture of four), and then the 3D board drew no
  pips, as its scene never read `ring.z`; both fixed that day. The count shows on mistakes
  only from a mistake while a capture is due (2026-11-09); it showed whatever the hints
  before, which gave the capture away. Once shown it stays to the capture's end,
  counting down (2026-11-12, the user): hiding it at the next right jump, as from
  2026-11-09, took away a count the child had already been given.
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
- The pieces a capture has jumped go see-through (0.35) until it ends, on both boards, in a
  game and a puzzle, made stop by stop or played as a move (2026-11-12, asked for puzzles:
  a king's capture that turns back round had the taken pieces in its way). The rules keep
  them on the board until the capture ends, so they stay, only faint. Before, they stayed
  whole until the move ended and then faded out.
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
targets given back at rest. The ngfx build keeps SMAA, as goose-ngfx has no MSAA, and 2 × 2 supersampling to compare;
its FXAA is gone (2026-11-12): it blurred the surfaces and dotted thin highlights, and
its speed over SMAA, a few tenths of a millisecond (tasks 070 and 074), wasn't worth that
look. Rejected: keeping it as a cheaper choice for slow GPUs, which take SMAA or none.

2× MSAA for a slow device (2026-11-13, task 081), in part replacing gfx's 4× above: on
Android, once 60 frames of the ready 3D board average over 1.25 refreshes of the display,
the pass draws 2× from then on (`render3d::FEW_SAMPLES`), and only if 60 more frames at 2×
are still that slow does the app ask for 60 Hz (the rule below, which came first before). The
Galaxy A33's Mali-G68 draws 2× a quarter cheaper than 4× (task 042), unlike the Pixel 7a's
G710, where MSAA is free, and the user moved the board at 2× on the A33 and found it fine.
The same timing as the 60 Hz rule, so one measure decides both, and the Pixel 7a (60 frames
on its 60 Hz display) and the tablet (90 on 90) keep 4×. Fewer samples come first, as
they keep the display's rate where 60 Hz gives it up. Rejected: a list of slow GPUs (the
measure finds them, as `auto` does for the renderer); SMAA or none as the fallback (SMAA
costs more than 4× MSAA on Mali, none shows the edges); deciding again later, back to 4×
when the board would keep up (a pass's targets made again mid-game, for a gain no one sees).

The ngfx build draws 4× MSAA by default too (2026-11-12, task 077), replacing its SMAA
default above, now that NoGraphicsAPI's fork and goose-ngfx have multisampling: the pass
into 4× color and depth that are transient (memoryless on Metal, never stored) and
resolved into the picture as the pass ends, as gfx's is. On the M1 Pro at full screen
its frame takes 3.05 ms of GPU against SMAA's 3.37, and while drawing it holds 12 MB less
GPU memory at 1280 × 800 than SMAA or gfx's MSAA; it looks as gfx's does (within 11 of
255 where SMAA differed by up to 119). It is still 2% over gfx's MSAA (2.99 ms), so the
Mac's `auto` keeps gfx first (task 073). SMAA and 2 × 2 supersampling stay choices for
comparing (`--aa`, the A key going MSAA, SMAA, none, supersampling).

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
  and 72 MB more without the fork's `msaa-resolve-without-store`, which keeps the samples and the depth
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
- **2× MSAA before 60 Hz** (task 081, 2026-11-13): the same timing first drops the pass to
  2× MSAA, on a display of any rate, and asks for 60 Hz only if the board is still that
  slow at 2× (see "gfx keeps 4× MSAA" above).
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
