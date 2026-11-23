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
- The sun's micro-shadowing on the field leaves out the pieces' occlusion of it (2026-11-22,
  task 107, builder 31's candidate D, `build/notes/builder-31/`): Filament's term scaled the
  sun by `nl / sqrt(1 - ao)` with the pieces' share of `ao` in it, which darkened a halo on
  each piece's lit side, where nothing blocks the sun (the shadow map draws the real
  shadow), most at the menu's low sun. The pieces' occlusion still darkens the field's
  ambient light. This changes the game's look. Rejected: the halo's strength or reach
  turned down (`--halo`, `--halo-reach`, 0.6 and 0.35), which kept a lighter ring.

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
- The brass is antialiased by its normals' spread (2026-11-23): its lobe's alpha² grows by
  the normal's screen derivatives, `|dFdx n|² + |dFdy n|²` (Tokuyoshi and Kaplanyan's
  kernel, its variance half a pixel), at most 0.5, where the room's other surfaces keep
  0.3 of it to at most 0.3; and it sees the room's box sharp over half its pixel's spread
  of reflected directions, not a quarter. The door's lever broke its highlights into
  dashes and the hinges sparkled (the sun's leaves on the walls they reflect) as the eye
  moved; now they hold, the brass a little softer close up. The books' gilt keeps the old
  values. Rejected: the kernel alone at the paper's half-pixel variance (the lever's dashes
  and the hinges' sparkles stayed), the full pixel's spread (the brass went dull, its
  windows gone).
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
- The library's windows have working shutters (2026-11-21, task 107; option A of
  `build/notes/shutters/`, the user's agreement; `room_shell::SHUTTER_*`,
  `shell_mesh::shutters`): two leaves a side of 0.325 m, as the shell's plan had them and
  as a real manor hall shows (the precedent photo, Eesti Sõjamuuseum), folded flat against
  the reveal from 2 cm in to the lining at 0.345 m, as tall as the casement (0.805 to
  3.24 m). The front leaf (30 mm, three raised panels toward the window's middle) hangs
  on the lining by three brass knuckles at its back edge; the back leaf (28 mm, plain)
  hangs on its front edge by two and lies behind it. The 58 mm stack stands inside the
  blind frame's 0.16 m, so the daylight stays 0.98 m. Closed, the two would span the
  0.65 m to the middle, their plain backs to the room. The middle window's right pair
  (as seen from the room, toward the stove's end; the one style-01 looks at) stands 14° ajar, as
  result-2 and the precedent show, a choice made here. The wainscot's cap returns 1.5 cm
  into the reveal, its end square 5 mm before the leaves' front edges, its underside closed
  round the corner (`shell_mesh::cap_return`, the user: a shorter return rather than none;
  replaces its stopping square at the pier's corner, earlier the same day; the cap stands
  9 cm off the reveal and the stack 58 mm, so a longer return would cut into the leaves). The baked light takes
  them: the reveals' cells and the sun's rays on the reveals meet the stack's painted face
  in front of the lining, and the sky and the bounce pass the niche only inside the
  stack's front edges (`room_light::open_half`, `past_shutters`); the ajar pair is taken
  as folded there, and the sun's shader test (`shell_open`) still sees the whole niche,
  since the stack stands outside the daylight. The light tuner's `--shutters off` (H)
  leaves them out, the cap's return 6.5 cm as before. Replaces one 0.265 m box a side from
  7.5 cm in, which covered 41% of its half of the niche and could not close (the user:
  "tiny").
- The library's doors are hung in their frames (2026-11-21, task 107; part 2 of
  `build/notes/shutters/`; `shell_mesh::door`, `DOOR_*`): the leaves' face 1.5 cm behind
  the wall's (2 cm before: their plane 4.5 cm in, the stiles 2.5 cm off it), 4 cm thick, a
  3 mm joint round each leaf and between them with a dark stop behind, a 28 mm meeting
  bead 8 mm proud on the right leaf, three brass knuckle hinges with ball finials a leaf
  on the outer jambs at 0.30, 1.35 and 2.40 m (14 mm across, 120 mm long, the axis 7 mm
  before the face), and a lever on a 35 × 220 mm escutcheon on the right leaf, 6 cm from
  the meeting at 1.05 m. The doors open into the library as planned; the hall side stays
  unbuilt. `corner_shade` takes the leaf's face at 1.5 cm (it took the plane's 4.5). The
  brass is the curtains' (`surfaces::LOOK.brass`). Replaces the two leaves as one panelled
  face 2 cm in, with no joint, edge or ironmongery, which read as a panel in a shallow
  box.
- Brass reads as brass in a window's niche (2026-11-21, builder 19b; the user found the
  shutters' hinges too dark): brass (metal 1, not the books' gilt) takes neither the
  screen's occlusion nor the corners' shade, only its mesh's own, and inside a niche its
  reflection turns to the window's light (`lace_light`) by how far it faces out of the
  room, from 15% facing the room to all of it facing the glass or across the reveal. Two
  lines in `ROOM_FRAG`, +0.3 to 0.5 ms a frame at 1600 × 1000 on the Mac. Out of the niches
  only the occlusion goes: the doors' hinges a touch lighter in their joints, the lever and
  the curtain rod as they were. Replaces the dark marks kept the same day: the brass saw
  the room's box, which behind the glass gave the dark wainscot and paper, and the screen's
  occlusion made the lining's knuckles near black in their corner; the reflection alone
  didn't help while the occlusion stayed. Rejected: the occlusion line alone (the cheaper
  half, the knuckles only dark brown).
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
- The tie-back's loop is drawn tight and its tails hang on each panel's cloth (2026-11-23,
  task 107, `build/notes/lace-cord/`; `curtains.goose`'s `hug_ring`, `hang_tail`): the
  settled chain's loop kinked up and down by ±2.5 cm where it had slack and floated off
  the folds, and the tails lay on the simulation's ellipse, not on the cloth drawn, so on
  the panels hung wider (the 0.15 m hang) they stood off it or sank into it. The
  simulation stays for where gravity puts the knot and the loop's tilt; the loop drawn is
  its heights' mean and first harmonic round the bundle (a plane's tilt, down toward the
  knot), each point on the convex hull of the panel's own cloth at that height, grown by
  the cord's radius, so it lies on the folds' crests and bridges their valleys as a cord
  under tension does. Each tail, with its tassel as two more links as wide as its head and
  skirt, is relaxed from straight down (24 steps of 4 passes: fall, keep the links' length
  from the knot, stay in front of the cloth's front along the tail's line), so it hangs
  plumb where free and lies along the cloth bulging below the tie; the tassel turns with
  its last links. The run to the hook keeps its catenary, moved with the knot. The cloth
  still gathers round the chain's loop as it settled: the lace's pattern climbs from the
  hem, so gathering it round the loop drawn tight would move the pattern all the way up the
  drop. Triangles unchanged.
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
- The wainscot stops against a door's architrave with no gap, and the architrave stands
  on a plinth block wider and deeper than itself (2026-11-21, task 107; `shell_mesh`'s
  `BLOCK_PAST`, `BLOCK_DEEP`): the block 2 cm past the architrave's outer edge and 6.5 cm
  out (the architrave 5), over the skirting's end; the cap ends square against the
  architrave's side. Replaces a 1 cm gap between the wainscot and the architrave, where
  nothing covered the wall from the block up to the wainscot's top (it showed a thin olive
  sliver), and a block only a centimetre past the architrave and 6 cm out.
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
- What stands out of the library's walls and ends is a finite box in `corner_shade`
  (2026-11-21, task 107; `box_hides`, `holed_wall`, `span_seen`): the bookcases (base and
  upper case), the doors' plinth blocks, architrave legs and heads, the sills' noses, and
  the piers either side of a niche (its reveals, from the wall's face to the glass). Each
  face hides `plane_hides` at its distance times the share of its extent the point sees
  along each of the face's axes (the angle the span takes of the half turn across the
  surface, of the quarter turn along its normal), so the shade falls off past an edge and
  wraps softly round an outside corner, and fades out as the point's distance to the box
  nears the reach. A door's opening and a niche are holes in their wall's face (the leaf
  1.5 cm behind it since the doors were hung, 4.5 before; the niche open), so the floor before an opening and a sill's nose take
  no wall that isn't there. Replaces the endless planes: a case's side and front, the
  architraves' and the sills' edges cut at their ends, which left a 90° wedge of shade on
  the floor off each case's outside corner and hard lines along the openings' edges.
  The boxes go through one loop whose count the compiler can't know, the hall wall folded
  about the door's middle (the trims and the cases are symmetric), and a wall's opening
  is worked out only within the reach: unrolled, the nine boxes made the room's shader
  157 ms a frame at 1600 × 1000 on an M-series Mac (5.6 before), even where it returned
  at once; now 6.0.
