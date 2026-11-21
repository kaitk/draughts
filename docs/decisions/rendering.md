# Rendering decisions

The decisions behind drawing, the UI, the look, the 3D board, and frames, dated, with
their reasons and what they rejected. The headings follow
[Architecture: Rendering](../architecture/rendering.md), which says how it works now.
Superseded entries are one line; the full history is in git (`git log -S` on a phrase).

## Drawing

The screen's pass has no depth target, and on Android gfx never cycles the screen (the
fork's `screen-without-depth`): together they kept SDL from a second 64 MiB block after
the first rotation, about 70 MB on the tablet.

### Two renderers

One seam between the app and its renderer (2026-11-14), replacing the facades and copied
tree of 2026-11-12 ([decisions](README.md#the-codes-layout)). The drawers take a backend
`be` and are generic over its type: each calls its recorder on a field
(`be.draw.board(...)`, `be.r3d.bake(...)`), which Goose resolves by the field's type, so
each drawer is compiled once per backend and calls that renderer directly. The choice is
one `if`, in `backend::with`, one file per root (`src/gfx/backend.goose` for gfx alone,
`src/ngfx/backend.goose` holding both); the ngfx build is a second root
(`src/main/draughts_ngfx.goose`) over the same program (`src/app/app.goose`). Goose 150
lines fewer, Python 85, the gfx executable 16 KB smaller; `--bench 60` and shots on both
renderers unchanged. Rejected: splitting at `render::frame`, each renderer drawing the
whole frame (duplicates about 2,000 lines of shared drawers); a list of pass commands
each renderer replays (the wrapper over single GPU calls rejected 2026-11-10, plus a copy
of every draw's data); and the facades kept in the repository, needing a forwarding
facade per recorder in the gfx build too.

## UI layer

- The UI's shader is built three times (base kinds, icons, players' faces), each at 32
  registers where one shader held 64; quads are shaded only where they show (2026-11-10,
  task 063). The UI drawn live went from 0.61M to 0.30M GPU cycles a frame on the Pixel
  7a. Rejected: interpolated atlas places, quads read in the fragment shader, `mediump`
  varyings.
- The UI is kept as a layer while it stands still (task 059): its quads were a quarter of
  the 3D frame's GPU cycles on the Pixel 7a while only the board moved.
- Layout stays rect-cutting with `gui::stack` (weighed again 2026-11-10). If it outgrows
  that, copy [Clay](https://github.com/nicbarker/clay)'s model rather than link it: its
  API is C macros Goose can't call.

### Screen sizes and the safe area

- The density floor is 0.75 (2026-11-08): an 88 dp tap is then about 10.5 mm on any
  phone, against 7.0 mm on the Pixel 7a without a floor. At 1 every layout would have to
  work 360 dp across; at 0.69 taps are 9.3 mm for most of the same work.
- A desktop is laid out for a mouse (2026-11-11, task 068): the scale's ceiling grows from
  0.75 points a dp at a 1000-point shorter side to 0.9 at 1440; `--touch on` gives touch
  sizes. Rejected: a second set of desktop sizes (about 330 dp values in 16 files).
- A desktop's tiles are 64 dp tall with 12 dp beside their words (`gui::tap_size()`,
  `gui::word_padding()`, 2026-11-11, task 069): 72, 64, and 56 were shot, 64 picked. Tiles with
  an icon over their word stay at 72 at least (`gui::stacked_tile_height()`).
- On a desktop the landscape board and its corner panels stand in a frame (2026-11-11)
  that grows with the window's height, 4% a side at 1000 points to 7.5% at 1440, at most
  1.45 times as wide as tall round the flat board and 1.7 round the 3D one, so the
  board's top stays level with the panels'.
- No desktop window lays out wider than 1.9 times its height (2026-11-14, task 087): one
  cap in `gui::safe` rather than a width per screen, so an ultrawide works.
- A large desktop window (`gui::large`, 1700 × 1000 dp) centers the replay and results
  and sets their words a face larger (the next baked face, not scaled glyphs), 2026-11-14.
- On a desktop, home's menu notes (the opponent, the level, the rating, new puzzles
  tomorrow) are in the body face rather than the small face, still at 66% (2026-11-14):
  the desktop's scale ceiling leaves the small face about 13 px at 1080p, which a TV
  across a room can't read. Brighter notes, at 80%, looked worse. Rejected for now: a
  larger layout when a controller is in use.
- On a desktop in landscape the replay's back is a row over the board at its left, as
  every screen has back at the top left (2026-11-14). The tablet keeps its layout: the
  row would cost its board 14%.
- The replay's move shown and best move (2026-11-14, task 087): glow dots along the way,
  the squares' numbers at its stops, and the best move drawn as the game's hint, shown
  only while asked for. They are UI over the board, so the board's shader is unchanged.
  Rejected: white dots to a dashed ring, the best move in words only.
- The replay's best move is the one in place of the move shown, compared with it
  (2026-11-14), replacing the bulb's best next move above. The bulb, and the glass's line
  "The best was 34-29" (or "This was the best move"), turn on a comparison: the board at
  the position before the move shown, the move's way in dots and its mark, the best move
  as the hint, both from the same position. It stays on through the steps, each step at
  once; it is dimmed where the move was forced, at the start, and in games with no best
  moves kept. Play from here plays from the position on the board. The best next move
  showed one turn's move under lines about the other's, so after a mistake the bulb
  showed the opponent's reply; the line's tap went back a move, which nothing said.
  Rejected: the best move drawn as a ghost on the position after the move (its piece may
  have moved, a capture's men may be gone), and keeping the best next with the line only
  made to look like a tap.

### Small windows

iPadOS 26's resizable windows get the compact layout (2026-11-09, task 050).

- Compact's controls are under the 88 dp floor, accepted for compact only.
- No fling in scrolling lists (2026-11-09).
- No screen moves out of the way of iPadOS's window control (2026-11-09): back and the
  chip are large enough beside the dots, and a control that moves in a window only is
  worse. A margin clear of the dots was built and taken out.

### Window resizing

A Mac window being resized shows the last frame scaled over a cover of the backdrop
(task 058). Rejected: drawing live during the drag (the loop run from SDL's expose
inside gfx's `frame()`, and Metal's frame lags the size by one), and a cover removed
after the next frame (it flickered). Windows' modal size loop shows the last frame
unscaled, black where the window grew (2026-11-10): the Mac's look would need a gfx
patch.

## Look

The HTML prototypes settled the look's values on 2026-11-07, the seasons' from the design
boards; summer takes the photograph's evening sky, where the boards' sea greens were cold.
The pieces' light is soft, from above and toward the top; a strong light pool was set aside.

### Themes kept for later

Set aside, not rejected, for another season or a theme setting:

| | Sand and pine | Sea (the design boards' summer) |
| --- | --- | --- |
| Light / dark square | `#e6cfa6` / `#56603f` | `#c7d5c6` / `#2e5546` |
| Frame | `#33361f` | `#1d3a30` |
| Light / dark piece | `#f7efdf` / `#b5603f` | `#f6f1e4` / `#b56a57` |
| Crown on a light piece | `#56603f` | `#2e5546` |
| Glow | `#ffc67a` | `#86e7d3` |
| Glass tint, copy dimmed to | `#3a2a1e` at 50%, 0.8 | `#1e4a4a` at 40%, 0.75 |
| Text, page | `#fbf3e6`, `#1e1a12` | `#f4f8f2`, `#0d1c1c` |
| Square surface | soft mottling, like sand | plain sheen |

### Scene and glass

- The flat game's photograph is blurred (2026-11-07). Rejected: the sharp photograph
  (busy behind the board), a painted tabletop, generated tabletop pictures (task 016).
- The 3D board floats in front of the scene with no room or table modelled.
- Photographs are ASTC 6 × 6 (2026-11-08): it looks as the JPEG and 4 × 4 do and is
  nearer the master than the JPEG (44 to 45 dB against 40 to 41). Rejected: PNG (about
  5 MB a season), AVIF (libavif and an AV1 decoder to save about 1 MB).
- One photograph size for every screen (2026-11-08): sizing by density saves at most 1 MB.
- Windows and Linux embed no ASTC (2026-11-17): their GPUs mostly can't sample it, so it
  was 7.5 MB of dead weight; the Windows program went from 17.3 to 9.7 MB.
- The Mac app ships ASTC alone (2026-11-20), replacing "the Mac keeps both" of
  2026-11-17: a release carries only the format it uses. The Apple GPU samples ASTC as
  the iPhone's does, at 1.9 MB a season against the JPEG's 16 MB texture and its decode;
  the disk image went from 17.2 to 13.2 MB with LZMA. The gfx root keeps both until the
  compressed formats are upstream in goose_gfx, so a plain `goose build` still shows the
  photograph. Rejected: JPEG alone (about 8.6 MB to download, 14 MB more resident, and
  another path than the iPhone's).
- The backgrounds stay the Lanczos-enlarged originals (2026-11-17, task 014 cancelled):
  3840 px masters redrawn with Qwen-Image 2.1 img2img and upscaled with SeedVR2 lost the
  originals' mesh and had more detail, but looked faker, the detail wrong. Their steps,
  the app's 4K desktop loading, and the results are on branch `bg-4k`; the masters are
  kept locally (`design/backgrounds/masters/<season>-01-3840.png`, gitignored).
- The photograph loads in the frame after the lit tile, after a `gfx::flush()`: a season
  change's longest frame on the tablet went from 54 to 66 ms to 22.
- Glass is a copy blurred once, not a live blur: Snowtime measured live blur costing more
  than its weather animation. The copies stay as they are (2026-11-08): they are
  1.25 MiB inside SDL's shared block and blur only on a season change, so smaller copies,
  a Kawase chain, a mip, or offline copies would save nothing measurable.

### Controls

The prototypes were cut to one plain page per screen on 2026-11-13; every take these
entries name is in git history at 086f47d.

On 2026-11-14 they were cut again, to what building a new screen needs: the takes already
chosen and built (`new-game.html`, `settings-takes.html`, the tutorial's, the replay's
numbers switch) and `design-boards-prompt.md` went, and the board and pieces became
plain CSS, close to the app's but not a copy, with no raised board and no plain
background. The shader port painted every board and piece in script, so a page took 260
to 340 ms to load in Chrome on the Mac; plain CSS takes 50 to 65. The app is the
reference for how the board looks. Rejected: keeping the port at a fixed small size (100
of its 300 lines for a look the app shows anyway). All of it is in git history at
fed389b.

**Input**

- The tile under the mouse lights on a desktop (task 066, 2026-11-11): the chosen tile's
  glow at 8% and a 1 dp border at 40%, faded over 0.12 s, never a motion, which would
  make the screen busy. Never on Android or with `--touch on`, where the pointer stays
  at the last touch. The hovered tile is the topmost found over a frame.
- Arrow keys move a focus by the controls' rects, Enter presses (task 072, 2026-11-11),
  built once in `gui`. The focus is a glow ring outside the control: the hover's light
  was too faint, a stronger fill read as chosen.
- Enter with nothing focused focuses and presses the screen's primary (2026-11-12): a
  gamepad's first press doing nothing looked broken.
- A puzzle solved with the keys gives next their focus (2026-11-14), so Enter or a
  gamepad's A goes on. The keys lead while a focus is held (`gui::Gui.focus` not 0),
  which the mouse or a touch lets go, so a pointer's solve focuses nothing. Rejected:
  focusing next always, which rings it on a touch screen.
- The board is one grid control whose cursor visits every square (task 072). Rejected: a
  cursor jumping between movable pieces (it gives away which must capture), dark squares
  only (up and down then need a rule). Enter is a tap, one path through `board::press`.
  The cursor is a glow line inside its square, drawn over the 3D board's kept image.
- Tab and a gamepad's shoulders step between the game screen's three groups (2026-11-11).
  Fullscreen is Alt+Enter or F11, borderless at the desktop's resolution (2026-11-12),
  and the device's settings.txt remembers it for the next start (2026-11-16).
- goose_gfx owns the gamepad (2026-11-12, replacing 2026-11-11's `src/native/pad.c`). With
  `SYSTEM_GAMEPADS` (the fork's `gamepad-wake`) the system wakes the idle wait on Apple's
  systems and Android; on Windows the idle wait reads the pads every 16 ms, about 0.5% of
  a core. Rejected: SDL's own reading (5% of a core idle on the Mac), waking 30 times a
  second (1.5% on the Mac, 4.3% on Windows). `host::keys` keeps the stick as a D-pad.

**The game screen**

- Each control a glass tile with an icon and a word (`game.html`, 2026-11-07): icons
  alone confused. The icon and word are centered on every tile (2026-11-11).
- Landscape only where the flat board fills about 2/3 of the height, else portrait
  (2026-11-09). Rows are 88 dp, the floor for small hands (2026-11-08).
- The flat game takes the 3D screen's corner panels (task 054, 2026-11-09), a puzzle too
  (2026-11-11), its play panel as tall as it holds, 504 dp.
- The child's pieces are at the bottom against the computer (2026-11-08).
- One way back on every screen that leaves (`back.html` take b, 2026-11-09), replacing
  buttons named for where they went, which children read as different controls; take
  back became "Undo move".
- Black's clock starts after white's first move (2026-11-08); the running clock goes gold
  under a minute and red at 0:20 (2026-11-09).
- In landscape the way out's tiles stand alone, each on glass's tint (`gui::under_tile`)
  with no glass border or shadow (2026-11-13): on full glass they looked too glassy. A
  panel only where it holds what isn't a tile; a small window's compact bar keeps its.
- On every touch screen in landscape the way out is back and settings side by side over
  start over, 204 dp tall (2026-11-13): the board fits better. A desktop keeps the three
  stacked.
- A tablet squarer than 3:2 in landscape takes a phone's 192 dp panels on the 3D board
  (2026-11-13): 4:3's board grows from 693 to 762 dp.
- In portrait the camera buttons are a row under the board at the right (2026-11-13); in
  landscape a row centered under the play or moves panel, or a column at the right edge.

**Home**

- `home.html` (2026-11-07). The bare gear in portrait (2026-11-08): the 88 dp tile looked
  too big beside the wordmark.
- Continue says whose game it is ("A friend", "The computer · easy") and isn't shown for a
  game nobody set up with no move played (`Saved.unset`, 2026-11-12).
- Continue isn't shown for a game won or drawn (2026-11-15): it is done, its replay in the
  results, and continuing it only showed its end again. New game is the first row then.
- Watch replay takes Continue's place once the last game has ended (2026-11-16), replacing
  the empty place above: the game just played is the one a player wants to look back on,
  and the results list was two taps from it. It opens that game's replay at its end, its
  back going home. Its note says how it ended against whom ("You won · easy", "White
  wins" for a friend's), and, for a game ended by a clock run out, that it was on time
  ("You lost on time · easy", 2026-11-17): a one-move "You lost" read as a bug. Only home's
  note says it; the history doesn't record how a game ended, so the replay and the results
  don't, which is enough while the note is where a player sees the game just played.
  Rejected: "Last game" and *Viimane mäng* (flat), *Viimase mängu tulemused* (too long),
  "Show results" (read as the Results row), *Vaata üle* (unclear in Estonian), and going
  back to the ended game's screen (the 2026-11-15 reason). Its icon is Lucide's history,
  restart's arrow round a clock's hands (`gui::REPLAY`): the replay's to-the-start
  chevron, tried first, read as a letter K. Rejected from eight takes: the arrow round a
  play triangle, play in a circle (reads as playing a game), a list with play, a piece in
  the arrow, rewind, a clapperboard, and a board with play.
- The row is named "Replay" (*Kordus*), not "Watch replay" (*Vaata kordust*), since
  2026-11-17: in the tablet's landscape column the longer label left "Võitsid · raske"
  shrunk to its least, and "Kaotasid · raske", "You lost on time · medium", or any note
  on time was left out (`gui::row`); the short label keeps every note, the longest "Kaotasid ajaga ·
  keskmine", on the tablet and a 20:9 phone in both orientations.
- The X closes the app at once on touch screens (2026-11-08/09). Rejected: a last row (it
  costs the portrait board), a door, a power sign.
- On a desktop's landscape column the way out is a Quit row (task 072, 2026-11-11), the X
  only where the row doesn't fit. Quitting on a desktop asks first (2026-11-12): a
  gamepad's B going back had closed the window.
- On iOS home has no way out (task 043, 2026-11-09): Apple's guidelines say an app never
  quits itself.
- One New game row, the opponent chosen in the setup (2026-11-13, task 080, `new-game`
  take c), replacing the A friend and The computer rows: a friend's game is rare, and two
  rows made it as prominent as the common one. The setup's first row is A friend, Easy,
  Medium, Hard; the opponent is kept. Where the column is short the choices scroll with
  Play pinned. Rejected: an Opponent row (overflowed the tablet's landscape), a switch in
  the head row (no room on a phone).
- Whether a friend's game turns the board is the setup's (2026-11-13), Stays by default:
  it is a choice about that game, not a look, and in settings it read as always applying.
- The language is only in settings (2026-11-07).
- The results screen is a row on home's menu (2026-11-12), named Results: Games blurred
  with the rows that start a game. Where the row would shrink the board, the menu scrolls.

**Settings**

- One list that scrolls, no tabs (2026-11-13, task 080, `settings-takes` take b): Look
  (Background, Theme, Board, Kings), Game (Move hints, Move list), the privacy note. A
  480 dp column in landscape; the preview a band at the top in portrait. It replaces the
  two glass groups and their tabs. Rejected: a Material row shown only while raised, a
  material per season.
- The board's material is in the Board row: Flat, Raised (the season's, "auto"), Wood,
  Stone, Carved, each a picture of the board (2026-11-13).
- Look's rows (2026-11-20, take b of the settings prototype, changed on review): Theme,
  then Board, the main choice, then under a small heading naming the board only the rows
  that board uses: the 3D board's Pieces and Background with a third tile, Table; the
  flat board's Background; Kings. Replaces Background first (2026-11-13 above). The 3D
  board's two rows add three tiles, judged fine. Rejected: a 3D board card the Board row
  opens (no cards in settings), a Look group per board, the 3D board's rows dimmed on the
  flat board, Table as a row of its own.
- A board on the table has the plain fade behind it, never the season's photograph
  (2026-11-20): a landscape behind a grounded table read as odd. A floor or a room is to
  come (task 095).
- The 3D pieces follow the board (2026-11-20): Matching (Laua moodi), the look's own
  material, or Classic (Tavalised), the plain pieces of before task 094, each a picture of
  a light and a dark piece on the board chosen. Rejected: Auto with a material picked
  apart from the board (the pieces belong to the board); the words Natural and Smooth
  (Looduslik, Sile), which said too little. Winter stone's own pieces are black marble,
  over the honed slate: this replaces the satin ivory and dark slate pieces of the Cloud
  breccia entry (2026-11-19, under "Board and pieces").
- No draughts row (2026-11-11): home's setup and the library choose it, and here it read
  as changing the game in progress.
- The preview is in the draughts of the board settings opened over, not the one a new
  game would start in (2026-11-15): home's game in progress in International beside a
  Brazilian setup made the board change size between the two, the 3D board's buttons
  jumping during the transition.
- The move list's setting is here alone (task 078, 2026-11-13), a line under the chosen
  tile saying what it shows.
- The language is a button in the title row, the globe, its code and a chevron opening a
  list (2026-11-13), replacing tiles that grew with each language.
- A drag on the 3D preview turns and tips it as on home (2026-11-14): one camera for both
  screens (`Shell.cam`), eased back to rest whenever either is left, so each opens at
  rest. The choices take their presses first, so a tap on one never moves the board and a
  drag from the board never presses one. Rejected: the angle carried between home and
  settings, which would leave a turned board in a screen opened to change something else.
- A drag past the showcase's limits keeps what it asked (`Rig.asked`, 2026-11-17): the
  board stops at ±35° or at 35° and 80° down, and turns back only once the pointer is
  back where it reached the limit, so through a drag the pointer keeps its place on the
  board. Turning back at once with the pointer's first move back made a drag to the edge
  feel as if the board slipped from under the pointer.

- About, a small row at the list's foot beside the privacy note (2026-11-17, task 092,
  `prototypes/settings.html?about=tablet`), opens a card of the build, the graphics, and what the
  3D board uses, with Copy for a bug report. It shows, it sets nothing. Rejected: a
  Graphics section with the antialiasing and the shadows as choices. The renderer is
  chosen at start, SMAA looks as MSAA does and costs more, and the 3D board's knobs are
  tuned per device (below); a player's choice would mostly undo that. Its tiles are 40 dp,
  a rare choice's size, each with a tap round it; the card's notes say only what the app
  lowered by itself (2× MSAA), not what it asked for.
- The battery saver caps the frames, not the look (2026-11-17, task 092): with the
  system's saver on, Android asks for 60 Hz; the 3D board's antialiasing and shadows stay.
  iOS caps itself and a desktop's GPU costs little, so neither is capped. Rejected: a
  saver setting of the app's own, and a lower 3D board in saver mode before a measurement
  shows it saves enough.

**The puzzle picker**

- A library list (`puzzles.html` take a, 2026-11-09). Rejected: large theme tiles (shrink
  long Estonian names), a library beside the theme (two scrolling panes).
- No tap is lost to an animation or to the window's focus (2026-11-16): a press while a
  move still shows waits for its end, and on a desktop the click that activates the
  window counts. A tap right after the computer's reply, or after working in another
  window, took two. Rejected: letting the press through mid-move (it would choose on a
  board still changing), and the Mac's usual first click that only activates (a board
  click only chooses a piece; a menu row's is what the player meant).
- Rows are glass, lit while pressed; the draughts switch on one glass (2026-11-09).
- The title row tops the rows, back at their left, the switch at the right; where the
  worded back doesn't fit, back keeps its arrow only (2026-11-14).

**A puzzle**: `puzzle.html` take c (2026-11-08). A selected piece's targets never show.

**Players** (`profiles.html` take a, 2026-11-09)

- The name on a glass pill; the chip mirrors the X, giving the board back its room.
- A badge is home's king with its animal in the crown's place.
- While a name is typed on a phone the field stays above the keyboard (2026-11-13). SDL
  doesn't give the keyboard's height on Android, so the sheet hides its pictures in
  portrait and shrinks to the head in landscape. A desktop's sheet doesn't move.

### How to play

Task 026, `tutorial.html`, 2026-11-13, replacing the earlier first-start pages:

- A new player is asked "Do you know how to play?" on their card; the tutorial teaches
  their own draughts rather than asking which (one question; the library's switch reaches
  the others).
- How to play is lit in Continue's place on home until learned, skipped, or a game begun,
  and always the library's first row. Rejected: a row on home always, the library alone.
- Each step is played on the board. The icon is a finger tapping.
- Home's How to play stays for a player still learning, under Continue or Replay where one
  shows, else first and lit, until they have played a tutorial to its end in any draughts,
  won a game against the computer, or solved the half of Learn that opens the other themes
  (2026-11-19, task 098; `shell::past_basics`). It replaces "until learned, skipped, or a
  game begun": a tester who took the game for checkers answered "I know how" or began a
  game, and then found the tutorial only in settings and the library. "I know how" now
  only skips the tutorial offered then. Rejected: the row on home for good, which clutters
  the menu once the rules are known. A win against a friend doesn't count, since
  pass-and-play always has a winner.
- A step for a king's multi-capture, after Kings take from afar, in every draughts
  (2026-11-19, task 098): a flying king may land on any free square behind a piece, but
  must land where it can take on, which the same tester found confusing.
- Back a step in the tutorial (2026-11-19, task 098): a player who missed something can
  look again. Beside next in landscape; under start over on a phone's narrow panel, which
  has no room beside or over next; over next in portrait, the play panel about 16 dp
  taller for it (`tutorial::taller`), the board that much smaller. Rejected: beside next
  in portrait, which squeezed the line to about 100 dp on a phone, and tapping a step's
  dot, each about 25 dp to hit.
- Russian has its own steps where its rules differ.

### The lookout and the hint

`coach.html` round 3 take a (2026-11-09). In compact, hint and undo go to icons where
words would crowd whose turn (2026-11-10).

### What each side has taken

Task 052, `game-captured.html` take a in its `row` look (2026-11-09).

In portrait each side's catch is on a glass card of its own, as wide as it, only once it
has taken something, with the last move's pill on glass between (2026-11-14, the user):
the tiles above stand without a bar, so the row under them shouldn't have one either.
Replaces one strip of glass across the bar's width under both catches and the pill.

On the 3D board's table (2026-11-20, task 099) the catch also lies on the table, by the
side of the board of the one who took it, mirrored across the board's middle rather than
turned about it: turned, black's catch lay at the far left, under the landscape's way out
and moves panels. Short askew stacks (`taken3d::STACKS`) chosen over a loose row (it ran
past the board's length by 20 pieces and still read as ordered) and a heap (good, but it
reads as tipped out rather than set down), first built with short askew stacks; towers
of five in a line chosen on review (2026-11-20), the kings past two along the outer line
only, where they clear the towers, and stacked past five. Their shadows are worked out
from discs, in the table's shader and traced in the lit shader for the pieces themselves
(their own shadow and each other's), not by widening the shadow map over the table, which
would have cost the board's shadows a third of their resolution and cut the towers at
its edge. In portrait the table beside the board is off screen; nothing lies in front
of or behind it, where the controls are.
The panels' counts stay: in portrait the table beside the board is off screen.

### The moves panel and the results screen

Task 074 (2026-11-11) and 078 (2026-11-13):

- The moves panel stands under the way out on a tablet and a desktop (2026-11-13): moves
  usually sit at the left and the screen was right-heavy. On a tablet squarer than 3:2 it
  stands above the 3D board where three rows fit. Its glass grows a row a move up to its
  room (2026-11-14); the layout keeps the room, so the board doesn't move.
- The panel scrolls through the whole game (2026-11-12). Before the first move it says
  "No moves yet", centered (2026-11-12/13). The panel and a phone's line have a "Move
  list" head (2026-11-13).
- No accuracy summary at the panel's foot (the user, 2026-11-16): each side's accuracy
  shows in a phone's sheet and the replay, after the moves; a running score beside a game
  in progress adds little for a child. Rejected: the prototype's summary of accuracy and
  marks counted under the panel.
- The results' dates are the day a game ended in the local zone (2026-11-16), the app
  reading the zone's offset as it reads the local day; they were UTC, a day off near
  midnight.
- A phone's moves (task 078's A, `history.html` take d): in landscape a line under what
  each side has taken, opening a sheet beside the board, which stays playable; in
  portrait only the last move in the bar, opening a sheet from the foot under a dim
  layer. Rejected: a strip under the play row (the iPhone's board 256 to 192 dp).
- Marks explained (task 078's B): a legend at the foot of lists one opens, a tip on the
  always-shown panel. The tip's next tap only closes it.
- Who's playing has no results tile (2026-11-13): the games are home's row.
- A face, a new player, or a removal on who's playing takes effect at the next frame's
  start (`shell::change_player`, 2026-11-17), not in the frame that laid home out for the
  player before: that frame drew the new player's pieces on the old size's board, and the
  3D board kept that image while it was prepared for the new size.
- A past game replays on its own screen, opened from its results row (task 078's C). It
  opens at the game's end, on the flat board even with 3D chosen, and its positions are
  played out from the kept moves. Its list's moves are 34 dp taps: a miss shows the next
  move, which the steps correct. Left and Right step the moves from anywhere.
- A replay of a game against the computer, won or lost, opens at the player's first
  blunder (else first mistake), with the bulb on (2026-11-16): the review is for a grown-up
  improving, and that move is what they came to see. A friend's game, or one with
  neither, opens at the end. Rejected: a won game at its end (a child rarely opens the
  review at all).
  The moves' columns put the player's side first where the board is turned for them, so
  a row reads the reply before the move it answers.
- Play from here (2026-11-13): a game from any move of a replay that is neither saved nor
  rated. It shares the replay's head with back; start over returns to the replay's
  position and back to the replay. The game in progress waits in `shell.parked` (53 KB)
  rather than a second `game::Game` (132 KB). Its moves are numbered on from the replay's
  (`Game.ply0`).
- That such a game doesn't count is one dim line over the replay's board (2026-11-13):
  read before the board, as what the position is for. It replaced, the same day, a pill
  on the way out, a note under the button, an info sign with a card, and a line under
  the board (`git log --grep 'replay' --since 2026-11-13`).

### Board and pieces

**The flat board**: the lip, flat-topped pieces with one groove, and calm warm wood follow
the close-up boards chosen 2026-11-07. Kings are a stack of two discs, as in Estonian
play; a stack's rings go round its foot (2026-11-08).

**The 3D board**

- The game screen round it is `game3d.html`'s `corners`; the portrait camera at 65° down
  (2026-11-09).
- The pieces' occlusion of the field goes into a map only where squares changed (task
  059), centered on the piece and reaching 5 × 5 squares (task 086, 2026-11-13): 3 × 3
  cut it off in a line.
- The crown is a 256² map drawn once (task 059): evaluated live it was a third of a frame
  with 16 kings on the Pixel 7a. The backdrop is kept as an image: its grade was 7% of
  the frame. A dark king's crown is gold, as on the flat board (2026-11-12).
- With the plain fade, the board's ambient is dimmed as a theme without a photograph.
- Getting ready is a step a frame (task 042).
- The raised board's material is one choice for every season (task 080, 2026-11-13):
  Auto, Wood, Stone, or Carved (`looks::of`), kept as the player's `material`. Rejected:
  a material per season, which matters only to a child liking one season's stone and
  another's wood.
- The twelve looks as built stand (the user, 2026-11-16), summer's stone given veins and
  cracks of its own, tuned in the 3D prototype's panel. Set aside: task 041's temple take,
  the amber reading as an inlay, and the carved motifs' size against the images'.
- Settings' board pictures are shots baked into one atlas in git
  (`tools/assets/board_thumbs.py`): 640 × 420 and 117 KB as ASTC, then 2560 × 420 and
  478 KB with the Pieces and Table pictures (2026-11-20), each season's sixteen. The
  thumbnails lay their slots 8 across (2026-11-20): in one column, 72 slots were 7560 px
  tall, past the 4096 some phones' GPUs take. Rejected: drawing them at run time (every
  look baked), a second texture (another binding in the UI's shader).
- The 180° turn keeps its size and eases on a sine over 0.7 s (2026-11-12): refitting it
  at each angle drew the eye. The flat board's turn fades its pieces 0.15 s each way.
- A friend's game doesn't turn the board by default, and on the 3D board begins in the
  top view (2026-11-12): the far player would watch it spin every move.
- The zoom sits at the room's bottom at the rest angle and in its middle in the top view
  (2026-11-16): at the bottom the top view looked low on a desktop. Centered it is a bit
  smaller where the panels and buttons stand in the way (a tablet's field 735 dp, was 796).
  On a desktop the top view's zoom reaches down past the frame margin to a gap above the
  window's foot, and sits lower where the middle isn't clear (2026-11-16): held down by
  what each side has taken, it left the space under it empty (field about 7% larger at
  1204 × 758 pt). The rest angle and a tablet stay as they were.
- The game's view and zoom are kept in the player's file (`view = top`, `zoom = on`) and
  come back at launch and with each game (2026-11-16), but not those a friend's game
  across the table sets for itself.
- On a desktop the 3D game's frame is raised by half its top margin (2026-11-16): the
  board, its near edge low and thick, looked low at rest and zoomed. What each side has
  taken above it is two cards either side of the middle, as in portrait, and the zoom keeps
  the whole board under them, frame and all; on a tablet, with no margin to give, only the
  field, else its top view's zoom was no larger than the board at rest.

**States and captures**

- A capture's count is pips (`count=a`); a number needs a child who reads digits. It shows
  on a mistake while a capture is due, and stays, counting down, to the capture's end
  (2026-11-12).
- The must-capture pulse ends once a move is played (2026-11-09).
- A capture of many jumps is never played by itself in a game (2026-11-09), so the child
  learns the way. The 3D board lights a missed capture's next stops.
- A puzzle's board makes captures by hand with none of the game's help (2026-11-08).
- Pieces a capture has jumped go see-through (0.35) until it ends (2026-11-12): a king's
  capture turning back had them in its way.
- Taps during a capture (2026-11-11): any of its ways may be taken (`rules::ways`); a
  square passed on the way is no stop and no mistake (`board::passes`); a last square
  further on plays the capture when every way there takes the same pieces; a stop shows
  the piece hopping (`board::hop`); a tap on the selected piece puts it down.

- Winter stone uses Cloud breccia on the dark squares and frame, with satin ivory
  and dark slate pieces at 0.3 roughness (2026-11-19). The subdued veins keep the
  pieces distinct while the close view shows the mineral pockets. This replaces
  the slate squares and grey-cloud marble frame. Marble 2 remains selectable.
  The frame keeps its marble through the rounded edge because the blue tint and
  outer line gave it a halo. The ivory and slate pieces use zero scattering. Its
  pieces are now black marble (2026-11-20, "The 3D pieces follow the board", under
  "Controls").

## Fonts

Libertinus Sans, in the style of Optima. Tenor Sans (the proof of concept's), Belleza, and
Marcellus were compared in Estonian; Tenor Sans is the runner-up, one weight only. One
face, for one atlas.

The title and figures faces hold only their characters (they were 71% of the atlas), and
the atlas is R8 with only the rows used: on the Pixel 7a 1.0 MiB where every glyph in
power-of-two RGBA took 16 MiB.

## GPU memory

- Large allocations are their own size (`patches/SDL/0003`), not upstream's shared 64 MiB
  blocks, and exact, not rounded (2026-11-08): SDL makes the new screen before releasing
  the old, so a freed block can't be reused, and rounding wastes 10 to 22 MiB.
- `gfx::flush()` between short-lived resources took the tablet's GL mtrack at home from
  60.7 to 36.4 MB; `mallopt(M_PURGE_ALL, 0)` after launch the native heap from 42.6 to
  26.7 MB.
- The 3D bake doesn't clear its surfaces (2026-11-09): each kept a cycled copy, 85 MB on
  the Pixel 7a.
- The 3D board gave back its pass's targets a second after it last drew (2026-11-11);
  replaced on 2026-11-14: it keeps them while it is on screen, giving them back once a
  screen without the board shows or the app goes to the background (iOS at the first
  frame without focus). The second's release cost every move after a pause +4 ms on the
  M1 Pro and +13 ms on the iPhone 13 mini, and allocations on every turn, for memory no
  other app wanted while ours was in front; the headless 3D game at 1280 × 800 holds 171
  MB at rest against 144 (ngfx, memoryless 4× targets, 153 against 146). On the iPhone 13
  mini the 3D game left for the app switcher and for other apps four times, once over 10 s,
  and came back each time, not ended for the release's GPU work. Rejected: a longer delay.
- A phone bakes the plan and the frame map at 1024 texels a side (2026-11-14), each texel
  the average of the full bake's 2 × 2 samples (`BAKE_FRAG`'s `tone.w`): its field spans
  about a thousand pixels, so 2048 gave two texels a pixel. Baked at 1024 plainly, the
  wood came out twice as coarse (98 of 255 off the 2048 bake); averaged, 35 to 45. Memory
  at the Pixel 7a's size 149 → 116 MB on gfx, 140 → 91 on ngfx. Phones are `gui::phone`,
  so a narrow desktop window takes 1024 too. Rejected: the plan's normal as RG8, whose
  dropped channels change the look.
- Not done: drawing straight into the swapchain (9.6 MiB for a large gfx patch), halving
  the worker's tables (3 MB).
- Antialiasing is 4× MSAA on both renderers (gfx; ngfx from 2026-11-12, task 077): SMAA
  looks the same and costs more (M1 Pro 3.05 against 3.49 ms; Pixel 7a 11.4 against
  12.5; 2026-11-16, an AMD Radeon iGPU on Windows, Vulkan, 2880×1800 uncapped, median
  of 5: 4.12 against 4.40 ms, memory at rest the same, so x86 desktops keep MSAA too).
  SMAA, none, and 2 × 2 supersampling stay for comparing (`--aa`, the A key).
  ngfx's FXAA is gone: it blurred surfaces.
- 2× MSAA for a slow device (task 081, 2026-11-13): on Android, once 60 frames of the
  ready 3D board average over 1.25 refreshes, the pass drops to 2×
  (`render3d::FEW_SAMPLES`), and asks for 60 Hz only if still that slow. The A33's
  Mali-G68 draws 2× a quarter cheaper; the Pixel 7a and tablet keep 4×. Rejected: a list
  of slow GPUs, SMAA or none as the fallback, switching back mid-game.

## The 3D board on devices

The current numbers are in [the architecture](../architecture/rendering.md); how they came
to be is in tasks 042, 059, 071, 081, and 086.

- Shader variants per material (2026-11-20, task 094): the pieces' materials and the
  winter slab and the table in one bake and one lit shader took the Pixel 7a from 1.6 s
  to 3.0 s to get the board ready, almost all of it the driver compiling branches the
  look never takes. Each look now compiles only its own variant (the bake in three, the
  lit shader in four per shadow filter, the board's scattering only in the desktop's),
  1.9 s. Rejected: fewer call sites alone (`plan`'s second call was cheap), and Vulkan
  specialization constants, which goose_gfx doesn't offer and which ngfx's offline
  Slang compile would need as variants anyway.

- A bar while the 3D board gets ready (2026-11-20, task 101): the words alone left a
  phone's 2 to 3 s without a sign of how long. The words stay, under a thin white bar
  with rounded ends over a faint track: take d of five in `prototypes/loading.html`,
  chosen on review over take a (the bar under the words, a tick at each end), which was
  built first; not the bar alone, nor one across the board's foot. It fills by each step's time on the Pixel 7a, fixed in the code:
  counted by steps, it stalled at its start on the bake's 0.85 s compile and ran through
  the 40 quick bands after. Rejected: timing the steps on the device as they run (the
  first run has nothing to go by). On the Mac the setup takes most of the time (1.5 s
  headless on an M1 Pro), so the bar waits at its start there.

- 60 Hz for a slow 3D board (task 056): the timing above asks for 60 Hz on the surface
  (`ANativeWindow_setFrameRate`) while the 3D board draws. The A33 ignores it.
- Baking the field's shadow with the shadow map was dropped (2026-11-09): the camera's
  turn went to 8.4 ms but every frame drawing the shadow map to 11.5.
- The shadow map's pass culls nothing (task 086, 2026-11-13, replacing task 084's
  back-face culling): culling leaked light through single texels where a piece's top
  curves away; both faces cost the A33 about 0.15M cycles on a moving frame. Front-face
  culling left acne on the pieces' feet.
- Shadow taps by platform (tasks 081 and 086, 2026-11-13): 16 over 7 × 7 texels on a
  desktop and iOS (`SHADOW_MANY`), 9 over 5 × 5 on an Android tablet, 4 over 3 × 3 on an
  Android phone (`gui::phone`, `render3d::set_shadow`), the 4 saving the A33 7% of its
  frame. Told by screen, not timed: timing starts a phone on the 9. Rejected: one shader
  branching on a uniform (the 9's registers on the A33), 9 taps over a wider grid
  (stippled), an analytic disc shadow (discs only).
- The shadow map is fitted to the board along the light (`render3d::plan_light`, task
  086), 2.1× the field's texels, for the same cost on the A33. Rejected: baking the
  field's shadow when pieces move (8.7M cycles on the A33), PCSS, VSM family, shadow
  volumes; the list is in task 086.
- Three shadow filters kept (2026-11-14, reviewed): two would put the Android tablet on
  the 4, whose steps crawl on its larger pieces, or the 16, 0.5 to 0.6 M cycles a frame
  over the 9 on a Mali. They cost an `#ifdef` and a Slang module each; one lit pipeline
  pair is ever made. Rejected: one filter for phones and tablets by screen size alone.
- The table takes the key's shadow map where it covers it (2026-11-21, task 107), with
  the same filter and its own pipeline per filter, min() with the board's outline swept
  along the light; before, the outline alone, whose soft edge left the board floating.
  The map isn't widened; the pieces on the table keep their discs.
- The games table stands on a pedestal with four scroll legs (2026-11-21, task 107;
  option A of `build/notes/games-table/`, the closest to style-01's): built with the top
  as one mesh and drawn in the game too, where the top hides it, for 6,480 more
  triangles (the column at 24 segments, its silhouette's chord under a millimetre; a leg
  41 sections of 12 points). The legs are swept sections (`mesh::bar`), not extruded
  outlines with flat faces, so a curl like the scroll needs no triangulation. The room's
  floor takes the base's shadow analytically (the column and three segments a leg), as
  it did the turned foot, which it replaces; the base takes the top's shadow the same
  way, and none from the shadow map. The top's size (the game's 1.05 m or task 109's
  0.80 m) is left open: the light tuner's `--table-top`. Rejected for now: Poly Haven's
  column (option B, the fallback if the urn reads heavy) and a tripod (C, which tips).
- The library's shell is lit as a room of its own (2026-11-21, task 107's light round,
  against ChatGPT repaints of our own room): its indirect light is baked on the CPU when
  the room turns on and again when the sun, the room's light, the tree or the table's top
  changes, never per frame (`model3d::room_light`, `render3d::bake_room_light`, about
  57 ms on an M-series Mac, into fixed buffers). A grid of 12,555 probes 0.3 m apart
  (31 × 27 × 15 over the plan, into the niches) keeps per colour a constant and a
  direction (two bands of spherical harmonics, the clamped cosine folded in), in a
  465 × 81 RGBA16F atlas of 0.3 MB that `ROOM_FRAG` reads with six taps. Two sources: the
  sky seen through each niche's outline, past the lace, the table's top shading what is
  under it (the room's large-scale occlusion); and the sun's patches thrown back once,
  from 1,080 rays traced through the three windows' glazing into 0.25 m bins on the floor,
  walls, sills, reveals and table, their colour taken 60% to grey (an amber sun off
  orange oak alone turned the ceiling peach). The fine occlusion stays the mesh's own per
  vertex and the floor's analytic bands. The probes replace most of the harmonics and the
  flat bounce on the room's surfaces only (`rooms::Room.baked`); the board, the table and
  the game keep their light, and the game's shot is unchanged. Rejected: SSAO (a pass a
  frame, and it darkens only what the screen shows, not the light the room throws back);
  per-vertex light (the floor and walls are a few large quads, so a patch's bounce has
  nowhere to land); a lightmap per surface (an unwrap of the shell, and the curtains and
  table left out); baking on the GPU (a pipeline and passes in both renderers for what
  the CPU does in tens of milliseconds once).
- The shell's sun is sharper and stronger than the game's window (2026-11-21,
  `rooms::Room.shell_sun`): its penumbra widens 0.0055 a unit of distance, about the sun's
  disc (0.0047), not the game's 0.012, and the sun on the room's surfaces is 2.2 times the
  board's, so its patches read against the room's exposure as the references' do.
- The window's glow is a small bloom (2026-11-21, `render3d::bloom_pass`): the room's image
  shrunk to a quarter, what is near white kept (the least channel over 0.72, so the
  glass, the sky and the backlit lace glow and the board's sunlit maple doesn't), blurred,
  and added back in linear light. Only where the pass draws into another target than the
  kept image (the tuner's), as the app shows no shell yet. No rays or shafts.
- The waxed floor and the curtains' brass reflect the room analytically (2026-11-21, after
  the gilt and brass study's proposal): the reflected ray meets the shell's box, whose
  surface there (wainscot, paper, the doors' paint, plaster, the floor's mean) is lit by
  the probes and the sun through the windows, and on the window wall the three windows as
  soft rectangles with their bars and the view out's light; mixed toward the room's light
  that way as the lobe widens. Only the floor and the brass see it sharply: the
  panelling's grain aliased a window's edge. About 1.1 ms a frame at 1600 × 1000 on the
  Mac, the heaviest part of the round. The polished table (TABLE_FRAG, the game's shader)
  is left for later. Rejected: a cube map (a pass per face, and the room changes with the
  sun), screen-space reflections (a frame's pass, and the windows are often off screen).
- The oak outside is blurred once when put on the GPU (2026-11-21, `render3d::soften`,
  sigma 3.5 texels, `view_out::OAK_SOFT`), as out of focus as the band's trees: the user
  found it too crisp. Rejected for now: depth of field over the frame.
- The library's probes sit half a step in from every surface (2026-11-21, task 107's
  leftovers; replaces the grid above, 31 × 27 × 15 from the far wall, the window wall and
  the floor): 30 × 26 × 13 probes from 0.15 m in, 10,140 in a 390 × 78 atlas, about 45 ms
  to bake. The old grid put probes in the end walls' and the floor's planes, and a
  surface's lookup half a step out mixed them with the next row. A probe within 0.2 m in
  front of a sun patch's surface takes none of that patch (`room_light::OWN_ROW`): that
  row is what the surface reads, a flat surface doesn't light itself, and two bands of
  harmonics with a strong patch behind ring dark on the far side, which showed as a soft
  dark band across the doors. The cost: the floor and walls within 0.2 m of a corner miss
  a little of the other surface's bounce. Rejected: clamping the direction to the
  constant (no negatives, but a strong patch behind still eats the rest of the light).
- The shell's tree casts finer, softer limbs than the game's (2026-11-21,
  `rooms::SHELL_LIMBS`, `trees::View.wood`): its trunk and limbs drawn half as wide and
  blurred three times as much in the map, so they cross the sun's patches as soft streaks
  like the blurred oak outside, not bold bars. The game's tree is unchanged. Rejected:
  moving the crown so no limb crosses a window (the limbs fan from a trunk behind a pier
  across all three).
- The floor before a door's opening keeps no darker wax band (2026-11-21): people walk
  through there; its contact line sits at the threshold's nose (3 cm out), not the
  plinth's lip (5 cm), and the wainscot's dark band is fainter there. The plinth and the
  wainscot's cap are mitred into the room's inside corners, not overlapped square.
- The library's bookcases are two tall open oak cases built into the hall wall either
  side of the door (2026-11-21, task 107; option B of `build/notes/bookcases/`,
  `room_shell::bookcase_at`, `bookcases.goose`): 1.2 m wide with 8 cm of papered wall to
  the architrave, a folio base 0.45 m deep whose 35 mm ledge carries the wainscot cap's
  line at 1.20 m, an upper case 0.30 m deep whose 140 mm cornice is the architrave
  head's band (2.70 to 2.84 m), two bays a case, pilaster strips with sunk panels, the
  wainscot's oak and plinth. They are openings of the shell's own kind, so the wainscot
  and the paper stop at their sides as at a door; the wainscot's cap runs into the ledge,
  and the strip of wall left by the door is paper over a plain plinth. Built with the
  shell, one mesh, one draw. Small choices made here: the shelves stand 4 mm back from
  the case's face; the sunk panels are 6 mm deep inside a 12 mm rim; the backs, shelves
  and sides inside carry a fixed occlusion (0.35 to 0.55); no busts or urns on the tops
  yet. The baked light sees the cases' fronts as a dark surface on the hall wall
  (`room_light::CASE_ALBEDO`, the sun's patches met at their fronts), and the floor's
  reflection sees them dark. Rejected: the low case (A, reads as a sideboard) and the
  concepts' glazed case here (C, kept for the stove wall).
- The books are boxes on the shelves with a rounded spine sampling a mask atlas, coloured
  per book by `ROOM_FRAG` from a small table (2026-11-21, task 107; option B of
  `build/notes/books/`, `model3d::books`): `design/materials/books_atlas.png`, 1024 × 928
  RGBA at 0.7 texels a millimetre (the tone, gilt or ink, the label, wear; 194 designs,
  one a volume of 51 titles), and its cells and the 32 covers' and 8 labels', gilt's,
  ink's and page edges' colours in `book_cells.goose`, both made by
  `tools/materials/books.py`. A book's material carries its cover, label, gilt or ink and
  how faded it is (12 bits in `mesh::Vertex.mat`'s fraction), so one cell serves many
  books and a set reused elsewhere in the room comes in other colours. A shelf is filled
  as a library's is (`books::fill`): its own formats first (folios in the base with
  quartos and octavos, a quarto shelf, three octavo shelves, duodecimos at the top), the
  least used sets first, sets whole and in order (a long one may run on), then odd
  volumes, to 85 to 92%; now and then a book out and its neighbour leaning into the gap,
  the last book leaning on the side on about a third of the shelves, a few small piles
  lying flat; volume 1 on the reader's left. The sun's fade grows toward the door's side,
  which faces the middle window squarely, and a little up high. 10 triangles a book,
  about 390 books. The spine titles are baked art in period languages (German, Estonian
  and Latvian in Fraktur, French and Latin in roman caps), not UI strings: they are a
  picture of old books, never shown as text, so they stay out of `strings/` (an
  assumption, to confirm). The OFL fonts that set them stay with the baker in
  `tools/materials/fonts/` with their licences; only the PNG goes into the program. No
  hero books yet. The light tuner's Bookcases and books section turns the books off and
  scales their fade. Rejected: a baked colour atlas (A, every copy its own texels) and
  spines drawn at load (C, a font rasteriser in the app).
- The books are retuned toward `library-autumn-02`'s case (2026-11-21, task 107,
  `build/notes/books-tone/`), which the first fill missed: it read as a decorator's set,
  long runs of like volumes in saturated blue, green, red and tan, lit evenly deep into
  the case. The covers are now mostly calf and half calf browns, aged dark (sRGB #3e2616
  to #765236), the cloth's and half leather's green, blue and red muted and rarer, the
  labels dark; the spines' tone a little lower (0.4 + tone, was 0.45 + 1.1 tone), each
  volume a shade of its own, darker at the head and tail, rubbed more at the head. A long
  set stands as a run of two to eight volumes (whole now and then), and a shelf's sets
  mix their heights. Inside the case: the spines' occlusion falls toward the head under
  the shelf over them (0.25 to 0.55 by the room left over them, 0.75 at the foot) and
  near the case's sides; the back 0.22, the shelves' undersides 0.3; and `ROOM_FRAG`'s
  `case_shade` keeps the sun off what the case and its books hide (the ray out through
  the open front, between the ends and the upright, under the shelf over it, over a
  block standing for the books), the cases' heights repeated there from
  `bookcases.goose`. The shelves' mean colour now measures as the concept's
  (sRGB 0.27, 0.17, 0.10 against 0.26, 0.16, 0.10). Replaces the first palette and the
  sets kept whole; the cases' casting no shadow of their own in the sun above.
- The library's wallpaper repeats every 0.9 m (2026-11-21, `surfaces::PAPER_TILE`),
  replacing style-01's 1.4 m: the flowers finer and still readable. A real paper's
  0.65 m was rejected for now: at that scale the mask's flowers filter into the ground
  and the wall reads muddier. The light tuner keeps the tile on a slider.
- The panelling oak is three times lighter and greyer (0.6 of its colour about its
  luminance), and the ceiling and its cornice have a limewash of their own, at 0.75 of the
  walls' light and 1.5 times their colour (#aa9e86 to #baaf9a) (2026-11-21): the
  references' panelling is lighter and greyer than the stain's dark red-brown, and
  `library-autumn-02`'s ceiling is darker and amber. Chosen on the light tuner's tints
  (`--oak-tint 3,0.6 --ceiling-tint 0.75,1.5`), then baked: the oak's tint is the last
  step of its bake (`surfaces::Oak.tint`, `BAKE_FRAG`'s `oak_finish`), the ceiling's
  colours are `surfaces::LOOK`'s, and the probes' albedos for the wainscot and the
  bookcases and the reflections' wainscot, cases and ceiling follow them. Replaces the
  wainscot's dark red-brown (sRGB about 14, 5, 2 in style-01's shade) and the ceiling in
  the walls' limewash. The tuner's tints are 1,1 at this look.
- The curtains' tie-back is a soft cord as in the concepts (2026-11-21,
  `curtains.goose`'s `tie_back`): a 9 mm cream cord, its three strands shaded on it,
  once round the bundle at 0.95 m, which it gathers to about three quarters of its width
  and half its depth, knotted on the front toward the hook, two short tails with small
  tassels, and its run hanging slack in a catenary (5.5 cm of sag) to a small brass hook
  turned up at its end, at ±0.95 m and 1.0 m on the pier. It replaces option A's cord
  drawn tight from a pin at ±0.80 m round the bundle and back, which read as a stiff U.
  About 920 triangles a tie-back (5,544 for the six), swept tubes and two balls for the
  knot.
- The tie-back is settled once by a simulation when the room is built (2026-11-21, task
  107; `curtains.goose`'s `settle_tie`), replacing the loop drawn level at 0.95 m and the
  knot as two balls: the cord's loop was perfectly horizontal. The cord is a chain of 68
  points (the loop, the run to the hook, two tails) in Verlet steps at 240 a second, 150
  steps of 10 iterations over fixed buffers, about 4.5 ms on an M-series Mac, once for all
  six tie-backs. The bundle is a soft ellipse a section, its waist gathered round 0.95 m
  where the cord was tied (to 0.74 of its width and half its depth over ±0.13 m), giving
  back a tenth of the cord's way in an iteration; the loop never longer than that waist's
  girth (drawn in without adding speed); the knot held where it was tied round the bundle
  (its front, toward the hook) and the lace gripping the cord along it (a move up or down
  held back by 0.2 of how hard the bundle pushed). The knot's and tails' weight drag their
  side down the waist's lower flank: the knot settles at 0.91 m, the loop's back at
  0.94 m, the run hanging slack to the hook. The cloth then gathers round the loop where it
  settled, per angle round the bundle (its height and how far it draws in), standing out
  a little above and below; the panel's rows close up round the tie (20 rows over the
  hem's 6, from 14 and 5). The knot is an overhand, a trefoil swept as the cord, about
  25 mm across. Rejected: placing the tilt by hand (it misses what gravity does to the cloth), the
  frictionless bundle (the run's pull turned the knot round to the wall's side and the
  loop slid 7 cm down), and longer steps (unstable at 80 a second).
- The curtains' folds hang round at the hem (2026-11-21): from 0.83 m down a panel has
  12 columns a fold, not 6 (whose hexagon read as a zigzag of points seen from above),
  and the hem's line lifts at each fold's turn, scalloping between them. The two grids
  meet on the 0.83 m row, the finer one's extra points on the coarser one's edges, so no
  crack opens. 1,512 triangles a panel (1,152 before, 2,160 more for the six). Rejected:
  the whole panel at 12 a fold (2,304 a panel, where only the hem is seen end on).
- The curtains' lace is way f3 (2026-11-21, `surfaces::LACE_WAYS`' first), replacing f2,
  the first of the four ways baked from the lace library: chosen on the curtains in the
  room. Ways f2, f and d stay built in, on the light tuner's `--lace` and C, while the
  light and later changes may favour another (about 2.1 MB of PNGs in every build).
- The games table's top is 0.95 m across, in the game and the room (2026-11-21, task 107;
  `mesh::TABLE_R`, 14.48 units), replacing the 1.05 m it was and closing the choice left
  open above: between a period games table's 0.80 m and the game's 1.05 m, with room for
  the score sheet at a near corner (task 103); a choice for now. What each side has
  taken still fits, its furthest
  piece 0.36 m from the middle (`build/notes/games-table/src/fit.py`). The wood's map keeps
  the 1.05 m top's extent (`mesh::TABLE_MAP_R`), so the figure keeps its scale and the
  game shows the same top wherever its rim is out of the frame: at 1280 × 800, 800 × 1280,
  a tablet either way and 16:9, the game's shot is unchanged. On a 9:19.5 phone in
  portrait the near rim now shows across the bottom under the panel, with the plain fade
  past it, and at 9:16 a corner of it; the 1.05 m top's showed only at the far corners.
  The light tuner's `--table-top 1.05|0.80` shows the others.
- The shell's swept mouldings shade as curves (2026-11-21, task 107; `shell_mesh`'s
  `sweep`): a profile point's normal is the mean of its two segments' where they turn by
  less than 37°, so the cornice's cove, the caps' ovolos and beads and the plinth's
  rounded edge shade smoothly, and each segment keeps its own at a sharper turn, so the
  fillets and steps stay crisp. It replaces a flat normal a segment, which showed the
  cornice's long cove as bands. No triangles more: each segment had its own vertices.
- A bound book's spine is a curve of five columns, four strips (2026-11-21, task 107;
  `books::spine_at`), replacing two strips meeting at a crest: from below a shelf each
  spine read as two flat facets with a dark line down its middle. Its columns stand back
  on a parabola (the edges 0.12 of the thickness), and their normals turn a quarter further
  than `bulge`'s, rounder than the curve (54° at the edges), so the roundness reads across
  the room and the edges roll into the boards. Flat boards and wrappers keep their slight
  turn. Four triangles more a book (1,536 for the 384).
- The panelled wall's mouldings and the raised panels' rings shade as curves too
  (2026-11-21; `surfaces::strip`, `surfaces::panel_ring`, the rule of the swept mouldings
  above, `surfaces::CREASE`): the wainscot's, the doors' and the shutters' panels. The
  ring's faces take the profile's own normal, which also turns the groove's inner wall to
  face the panel's middle, where the facing toward the side had turned it into the
  moulding. No triangles more.
- The sun's highlight takes only the sun that comes through a window (2026-11-21, task
  107; `LIGHT_FN`'s `window_open`): the window's pattern keeps out `room.y` of the key in
  its shade (`window_light`), so the rest, 10% in autumn, lit every surface's GGX highlight
  through the walls; on the pier between two windows the wainscot's waxed cap and the floor
  showed the sun's sheen in shade. In `ROOM_FRAG` and, with the room shown, `TABLE_FRAG`
  the highlight now takes `window_open` (0 to 1, a wall keeps all the sun out); the
  diffuse keeps the shade's floor as before, in the room as light thrown back, so it takes
  the occlusion as the probes do. The game, which shows no room, keeps its light exactly.
  The room in shade is darker where the false sheen lit it: style-01's camera's mean 3%,
  the far wall's paper beside the windows a fifth. Rejected for now: dropping the floor
  from the room's diffuse too (the hall view's mean a further 7% down, the look as tuned
  lost); a choice for the light's next round, when the probes carry all of the shade.
- The games table casts its own shadow in the room from a map of its own (2026-11-21,
  task 107; `render3d::table_map`, `shaders::TABLE_MAP_FN`): its top and base drawn into a
  1024 × 512 DEPTH16 map (1 MB) projected along the key onto the floor round the table,
  fitted to the top and its shadow's reach (up to 4 m), with the key's pipeline; drawn
  again only when the key or the table changes, never in the game. The floor, the walls
  it reaches and the base (the top's frieze over it, the column over the legs, the legs
  over one another) take it with the 9-tap filter, its texels about 3 mm on the floor; the
  analytic shadows (`table_shade`, `under_top`) stay where the map isn't drawn. Before,
  the floor took the base's shadow worked out from the column and three straight pieces
  a leg, which met the scroll toes a few centimetres off, and the base none of its own:
  the table floated. Rejected: the table in the key's map (fitted to the board, 2.1× the
  field's texels; the table's shadow on the floor reaches 2.3 m at autumn's sun, and the
  top in it would shade itself where it takes the board's); a blocker search for the
  penumbra (the sun's disc widens it about 1 cm over the table's height, near the
  filter's 1.5 cm).
- Under the games table the floor is darker by its base's own occlusion (2026-11-21,
  `ROOM_FRAG`'s `base_hides`): the drum and each leg as spheres along its curve, a sphere
  of radius r at distance d as high over the floor as h hiding r²h/d³ of the sky
  (Quilez's sphere occlusion), the nearest point of each leg's pieces taken, so the
  scroll standing on the floor darkens it most, tight round the toe. It replaces a round
  blob at each toe.
- The library's corners and edges are darkened analytically, in every tier (2026-11-21,
  task 107; `ROOM_FRAG`'s `corner_shade`, `rooms::Room.corners`): the shell is a box of
  known planes, so a point's distance to each plane standing square to its surface gives
  the share of the room's light that plane hides within a reach, the segment of the
  hemisphere's projected disc beyond d / reach (a half at the plane), times a strength.
  The floor along the walls (to the plinth's face), the walls into the inside corners,
  along the floor and under the cornice, the ceiling past the cornice (half, a cove; the
  cornice keeps its profile's per-vertex shade), the wall over and under the wainscot's
  cap and under the sills, the windows' niches (reveals, sill, the casements' frames,
  head), the doors (jambs, leaf, architrave), round the bookcases (sides, fronts, tops).
  Strength 1 and reach 0.4 m in autumn, against the ChatGPT repaints of our room
  (`02-style-01`, `03-autumn-02`): a soft shade about 0.2 m wide, half the light at the
  line, none past 0.35 m. It darkens the indirect light only (the probes, the harmonics,
  the shade's floor), never the sun. It replaces the floor's band along the walls (0.45 at
  the wall over 0.3 m); the dark line at the plinth's lip stays. Where the probes, 0.3 m
  apart, can't follow an edge, this does, for a few operations a pixel. Rejected: SSAO
  for the room's planes (a pass a frame, and only what the screen shows; it comes in the
  next step for what the box doesn't know: the furniture, the books, the curtains' folds);
  per-vertex occlusion on the shell (its walls and floor are a few large quads).
- A new player starts on the 3D board on a desktop and flat on a phone or tablet
  (2026-11-14, `settings::default_board`); a player's file keeps the board they had.
- The spring stone board scatters light through its stone on a desktop only
  (2026-11-19, task 094; `looks::Theme.board_scatter`, `render3d::scatter_allowed`): 16
  shadow taps over a disc sized by each channel's reach, the square's figure seen a
  little below the surface, its painted cracks and veins keeping their pigment.
  Measured +0.35 ms in the board pass at 1280 × 800 on an M1 Pro (5.42 to 5.77 ms
  median over eight alternating runs). Phones and tablets keep it off until timed.
  Rejected: scattering along the frame's cracks (they are thin painted lines), and
  tying it to the 16-tap shadow filter (it would turn on for iOS).
- Open: at rest the tablet's 3D board spends about 2.7 ms CPU a wakeup against the flat
  board's 0.3 (task 042).

## When a frame reaches the screen

goose_gfx records a frame and its blit into the window's image in one command buffer.
Submitting the frame before the wait and the blit apart was worse: the window has 3
surfaces and the compositor holds two, so the blit waited for one and the frame for the
blit.

## Frames and battery

- A drop that leaves a piece waiting draws the frame after too (2026-11-08): a puzzle's
  next stayed dim on the Pixel 7a.
- A high mode that draws all the time (the user, 2026-11-20; planned in the epic 107, not
  built): the wind in the window's pattern, dust in the beam, and the clock's seconds hand
  move continuously, so every frame draws. It is the high render tier's: on by default
  on desktops; on laptops and tablets while on mains power, back to drawing on change on
  battery; a setting forces it on or off. In the game the clock ticks and the window's
  pattern sways only gently, its dapple kept off the squares; the full wind and the dust
  stay on the home screen and menus. Drawing on change (below) stays the default
  everywhere else and the only mode on phones. Rejected: the high mode by device alone
  (a plugged-in tablet could afford it) and a setting alone (desktops would start
  still).
- A running clock has its own wake timer (2026-11-08): without it the tablet drew the
  clock 6 ms later each second and skipped a second every two and a half minutes.
