# Rendering

## Drawing

NoGraphicsAPI's ideas, inside SDL_GPU:

- **Vertex pulling.** All pieces are one instanced draw. The vertex shader reads a
  storage buffer of `{pos, kind, color, lift, glow}`, so there is no vertex layout to keep
  in sync. The board is one pass, with the squares worked out in the shader.
- **One upload a frame.** All of a frame's per-draw data goes into one buffer region per
  frame in flight.
- **SDF shapes.** Pieces, highlights, rounded panels, and their soft shadows are signed
  distance shapes in fragment shaders, crisp at any resolution without textures.
- **3D later** reuses the game state and the storage buffer, with a camera and lit meshes
  in place of the 2D pieces.

## UI layer

The UI is a small immediate-mode layer in Goose, drawn the way Goose's Mini Minecraft
draws its HUD:

- Each frame, screens are declared in code. Layout cuts rows, columns, and grids from
  the screen rect.
- `button(id, rect, icon)` returns true on release over the button it went down on. A
  small fixed table holds per-id state for the press animation (0.12 s). A press that
  lands on the UI is the UI's and never reaches the board.
- Calls append quads (`panel`, `button`, `icon`, `fill`; `text` with home) to one fixed
  array, reset each frame, and one pipeline draws them in one instanced draw.
- **Native form**: `gui/` holds the layer with no graphics (tested headless in
  `test/gui/`), and `app/widgets.goose` draws it: each quad pulls `{rect, color, kind,
  radius, icon, pressed, dp, look}` from one storage buffer, and its fragment shader works
  it out as a signed-distance shape: glass with its shadow, a tile with its shadow (plain,
  primary, or a toggle on or off), a line icon as distances to its strokes' segments and
  arcs. `game/` is the game screen with no graphics, tested headless in
  `test/game/`: it declares the panel (`game/panel.goose`) and the celebration, does what
  their buttons ask, and hands the pointer to the board only when a press didn't land on
  the UI. Pieces shown on the UI (the side to move, the winner) are drawn after it by the
  piece pipeline from a second small storage buffer, so they look exactly like the
  board's.