- The library's corner and edge shade is baked, not worked out a pixel (2026-11-21, task
  110; `model3d::corner_map`). It depends only on the shell's planes and a surface's place
  and normal, so when the shell's mesh is made (and again when `rooms::Room.corners`
  changes, not while a slider is held) the CPU works the same function out once a texel
  into one R8 atlas, 4096 × 1013 texels (4.1 MB), in about 300 ms on an M1 Pro; `ROOM_FRAG`
  and the mirror's pass read it with one bilinear tap. The mesh is cut into charts, the
  triangles sharing a plane and their vertices (16,623; vertices copied where charts meet,
  47,608 to 73,044), each laid flat with 16 texels along each side, from 2.5 mm to 2 cm a
  texel, so a narrow jamb or a sill's nose keeps its steep shade; each texel takes the
  shade at the nearest point of its chart's triangles with the normal the GPU interpolates
  there, a texel no triangle reaches its neighbour's. A room vertex carries its place in the
  atlas and its chart's first and last texel (56 bytes, 40 before), and the tap is held
  inside the chart, as a pixel's middle past a triangle's edge would read another chart.
  Measured headless at 3024 × 1890, the room view, two rounds: the main pass 23.6 to 18.3
  ms, the mirror's room 1.8 to 1.2, the frame 27.6 to 21.7. The look: a mean difference of
  0.03 to 0.1 levels against 1.3 to 2.5 for the shade itself, one-pixel lines along edges
  seen at a grazing angle, a step a term makes inside a face softened over a texel; the
  game unchanged. Replaces the per-pixel `corner_shade` above (its model stays, in Goose).
  Rejected: a bake on the GPU (the same shader text, a few ms, but new pipelines in both
  renderers and holes where no texel's middle falls inside a thin triangle); per-vertex
  values (the walls and floor are a few large quads); a texture a plane in plan
  coordinates (a plane's faces overlap in plan at other depths, and the swept mouldings
  aren't planes); 1 cm texels on the large charts (9.6 MB, 860 ms, for a third fewer
  pixels over 8 levels).
- With the floor's mirror, the room's box is seen sharply only by the brass and the books,
  drawn with a pipeline of their own (2026-11-22, task 110's fix 2; `shaders::ROOM_SHARP`,
  `render3d::sharp_last`). In that shader only a metal ever took the sharp path (any
  other surface's `px` is 1, so its `sharp` 0), yet `room_seen`'s code alone made the
  main pass 18.3 ms against 14.9 without it at 3024 × 1890 on an M1 Pro, the room's
  shader being near the register limit: most of it the second probe lookup at the hit
  (2.2 ms), then the windows' loop (1.2), the sun through the windows at the hit almost
  nothing alone. When the mesh is made the brass's and books' triangles go last in the
  room's index buffer, and the board's pass draws them with `ROOM_SHARP`, the rest with
  `room_wide`, which is what `room_reflection` gave them. The main pass 18.3 to 15.1-15.4
  ms, the frame 21.7 to 18.4-18.7; the look unchanged but for one pixel at a brass edge;
  one pipeline more, made with the mirror's. Replaces the one shader for the whole room
  with the mirror on (the 2026-11-21 analytic reflection above stays as it was, and
  whole in the room's shader without the mirror, whose floor sees the box). Rejected:
  rearranging the code (one call site of the probes' lookup in a loop for the diffuse, the
  wide and the hit, 1.7 ms slower; the reflection worked out before the diffuse, 5.5
  slower; the window loops counted by a uniform, within 0.5), a cheaper hit (one layer
  of probes saves 1.6 ms, but changes the brass's reflections; a baked table of the box's
  walls goes stale as the leaves move and takes the last texture slot), both short of
  drawing the few triangles that need the code apart.
- The room is drawn with a pipeline per material group, each shader holding only its
  group's code, compiled per tier (2026-11-22, task 110's fix 3; `render3d::room_group`,
  `by_group`, `room_textures`, `make_room_tier`; `shaders::ROOM_FLOOR`, `ROOM_WALLS`,
  `ROOM_METALS`, `ROOM_GLASS`). The groups: the floor; the walls' surfaces (the panelling
  oak, the paper, the plaster and the ceiling, the paint and the sills, the cord); the
  metals (the brass, the books with their gilt), which see the room's box sharply
  (`SHARP_BOX`, as the floor does without the mirror); the glass and the lace, a mesh of
  their own. When the mesh is made its triangles are sorted into the first three groups'
  index ranges, and the board's pass draws each range with its pipeline. Why: the one
  room shader was near the Mac's register limit, so every pixel paid for the code of every
  material and path (fix 2's finding). Measured headless at 3024 × 1890, the room view, on
  an M1 Pro, two rounds, with the views below: the main pass 14.8 to 10.8-10.9 ms, the
  frame's GPU parts 18.1 to 13.7, the fps counter 17.3-17.9 to 12.9 ms a frame; at
  1512 × 945 the main pass 5.0 to 3.6, the frame 6.8 to 5.2. Each group alone in the main
  pass: the floor 5.7 ms, the walls 3.4, the glass 0.8, the metals 0.1. The look unchanged
  (17 shots within a level, as two runs of one build are; the game's unchanged).
  - The tiers are compiled, not switched by uniforms: the phone's pipelines leave out the
    screen's occlusion and the contact shadows (`NO_SSAO`) and make no mirror's; the
    standard and high tiers' have both. The pipelines are made for `ssao_allowed` and made
    again when it changes.
  - The floor's mirror draws the walls' and metals' ranges with their own pipelines
    (`MIRROR_PASS`: linear light, no screen maps, nothing seen sharply) and not the floor,
    which lies under its clip plane: the mirror's pass 1.3 to 0.73-0.78 ms.
  - The tonemap is a define (`LINEAR_OUT`, `ROOM_FRAG`'s `room_out` and `TABLE_FRAG`'s
    end): tonemapped sRGB for today's 8-bit targets, or the light itself, as the mirror's
    room and table now take it (the table's in place of its uniform switch, `ssao.w`
    -1). The HDR step can give the main pass's pipelines `LINEAR_OUT`; the view out still
    switches by its uniform.
  - Each group's shader declares only the textures it reads, without gaps (gfx counts a
    shader's samplers from 0; ngfx's root takes them in that order): at most 11 of
    ngfx's 16 (the walls with the screen's maps), so a new material's textures fit.
  - The light tuner's views (the screen's occlusion, the indirect light, the sun's
    highlights, the floor's reflection alone) cost 0.55 ms as uniform-off code, so they are
    pipelines of their own made while a view is on (`ROOM_VIEWS`, `room_views_on`).
  Replaces the one room shader with its `ROOM_SHARP` split above (the metals' group keeps
  that split), and the table's mirror switch by uniform. Rejected: splitting the walls
  further (their shader with only the plaster's code drew them 0.1 ms faster, without the
  oak's 0.26: less than a draw and a pipeline more pay for); keeping every texture in
  every shader at fixed slots (15 of 16 taken already); the views as uniforms.
- The high tier draws the 3D scene under a budget of 4.1 million pixels and scales it up to
  the screen with Catmull-Rom; the UI over it keeps the screen's pixels (2026-11-22, task
  110's fix 4; `render3d::scene_size_of`, `HIGH_SCENE_PIXELS`, `upscale_pass`,
  `shaders::UPSCALE_FRAG`). The room's passes cost about their pixels (the main pass
  10.9 ms at 3024 × 1890, 3.6 at 1512 × 945 on an M1 Pro), and a Retina or 4K screen
  draws more than the look needs. A screen over the budget draws the scene at the scale
  that fits it, keeping its shape (0.85 of a 3024 × 1890 screen's side, 0.70 of 4K's);
  under it, nothing changes. Measured headless at 3024 × 1890, the room view, two rounds,
  GPU ms by Metal's encoder labels: the main pass 10.9 at native, 8.2 at 0.85, 6.6 at 0.75,
  5.5 at 0.67; the frame's parts 13.7, 10.9, 9.1-9.2 and 7.9 (the last with nine taps);
  the fps counter 12.9, 10.1, 8.4 and 7.2 ms a frame. The upscale itself 0.30 ms
  (Catmull-Rom from five bilinear taps; nine taps 0.44 for the same look within a level,
  bilinear 0.11). The 0.85 keeps the lace's net and the board's grain close to
  native at 100%; 0.75 and under soften them visibly. The budget is the one constant to
  change; the light tuner's N cycles it against fixed scales and M the filter
  (`build/notes/builder-24/` shows the crops).
  - Everything the scene's frame draws follows its size: MSAA's or SMAA's targets (the
    antialiasing is done before the upscale, which keeps its edges), the screen's
    occlusion at half the scene, the glow at a quarter. The floor's mirror keeps its least
    width of 1600 texels, so at these scales its map is the same and its cost falls only by
    the pixels reading it (0.77 to 0.64 ms at 0.85).
  - Only `draw()` into a given target scales (the light tuner's screen, and the high mode
    when it draws every frame); the app's kept image is drawn at the screen's size, so the
    standard tier and phones are as they were: the 3D board at native pixels with 4× MSAA
    (2× on a slow Android device), and no room yet. The game's shot is unchanged.
  - Rejected: bilinear (0.2 ms cheaper, but at a scale it kept a quarter to a third less
    of the high-frequency detail than Catmull-Rom, the lace's net and the grain smeared);
    FSR1's EASU and RCAS (an edge-adaptive filter of twelve taps and a second pass at the
    screen's size, for the softness 0.85's Catmull-Rom hardly shows); a fixed scale (a
    pixel budget caps the cost on any screen, and a smaller window stays native); folding
    the upscale into the glow's add (0.15 ms, both shaders' code for it).
- The scene's resolution budget is off by default: the 3D scene draws at the screen's native
  size on every screen (2026-11-22). It replaces the budget's default above; the code stays
  (`render3d::scene_size_of`, `scene_pixels`, `scene_scale`, `HIGH_SCENE_PIXELS`,
  `upscale_pass`), and the light tuner switches it on with `--scene-pixels`, `--scene-scale`
  and N. It is meant to become a "render scale" setting: native by default; an auto mode
  that lowers the scale only while frames miss the display's refresh; and a fixed 4.1 MP
  cap as a manual choice. A cap chosen for one Mac's Retina screen doesn't fit a 4K monitor,
  an ultrawide or a desktop GPU, which may draw native at full rate; only a measured miss
  should cost the picture its sharpness.
- The doors' and windows' painted wood takes the paint research's quiet variant, drawn
  with a pipeline of its own (2026-11-22, task 107; `build/notes/paint-research/`,
  `room_shell`'s `joinery.goose` and `relief.goose`, `shaders::ROOM_PAINT`,
  `render3d::GROUP_PAINT`). Old oil paint on pine reads quiet: soft rounded arrises, dirt
  in the quirks, a hairline at each joint, each piece catching the light a little
  differently, and brush and grain only in the sheen under grazing light. So, in the order
  the research gives, each step judged in shots: (1) the shape in the mesh: fillets 1.2 mm
  on the doors and 0.9 mm on the windows, the quirks 40% shallower, each piece tilted
  about 0.2° and each panel cupped 0.8 mm; (2) the lines from distances the mesh carries in
  its uv: a 3 mm dirt band in the recesses (−9 to −14%, toward a warm grey, rougher) and a
  0.3 mm hairline at the joints, both filtered over the pixel; (3) one relief tile made in
  code at startup, driving the normal and the sheen, never the colour. Sheen 0.36 on the
  doors and 0.42 on the windows; the colour `#c6beae`, a percent's tone a piece. The
  tile's heights are twice the research's quiet ones (a 5 µm brush): at its own they made
  at most 7 levels' difference in a close-up at 0.2 mm a pixel in the sun, nothing to see.
  - Its own pipeline: the walls' shader lost the paint's code and the paint's has only
    its own (the sills' stone stays with the walls), so the quiet paint's cost falls on
    its pixels. Measured headless at 3024 × 1890 on an M1 Pro, the room view, GPU ms by
    Metal's encoder labels, two rounds alike: the main pass at native scale 10.86 before,
    10.66 with the split alone, 11.10-11.11 with the quiet paint; at the 4.1 MP budget
    8.19 and 8.41-8.43; the salon door's view at native 5.43 and 5.68; the frame's parts
    13.68 and 13.99-14.00; the fps counter 12.8-12.9 and 13.1 ms a frame. Of the quiet
    paint's 0.44 over the split, its mesh 0.18 (the fillets 0.12) and its shader 0.25
    (the tile's fetch 0.05). The mesh 35,074 to 37,906 triangles (made in the same 12-14
    ms), the corners' map 16,623 to 18,159 charts in the same 0.29 s, the tile 25 ms and
    1.4 MB.
  - A fillet's normal turns through 90° over a millimetre; a pixel's middle past the
    strip's edge reads it far beyond, and the arrises shaded in dashes. The shader holds
    it within 46° of the strip's own plane. Some dashing stays where a 0.9 mm fillet is a
    fraction of a pixel (a casement's cover strip at 2 mm a pixel).
  - Under a pixel the fillet takes the normal of the face that faces the eye more
    (2026-11-23, `build/notes/paint-edges/`): the sunlit casements' edges and bars showed
    bright dots that crawled as the eye moved, the strip being a few of a pixel's samples
    shaded at its middle. Faded in as the mesh's normal turns 0.8 to 2.2 of its 1.41 within
    a pixel, so at a metre's distance (two pixels at 4K) the eased edge still catches the
    light. Rejected: the strip's own plane (a lit 45° line the samples still dashed) and the
    face on the pixel's middle's side (it flips along a slanted edge: the dashes again).
  - The mesh is closed where it cracked (2026-11-23): side faces along the grain and the
    fillets beside them are split where the front's edge is, and fillets across the grain
    are whole, so no vertex lies on another face's edge; a fillet's end that meets no
    other rounded edge is closed out to the box's corner. The T-junctions showed the
    glass through as single dots at the outer casement's stiles. The shell 37,906 to
    40,182 triangles.
  - The light tuner keeps the old paint one key away (J, `--paint old`) and switches each
    step alone (`--paint-off fillets,tilt,dirt,joints,tile`, `--paint-relief K`), in a
    shader of its own (`PAINT_STEPS`) used only while a switch is off, so the app's has no
    switches.
  - Rejected: the materials pass's paint (`build/exp/materials`, 2026-11-21, judged far
    worse): the wainscot oak's coarse figure as relief under the paint (joinery here was
    pine, its pores filled by many coats), 0.2 m value-noise "brush" cells that read as
    soft streaks a few centimetres wide at every distance, relief in the diffuse at full
    strength rather than in the sheen, and edges and the hand's zone worn to dark oak by
    screen-space curvature, which crawls and reads as dirt or rust. Also left out for now:
    the research's lived extras (chips to an older coat, hand grime and burnish, kick
    scuffs, a per-leaf door map), the user's to choose.