Nuklear (`ui`) is only for developer tools, such as a puzzle editor, because restyling
its desktop widgets into the kid UI would fight it. If layout outgrows rect-cutting
(scrolling lists, wrapping text, menus like Snowtime's), we copy
[Clay](https://github.com/nicbarker/clay)'s model, a per-frame layout tree with
grow/fit/fixed sizing, rather than linking it. Its API is C macros, which Goose can't
call directly.

## Look

Reference: Snowtime's UI ([repo](https://github.com/Snowhound/snowtime), its
`prototypes/`): frosted glass panels over a scene, thin light borders, flat buttons;
and the seasonal design boards made with `prototypes/design-boards-prompt.md`, which set
each season's palette. The HTML
prototypes in [`prototypes/`](../../prototypes/README.md) settled the values below on
2026-11-07; they use only what this renderer draws cheaply.

### Seasons and themes

The season, picked from the date, chooses the background and the board theme together;
the theme can be overridden in settings. Values from the design boards (2026-11-07):

| | Autumn: wood | Winter: stone | Spring: birch | Summer: sunset |
| --- | --- | --- | --- | --- |
| Light square | `#e2b070` | `#d8dee7` | `#e8e2d3` | `#efd9c3` |
| Dark square | `#7a4626` | `#5a6777` | `#6b7f6a` | `#9a6655` |
| Frame | `#3b2112` | `#2a3442` | `#3d4a3c` | `#4a2c26` |
| Light piece | `#f0d4a4` | `#f3eee2` | `#f6f3e7` | `#fbf3e8` |
| Dark piece | `#4a2918` | `#2b3440` | `#3a4a3f` | `#4a2f35` (plum) |
| Glow | `#ffd75a` | `#a7d0fb` | `#8fd4ff` | `#ffb08a` (coral) |
| Glass tint | `#2b1e18` at 66% | `#1e2f45` at 40% | `#1e2f45` at 40% | `#462828` at 45% |
| Glass copy dimmed to | 0.9 | 0.75 | 0.75 | 0.8 |
| Text | `#f8f3e6` | `#e6f4ff` | `#e6f4ff` | `#fff3ea` |
| Page under the scene | `#1c1410` | `#0b1622` | `#101a14` | `#20140f` |
| Square surface | wood grain | soft mottling | faint fibre | plain sheen |

Summer's sunset (chosen 2026-11-07) takes the summer photograph's evening sky, peach and
dusky rose, where the design boards' sea greens were cold against it and close to
spring's sage. The crown on a light piece is the dark piece's color.

Secondary text is the text color at 66%. The surfaces are faint, never busy: a few sines
and value noise in the board shader. Wood is fine irregular streaks along the board and
a broad soft figure, never a regular stripe, which reads as bands from afar, with each
square its own tone; stone a paper-like mottling; birch a hint of fibre across;
sunset almost flat.

#### Themes kept for later

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

- **The scene** is a calm Estonian landscape for the season: autumn forest, winter
  spruces, spring birches, summer coast. Each is a photograph-like picture
  (`design/backgrounds/`, placeholders until task 014), shown as it is, cover-cropped to
  the screen by its long side, sharp behind the title menu, the puzzle picker, settings, and the 3D
  board.
- **Behind the 2D game the scene is blurred** (a 14 px blur at 1280 px wide, dimmed to
  0.8), as on the design boards, so the flat board reads cleanly. Natively
  (`app/scene.goose`) the decoded image is scaled down to 512 × 512 and blurred once on
  the GPU when the season is picked, two passes of a Gaussian of sigma 5.6 texels: since
  a square image is cover-cropped by the screen's long side, that is the same blur at
  every screen size and orientation, so a new screen size needs no new blur. The board
  pass samples it, a 1 MB texture. Tried and set aside
  on 2026-11-07: the sharp photograph (busy behind the board), a plain painted tabletop,
  and generated tabletop pictures with a crafted board (task 016).
- **The 3D board floats in front of the scene**, with a soft shadow under it: no room or
  table to model. A painted backdrop with a real table comes later only if this falls
  short (task 015).
- **Stored** as one JPEG per season, 2048 × 2048 at quality 85 (0.46 to 0.70 MB each),
  in `assets/backgrounds/<season>.jpg` and built into the program with `embed_file`, as
  the font is: nothing to package in the APK's assets, and the same path on the Mac and
  Android. goose_gfx's `load_texture` reads only PNG and BMP from a file (through SDL),
  so the program decodes the JPEG itself: stb_image, JPEG only, in the program's own C
  (a `c_sources` entry in its `.build` sidecar), from the embedded bytes to RGBA, then
  `gfx::texture2d` and `update_texture`. stb_image's NEON loops are switched on for ARM
  (`STBI_NEON`; on x86 it uses SSE2 by itself, elsewhere its plain C), and it decodes to
  four channels, the only case its NEON color conversion handles. A season is picked
  by a settings tile, which lights in the frame after the tap; the photograph loads in
  the frame after that, once the lit tile is on screen. No goose_gfx patch is needed
  ([findings](../goose-findings.md)). Only the current season is decoded, once: into
  the sharp texture behind home, 2048 × 2048 as stored (16 MB of graphics memory), and
  the 512 px copy that is blurred. The pixels' data-stack pages are given back with
  `trim_memory()` after loading. Until the
  images are checked in, `app/background.c` embeds the local masters with C23 `#embed`
  under `__has_embed`, so a checkout without them builds and shows the page color; the
  four add 2.3 MB to the APK (5.0 MB). PNG was
  rejected at about 5 MB a season; AVIF needs libavif and an AV1 decoder on both
  platforms to save about 1 MB. If graphics memory gets tight, ASTC at build time cuts
  a 2048² image from 16 MB to about 2 MB.
- **Glass is a pre-blurred copy, not a live blur.** Snowtime measured live backdrop blur
  costing more than its weather animation, and switched to a copy of the background
  blurred once (its `docs/architecture/scene.md`). Here the scene is blurred on the GPU
  when the season is picked, into a small texture (the blur a 24 px one would be at
  1280 px wide, saturation 1.3), so nothing pre-blurred is stored. Natively
  (`app/scene.goose`) two more passes blur the 512 px copy into a 256 × 256 one (sigma
  3.9 texels, on the copy's 2.8), the same at every screen size for the same reason as
  the board's copy. A glass panel samples it at its screen position: one texture fetch
  per pixel, no blur per frame.
- **Glass layers**, bottom to top: the copy, dimmed as the table says; the theme's
  glass tint; a 1 px border of white at 14%; a 1 px top highlight of white at 12%; a
  shadow `0 12px 32px -14px` of black at 55%. Corner radius 28 px.

### Light

The 2D board is kept simple: flat squares with no light pool, as on the design boards.
The pieces have a soft, diffuse light from above the board and toward its top
(2026-11-07): the rounded outer edge catches it on its upper side, most halfway round,
and is in shade on its lower side; in the groove the wall facing the light is lit and
the other in shade. Nothing else: no glossy spot, the face matte. Shade darkens toward a
deeper tone of the piece's own color, which keeps a cream warm where black would grey it. A strong light pool
and, with the tabletops, a crafted board with a soft light were tried on 2026-11-07 and
set aside. The 3D board has one key light from the top left,
as in the design boards, a few terms in its shaders with no lighting pass. The terms
the prototype tried, kept for 3D:

- **Board**: a pool of light toward the top left (warm white at 22%) falling off to
  black at 40% in the bottom-right corner, over the squares; a soft inner shadow where
  the squares meet the frame; the frame bevelled, lit on its top-left edge and shaded
  on its bottom-right.
- **Pieces**: a specular spot at 32%, 28% of the disc (white at 60% on light pieces,
  30% on dark), the face darkening toward the bottom right (black at 18%, 30% on dark),
  a lit upper rim and a shaded lower one, and a soft shadow cast down and to the right:
  a tight contact shadow and a wider one. The disc's side is 0.8% of the board deep.
- **3D**: the same light on lit meshes; the side of a disc lit on the left and dark on
  the right.

### Controls

- **Buttons** are glass tiles: white at 10%, 16% when hovered, 24% while pressed (and
  scaled to 0.96), with an inset 1 px border of white at 20% and a top highlight; radius
  22 px; at least 88 × 88 px (dp) for small hands, icons half the tile with strokes 2.4
  units of their 24-unit grid. A primary button is the glow color at 22%.
- **Icons** are line icons on a 24-unit grid with round strokes, in the Lucide style:
  undo, hint (a bulb), restart, back (an arrow left), next, star, crown, lock, and the
  puzzle themes' target, crown, and shield. The home tiles' icons are filled shapes,
  which read better large: two figures, a robot head, a jigsaw piece.
- **Game screen** (`prototypes/game.html`, chosen 2026-11-07 over three other takes):
  the board in the middle, leaving the game on its left and playing it on its right,
  each control a glass tile with an icon and a word, as on home, since icons alone (three
  arrows for undo, restart, and back) confused. In landscape the board fills the height
  less a 24 px margin, between two glass panels 232 px wide and as tall as it: on the
  left home (a house), settings, and at the bottom start over, 72 px rows with 34 px
  icons and 24 px words; on the right whose turn it is (a 72 px piece of its color with
  the glow ring, 4 px of the glow color at 80% and a 22 px glow, over "White's turn"),
  or the two clocks, and at the bottom take back, a tall 132 px tile with a 48 px icon
  over its word. In portrait the left side is a bar above the board, its three tiles in
  a row, and the right side is below it: whose turn, or the clocks side by side, over
  take back across the width. Start over sits far from take back so it isn't hit for
  it. There is no hint button and no move-hints toggle: help that does the thinking
  doesn't belong a tap away, and move hints are a setting, reached through settings.
  Take back takes back one move, also one still animating; start over goes back to where
  the game began; home goes home; settings opens settings, whose back returns to the
  game. Against the computer the child's pieces are at the bottom: when the child plays
  black the board is turned, black playing up the screen (2026-11-08). While the
  computer thinks its piece's glow ring pulses once, and its move comes after a short
  pause, or against the clock after the time a player of its level would take;
  take back then takes back the child's move and the computer's reply
  ([computer player](ai.md#in-the-game)).
  The words are 24 px; the turn's words say who has won once a side has.
- **Clocks**: each side's piece and its time, m:ss in 36 px tabular figures, in a tile
  of radius 20 px; black's on top, as black's side of the board is (white's on a turned
  board, so the child's clock is the nearer one). The running clock is
  the glow color at 18% with a 2 px glow border and its piece has the glow ring; the
  other is white at 6% with its text and piece dimmed. Under ten seconds the running
  clock turns the forced-capture red. A running clock redraws once a second, when the
  time it shows changes; a stopped one draws nothing. The time shown is rounded up, so
  0:00 shows only once the time is out. The player whose time runs out loses, as FMJD's
  rules say, and the win card shows the other. The clocks start with the first move:
  white's first move is untimed, then black's clock runs (2026-11-08), so a child can
  settle before anything counts. A move adds the increment to the clock that ran; take
  back runs the clock of the side to move again, the time taken staying taken, and none
  back at the start; start over sets both full again. Only time with the game on screen
  counts: not while Android has the app paused or it is in the background, nor while
  home or settings shows. A clock is the value `game/clock.goose`, no graphics, saved
  with the game. The choices are no clock, 5+3, and
  10+5 (five minutes plus three seconds a move, ten plus five): 5+3 is FMJD's usual
  blitz and both are in IDF's 8×8 rapid list, gentle enough for children.
- **A win** (`prototypes/win.html`, take a): once the winning move has shown, the
  winner's pieces answer, with no particles. Every moment is a function of the time
  since the win. The winning piece, the last move's, lifts on its square with its glow
  ring (0.35 s, easing out), and stays so. A ring of glow passes across the winner's
  other pieces outward from it: each lifts with its ring and its square lit in the glow
  color at 40% for 0.6 s, from 0.15 s plus 0.08 s per square of distance (straight
  across the board). A lifted piece rises 6% of its size and grows 5%. From 0.9 s the
  board and its pieces dim to 55% over 0.6 s, under the winning piece, which is drawn
  last and stays lit above the dim; from 1.0 s a glass card over the board (356 × 300
  px) slides up 28 px as it fades in (0.7 s, easing out), back and restart (primary,
  112 × 88 px) on it, and from 1.2 s the winner's piece, crowned, with its ring fades in
  above them (0.5 s). The screen is still from 1.7 s, or once the glow has passed the
  winner's farthest piece (up to 1.77 s on 10 × 10); the frame then is drawn at rest,
  and none after. A win with no winning piece to lift (a flag while the last move still
  shows, a position set up already won) starts at the dim, still from 0.8 s. The dim is
  the board pass's and the piece shader's, not a fill over them, so the winning piece
  can stay out of it while the card, in the UI's draw, is over it; the lit square is the
  piece shader's too, drawn under the piece. The panel's piece shows the winner.
- **Home** is a title menu (`prototypes/home.html`, chosen 2026-11-07 over the
  icon tiles and two other takes): the scene and the 3D board, and one glass column
  with the wordmark, then continue, a friend, the computer with its level, and puzzles
  with stars, then settings, each an icon and a word. In portrait settings is instead
  a quiet button beside the wordmark, so the sheet leaves the board its room. In the
  screen's top right, 24 dp from both edges, a round glass button 88 dp across with a
  32 dp X closes the app at once, asking nothing, since the game is kept anyway; on the
  menu and in a setup, in both orientations (`prototypes/exit.html?take=b`, chosen
  2026-11-08 over a quiet last row and a door). It is glass under a quiet tile, both
  going down as a tile does while pressed. In landscape it sits above the photograph,
  clear of the board (28 dp right of its edge, 8 dp above its top); in portrait, where
  it would reach the board, the board moves down to 16 dp under it and shrinks to keep
  24 dp above the sheet (640 to 620 dp on the tablet). A friend
  and the computer open a new game's setup in the same column: back and the title, then
  a row of tiles per choice, lit as in settings, each with its dim name above it: which
  draughts (international 10 × 10, the default, Brazilian 8 × 8, or Russian 8 × 8, each
  with a small board at the start), the level against the computer (easy, medium, hard,
  with one to three pips), the child's pieces against the computer (white, the default,
  or black, each tile showing its piece; 2026-11-08), and the clock (none with a
  stopwatch, 5 min +3 s a move, 10 min +5 s a move); then play, a primary row. The
  choices are kept for next time in `settings.txt`, and play replaces a saved game
  without asking. The draughts' tiles are thirds of their row while each name fits a
  third with 16 dp either side; else, as in landscape, each takes its name's width and
  an even share of the rest (2026-11-08). A tile's word still too wide for it, as a
  translation's may be, takes the small face. Home's computer row notes the kept level. The language is
  only in settings (2026-11-07): kids who can't read yet don't need it on home, and a
  tablet set to one language can still play in another. In portrait the column is a sheet below the
  board. **Settings** (`prototypes/settings.html`, regrouped 2026-11-07): back and the
  title, with the language at the title row's right end on glass, each named in itself;
  the choices as words in two glass groups (radius 24 px, icon and title in 24 px) by
  what they change; and beside them one preview of what they make. In landscape the
  choices take the width they need at the left, as home's menu does, and the board the
  rest, about two thirds, so from home the board only moves a little; in portrait the board is
  on top, as large as the rest leaves, and the two groups stand side by side under it.
  **Game**: the draughts a new game starts on (international, Brazilian, Russian; the
  setup can still change it), move hints, and the tutorial (one tile, learn the moves).
  **Look**: the background as thumbnails of the four photographs (62 × 40 px) after a
  tile for by the date, the board (flat or raised, 3D dimmed until task 015), and kings
  (auto, crown, or stack, the last two each with its king drawn on the tile). Each
  setting is a dim 18 px name at the left of its tiles (above them in portrait); a tile
  has radius 16 px and is lit in the glow color at 22% with a 2 px glow border when on.
  The preview is the board as the choices make it: its size, flat or raised, the kings,
  and what the move hints show (all moves: the selected piece's capture; mistakes only:
  a wrong move's red ring and the piece that must capture pulsing), over the season's
  photograph. It is home's board: opening settings moves it aside, and back moves it
  home (see "Transitions").
  Natively (`shell/settings.goose`) the preview is a board of its own on one fixed
  position, the same on every board size and a square in from the corner on 10 × 10:
  white must capture two, with the man on d4 or the king on h6. With all moves d4 is
  selected and its capture shown, target and stop; with mistakes only, a wrong move to
  c5 flashes and both capturing pieces pulse as in a game, then the ring and the pulse
  stay lit and still, so the screen draws nothing more until the next tap. Each tap
  sets the preview up again. The choices take the width their words want, at most 55% of
  the page, and wrap beyond it; their notes and the thumbnails' labels are in the 17 px
  face, which makes them a little wider than the prototype's 13 px, so the landscape
  board is about 550 px where the prototype's is 590. The tutorial's tile and the raised
  board are dimmed and take no tap until they exist.
  **Puzzle picker** (`prototypes/puzzles.html`): back, and one glass row per tier,
  its mark (a target for captures, a crown for many jumps and crowning, a shield for
  shots and the safe move) and its ten tiles, each with 0 to 3 stars in the glow color,
  outlined for those not won; the next unsolved puzzle is lit; a tier not yet open shows
  a lock on each tile. In portrait the title stands beside back, as in settings, and
  each tier is its mark beside two rows of five tiles, about 120 dp on the tablet, where
  ten in a row would be 66 dp, under the 88 dp a small hand needs. Behind it the sharp
  photograph and no board. **A puzzle** (`prototypes/puzzle.html`, take c, chosen
  2026-11-08): the game screen's layout, the left panel the game's with the puzzles in
  home's place; on the right the goal's icon in the glow color over its words
  ("Capture 2", "Become a king", "Stay safe"), the three stars at stake, 44 px, and at
  the bottom next, the tall tile, at 35% and taking no tap until the puzzle is solved,
  then lit as a chosen tile. There is no hint tile, as in a game. A wrong move plays,
  then 0.35 s after it lands slides back along its way, the pieces it took fading back
  in, while its square flashes the red ring over a ghost of the piece fading from 80%;
  the goal gives way for 2 s to "try again" in a pill of the forced-capture red at 16%,
  and a star goes out. A tap the board flashes as a mistake is a miss too, without the
  must-capture pulse, which would show the answer. A selected piece's targets never
  show, whatever the move hints (2026-11-08). After two misses the piece to move
  has the glow ring, pulsing twice, then still. A right move that leaves the goal ahead
  is answered 0.5 s after it lands. Solved, the words say so, the stars won pop in one
  after another (56 px, 0.6 s each, 0.15 s apart), and next lights; nothing covers the
  board. In portrait the goal and the stars share a row under the board, over next
  across the width.

### Transitions

Home to settings and back take 0.25 s, eased (smoothstep), rather than switching at once
(task 022). The board slides and resizes from one screen's place to the other's: in
landscape to the right, in portrait down a little as it shrinks under settings' title
row. The screen left fades out and the one come to fades in, both drifting 40 dp the way
the board moves. The photograph stays as it is, sharp behind both. Since settings' preview
is its own fixed position, the game's pieces fade out under the preview's as the board
slides; the marks, and the squares when the two sizes differ, switch halfway. A tap during
a transition lands on the screen come to. Back, during one, turns it round where it is.

Natively the shell keeps one transition: the screen left and when it began
(`shell::go_to`). Each frame it declares the screen left with no pointer (`gui::listen`),
then the screen come to. It fades and moves each one's quads (`gui::fade`; a quad's
`extra.w`, which the UI shader multiplies its result by) and its pieces over the UI. It
eases the board's rect between the two layouts. The app fills the board through
`shell::fill`, which lays the other board's pieces under it at the other opacity
(`board::under`). While a transition runs, `shell::animating` is true. The frame after it
ends is drawn at rest, and then nothing more.

### Board and pieces

- **Board** in 2D: the theme's squares in a thin raised lip 1.1% of the board's width,
  corners rounded 1.6%, and a soft shadow under it (down 1.4%, 3.6% soft, black at 55%).
  The lip is the dark square's color, with a line of the light square's color on its
  outer edge (gold on wood, pale blue on stone), brightest on top, and a dark seam where
  the squares sit below it. The lip, the pieces' flat tops with one groove, and the wood
  theme's warm tones and calm grain follow the close-up boards chosen on 2026-11-07,
  which read better than the first design boards' frameless board and two-ringed pieces. The 3D board has a
  frame 2.4% of the board's width. 10 × 10 uses the same.
- **Pieces** are SDF discs filling 78% of a square, flat-topped and matte like turned
  discs, as the 3D close-up shows them: one color and one height across the top, with
  a groove cut into it at 70% of the radius (13% of the radius wide, its floor in soft
  shade, so it reads as a ring on light pieces too), only the
  outer edge rounded (from 86%), and the side under the disc (0.55% of the board deep).
  A short soft shadow falls straight down and a touch right (a quarter of the radius
  down, softened over a third of it), with a tight one where it touches. Each side has
  one color in the theme; the rest is worked out from it. The edge's highlight is
  clearer on dark pieces than on light ones. Light pieces: the side the face's color
  squared, at 92%. Dark pieces: the side 50% toward black.
- **Kings** are a setting: crown, stack, or auto (the default). Auto draws a crown on
  the face in the top-down board (the theme's dark piece color on a light piece, gold
  `#e9c46a` on a dark one), which reads at a glance, and in a 3D board a stack of two
  plain discs, no crown, as kings are in Estonian play (2026-11-07). Top down, a stack reads as
  a shadow at tablet size, so it's there for those who want it. The stack's upper disc
  sits 1.3% of the board above the lower one, its side as deep, so the lower disc's rim
  shows under it. A selected or must-capture ring goes round the lower disc, the stack's
  foot, with the upper disc hiding its back (2026-11-08). The setting applies to the game's board, the winner's piece,
  and the preview; home's wordmark keeps its crown.
- **Native form** (`app/draw.goose`): the blurred photograph, the board's shadow, lip,
  squares, and marks are one full-screen fragment pass, worked out at `gl_FragCoord`
  (interpolated coordinates put a square's edge a pixel off on some rows); the pieces
  are one instanced draw of quads, each pulling `{center, radius, lift; black, king (none,
  crown, or stack), selected, opacity; must capture (pulsing or still), side to move}`
  from a storage buffer and drawing its shadows, side, face, light, crown or second disc,
  and rings in the fragment shader, blended premultiplied, top row first so a lower
  piece covers the shadow above it. The crown is a signed-distance polygon in that shader. The panel's line icons are
  to be drawn the same way, as distances to their strokes' segments and arcs, rather than
  baked into the font atlas: crisp at any size, no texture.
- **3D board**: the same board tilted (about 38°, in perspective) with a front edge,
  pieces as discs with height (one disc 1.7% of the board), and the selected piece
  lifted. `prototypes/boards.html` shows it for every theme.
- **States**, in the theme's glow color: the selected piece lifts by 0.8% of the board
  and grows to 1.05 with a glow ring a little out from it (at 1.13 of the radius); with move hints on, a legal target is a glowing
  dot 30% of a square and a capture's stop on the way is a ring. With hints on mistakes
  only (the default, `docs/product.md`), there are no dots: a wrong move flashes a red
  ring on its square twice (0.6 s each), and the piece that must capture pulses; the
piece stays selected. A tap or a drop on an empty square that isn't a move is wrong, as
is touching a piece that can't move because another must capture. A capture of many
jumps is tapped by its last square or stop by stop (`board::follow`): a tap on the next
stop of the selected piece's captures rings it, whatever the hints, and narrows the
targets shown to the ways through it; once only one capture goes on that way it is
played, and a tap off every way is wrong and forgets the stops. A piece that must
capture pulses a red ring
  `#ff5a4a` with a soft red glow every 1.4 s, in every theme. The last move's squares are
  tinted with the glow color at 16%.

## Fonts

**Libertinus Sans** (SIL OFL 1.1), the maintained fork of Linux Biolinum: a humanist sans
with flared strokes in the style of Optima, the face of the reference the user liked
(arXiv 2611.07289), with a regular and a bold. Tenor Sans, Belleza, and Marcellus were
compared with it in Estonian text; all four have õ ä ö ü š ž. Tenor Sans, which the
proof of concept uses (`assets/fonts/`), is the runner-up: clean and wide, but one weight
only. Marcellus has small serifs, further from Optima. The atlas bakes Latin-1, Latin
Extended-A, and general punctuation. If titles want more character, Tenor Sans could set
them and Libertinus the rest; one face is the default, for one atlas.

Natively (`app/text.goose`) the regular weight (`assets/fonts/`, from the v7.051
release) is baked by `ui`'s atlas once per size the UI uses, at the screen's pixel size,
so a glyph is drawn a texel to a pixel: 64 dp for the wordmark, 30 for labels, 17 for
notes. The atlas sizes a font by its ascent less its descent, 1.14 em for Libertinus,
so each is baked at 1.14 times its size in ems to match the prototypes' CSS. The glyphs'
boxes and atlas places are copied into `gui`'s fixed tables, which lay text out headless,
the image into a texture, and the atlas is then destroyed. A glyph is one more quad kind
in the UI's one draw. Baked again only when the layout's scale changes.

## Frames and battery

The app draws only when something changed: input, a running animation, the AI's reply, or
a new screen size. Otherwise it draws nothing in that frame, and goose_gfx's `frame()`
then neither presents nor spins: it waits for the next event, up to a second. An idle
board costs about one wakeup a second and no GPU work. The loop is the same on every
platform:

```goose
while gfx::frame() {
    // read input, advance animations; set dirty if anything changed
    if dirty || animating { draw(); dirty = false; }
}
```

This is `patches/goose_gfx/0002-draw-on-demand.patch`, applied in the Android build
([findings](../goose-findings.md)). The Mac's built-in gfx still presents every frame at
the display's rate, which costs nothing that matters there. The patched `frame()`:

- presents only if something used the GPU since the last call, or the window needs the
  screen again (exposed, restored, back in the foreground, resized);
- after a frame with nothing drawn, waits in `SDL_WaitEventTimeout` for up to 1 s before
  reading events, so input wakes it at once and timers still run once a second;
- tries again for up to 8 frames when the window has no image to show, as on the first
  frames after Android recreates the surface on resume;
- leaves the wait out of `delta_time()`, so the first animation frame after idle doesn't
  jump.
- on Android, turns off SDL's poll sentinel, without which SDL's wait spins instead of
  blocking there.

An animation's last frame is not the resting state: the frame after a move or a pulse
ends is drawn too (`board::update` reports it), or the board would keep the move's last
in-between frame without its marks.

A running clock must show its next second on time, which the wait doesn't: after a drawn
frame the next wait ends a second and a frame later, so the clock was drawn 6 ms later
each second, up to a second late, and skipped a second every two and a half minutes
(measured on the tablet, 2026-11-08). So while a clock runs the app sets an SDL timer for
when the time shown changes (`app/wake.c`), which pushes an event of the program's own
type and ends the wait; the second is then drawn within 5 ms. The Mac's gfx doesn't
wait, so the timer is Android's only.

Work that finishes on another thread, such as the computer's reply, would be seen only
when the wait ends; so as the computer begins to think its piece on the panel pulses,
which keeps frames coming until the reply has come, and it is seen the next frame. A
longer think against the clock draws only the clock's seconds after the pulse: the
timer is also set for when the computer's move is due (`game::due`). Once its move has
landed nothing animates and the app draws nothing. While Android has the app paused, SDL blocks
the loop: it draws nothing and submits no GPU work.