- The window view's first steps, each in the pipeline it belongs to (2026-11-22, task 107;
  the plan `build/notes/window-view/`, built by builder 27, `build/notes/builder-27/`): the
  lace hung 0.15 m further over the openings on all three windows, so the low sun reaches
  its inner folds; the sun's shadows on the lace at their full depth, a little stronger
  than the room's lifted shade gave them, and the lit cloth glowing 60% more; a soft share
  (0.35) of the sun the lace stops scattered on below it in a cone about 25° across; a
  broad veil of about 10° round the sun in the sky; dust motes over the games table, lit
  by the sun at each mote through the bars, the lace and the leaves, a pixel or two
  across, only in the view from the table; and the glass's wiped film and cleaning
  scratches from a tile made in code, faint, showing only toward the sun.
  - No god rays: the dust is particles lit where they are, never light scattered in the
    air, which is what draws shafts; and no starburst round the sun.
  - No tree is drawn through the glass and no new wind (the plan's W4 and W6): the tree
    is a research of its own (`build/notes/tree/`). The veil is only the sky's.
  - Each step is a strength over its look's (`render3d::window_view`, `sun_veil`; 1 as
    made, 0 off), not a tuner-only shader variant: at 0 the room matches the build before
    exactly (one pixel of the room view by a level), the old paint and stone too, and the
    game's shot is unchanged in both renderers. The light tuner's Z switches them all.
  - The lace's light below lives in `LIGHT_FN`'s `shell_open`, which every room group
    shares, from the same `lace_shadow` call as the shadow (the outline blurred wide times
    the pattern's mean stop): a second call cost 1.05 ms on and 0.39 off. It still costs
    0.70 ms of the room view's main pass at 3024 × 1890, the most of the steps, because
    every pixel it reaches shades the sun; kept on as asked, its cost an open choice.
  - The scratches follow Raymond et al.'s cone (a groove glints where `t · (l + v)` is
    near 0), the film a Henyey-Greenstein lobe (g 0.75); both are skipped past 35° from the
    sun. Rejected: the plan's per-pane turn of the tile (each window and sheet takes an
    offset of its own), the near, out-of-focus dust discs (the dust is to be a few pixels
    at most).
  - Costs, headless 3024 × 1890 on an M1 Pro, the main pass, two rounds alike: the room
    view 10.95 before, 11.08 with every step at 0, 11.94-11.95 with all; the table-window
    view 4.58, 4.75, 5.04-5.05; at the 4.1 MP budget the room 8.28-8.32 and 9.04-9.05,
    the table-window view 3.59 and 3.94 (each step's share in task 110).
  - The scratches thinner and half as many, the film a quarter fainter (2026-11-22, task
    107, builder 31): from the table a millimetre texel drew 3-4 px hairlines at 3024 ×
    1890, so the tile is half a millimetre a texel (1024 texels, 5.6 MB with its mips,
    about 210 ms to make once), 35 arcs and 12 straight wipes; the film scatters 0.0015
    of the sun, was 0.002. Rejected: a finer tile repeating every 0.256 m (it would
    repeat inside a pane). The main pass unchanged.
- The lace's room-side fill is lowered in the shade and in its folds' valleys (2026-11-23,
  task 107, `build/notes/lace-shade/`; `render3d::lace_shade`, the light tuner's
  `--lace-shade-fill` and `--lace-fold-ao`): where neither the sun nor the sky behind the
  niche reaches the cloth its fill is half (0.5), and the folds beside a point take 1.5 times
  their baked depth off it (`curtains.goose`'s `fold_hidden`, up to 0.4, so the deepest
  valleys keep 0.4 of it). The user's pick, by eye against the references there: the lace
  read far more realistic, its folds deep where the room's light can't reach. Replaces the
  fill at full strength everywhere (1 and 0, the tuner's first defaults).
- The board and the table in the room take the sun through the shell's own windows
  (2026-11-22, task 107, builder 29, `build/notes/builder-29/`), as the room's surfaces do
  (`LIGHT_FN`'s `shell_open`; `shaders::LIT_SHELL`, `TABLE_SHELL`). Before, they took the
  game's window, whose opening stands on the line from the board's middle to the sun: a
  sun turned 30° across the window wall lit the board through the pier beside the
  window, and at today's 20° the board, behind the casements' frame, was still lit. The
  game keeps its window; only the room's pipelines changed (the HDR lit and table ones, the
  room's table and its mirror, and an 8-bit `lit_shell` made when the shell shows), so the
  game's shot is unchanged in both renderers.
  - The box window bounds the sun's angle: its two casements 0.2 m apart in a 0.8 m wall
    narrow an oblique beam, so the board at the table as made is lit within about ±10°
    across the wall, to about 25° with the table moved along the wall, hardly past that.
    The sun's turn and height and the table's place are the user's choice from six options
    the light tuner's `--sun-check` verified (`--table-at` moves the table); none is the
    default yet.
  - Costs, headless 3024 × 1890 native on an M1 Pro, the main pass, two rounds: the
    table-window view (option 2's sun, the dust off) 8.18-8.28 to 8.84-8.90 ms, `shell_open`
    on the board's and the table's pixels; the room view unchanged within the rounds'
    spread (11.73-11.90 to 11.87-11.90).
- Light through the shell's windows lands only where the glass lets it (2026-11-22, task
  107, builder 30, `build/notes/builder-30/`). The lace's light below came from the niche's
  arched outline, not the glass: a faint arch of light, with the tree's dapple in it, stood
  round every sun patch on the wainscot, the doors, the floor and the games table, where the
  frame, the sashes' surround and the plaster round the niche should have kept it out; and
  the lace glowed in the same arch from the sky it took to see through the whole niche. Now
  the cone's light is cut to the casements' glazed opening at both glass planes, blurred as
  wide as the cone (`LIGHT_FN`'s `glazing`), and the lace sees the sky only through that
  opening (`sky_behind`). The lace's own shadow had been blurred 3 cm a metre over the
  sun's penumbra, 0.3 m at the far wall, so the panels' inner edges over the glass left no
  trace in the patch; at 0.6 cm a metre (`LACE_SOFT`) their pattern shows on the patch's
  sides where the lace hangs in the sun's path. Which rays the lace meets is geometry: at a
  sun square to the wall only the patch's far part comes through the glass the hung lace
  covers (the upper sash's outer panes), an oblique sun covers more on one side.
  - The game's shot is unchanged in both renderers (all of it is `SHELL_WINDOWS` code).
    Main pass at 3024 × 1890 native, two rounds: the room view 11.84-11.85 to 11.98 ms,
    the table-window view 9.02 to 8.95-8.97.
- The menu scene's sun, table and board start from library-home-01's sun and sit two
  players across the beam (2026-11-22, task 107, builder 30, `build/notes/builder-30/`).
  - The concept's sun is about 20° across the window wall, from the left as seen from the
    room, and about 12° up: its level camera puts the disc 20° left of its axis and 12°
    above it at a 60° lens (9-15° up for 75-50°). Seen from the table-window view's chair
    the same pane needs it 29° up. With the table as made, `--sun-check` lights none of the
    board's field at either height (0 of 81 points): the oblique beam ends on the sash and
    the frame of the 0.8 m deep box window. Moving the table 0.375 m toward the stove's end
    (4.125, 5.8: still 1.2 m from the wall, its middle in front of the middle window) lights
    all of it (81 of 81) at both heights; between 12° and 29° up the height changes nothing,
    all of it the lower sash. So the concept's sun stays, the table moves; past about 25°
    across the wall no place lights the whole field (72 of 81 at 25°).
  - The players sit across the beam: the board's own axis between them square to the
    sun's way across the floor, the board turned by minus the sun's turn (-20° for the
    concept's). Both get side light; neither faces the glare or shades the board; and the
    field, seen along the beam, is 0.28 m wide, inside one leaf's 0.37 m of glass (square
    to the wall it is 0.36 m, a stile's shadow across two corners: 73 of 81). Each chair
    has 0.9 m behind the table's edge (its 0.5 m and room to pull it out) clear of the
    walls, the sills, the lace, the doors' swing and the bookcases; no chairs are modelled
    yet. Rejected: across the wall (the window-side chair has 0.725 m to the
    wall, too little, that player's back shades the board and the other faces the glare);
    the concept's table in front of the pier (`concept-pier`, 3.625: lit, but its middle
    0.225 m past the niche, against the plan) kept only as an option.
  - The table's top turns 25° under the board, so its figure no longer runs square to the
    board's; its base turns with it. The room's table only, a tuner's value for now.
  - Six placements, each verified by `--sun-check`, are on the light tuner's A key and its
    `--place` flag; none is the app's yet, the user picks. Costs: as before within the
    rounds' spread (task 107).
  - The menu scene's placement is `less-turned` for now (2026-11-22): the sun 12° across
    the wall and 15° up, the table at 4.4, 5.8 (0.1 m off the plan's place), the board
    turned -12°, the top 25° under it. The tuner starts there without `--place`; `--place
    free` gives the other flags' own. The other five stay on A.
- The table-window view's dust is flakes and lint in the sunbeam (2026-11-22, task 107,
  builder 29), replacing builder 27's round points in a box as the default: irregular
  flakes and short fibres a pixel or a few across at 3024 × 1890, each tumbling slowly on an
  axis of its own and glinting as a face (a fibre's length) turns square to the sun and the
  eye, dim between; placed in the beam's own volume over the table round the board (sheared
  as the sun comes in), lit only by the sun straight through the glass, never by the shade's
  floor or the lace's scattered light, and not drawn where unlit. Three densities (40, 90,
  220 motes); the old round points stay a switch away. Measured as above: 0.0-0.1 ms over
  the dust off whatever the density, the old points 0.04-0.19.
  - The beam's haze, an experiment off by default (2026-11-22; it relaxes the "no god
    rays" rule above for this one switch only): 900 faint, even sprites 8 cm across in the
    motes' volume, lit as they are, so a slight in-scatter shows the beam with the bars'
    stripes. It costs 0.8 ms of the main pass (9.72-9.74 against 8.90-8.98), the sprites'
    overdraw; a strength of 0.0004 is subtle, 0.001 reads as smoke. A ray-marched in-scatter
    over the beam's volume would be the alternative if it is kept. Replaced on 2026-11-22 by
    the analytic haze below.
- The table-window view's dust is real dust's points (2026-11-22, task 107, builder 33,
  `build/notes/builder-33/`), replacing builder 29's motes as the default (they stay as
  `--dust motes`, matching their old picture within a level). Each mote is a fixed Gaussian
  footprint (sigma 0.75 px) at any size and distance, carrying the light it really scatters:
  the sun's irradiance as the room's surfaces take it × its cross-section × its phase
  (Henyey-Greenstein g 0.7 with a fifth isotropic, plus a narrow lobe toward the sun) ×
  pixels a metre squared, so its brightness is energy-conserving over the footprint. Sizes
  are log-normal; 15% are fibres, 10 µm thick and 0.5-3 mm long, drawn as projected lines a
  pixel wide; flakes glint for a few frames as they tumble. They drift, rise where the air is
  warm, settle by size and swirl in four divergence-free waves, all in world cm a second and
  none random a frame. Three densities, 250, 500 and 1000 points in the beam's volume, denser
  round the board. With the lens on each point is the lens's disc, its light spread over it.
  - Exact points are about 40× too faint to see against the shaded wainscot; a factor of 40
    (`--mote-bright`) stands for the camera exposed for the window, where the larger motes
    show. They then read about as visibly as the old motes.
  - Measured as above (the menu view, two rounds): the main pass 9.87-9.92 ms against
    9.81-10.06 with the dust off and 9.83-9.90 with the old motes; the dust's own pass
    0.24-0.34 ms whatever the dust. The points cost nothing measurable.
  - The lens's discs are drawn in the scene's pass for now; they move after the depth of
    field's blur when it comes.
- The beam's haze is analytic (2026-11-22, task 107, builder 33), replacing the sprite haze;
  an experiment off by default, in the light tuner only (`--haze`), needing the room's
  pre-pass. The sun is one direction and the glass flat, so how much sun reaches any point
  is what passes the beam's cross-section where the point maps along the sun onto the outer
  glass's plane. A small pass draws that cross-section each frame into an atlas, a slot a
  window: the panes' coverage, exact (each sash of the outer glass cut by one of the inner
  glass's and the niche's opening is a product set of columns and rows), times the lace and
  the tree, sharp and blurred. The haze, at the pre-pass's half size, carries each pixel's
  view onto that plane, where it is a segment, and averages the atlas over 12 jittered taps
  along it; the stripes blur with the depth from the glass as the sun's disc widens the
  bars' shadows. That lit length × sigma × the phase (g 0.7, a fifth isotropic) × the room's
  sun is added into the HDR target before the glow. Strengths: the air's sigma 5e-5, 1.5e-4,
  4e-4 a metre (clean, lived-in, just dusted, the research's estimates) and 3e-3 with its
  stripes four times as soft (the ChatGPT study's beam).
  - Looking toward the sun the stripes converge on it and read as light shafts; a softness
    that grows toward the sun (`--haze-toward`, 4 in the study's preset) melts them into
    the beam, which keeps to the "no god rays" rule above.
  - Rejected: walking the panes exactly for every pixel. Its first version, a few hundred
    rectangles a pixel, cost 3.7-4.0 ms at half size (14.9 at full); walking the product
    sets instead made the clip cheap but the pass stayed at 3.4 ms, the lace's and tree's
    code costing registers even where it never ran (2.1 ms without it). With the atlas the
    haze's three passes take about 0.7 ms at 3024 × 1890 (the cross-section 0.15, the haze
    at half size 0.34-0.37, its add 0.18-0.22; two rounds, the menu and the room views
    alike, every strength), the frame's GPU sum 0.5-1.0 ms over the same view without; at
    full size 1.5-1.8.
  - The old soft stripes, the panes grown and shrunk, added light where a shrunk pane
    vanished: about 40% more than the sharp beam. The blurred atlas keeps the sharp beam's
    light, so the study's sigma went from 2e-3 to 3e-3 for the same look.
- The dust and the haze are the main menu's scene's only, never the game's (the user,
  2026-11-22; task 107, builder 34, `build/notes/builder-34/`). The light tuner keeps only
  the points (`--dust off|points|points-few|points-many`, D cycles them): builder 27's
  round points in a box and builder 29's flakes and lint were taken out of the tuner, the
  shader and `render3d::Dust`, which replaces the two entries above for the dust's ways.
  - The fibres among the points read as stripes: they are now half a point's footprint
    across (sigma 0.375 px at 3024 × 1890), sub-pixel, with their light kept, so each is a
    fainter, thinner line (`--fibre-width`, 1 the old width; `--mote-fibres 0` none). The
    points themselves are unchanged.
  - The haze's levels, the user's (2026-11-22): the main menu's scene at the study's (sigma
    3e-3 a metre, its stripes four times as soft and softer toward the sun, 4) with the
    motes; the game's own scene, should it get haze, at just dusted (4e-4; the user's slider
    sat at about 4.5e-4, "certainly not more"). The tuner's `--haze menu` and `--haze game`
    give them; the haze stays off by default and nothing of it is in the app yet.
- The depth of field's groundwork for the scenic views (2026-11-22, task 111; the plan
  `build/notes/bokeh/`'s B0 to B2, built by builder 28, `build/notes/builder-28/`): one lens
  for every pass that will blur, the scenic views drawn in HDR, and a sampled depth of the
  scene. Nothing blurs yet. The user's choices: depth of field only for artistic scenes
  (the menu's and a few more, never the game), on the high tier; tablets the cheap
  fallback later, phones none; the concept's flat disc the default lens; a fixed aperture
  per scene, the focus pulled in dioptres over about 2.2 s.
  - The lens is a thin lens written as a tuner wants it: a disc's radius aperture ×
    |1 − focus / d| of the width, the aperture the radius at infinity (independent of the
    field of view), capped before and behind the focus. The motes already followed that
    shape, so they take it when it is on.
  - HDR: 4× MSAA in RG11B10F (as many bytes as the 8-bit target, MSAA kept for the bars,
    twigs and the leaves' coverage), RGBA16F MSAA where RG11B10F can't be drawn into;
    rejected 1× RGBA16F with SMAA. Measured headless at 3024 × 1890 on an M1 Pro, two
    rounds alike: the room view's main pass 11.93-11.96 ms in 8 bits, 11.63-11.64 in HDR,
    the tonemap's pass 0.45-0.46 after it, the frame's GPU parts 14.90-14.93 to
    14.82-14.84; the table-window view 5.02-5.04 to 4.65-4.66 and 0.43-0.44 (7.46-7.58 to
    7.39-7.48); at the 4.1 MP budget the room 9.02-9.03 to 8.81-8.82 and 0.35, the frame
    11.87 to 11.85-11.86. The pipelines gain what they no longer tonemap; the pass costs
    about that again. RGBA16F's main pass 0.1 ms dearer and its targets 114 MB more at that size.
  - Each pipeline keeps its own tonemap's toe (the room's on the luminance, the board's and
    the table's on the least channel) and the shoulder, grade and dither move to the pass
    after: the toe only lowers the darkest 4%, which no disc will show, and one tonemap for
    all stays an open choice (the toes' switch above). The surfaces then match the
    8-bit picture within 2-3 levels (the dither and RG11B10F's steps). What differs is
    what blends: the lace and the glass over the sky now mix in linear light, so the lace
    reads lighter and more opaque, and the glass's film and scratches, added at the sRGB
    curve's slope over a bright sky (0.5) in 8 bits, add their light linearly, by the
    curve's slope about three times stronger over the darker tree than over the sky; the thin bars against the sky
    resolve in linear light, a little thinner. These are left for the user to retune in
    HDR (the shots page), not hidden by a compensating factor.
  - The glow keeps reading the tonemapped picture for now: from the HDR light it needs its
    threshold retuned, and it belongs after the depth of field (B4).
  - The depth is its own 1× pass (the main pass's is multisampled, which SDL can't
    sample), DEPTH32F, the lace written where its thread covers half the pixel; the view out
    writes none (its own layer gets the tree's depths in B3). The tuner's views (the
    distance, the lens's signed disc) are drawn from it. It costs 0.19 ms at 3024 × 1890 in
    either view (0.16 at the budget), its view 0.13; 23 MB at native, as the HDR resolve.
  - Kept in the tuner only: the app draws no scenic view yet (`hdr_allowed` is off), so the
    game, the standard and phone tiers and the app's kept image are unchanged; the game's
    shot is identical in both renderers. ngfx has the same pipelines, passes and
    targets (its multisampled one transient), not yet run in a scene.
  - A NaN in the glass's scratches (`atan(0, 0)` where no groove is) dropped those pixels'
    added light in 8 bits and blacked them in HDR; fixed, 34 pixels of the table-window
    view gain their glint (up to 7 levels).
- The scenic views' glow is drawn from the HDR target's linear light, before the tonemap
  (2026-11-22, task 107, builder 32, `build/notes/builder-32/`; `render3d::glow_pass`,
  `HdrGlow`, `shaders::GLOW_DOWN_FRAG`, `GLOW_UP_FRAG`). This replaces, in HDR, the window's
  glow of 2026-11-21, which read the tonemapped picture's near-white and so could not tell
  the sun from a white sky; the 8-bit path keeps that one as its fallback. Light over a
  threshold (1, a soft knee of 0.5) is picked into a quarter of the picture (a 4 × 4 block a
  texel), halved five times with Bjorge's dual filter (5 taps down, 8 up) and widened back,
  each level blended over the one above by the reach (0.65), so the levels' shares sum to
  one; the tonemap's pass adds it times the strength (0.06), which round the windows looks
  like the old glow. One step, not a one-off for the sun: the bokeh's composite (B4) takes
  it. Rejected: a Gaussian at a quarter (the old glow's, too short a reach for a sun's
  bleed without many taps) and an energy-based glow with no threshold (it softens the
  whole room). Cost at 3024 × 1890 on an M1 Pro, two rounds: the glow's passes 0.38-0.44 ms
  (the first pick, reading the whole target, 0.23-0.24), the tonemap's pass 0.08-0.10 ms
  cheaper as it now writes the target itself, so the frame is 0.08-0.28 ms cheaper than with
  the old glow; six RGBA16F levels, 3.8 MB. ngfx has the same passes,
  built but not yet run in a scene, as the rest of HDR.
- The sun in the view out has a look of its own, picked by the user from builder 32's
  presets (2026-11-22: open; `render3d::SunLook`, the light tuner's `--sun-look`): the
  disc's radius, limb darkening, edge and brightness, the haze's halo as a tight core and a
  wider glow. Until the pick, the made look: the disc 0.27° at 30 times the sky. With a
  brighter disc the glow above is what bleeds it over the leaves, the bars and the frame.
  Today's tree is seen against the sky round the sun from its shadow's own map, looked up
  along the view (`OUTSIDE_FRAG`'s `tree_seen`, off in the made look), so the leaves over
  the sun are the ones whose shadows dapple the board, moved by the same wind; seen in the
  whole window it costs the menu view's main pass 0.35-0.45 ms.
- The sun keeps the made look with builder 32's HDR glow (2026-11-22, task 107; replaces
  the open pick above): the glow alone shows where the sun is. Builder 32's presets (real,
  tight, concept, soft) are dropped, as are the sun research's looks
  (`build/notes/window-view/refs/research-sun.html`, `build/notes/builder-34/`) a, c and d.
  Look b, the eye's veil round the sun in the tonemap (`HDR_TONE_FRAG`, scaled by the sun's
  open share), stays as a switch, off by default (the light tuner's `--sun-look veil`): it
  looked overdone against open sky but may suit a sun behind thick leaves, to be tried
  again with the new maple. Rejected: hairline needles out of the sun (look d), and a
  narrow forward lobe in the lace toward the sun (the lace near the sun already glows in
  the HDR glow without it).
- The eye's veil is on by default at a third of look b's strength (2026-11-22, task 107;
  replaces "off by default" above): `--sun-eye 1,1.5,20,1`, the user's pick in the app.
  Look b's full veil (3) stays the `--sun-look veil` switch, overdone but for corner cases.
- The windows' sills are a Vasalemma-type limestone, drawn with a pipeline of their own
  (2026-11-22, task 107; `build/notes/paint-research/`'s sill section,
  `room_shell`'s `limestone.goose` and `shell_mesh::sill_slab`, `shaders::ROOM_SILL`,
  `render3d::GROUP_SILL`). Of the research's three stones (the materials pass's clouds and
  round specks, a Saaremaa-type dolomite, a Vasalemma-type crinoidal limestone) the
  Vasalemma one, for its speckle, which the concept's sill shows; with the wear a sill
  gets: a patchy band polished by hands, an eased arris with a few chips, a darker nose
  toward its foot, a dust line before the glass. Nothing else of the research's
  (laminae, stylolites, fossils, rust) is in it.
  - Its own material (`surfaces::MAT_STONE`) and pipeline, the walls' shader without the
    stone's code: the shaders where they belong, no one shader for everything. This ends
    the stone's place in the walls' group, which the painted wood's split above kept.
    Drawn before the paint, as in the walls' draw, so faces that tie in depth resolve as
    before.
  - The speckle is a tile made in code when the shell first shows (1024 texels over
    256 mm, 67 ms, 5.6 MB with its mips), its albedo over the stone's mean: the
    stone's colour stays the old one's (`Look.stone`, `#b6b2a8`), so the baked light's
    albedo for the sills (`room_light::STONE_ALBEDO`) still holds and the room's bounce
    doesn't change. The research's Vasalemma base was a little paler, `#bdb9b0`.
  - The arris is eased in the shader, not the mesh (4 mm, the normal turned toward the
    arris by the distance the mesh carries in its uv, spread over the pixel when it is
    under one): the mesh keeps its triangles, and it filters where the paint's
    millimetre fillets in the mesh dash. Chips, about one in 30 cm, 0.8 to 2.5 mm.
  - The nose 6% darker at its foot in sRGB (13% of its linear albedo; at 6% linear it
    moved 4 levels, nothing to see); the band from 25 to 70 mm back, its roughness 0.55
    to about 0.33; the dust's line fading over 2 cm (12 mm showed only as a hairline
    beside the frame's contact shade).
  - Measured headless at 3024 × 1890 on an M1 Pro, GPU ms by Metal's encoder labels, two
    rounds alike: the room view's main pass at native scale 11.11 before, 10.92-10.93
    with the split alone, 10.94-10.95 with the limestone; a sill close up 5.93-5.94,
    5.76 and 5.78-5.79; at the 4.1 MP budget the room 8.41 and 8.28, the sill 4.58 and
    4.47; the fps counter 13.1 and 12.9-13.0 ms a frame (room, native). The split saved
    0.18 (the walls' shader without the stone's code), the limestone costs 0.02-0.03 over
    it. The mesh the same 37,906 triangles.
  - The light tuner keeps the old stone one key away (I, `--sill old`) and switches each
    part alone (`--sill-off speckle,band,arris,nose,dust`), in a shader of its own
    (`SILL_STEPS`) in the room and the floor's mirror, used only while a switch is off.
    The old stone matches before within a level but for a few dots along the nose's sharp
    arris (up to 21 levels at 7 pixels of 1.6 million, derivatives at the edge compiled in
    another shader); the game's shot unchanged (both renderers).
- The library's baked light bounces three times (2026-11-21, task 107;
  `room_light::first_light`, `bounce_once`, `gather_half`): the room's surfaces as 1,208
  cells, about 0.5 m a side on the floor, the ceiling and the four walls (a door's leaf, a
  bookcase's front, the paper, the wainscot and the cornice each by its share of the cell,
  the windows' openings left out), 0.2 m in the niches (sills, reveals, heads), the
  table's top one more, and the lace before each niche in four bands a panel as a source
  only. Every source goes in: the sun's rays deposit into the cells they land on, the sky
  through the niches lights every cell it reaches (the floor, the sills, the reveals), the
  lace throws on what it stops. Each bounce gathers cell to cell (each a small lambertian
  light, the distance kept to about the cells' size, no cell taking more than the whole
  room's light), the thrown light taken toward grey as the sun's patches are. The probes
  keep the sun's patches exactly as before and gather the rest on a grid of half their
  density (15 × 13 × 7), spread trilinearly over all 10,140. Cells finer than half a
  metre were rejected: the probes read the light at 0.3 m and half a step out, so finer
  cells change nothing they show and cost the square. Replaces the single bounce of the
  sun's patches with the sky's light ending where it landed. The bake takes about 87 ms
  on an M-series Mac (47 before), into fixed buffers (about 0.2 MB), still never per
  frame. Against the ChatGPT repaints of our room (`02-style-01`, `03-autumn-02`, sRGB
  luma): the hall wall's wainscot in shade 8 to 10% (theirs 10), 7 to 9% (8); the paper
  in shade 11 to 17% (18), 15 to 21% (18); the ceiling 49 to 53% (49), 49 to 53% (40);
  the window wall's wainscot 6 to 7% (15), 4 to 5% (13). The exposure stays: lifting it
  for the window wall would take the ceiling and the paper past the references; that wall
  is dark because the floor's sun patches it would see are a tenth of theirs.
- The curtains' lace in the baked light and its sun shadow (2026-11-21, task 107;
  `room_light::lace_lets`, `LIGHT_FN`'s `lace_shadow`): the lace lets 0.72 through where
  a panel hangs at its 2× fullness (0.55 m wide, at the rod) and that to the power of how
  many times narrower it is gathered, about a third at the tie and 0.6 at the hem, for the
  sun's rays, the sky and the bounces alike; of what it stops, 0.4 it throws on into the
  room as a soft source (its thread near white, half of it scattered forward). Its sun
  shadow follows the same rule, its pattern half washed out (the lace scatters forward
  much of what it doesn't let straight through) and blurred by 3 cm a metre past the
  sun's disc, so it reads faint, soft and dappled beside the bars' crisp ones: on the
  floor it now stops 13% on average where it falls, at most half under the gathered
  folds. Replaces the flat 0.72 everywhere and a shadow as sharp as the bars', its
  densest parts stopping two thirds at the sun's own softness.
- The games table takes the room's baked light in the room (2026-11-21, task 107;
  `render3d::probes_on_table`, `TABLE_FRAG`'s `room_light_at`): the probes sampled on the
  CPU after each bake at four heights on the table's axis (0.15 m, then 0.3 m apart up to
  just over the top), each colour's constant and direction turned into the world's, ride
  in the table's block; `TABLE_FRAG` mixes them by height, with the harmonics and the even
  bounce the room keeps, at the room's exposure under the top and the board's over it (the
  room's lifted the top's shade grey and drowned the sun's dapple on it). The polish
  reflects that light by the room's mean albedo, 0.2, as `ROOM_FRAG`'s rough reflections
  do. The base in shade no longer reads near black; the top in `library-menu-01`'s camera
  13% luma (9 before, the repaint 34). It is a variant of the table's shader by a define
  (`shaders::TABLE_ROOM`, its own pipeline in both renderers, made with the room's): the
  room's branch in the one shader moved a pixel of the game's shot by one level, and a
  Mali compiles every branch; the game's table shader is as it was, its shot unchanged. Rejected: the probes' texture in the table's pipeline
  (a binding more in both renderers' roots for a table 0.95 m across, which four samples
  cover). The shade's floor of the key (10% in autumn) stays on the room's surfaces and
  the table beside the baked light (`render3d::shade_fill`, the tuner's `--shade-fill`):
  without it the hall wall's wainscot in shade fell from 11 to 6% at style-01's camera
  (the repaint's 10), the paper from 18 to 13% (18), the floor from 18 to 13% (27); the
  probes don't carry that much yet.
- The library takes screen-space ambient occlusion in the standard and high tiers
  (2026-11-21, task 107; `render3d::ssao_pass`, `shaders::PRE_FRAG`, `SSAO_FRAG`,
  `SSAO_BLUR_FRAG`, `SSAO_FN`, `rooms::Room.ssao`), for what the box's corners and the
  probes can't know: between the books and under the shelves, the table's base and the
  floor round it, the curtains' folds, the shutters, the window's frames and the sill's
  nose, and later the props. Replaces "no SSAO" (the light's round 1 and the corners'
  entries above), whose reasons were the planes' light, which the probes and
  `corner_shade` keep. Before the board's pass, the room, the table, the board and the
  pieces are drawn at half size into where each pixel is from the eye (RGBA16F, world
  units) and its normal (RGBA8), with a 16-bit depth for the test alone; each pixel's
  occlusion after McGuire's Alchemy obscurance, eight taps on a spiral out to the reach
  (0.35 m), each turned its own way across a 4 × 4 block, then a 4 × 4 blur weighted by
  the distance from the eye, which takes all sixteen turns, so a still frame has no
  noise; the room's and the table's shaders read it back by the distance-weighted four
  texels round the pixel and darken their indirect light only (the probes, the
  harmonics, the shade's floor, the reflections' occlusion), never the sun. It meets the
  analytic shade as `min(known × corners, SSAO)` times the floor's own narrow lines (its
  joints, the plinth's lip), where known is the mesh's and the analytic terms (the
  table's shade on the floor, the cases' shelves, the board's foot on the table): a plane
  the box already darkens isn't darkened twice, and SSAO adds only where it finds more.
  The lace hides 0.4 of what it covers in it, and glass nothing. Strength 1, reach
  0.35 m, bias 0.05 (the cosine over a plane that hides nothing, over the half floats'
  steps: 4 mm at 8 m), gain 3, in autumn only, as the corners are. It costs about
  0.5 ms a frame at 1600 × 1000 on an M-series Mac (1 ms when the GPU is waited for) and
  8.8 MB of targets at that size. Phones keep it off (`render3d::ssao_allowed`, the app's
  `!phone`). Rejected: GTAO (slices in view space, a view matrix the block lacks, for the
  same look after the blur at this tap count); the pass's own depth (multisampled, not
  sampled, and written by the pass that needs the occlusion); a better depth (the
  occlusion reads the half floats, not the depth buffer); normals rebuilt from the
  positions (the rounded spines and the lace's folds lose them at half size); temporal
  accumulation (the app draws only when something changes, so a still frame would never
  settle); full size (four times the cost for detail the blur takes); the board itself
  taking it (its shader is the game's, whose shot stays as it was).
- The screen's occlusion stays off the doors' panels' and architraves' profiles (2026-11-23):
  the painted wood (`ROOM_PAINT`) fades it out within 2 cm of a recess (the paint's dirt
  distance, so all of a panel's ring and the leaf's edge at its frame) and back by 4.5 cm.
  The profiles step by a few mm, under the half-size map's texel, so its lines crept along
  the insets in dashes as the eye moved; the rings' own occlusion and the dirt shade them.
  The windows' paint keeps it (their casements' inner corners), and so do the wainscot's
  oak panels (their bands came out smooth, no dashes), the sills, the niches and the cap's
  corner. Rejected: a full-size map for those profiles (four times the pass for a few cm).
- The library's waxed floor reflects the room by a planar mirror in the standard and high
  tiers (2026-11-21, task 107; `render3d::planar_pass`, `shaders::MIRROR_PASS`,
  `PLANAR_FLOOR`, `PLANAR_RESOLVE_FRAG`, `rooms::Room.planar`). Replaces, for the floor,
  the analytic room-box reflection above, which stays for phones
  (`render3d::planar_allowed`, the app's `!phone`) and for the curtains' brass: the box had
  no curtains, table, bookcases or backlit lace to reflect, and its doors' hard edges read
  overdone. Before the board's pass, the view out, the table and the room are drawn
  mirrored across the floor at half size: the view times the mirror, the eye under the
  floor, the clip's z replaced by the height over a plane 1.5 mm above the floor (an
  oblique near plane), so nothing under it draws and depth grows along each ray; the
  table's winding turned. The room's shader there leaves out its sharp reflections and the
  screen's occlusion and keeps its corners, which shape the contact line (0.2 ms). The
  board and its pieces are left out: from under the floor the table's top hides them. The
  pass draws what the screen would show; a resolve takes it back through the room's
  tonemap (its shoulder, whose mix toward white the peak gives back, and its toe) and
  exposure, so every shader draws there unchanged, and puts each texel's distance from the
  floor along the reflection, from the depth, in its alpha; where nothing of the room drew
  (past the floor's far edge) it takes the wall's foot below, or the floor's edge pulled in
  the sky. The floor reads it at the point its own board's tilted normal reflects to,
  through the wax's film (half the oak's 0.42 roughness): blurred as wide as the film's lobe
  is at that distance (six mips), drawn out down the screen by 1 / n·v through a 16×
  anisotropic sampler, as a grazing look streaks a waxed floor's reflections; each board
  ±12% in strength and its film ±5%; Fresnel by the film; 0.85 of it, the doors a little
  weaker than the box drew them; no occlusion of its own on top. Half size (a third since
  2026-11-23, below), not quarter:
  the contact lines stay sharp, and quarter saved 0.1 ms. About 0.7 ms a frame at
  1600 × 1000 on an M-series Mac and 8.3 MB of targets at that size; the room without it
  is the same shader as before, the planar floor a variant of its own. Rejected:
  screen-space reflections (they reflect only what the frame holds, and the windows and the
  curtains' backlit sides are what the floor shows most and are often off the frame, under
  the camera or above its top; a march a pixel, noisy at grazing angles, and with drawing
  on change no frames to accumulate over); the oak's own roughness for the blur (it
  smeared the doors away, and its Fresnel left the floor dull against the references);
  mips alone (they blur across as much as down, losing the streaks); a uniform switch in
  the room's one shader (its unused code cost 0.9 ms with the mirror off); the board and
  pieces in the mirror (never seen).
- The games table's sun shadow in the library takes only the sun (2026-11-21, task 107;
  `ROOM_FRAG`'s and `TABLE_FRAG`'s `vis` and `pattern`): inside a sun patch any shadow
  only removes the sun, and the light thrown back there is the same either side of its
  edge. The table's map and the bookcases' shade now keep the shade's floor of the key
  (`room.y`) as the window's bars do, where before they kept out all of it; and in the
  room the floor under the table loses its broad darkening (0.55 at the column to nothing
  1.4 radii out), leaving the probes, the screen's occlusion and `base_hides`' contact at
  the drum and toes. On a grey floor at style-01's camera the table's shadow beside a bar's
  in the same patch measured 130 against 144 (sRGB, 10% darker) before and 140 against 144
  after, the rest the floor's own gradient there. Replaces "the table's top is solid: its
  shadow keeps all the key out" for the room; the game keeps its light exactly.
- The library floor's mirror is steadied for a moving eye (2026-11-21, task 107;
  `PLANAR_RESOLVE_FRAG`, `planar_seen`): its half-size picture has no antialiasing, so a
  nearly level edge (a threshold, a door's foot, a moulding) showed in steps that crawled
  along the edge as the eye moved. The resolve takes a 3 × 3 tent over what the pass drew,
  the floor reads at least two of the map's texels across and four down the screen (the
  way the streaks run), the reflection's distance comes from the map's first mip, so the
  point found doesn't jump where the distances do, and the wax film's normal takes each
  board's tilt and cup and only a quarter of the grain's relief. Rejected: multisampling
  the mirror pass (its depth is read back, which a multisampled target can't give
  without a resolve of its own); drawing it at full size (four times the pass).
- The library floor's mirror reads its blur from the widths alone and keeps its map clean
  (2026-11-21, task 107; `PLANAR_RESOLVE_FRAG`'s `kept_light`, `planar_seen`): five taps
  down the screen of one mip, the mip chosen from the lobe's width across (at least three
  of the map's texels) and down (at least six), so the blur grows smoothly with the
  distance; the reflection's distance from the second mip. The resolve makes a NaN, an
  infinity or a negative channel black before the mips and holds a texel's luminance to
  16, keeping its hue; above the floor's far edge it takes the nearest drawn texel below
  (in doubling steps past the first eight), and the floor falls back to the room's box
  where a read still goes wrong. A few bad texels had made the mips' wide blurs into large
  black blotches on the floor. Replaces the same day's anisotropic read (`textureGrad`
  through a 16× sampler, at least two texels across and four down), whose taps and mip
  the filter picked from the gradient, and the empty texels left black. The view out
  stays 6 times its look in the mirror ("Sky in mirror"): it is what greys the floor by
  the windows (at style-01's camera sRGB 76, 48, 31 at 1×, 83, 58, 45 at 3×, 93, 70, 60 at
  6×, 68, 40, 22 with the mirror off), the user's choice.
- The library floor's mirror no longer boils as the eye strafes or turns (2026-11-21, task
  107; `shaders::PLANAR_MIP_FRAG`, `render3d::planar_size_of`, `planar_least_wide`): its
  mips are made by passes of their own, each texel a 4 × 4 tent [1 3 3 1] of the level above
  in four bilinear reads, and the map is at least 1600 texels across (at most the screen's
  width), half the screen's height. The floor's blur reads a coarse mip, whose 2 × 2 box
  texels were tied to the screen: a window's bar slid over them fell into one texel or
  across two, and the windows' reflections pulsed several times a second as the eye moved
  (in a strafe at 1600 × 1000 the error against a dense reference changed 0.11-0.21% of the
  windows' light a frame, 0.02% after, as the reference itself). Half the width of a
  1600-pixel screen was the rest: the bars, a few texels wide and drawn without
  antialiasing, stepped a whole texel. The pulsing was there from the first mirror and
  became plain with its light kept before the tonemap and the view out at 6× (5a52e485).
  The cost is not yet measured: every timing so far was taken with other renders sharing
  the GPU (about 0.3 ms for the wider map at 1600 × 1000 there). On a 3200-pixel (Retina)
  screen the map stays half size, which was already steady once the mips were tents.
  Turns measured too (a near view 2.2 m from the windows and one from the bookshelves, 0.4°
  and 1° a frame, at 1600 × 1000 and 3200 × 2000): the reflection's frame-to-frame change
  is the dense reference's own, and the error against it changes 1.20 levels a frame on a
  floor pixel at 3200 × 2000 (0.96 with the map at full size). Rejected for now: the whole
  mirror at full size (a quarter less of that error, its cost not yet measured; kept as the
  tuner's `--planar-size 1` for the planned high mode); more taps of a finer mip in the floor (the
  room's shader is at its register limit; 20 taps two mips finer halved the pulsing only);
  a temporal accumulation of the map while the eye moves (the last frame's map reprojected
  through the depth, held within the neighbours' range, 0.8 of it kept): built and
  measured, it changed neither the strafe's nor the turns' error, clamped or not, for a
  second map (8.5 MB at 1600 × 1000); lowering the view out's 6× (it is the user's look,
  and the error was there at 1× too, only fainter); the wax's worn patches (no change
  without them). The table's dark disc in the floor near it is the table hiding the
  windows' reflection, as on a real waxed floor; lighting its underside by the floor's
  bounce changed the floor by at most 1/255.
- The library floor's mirror is drawn at a third of the screen, not half (2026-11-23,
  task 107; `render3d::planar_scale`, the tuner's `--planar-size`): it replaces the half
  size of the entries above, and the least width of 1600 texels stays. It saves 0.4-0.6 ms
  a frame at 3840 × 2160 and 1.4 at 5120 × 2880 on an M-series Mac. The windows' streaks
  in the floor are a little blurrier (the room view's largest change 35 levels) and shimmer
  a little more as the eye moves; the user accepts that for the time. The half size stays
  as `--planar-size 2`, full as `1`.
- Skip the library floor's mirror when the floor is outside the camera frustum
  (2026-11-23, task 107, `render3d::floor_in_frustum`). This limits the earlier
  per-frame mirror pass to views that can show the floor. Both renderers reject the
  floor only when all four corners lie outside the same clip plane, with a margin
  for rounding. This keeps grazing views and views with corners behind the eye safe.
  The corners are turned by the room's frame, as `ROOM_VERT` turns the floor (2026-11-23):
  unturned, the test missed the floor in about one view in eight, walking toward the
  stove-end door among them, and the floor popped to its sharp box reflection.
  A returning floor gets a fresh mirror before the room draws. The tuner's
  full-screen mirror preview still renders the map because it displays it directly.
- Keep the full mirror target when the floor can show (2026-11-23, task 107).
  Rejected scissoring the mirror draw, resolve and mips to the projected floor bounds
  plus 64 or 192 texels. The experiment fell back to the full target at 70% coverage
  and clamped samples to drawn texels. The tilted plank normal and sampled reflection
  distance move the lookup through reprojection, and the blur widens at shallow
  projected depth. Edge clamping changes reflections when those taps reach past the
  scissor. The 64-texel trial saved 1.06 ms in the 3840 × 2160 thin-strip view with an
  identical capture, but changed the corner by up to 218 levels. Padding by 192
  texels still changed 90,659 menu pixels by more than eight levels and saved
  0.24 ms in the thin-strip view, below the 0.3 ms threshold. Both trials were
  reverted. The timing and captures are in task 107's results page.
- The library floor's mirror keeps the light before the tonemap (2026-11-21, task 107;
  `TONE_FN`'s `mirror_light`, `OUTSIDE_FRAG`, `rooms::Room.planar.w`): the room, the table
  and the view out write their exposed linear light into the mirror pass's RGBA16F
  target, held to 16 (the sun's disc), and the resolve takes back only the exposure. It
  replaces taking the tonemapped picture back through the inverse tonemap, whose inverse
  grows without bound toward white (held at 0.9995) and which put the table back through
  the room's curve instead of the board's. In the mirror the view out is `planar.w` (6) times its look: the
  look's exposure is set through the tonemap's shoulder, where the sky reads white
  whatever it is, and a clear sky by a low sun is some 13 times or more a sunlit dark oak
  floor, the look's about 3; the backlit lace keeps the light the room gives it, well
  under the sky. Where the wax is worn thin (the paths, the scratches, slow patches waxed
  less, the grain's open pores) the film's mirror turns into the oak's own rough sheen
  (the film's roughness toward the oak's, the mirror 30% weaker at most), so the windows'
  bright sheen shows the floor's surface; strong wear stays for the materials pass.
- The library's door thresholds are oak boards 2 cm proud of the floor with a rounded nose
  3 cm into the room, the grain along them, swept as the mouldings are, paler and smoother
  than the stained panelling (2026-11-21, task 107; `shell_mesh::THRESHOLD_OWN`). Replaces
  a square box in the panelling's oak, which read as an unfinished dark bar. Their middle's
  wear is the materials pass's.
- The library's paint is eggshell and its wallpaper has a slight sheen (2026-11-21, task
  107; `surfaces::LOOK`): the doors', windows' and shutters' paint 0.38 rough (0.45
  before), the paper's ground 0.66 (0.85) and its print 0.52 (0.6), so the sun's GGX
  highlight through the window shows on them as a soft sheen. At style-01's camera the
  sun's highlight is still small: about 2% of the door's sunlit diffuse and a fifth of
  the paper's, as the sun skims those walls away from the mirror direction; the
  references' sun patches read whiter mostly by their whiter sun.
- The games table in the room keeps the board's tonemap toe, off the least channel, as in
  the game (2026-11-21, task 107; `TABLE_FRAG`'s `tonemap`): the game's own table look is
  the anchor (the top in shade sRGB 67, 33, 9 at table-01's camera, the base 40, 16, 2).
  Replaces the room's toe on the luminance for the table in the room, the same day, which
  took the base from 52, 24, 6 to 29, 16, 10 at style-01's camera but also a third of the
  top's light and most of its colour. The base's orange cast in the shade is for its own
  light to fix, not the tonemap.
- The curtains' lace stops about 28% of the sun where its beam crosses a flat panel
  (2026-11-21, task 107; `LIGHT_FN`'s `lace_shadow`, `LACE_NET_STOPS`,
  `LACE_PATTERN_SHOWN`): the net ground a fifth, the motifs what the thread keeps
  (`Room.opening.w`), the pattern at three quarters of its contrast, the folds and the
  gathering toward the tie darker as before. Replaces about 11% at the same place (the
  pattern half washed out and the ground letting all through), which hardly showed; a
  real machine lace's net stops 20 to 30%, its motifs 50 to 70%. Still much lighter and
  softer than the bars' shadows.
- The library's panels shade as their profiles are, with a thin dip at the groove
  (2026-11-21, task 107; `surfaces::panel_ring`, `panel_ao_scale`, `panel_ao_width`,
  `panel_crease`, `THIN_STEP`): the rings' crease at cos 32° (0.85), so the wainscot's
  7.8° bevel, which met its 44.5° fillet just inside the old 37°, is a flat facet and no
  longer shades as a ramp running to black on the side away from the sun; the rings'
  baked occlusion at 0.6 of what it was and its dip held to the groove's first 4 mm (a
  ring point put in up the bevel), not across the whole bevel. A step narrower than 5 mm
  with a crease each side (the doors' 2 mm fillet into the field, the wainscot's riser)
  shades from the facet before it to the one after: its own sharp normal, a fraction of a
  pixel wide, rasterized as the faint dashed line round the doors' fields. Replaces the
  37° crease, the full-strength occlusion ramp and the fillet's own normal. Every facet
  flat (crease over 1) banded the ovolo; a narrower bevel rose steeper and fell under the
  crease again: both rejected (build/notes/panels-shade/).
- The sun casts contact shadows in the library in the standard and high tiers (2026-11-21,
  task 107; `ROOM_FRAG`'s `contact_lit`, `render3d::contact_look`): 12 steps along 3 world
  units (10 cm) toward the sun over the SSAO's half-size map of positions (`pre_place`),
  counted by a uniform, a surface there taken 1.5 units thick, 0.8 of the sun stopped: the
  architraves' shadow on the recessed leaves, the caps' and mouldings' on the wainscot,
  which the window's pattern can't cast. Only where the SSAO's map is drawn; off on a
  phone. Its edge steps at the map's texels close up (a depth-aware upsample would fix
  it). Replaces no small shadows at all.
- The floor takes no contact shadow (2026-11-22, task 107, `build/notes/floor-perf/`): the
  shots of the room's, the table-window's and a straight-down view were byte-identical
  without it, and it cost 1.8 ms of a 17.4 ms frame looking straight down at the parquet
  (3024 × 1890). Replaces the contact shadows on the floor; the walls, the joinery and the
  metals keep theirs.
- The floor's scratches come from a repeating tile, and its darker wax along the walls runs
  across the doorways (2026-11-23, task 107, `build/notes/floor-perf/options.html`, the
  user's picks): the tile is 1.57 m square (`surfaces::scratch_tile`, 2048² R8 with its mips,
  made with the room's bake) with the same scratches, a little softer and repeating, which
  the herringbone and the wear hide; the band and the plinth's contact line no longer stop
  at a door. Looking straight down the frame went from 13.3-13.7 to 9.9 ms (3024 × 1890).
  Replaces the scratches worked out in 3 × 3 cells a pixel and the gaps before the doors.
- Planned (2026-11-23, task 107; built the same day for the floor, the next entry): what depends only on the sun is
  worked out at the room's bake, in one place, and the shaders skip what the bake proves
  empty. The sun moves only with a rebake (and the season's transitions will rebake), so
  where each shadow can fall is known then: each window's opening projected along the sun
  onto the floor and widened by the penumbra's largest spread (the only area `shell_open`
  needs), the table's outline projected likewise and clipped to those (the table map's
  square fitted to it). One function in `render3d` fills one sun-derived block from the sun
  and the room; both renderers' passes only read it, and each new sun-only saving adds a
  field and a line there. Measured first: looking straight down, the sun through the
  windows cost about 4.5 ms and the table's nine taps 1.4 ms though no shadow of it showed.
- The floor is drawn in pieces cut along the sun (2026-11-23, task 107,
  `build/notes/floor-perf/night.html`; `render3d::SunDerived`, `sun_derived`,
  `floor_pieces`): when the sun, the room's turn or the table's map changes, the shell's floor
  is cut into where no sun reaches it through the windows, where it may, and where the table's
  map may darken that too, each drawn with a floor shader holding only what it needs
  (`shaders::FLOOR_SHADE`, `FLOOR_NO_TABLE`), in the HDR target. The cuts are lines along the
  sun at each window's sides and the table map's, and the band of the floor the openings'
  heights reach, each widened by the penumbra's largest spread and a centimetre, so each
  piece's shader gives what the full one would; the pieces share their corners exactly, so the
  floor stays whole. Looking straight down the frame went from 15.8 to 12.5 ms at 3840 × 2160
  (27.5 to 21.6 at 5120 × 2880), the room's corner view 17.7 to 16.5; shots differ only in a
  few dozen single pixels on the boards' joints, where an attribute interpolated over another
  triangle rounds across a joint. Rejected: skipping `shell_open` behind a test in the
  shader, which leaves its code compiled: an early return always taken saved two thirds of
  what removing it did, and a test of each window's reach hoisted before the loop saved
  nothing more over the pieces; a floor-space mask texture, a tap a pixel for what the cuts
  give for free.
- The floor's joints stay flat lines (2026-11-23, task 107; `build/notes/floor-perf/night.html`,
  `joints.html`). Tried and removed, kept for a later look: a deep version (each board's edge
  rounded over 2.5 mm in the shading and the wax's normal, the gap darker at its bottom with
  a fringe; commit 2f427b12), which aliased and was far too strong, and an eased one (a
  0.08 tilt faded by the pixel's footprint, a faint shade along the gap where the pixel is
  wider; fd982f90), alias-free but hardly seen, 0.15 ms straight down at 4K. To revisit,
  start from fd982f90: the concept's deep gaps may need the low sun and close views it
  shows.
- The library's light retuned for a larger sun-to-shade range, with today's toe (2026-11-21,
  task 107; `rooms::AUTUMN`'s `shell_sun` and `baked`, `render3d::shade_fill`,
  `room_light::bounce_grey`, `room_light::BOUNCES`, `render3d::room_sun`,
  `render3d::sheen_look`): the sun on the room twice what it was (shell_sun.y 4.4, from
  2.2), the probes' bounce of the sun's patches and the shade's fill halved and a fifth
  (baked.y 6 from 12, shade_fill 0.2 from 1), so the patches gain about a stop and the
  shade stays near where it was; the sun's saturation on the room and in its bake 0.6 of
  the key's; the bounce taken a quarter of the way to grey (0.6 before: the light thrown
  off oak, paper and wax is warm); one bounce (three before: two and three changed no
  patch by more than a level and cost the bake two steps); a broad second lobe of the
  sun's highlight (roughness 0.8, ×2) on the painted wood and the paper, which gives the
  paper's sun patch its sheen. The panelling oak keeps the sun as it was (half the
  room's, at the key's saturation, no broad sheen; `room_sun`'s y, z, w), as the user
  asked the stronger sun only on the paper and the doors: its sunlit patch stays at
  217, 137, 87 sRGB in the wainscot close-up (the panels' fixes alone, 217, 137, 87;
  before them 232, 155, 104), where the broad sheen and the doubled sun turned it pink
  (248, 189, 154 against result-2's 190, 131, 93). At style-01's camera against result-2:
  the paper in sun 147, 116, 89 (146, 117, 90; 101, 71, 45 before), the door in sun 222,
  186, 153 (217, 192, 168; 238, 186, 138), the door in shade 157, 126, 99 (155, 127, 99;
  180, 144, 111); the wainscot in shade darker, 31, 15, 8 on the end wall (40, 23, 13;
  44, 24, 14). The room's exposure (1.8) and its toe stay; the tone is for after the
  materials pass. The no-toe set (the sun three times, exposure 1.55) is the tuner's.
  Replaces the sun 2.2 times the board's, the fill at 1, the bounce 12 and three bounces.
- The library's probes give the walls, the floor and the ceiling their exact light
  (2026-11-21, task 107; `room_light::settle`, `fill_walled`, `probe_place`,
  `thrown_albedo`, `LACE_SCATTER`): a probe gathers, beside its constant and direction,
  the clamped cosine sum for each room plane it stands within 0.35 m of, and its direction
  is turned along that plane's normal so the plane reads exactly its own light. Two bands
  alone gave a wall a quarter of each light along it or behind it and the floor a quarter
  of every low light: the floor read 1.3-2× its light away from the walls, and a wall's
  own sun patch rang dark round itself (the black half disc at the hall door's foot). A
  probe inside a wall, past the inner glass or behind the hall wall takes the light of the
  nearest probe toward the room, and one in a niche sees only its own window: the window
  wall's corners and the floor and ceiling along it read the sky through the piers. A
  sunlit sill's or reveal's light leaves its niche only through the niche's outline. No
  surface throws back more than 0.85 of the light it gets (the patches' gain had made the
  white doors, reveals and sills throw 2.8-3.4×), the lace throws on only its own share
  of the sun it stops (0.4, without the gain), and the half grid has the stove end's own
  row: together they were the stove end's light band by window 1 (+28% over the wall,
  +9% now, as a 12.5 cm reference bake rises there). Against that reference
  (`tools/light_ref.goose`, the tuner's `--light-ref`) the bake's error went from 0.79 to
  0.14 rms in log₂. The indirect light is about half what it was, so the darks come back;
  the probes' bounce is 10 (baked.y, from 6; the tuner's "Probes' bounce"), now lifting
  only the floor, the oak and the paper, one bounce as before. The bake takes about
  10 ms more on the CPU (78 to 88 ms). Replaces the probe row that took none of its surface's own patch
  (`OWN_ROW`, above) and the lace's light lifted by the patches' gain.
- The tonemaps' toes switch only in the light tuner (2026-11-21, task 107;
  `shaders::TOE_FN`, `render3d::tone_toe`, `render3d_gpu::tuned_frags`; `--toe`,
  `--table-toe`, `--board-toe`, `--toe-off`): the tuner embeds its own fragment shaders
  with the switch (the board's and pieces', the table's, the room's, the mirror's, the
  view out's) and uses them only when a toe flag is given; the app's keep their own toes,
  unchanged. A uniform switch in the app's shaders cost the room 0.7 ms a frame on the
  Mac (0.45 without a branch), and any change to the lit shader's text moved two pixels of
  the game's shot by 7 levels; a Mali would compile every branch of it too.
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

### Oak texture sampling

- Keep the room's floor and panelling normals in RGBA8 (2026-11-23, task 107).
  Both renderers can bake and sample RG8, and the oak shaders read just the two
  tangent components. RG8 saved 21.33 MiB across the full-resolution fields and
  matched the original image within repeat-run noise. The warmed Mac runs showed
  no repeatable frame-time gain, so the bake retains its existing format.

- Use 8× anisotropy for the floor and wall oak (2026-11-23, task 107). At 4×,
  grazing views lose some grain detail and differ beyond repeat-run noise.
  `--oak-aniso-4` lets the light tuner preview both fields at 4×.

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
