# Rendering

How the app draws: the GPU side, the UI layer, the look of each screen, and what a frame
costs. The values here are what the code does; the reasons are in
[decisions](../decisions/rendering.md), and each screen's prototype in
[`prototypes/`](../../prototypes/README.md).

## Drawing

NoGraphicsAPI's ideas, inside SDL_GPU:

- **Vertex pulling.** All pieces are one instanced draw; the vertex shader reads a storage
  buffer of `{pos, kind, color, lift, glow}`, so there is no vertex layout. The board is
  one pass, the squares worked out in the shader.
- **One upload a frame.** A frame's per-draw data goes into one buffer region per frame in
  flight.
- **SDF shapes.** Pieces, highlights, rounded panels, icons, and their soft shadows are
  signed-distance shapes in fragment shaders: crisp at any resolution, no textures.
- **One screen, no depth.** A frame draws into goose_gfx's screen, an RGBA8 texture the
  window's size that `frame()` blits into the swapchain. Nothing tests depth, so the pass
  has no depth target (`gfx::begin_pass` with `Texture { 0 }`). On Android the fork's gfx
  makes the screen's depth only when asked and never cycles the screen
  (`screen-without-depth`, [findings](../goose-findings.md); [GPU memory](#gpu-memory)).
- **The 3D board** reuses the game state and the flat board's draw lists, with a camera
  and lit meshes in place of the 2D pieces ([Board and pieces](#board-and-pieces)).
- **One frame call.** `render::frame` (`src/app/render.goose`) draws each frame from a
  `render::Frame` of plain values and owns the screen's pass: copies and passes into
  textures first, then the screen's one pass. The app holds no gfx handle
  ([architecture](README.md#code-layout)).

### Two renderers

gfx ships everywhere; the build holding goose-ngfx too (`scripts/ngfx.py`) draws the same
frames through either, chosen at start (`--renderer auto|gfx|ngfx`). The drawers (`draw`,
`scene`, `widgets`, `draw3d`, `render3d`) are shared: each records through a backend
handed to it, `be`, calling the few calls every drawer makes on it (`be.flush()`,
`be.begin_pass(...)`) and its own recorder on a field (`be.draw.board(...)`,
`be.r3d.bake(...)`, `be.host.frame()`). A backend is one struct per renderer holding each
recorder's state: `gpu::Gfx` and `gpu_ngfx::Ngfx`. The drawers are generic over its type,
so each is compiled once per backend and every call goes straight to that renderer's
recorder, with no branch.

The one seam is `backend`, a file per root: `with`, which runs a block on the chosen
backend, and `open`, which chooses it and opens the window. `render.goose`'s calls that
reach the GPU and `host.goose`'s window calls each run their drawer in
`backend::with() { be => ... }`. The gfx build's `src/app/backend.goose` hands gfx's
backend; `src/ngfx/backend.goose`, in the second root `src/ngfx/draughts_ngfx.goose`,
makes the choice ([architecture](README.md#code-layout)) and holds both. Both roots run
`src/app/app.goose`'s program.

goose-ngfx's shaders are gfx's GLSL, written as Slang at each build into
`build/ngfx/shaders/` (`scripts/ngfx_2d_shaders.py`, `ngfx_3d_shaders.py`) and compiled
ahead into `build/ngfx/blobs/`, which `src/ngfx/` embeds. `scripts/ngfx.py` also links the
goose-ngfx checkout at `build/ngfx/goose-ngfx` and writes the app's version for the crash
marker (`build/ngfx/draughts_version.h`).

## UI layer

A small immediate-mode layer in Goose, drawn as Goose's Mini Minecraft draws its HUD:

- Screens are declared in code each frame. Layout cuts rows, columns, and grids from the
  screen rect, or lays out a row or column of sized and growing children in one pass
  (`gui::stack`): no tree, nothing kept, taps tested against the same frame's rects. A
  screen works out its places in a function that declares nothing (home's and settings'
  `layout`, the panel's `way_out` and `*_play`), and its frame declares into the result.
- `button(id, rect, icon)` returns true on release over the button it went down on. A
  fixed table holds per-id press state (0.12 s, `gui::PRESS`). A press that lands on the
  UI never reaches the board.
- Calls append quads (`panel`, `button`, `icon`, `fill`, `text`) to one fixed array, reset
  each frame, drawn by instanced draws in order: one pipeline for icons, one for the
  players' faces, one for the rest, each shader at 32 registers
  ([why three](../decisions/rendering.md#ui-layer)).
- `gui/` holds the layer with no graphics (tested headless in `test/gui/`);
  `src/app/widgets.goose` draws it. Each quad pulls `{rect, color, kind, radius, icon,
  pressed, dp, look}` from a storage buffer and its fragment shader draws glass, a tile
  (plain, primary, toggle), or a line icon as distances to its strokes. `game/` is the
  game screen with no graphics (`test/game/`): it declares the panel
  (`src/board/panel.goose`) and hands the pointer to the board only when a press missed the
  UI. Pieces on the UI (the side to move, the winner) are drawn after it by the piece
  pipeline, so they match the board's.
- **Shaded only where it shows.** A quad is only as large as its shadow reaches (glass
  6 dp above, 18 to the sides, 30 below; a tile 0, 6, 12); outside the shape a pixel is the
  shadow alone, more than 3 dp inside the fill alone. The UI drawn live costs about 0.30M
  GPU cycles a frame on the Pixel 7a.
- **Kept while it stands still** (`widgets::prepare`): when a frame's quads, view, theme,
  and textures match the last frame's, they are drawn once into a premultiplied layer the
  screen's size (10 MB on the Pixel 7a) and laid with one fetch a pixel until they change.
  `--keep off` draws the UI and the 3D backdrop every frame, to measure them.

Nuklear (`ui`) is only for developer tools such as a puzzle editor.

### Screen sizes and the safe area

Layouts are in dp, the screen's shorter side 800 dp (`gui::scale_of`, the one place the
scale is computed), so the tablet's 1200 px are 1.5 px a dp. A floor in physical size
keeps a phone's dp at least 0.75 of Android's: `max(short side / 800, 0.75 × display
scale)` (`gui::DENSITY_FLOOR`, [why](../decisions/rendering.md#screen-sizes-and-the-safe-area)),
the display scale being Android's density / 160. The Pixel 7a then lays out about 549 dp
across; the tablet is unchanged. An 88 dp tap is about 10.5 mm on any phone. Layouts are
made for a short side down to 480 dp. A larger tablet lays out the same dp scaled, the
2048 px photograph stretched up to 1.41×. A Mac window stands for a screen of its size in
pixels: its display scale is left out of the floor.

**A desktop** is laid out for a mouse (`gui::desktop_scale`): a
ceiling of 0.75 points a dp (`gui::DESKTOP_DP`), growing from a 1000-point short side to
0.9 at 1440 (`gui::DESKTOP_DP_LARGE`). A larger window keeps its controls that size and
gives the room to the board. `--touch on` lays a desktop window out as a touch screen;
`--size`, `--dp`, and `--inset`, which stand for a device, imply it
([development](../development.md)). On a desktop:

- The landscape game and puzzle stand in a frame (`panel::framed_in`): 4% to 7.5% of the
  height on each side, at most 1.45 times as wide as tall round the flat board and 1.7
  round the 3D one, so the panels stay near the board; `panel::flat_frame` centers it down
  a window whose width limits the board.
- Home's column stands 40 dp from the top, at least 440 dp wide (`home::DESKTOP_TOP`,
  `DESKTOP_COLUMN_W`).
- No window lays out wider than 1.9 times its height (`gui::WIDEST`): `gui::safe` keeps
  the middle of an ultrawide; the photograph and edge glass (`gui::bleed`) still fill it.
- Taps are thinner: every tap-sized length is `gui::tap()` (88 dp touch, 64 desktop), a
  worded tile's side room `gui::side()` (16 and 12), a tile with its icon over its word
  `gui::stacked()` (at least 72 dp). The panels' heights are sums of their rows
  (`panel::corner_h`, `left_h`, `bar_h`, `play_h`), so they follow.

The **safe area** is the window less its insets (camera cutout, gesture bar). SDL reports
them (`SDL_GetWindowSafeArea`, read each frame with the display scale by
`src/app/display.c`). The app draws behind the cutout, so the photograph and glass that
runs off an edge reach the screen's edges; everything else is placed in the safe rect as
in a whole window of that size (`gui::safe`, `shell::frame`). The scale stays the whole
short side's, the same in both orientations. Layouts hold down to a safe area of 443 ×
801 dp. `patches/SDL/0002` keeps the back gesture's side strips and the top swipe strip
inside the safe area, since taps there still reach the window. A change of insets or scale
redraws, as a new size does; when the screen turns, insets and size arrive a frame or two
apart and the layout follows each.

### Small windows

iPadOS 26 resizes any app's window, down to about 374 × 484 pt (499 × 645 dp). Every size
works; the extremes aren't polished.

- **Compact** (`gui::compact`): a portrait safe area under 760 dp tall, which only a small
  window takes (every phone is 801 dp or more). The game's bar is three icon-only tiles
  72 × 64 dp, the play one 112 dp row; home's rows are 72 dp. Settings keeps 88 dp tiles
  and scrolls; a single puzzle keeps its layout.
- **Scrolling** (`gui::scroll_begin`, `scroll_end`): one vertical list a frame, its offset
  kept by the list's id. A press is a tap until it moves 10 dp (`gui::SLOP`), then a drag
  that takes the pointer. The wheel scrolls 40 dp a step; no fling. The list's quads carry
  `gui::CLIP` and the UI shader clips them to the view, still one draw. `test/gui/scroll`
  covers it.
- **The window control** (iPadOS's three dots at the top left) may sit over back or the
  player's chip; no screen moves for it ([why](../decisions/rendering.md#small-windows)).
  UIKit's corner-adapted safe area reports its reach, should a screen need it.

### Window resizing

While a Mac window's edge is dragged, Cocoa holds the main thread and the frame loop
doesn't run. `src/app/resize.c` keeps the Metal layer's last frame its shape, scaled to
fit, over the window's content view showing the backdrop cover-cropped: the flat game's
blurred photograph or page color, or the 3D board's graded backdrop (`draw3d::cover`).
They are read back to the CPU only at a season or board change (`draw::cover_with`), never
per frame. On mouse-up the frame at the new size fills the window. Android and iOS don't
hold the loop; Windows does and shows the last frame unscaled
([why](../decisions/rendering.md#window-resizing)).

## Look

Frosted glass panels over a scene, thin light borders, flat buttons, after Snowtime's UI
([repo](https://github.com/Snowhound/snowtime)) and the seasonal design boards made with
an image model. The HTML prototypes settled the values; they use only
what this renderer draws cheaply.

### Seasons and themes

The season, picked from the date, chooses the background and the board theme; settings can
override it.

| | Autumn: wood | Winter: stone | Spring: birch | Summer: sunset |
| --- | --- | --- | --- | --- |
| Light square | `#e2b070` | `#d8dee7` | `#e8e2d3` | `#efd9c3` |
| Dark square | `#7a4626` | `#5a6777` | `#6b7f6a` | `#9a6655` |
| Frame | `#3b2112` | `#2a3442` | `#3d4a3c` | `#4a2c26` |
| Light piece | `#f0d4a4` | `#f3eee2` | `#f6f3e7` | `#fbf3e8` |
| Dark piece | `#4a2918` | `#2b3440` | `#3a4a3f` | `#4a2f35` |
| Glow | `#ffd75a` | `#a7d0fb` | `#8fd4ff` | `#ffb08a` |
| Glass tint | `#2b1e18` at 66% | `#1e2f45` at 40% | `#1e2f45` at 40% | `#462828` at 45% |
| Glass copy dimmed to | 0.9 | 0.75 | 0.75 | 0.8 |
| Text | `#f8f3e6` | `#e6f4ff` | `#e6f4ff` | `#fff3ea` |
| Page under the scene | `#1c1410` | `#0b1622` | `#101a14` | `#20140f` |
| Square surface | wood grain | soft mottling | faint fibre | plain sheen |

A light piece's crown is the dark piece's color; a dark piece's is gold (`#e9c46a`) on
every theme. Secondary text is the text color at 66%. The surfaces are faint: a few sines
and value noise in the board shader, never a regular stripe.

### Scene and glass

- **The scene** is a calm Estonian landscape per season (`design/backgrounds/`),
  cover-cropped by its long side, sharp behind home, the puzzles, settings, and the 3D
  board.
- **Behind the flat game it is blurred** and dimmed to 0.8 (`src/app/scene.goose`): when
  the season is picked the sharp texture is averaged down to 512 × 512 on the GPU and
  blurred once (sigma 5.6 texels), a 1 MB texture. A square image cropped by the long side
  needs no new blur for a new screen size.
- **Stored** twice per season at 2048 × 2048, embedded in the program with C23 `#embed`:
  as ASTC 6 × 6 (1.87 MB each, from the masters with `astcenc`,
  `design/backgrounds/README.md`), sampled as stored; and as JPEG at quality 85, the
  fallback for a GPU without ASTC and for the release's own gfx, which lacks compressed
  formats ([why 6 × 6](../decisions/rendering.md#scene-and-glass)). Android embeds only
  the ASTC (7.5 MB of `libmain.so`) and no stb_image. A checkout without the images still
  builds and shows the page color (`__has_embed`).
- **Loading**: `src/app/background.c` decodes (no graphics API) and `src/app/photo.c`
  uploads through gfx's C API, with no copy on the data stack. Compressed formats come
  from the fork's `compressed-textures` ([findings](../goose-findings.md)). Where ASTC
  isn't taken, the JPEG is decoded with stb_image into a 16 MB texture. A season loads in
  the frame after its lit tile shows, after a `gfx::flush()`; only the current season is
  resident, and the embedded pages are given back once read (`madvise`).
- **Settings' thumbnails** (`scene::thumbs`): each photograph shrunk on the GPU in turn,
  waiting after each, into one 160 × 2520 texture (1.6 MB) of 160 × 105 px slots: four
  photographs, four plain fades, and sixteen board pictures from the atlas
  `design/boards/boards.jpg` / `boards-6x6.astc`, made by `scripts/board_thumbs.py` from `tools/board_shot.goose`'s shot of each look.
- **The plain background** (settings' Background row; the player's `background =
  photo|plain`): a fade matched to the season's board in place of the photograph, from the
  theme's page color at the top to a deep tone of its frame at the foot, a faint light of
  its dark square behind the middle, corners 30% darker, mixed in linear light and
  dithered. It is a function of screen position (`FADE_FN` in
  `src/render3d/shaders.goose`) drawn wherever the photograph would be sampled. No
  photograph is decoded or held.

  | | Autumn | Winter | Spring | Summer |
  | --- | --- | --- | --- | --- |
  | Top | `#1e1510` | `#0c1724` | `#101b15` | `#21150f` |
  | Foot | `#4a2c1a` | `#2c3a4c` | `#2f3d30` | `#4f2e28` |
  | Light | `#7a4626` | `#5a6777` | `#6b7f6a` | `#9a6655` |

- **Glass is a pre-blurred copy, not a live blur**
  ([why](../decisions/rendering.md#scene-and-glass)): two more passes blur the 512 px copy
  into a 256 × 256 one (saturation 1.3); a panel samples it at its screen position, one
  fetch a pixel.
- **Glass layers**, bottom to top: the copy, dimmed as the table says; the glass tint; a
  1 px border of white at 14%; a 1 px top highlight at 12%; a shadow `0 12px 32px -14px`
  of black at 55%. Corner radius 28 px.

### Light

The flat board is flat squares with no light pool. Its pieces have a soft diffuse light
from above and toward the top: the rounded edge lit on its upper side and shaded on its
lower, the groove's wall facing the light lit; the face matte. Shade darkens toward a
deeper tone of the piece's own color. The 3D board has one key light from the top left, a
few terms in its shaders and no lighting pass.

### Controls

`prototypes/` holds one page per screen as built; takes named by file below are in git
history ([where](../decisions/rendering.md#controls)).

- **Buttons** are glass tiles: white at 10%, 24% and scaled to 0.96 while pressed, an
  inset 1 px border at 20% and a top highlight, radius 22 px, at least one tap across
  ([Screen sizes](#screen-sizes-and-the-safe-area)); icons half the tile, strokes 2.4 of
  their 24-unit grid. A primary button is the glow at 22%.
- **Under the mouse** (desktop only), a tile that takes a tap lights faintly in the glow
  (8% and a 1 dp border at 40%), fading over `gui::PRESS`. `gui::hold` notes the topmost
  tile each frame and the next frame's `gui::begin` makes it the hovered one. A frame is
  drawn only while the hover changes or fades (`gui::animating`). `--mouse X,Y` holds the
  pointer for a shot.
- **The keys' focus** (`gui::focus_keys`): arrows move a focus among the controls each
  `gui::hold` offers (`gui::Spot`), Enter or Space presses it. The focused control is lit
  and ringed (2 dp, 3 dp outside, `gui::RING_W`, `RING_GAP`). The first arrow focuses the
  screen's primary control; later ones go to the nearest control that way, weighting the
  gap across twice. Mouse movement lets the focus go. `--keys down,enter` presses keys for
  a shot. A puzzle solved while the keys hold a focus hands it to next
  (`puzzle::Play.to_next`).
- **The board with the keys** is one control, a grid of squares (`gui::grid`,
  `board::keys`): arrows move a cursor as the screen shows the board, Enter on a dark
  square is a tap (`board::press`), an arrow past the edge leaves for the nearest control.
  The cursor is a glow line round its square; on the 3D board it is drawn with the marks
  over the kept image, so moving it doesn't redraw the board.
- **Groups**: Tab and Shift+Tab step between a screen's groups (`gui::group`), each
  remembering its last control.
- **Fullscreen**: on a desktop Alt+Enter or F11 toggles it (`host::fullscreen_key`);
  `--size full` opens fullscreen.
- **A gamepad** is the keys (`host::keys`): D-pad or left stick move, A is Enter, B is
  Escape, the shoulders Shift+Tab and Tab. goose_gfx reads the first gamepad each frame,
  opened with `SYSTEM_GAMEPADS` so the system wakes gfx's idle wait on input (on Windows
  gfx polls every 16 ms while focused, waking the loop only on use).
- **Icons** are Lucide-style line icons on a 24-unit grid; home's tiles use filled shapes.

**The game screen** (`prototypes/game.html`): the board in the middle, leaving the game on
one side and playing it on the other, each control a glass tile with an icon and a word.
Landscape is taken where its flat board fills about 2/3 of the height (`panel::landscape`);
otherwise, and with the 3D board, portrait: a bar above the board and the play below.

- In landscape the flat and 3D boards share the same short corner panels
  (`panel::flat_corners`, `corners_in`; `Layout.corners`): top left back, settings, and
  start over, each its own tile; top right whose turn (a 72 px piece with the glow ring
  over "White's turn") or the clocks, the lookout's eye, the hint, and undo move as a tall
  tile. 232 dp wide, 192 on a phone. A puzzle takes the same panels (`panel::puzzle_in`).
- In portrait the bar holds back, settings, and start over in a row, icon over word on a
  phone; below the board whose turn and undo move.
- Undo move takes back one move (against the computer, the child's and the reply); start
  over goes to the game's start; back goes home. There is no move-hints toggle on the
  panel. Against the computer the child's pieces are at the bottom; while it thinks its
  piece pulses and its move comes after a pause, or as a player of its level would spend
  its clock ([computer player](ai.md#in-the-game)).
- **The way back**: one glass tile, arrow and "Back", top left on every screen that
  leaves, going where the screen's way out goes; Android's back and Escape do the same.
  Where its word doesn't fit it is a square with the arrow over the word.
- **Clocks** (`src/game/clock.goose`, saved with the game): each side's piece and m:ss in
  36 px tabular figures. The running clock is lit in the glow; under a minute it turns
  gold, at 0:20 the forced-capture red. It redraws once a second. Time shown is rounded
  up; a flag loses (FMJD). Clocks start after white's first move; a move adds the
  increment; only time with the game on screen counts. Choices: none, 5+3, 10+5.
- **A win**: the winning piece lifts with its ring (0.35 s), a wave of glow passes across
  the winner's other pieces from it, the board dims to 55% from 0.9 s, and a glass card
  slides up from 1.0 s with back and restart, the winner's crowned piece and who won. The
  screen is still from about 1.7 s and draws nothing after. The dim is in the board and
  piece shaders, so the winning piece stays out of it.
- **A draw** ([rules](rules.md#draws)): the clock stops, the board dims, and a card like
  the win's shows both pieces, "Draw" and why, over back and play again.
- **The countdown** before a draw: in a count's last five moves a line under whose turn
  ("Draw in 3 moves", "White must win in 3 moves", "Same position twice"), with dots in
  landscape; with clocks a short form between them.

**Home** (`prototypes/home.html`): the scene and the board, and one glass column with the
wordmark and rows 88 dp tall: Continue (when there is a game to resume, `shell::resume`),
New game with the setup's opponent at its end, How to play in Continue's place for a
player who hasn't learned yet, Puzzles (solved count, or today's dots once
[daily puzzles](puzzles.md#daily-puzzles) open), the games played with the rating
([results](#the-results-screen)), and Settings. Where the rows don't fit they scroll under
the wordmark, fading at the foot. In portrait settings is a bare gear beside the wordmark.
A bare X in the top right closes the app at once on a touch screen
([why](../decisions/rendering.md#controls)); on a desktop a Quit row replaces it where it
fits, and quitting asks first (`home::ask_quit`). The player's chip mirrors the X at the
top left (`home::player_spot`). The board keeps clear of both and isn't shown under
128 dp (`board::SMALLEST`).

**New game** (`prototypes/setup.html`) opens the setup in the same column: whom to play
(a friend, or the computer easy, medium, hard), which draughts (International, Brazilian,
Russian), the child's pieces against the computer or whether the board turns with a
friend, and the clock; then play. Choices are kept in the player's file. The board beside
it is the game play will start, so nothing jumps; it switches at once rather than
crossfading. Where the choices don't fit they scroll between the head and play.

**Settings** (`prototypes/settings.html`, `src/shell/settings.goose`): back,
the title, and the language button pinned on top, then one scrolling list: **Look**
(Background, Theme, Board: Flat, Raised, Wood, Stone, Carved; Kings), **Game** (Move hints,
Move list), and the privacy note. A new player starts on Raised on a desktop and on Flat
on a phone or a tablet. Pictured rows show a 76 × 50 dp picture over the word
(`gui::choice`). In landscape the list is a 480 dp column at the left and the preview the
rest; in portrait the preview is a band on top. The preview is home's board moved there
(see [Transitions](#transitions)), set to one fixed capture position that shows what the
move hints do; the 3D preview turns under a drag as home's board does (see [Board and
pieces](#board-and-pieces)). The language button opens a small list of the languages in
themselves.
`test/shell/settings_sizes` checks the sizes.

**The puzzles** (`prototypes/puzzles.html`): a library of themes and a theme's page. The
library has back, the title, the draughts switch (the setup's choice, one setting), and a
glass row per theme with its mark, stars, and a bar; locked themes show what unlocks them.
How to play's row, and Today's row once open, head the list
([daily puzzles](puzzles.md#daily-puzzles)). Today's row holds a tile per puzzle, and the
row itself is a tile round them that opens the first unsolved, or the first once all are
(`picker::today_row`). Rows are one column in portrait and two in
landscape where they fit, scrolling where they don't. A theme's page lists its levels as
rows of tiles with 0 to 3 stars.

**A puzzle** (`prototypes/puzzle.html`): the game's layout; on the right whose puzzle it
is, the goal's icon and words, the three stars at stake, and next (dim until solved). A
wrong move plays, then slides back with a red flash, "try again" shows for 2 s, and a star
goes out; where the other side would answer it, that answer plays first
([puzzles](puzzles.md#the-screen)). After two misses the piece to move glows. Solved, the
stars pop in and next lights.

**How to play** (`src/shell/tutorial.goose`, `prototypes/tutorial.html`): the rules one
step at a time, each played on the board in a puzzle's layout with the moves shown: nine
steps for International and Brazilian, ten for Russian. The last opens a card offering
Puzzles, New game, and Home. Steps played are kept (`learned.<draughts> = n`).

**Players** (`prototypes/players.html`; what a player holds:
[players](README.md#players)): home's chip opens who's playing, a card of up to four
players' badges with + and a pencil for editing. The sheet edits the badge and name (up to
12 characters, SDL's text input) and offers start again and remove as 1.5 s holds, not
dialogs. A new player is asked whether they know how to play.

**A badge** is a man with an animal in the crown's place (`badge()` in
`src/app/widgets.goose`). The animals are SVGs in `assets/badges/`, baked at start by
`src/badges/badges.goose` into a signed distance field, 96 × 96 per animal (an R8 texture,
54 KB). An SVG needs a viewBox and one or more paths (`d` commands M L H V C S Q T A Z,
transforms applied, filled even-odd); fills, strokes, and other elements are ignored.
`test/badges` checks each file.

### The lookout and the hint

What they show is in `docs/product.md` and [ai](ai.md#the-lookout).

- **The eye** (`panel::eye`): a floating disc toggling the lookout, at the end of whose
  turn's line.
- **The hint's tile** (`panel::hint_tile`): the bulb, its word, and three pips for the
  hints left; dim with none left or none to give.
- **The marks** on the board (`board::fill`): a piece in danger is drained (greyed, darker,
  tinted red, `board::DRAINED`); a crowning square is shaded red under a ghost of the other
  side's king; the hint's piece takes the glow ring and its square a light ghost, pulsing
  twice then holding. A move clears them.
- **On the 3D board** the same state: drained pieces by a negative seed, ghosts as blended
  instances, the shaded square in the still marks' pass. They are part of the scene, so
  they redraw the board once when they change.

### What each side has taken

`game::taken` counts each color's start pieces less those on the board, men and kings
apart (kings from the undo history), once a move has shown. They are drawn as piece
instances over the UI (`panel::taken`): on glass under the left corner panel in flat
landscape, above the board between the corner panels in 3D landscape where it clears,
under the bar in portrait, each side's on a card of its own once it has taken something.
A puzzle shows none.

### The moves panel

The game's moves (`game::moves_panel`; the player's `moves` setting: off, the moves, the
moves marked). On a tablet or desktop in landscape it is a glass panel under the way out's
tiles, a scrolling list of rows: the move's number, white's and black's move, the latest
lit, each with its mark ([ai](ai.md#judging-a-move)): a star for the best, `?!` gold, `?`
orange, `??` red. The glass grows a row a move up to its room. A marked move explains
itself in a tip (`game::tip`), under the mouse or on a tap.

On a phone the moves show as a line that opens a sheet (`src/game/sheet.goose`): in
landscape the left column's foot, in portrait a pill of glass in the bar's row, between the catches. The sheet lists every
move, each side's accuracy, and the marks' legend (`game::legend`). With the setting off
there is no panel or line.

### The results screen

`src/shell/results.goose`, from home's results row: the draughts as tiles with the
player's rating there, a panel with the rating and the results against each level, and a
scrolling list of the games, newest first: the result, the opponent and date, the rating's
change, and the blunders as `?? n`. A row opens the game's replay. On a desktop's large
window (`gui::large`) it is at most 1640 dp wide and drawn larger.

#### A game's replay

`src/shell/replay.goose` shows a finished game at any move, opened at its end: four step
tiles (start, back, on, end) beside or under the board, and a glass with the move shown,
its mark and tip, each side's accuracy, and the moves as the moves panel draws them. A
line over the board says a game from here doesn't count. On the board the last move's
squares are shaded, its way drawn in dots with the squares' numbers, and its mark in a
disc. The bulb, or the glass's line saying what was best, compares the move shown with
the best one in its place: the board goes back to the position before the move, its way
still in dots with its mark, and the best move drawn as the game's hint. The comparison
stays on through the steps.
Left and Right step with the keys (`gui::claim_sideways`). The board takes no taps.

The replay has its own board and moves (`shell.replay`): opening it reads the game's line
from the history file (`history::line_of`) and plays it out with the rules into fixed
buffers (513 positions, 512 moves). A frame allocates nothing.

#### A game played from a replay

Play from here (`shell::play_from_here`) starts a game from the position shown: the same
draughts, opponent, and side, no clock, its moves numbered on from the replay's
(`Game.ply0`). It counts for nothing (`shell.trial`, `Game.no_count`): it writes no
history and moves no rating. The game in progress is set aside (`shell::park`) and comes
back on leaving (`unpark`). Start over goes back to the replay's position; the way out
goes back to the replay.

### Transitions

Three switches take 0.25 s each way, smoothstep-eased: home and settings, home and the
game, the puzzles and a puzzle. The board slides and resizes between the two screens'
places, over both screens' panels; the screen left fades out and the one come to fades in,
drifting 40 dp the way the board moves. The photograph goes from sharp to blurred into
the game or a puzzle. Only one set of pieces is ever on screen. A tap lands on the screen
come to; back turns a transition round. The clock and the computer wait until it ends.

The shell keeps one transition (`shell::go_to`). Each frame it declares the screen left
with no pointer (`gui::listen`, `game::still`), then the screen come to, fades each's
quads (`gui::fade`, a quad's `extra.w`), and cuts the board's rect out of them
(`shell.hole`) but for what lies on the board (`gui::on_board`). The board pass mixes
the sharp and blurred photograph by one uniform. While a transition runs
`shell::animating` is true; the frame after it ends is drawn at rest.

With the 3D board the board is drawn once into its kept image through the larger end's
view, and each frame lays that image moved and scaled between the two ends' bounds
(`shell.place`); both ends share the camera, so the image only scales and shifts.

### Board and pieces

- **The flat board**: the theme's squares in a raised lip 1.1% of the board's width,
  corners rounded 1.6%, a soft shadow under it. The lip is the dark square's color with a
  line of the light square's on its outer edge.
- **Pieces** are SDF discs filling 78% of a square, flat-topped and matte, with a groove
  at 70% of the radius, only the outer edge rounded, and a short soft shadow.
- **Kings** are a setting: crown, stack, or auto (the default: a crown on the flat board,
  a stack of two discs on the 3D one). It applies to the game, the winner's piece, and the
  preview.
- **Native form** (`src/app/draw.goose`): the blurred photograph, the board's shadow, lip,
  squares, and marks are one full-screen fragment pass worked out at `gl_FragCoord`; the
  pieces are one instanced draw of quads pulling `{center, radius, lift; black, king,
  selected, opacity; must capture, side to move}` and drawing shadow, side, face, crown,
  and rings, top row first.
- **States**, in the theme's glow: the selected piece lifts and takes a glow ring. With
  move hints on, a target is a dot and a capture's stop a ring. On mistakes only (the
  default, `docs/product.md`) a wrong move flashes a red ring twice and the pieces that
  must capture pulse a red ring (`#ff5a4a`, every 1.4 s); under the majority rule the
  pieces the legal captures take pulse too (`board::outnumbered`). A piece that must
  capture shows how many it takes as pips on its ring (`board::takes`, `board::counting`),
  one larger red pip with the number past five. The last move's squares are tinted with
  the glow at 16%.
- **Multi-jump captures** are tapped or dropped by their last square, or stop by stop along
  any of their ways (`board::follow`, `rules::ways`): the piece waits on each stop, the
  pieces it jumped see-through (`board::TAKEN`) until the capture ends; it is never
  finished by itself. A square merely passed over is nothing (`board::passes`). A wrong
  square leaves the waiting piece (`board::missed`): the first miss pulses what remains to
  take, the second lights the next stops. Undo while a piece waits unwinds the capture
  (`board::unwind`). A puzzle (`Board.by_hand`) shows none of these.

**The 3D board** (`src/board/view3d.goose`, plain math): the
board in perspective, 52.5° down with a 31° field of view, fitted into a screen rectangle
by a scale and shift in clip space; 65° down in portrait (`panel::PITCH_PORTRAIT`). A tap
becomes a square by a ray through the perspective. Each frame's instances are filled from
the flat board's draw lists (`board::fill`), so both views follow one state.

- **The screen round it** (`panel::corners_in`): the corner panels as above, the board as
  large as clears them.
- **The camera buttons** (`gui::floating`): View cycles the rest angle and the top view
  (74°), Zoom frames the playing field (landscape only), Showcase lets a drag turn the
  board ±35° and tip it 35° to 80°; each eases over 0.6 s. The camera is plain data in
  `board/rig.goose`; `panel::aim` fits it each frame.
- **Against a friend** the game starts in the zoomed top view (`rig::across_table`); with
  Turns it starts at rest and the board turns 180° after each move, the light keeping its
  place on screen (`render3d::turn_light`).
- **Every screen with a board** shows the 3D board when chosen: home and settings fit it
  into their room (`view3d::square`); a drag that starts on their board, off the UI,
  moves the showcase camera (`rig::drive`, `shell::drag_board`), drawing only on the
  frames it moves. The two screens share the camera (`Shell.cam`), eased back to rest over
  the transition whenever either is left (`shell::dragged_view`), so each opens at rest.
- **Drawn** by `src/render3d/` from `src/app/draw3d.goose`, meshes, looks, and the bake
  from `src/model3d/` (no graphics). The shadow map is drawn only when pieces move; the
  pieces' occlusion of the field goes into a 512² map only where squares changed; a
  king's crown is baked once into a 256² map. One 4× multisampled forward pass (the
  board's shadow, the lit board and pieces with the key light's shadow from a 1024² map,
  filtered more taps on desktop and iOS than on Android) draws into a kept image, only when
  the 3D scene changed (`view3d::changes`); each drawn frame lays it over the backdrop,
  itself kept (`render3d::keep_backdrop`), under the UI.
- **Off the screen** the pass's MSAA targets, the kept backdrop, and the kept depth go
  back: they stay while the board shows, so a move after a pause draws at once, and go at
  the frame's end once a screen without the board shows or the app on a phone or tablet
  goes to the background (`draw3d::rest`, `render3d::rest`); the next draw makes them
  again (about 4 ms more on an M1 Pro, 13 ms on an iPhone 13 mini).
- **Ambient light** is nine spherical harmonics from the blurred photograph, or from the
  plain fade scaled to a dim ambient (`model3d::no_photo_ambient`).
- **Getting ready** (`draw3d::prepare`) takes a step a frame: the setup, the theme's 28
  steps, the pass's 11 pipelines; a still mark shows meanwhile and the board fades in over
  0.3 s. A new season, size, or material keeps the old image, eased toward grey, until the
  new one is ready (`shaders::SHOW_FRAG`).
- **Pulsing marks** (a must-capture ring, a wrong move's flash, a hint's ring) stay out of
  the kept image: each frame adds them over it in one quad (`render3d::marks_over`),
  tested against a 16-bit depth the pass keeps while marks pulse, so a pulse runs the 3D
  pass only at its start and end. Still marks, including the count's pips, are drawn on
  the field by the still marks' pass (`shaders::MARKS_FRAG`).
- **Looks** are data (`src/model3d/looks.goose`). The material (the player's `material =
  auto|wood|stone|carved`) picks each season's look (`looks::of`):

  | Season | Auto | Wood | Stone | Carved |
  | --- | --- | --- | --- | --- |
  | Autumn | wood | maple and walnut in cherry | sandstone and porphyry | rust vines in weathered stone |
  | Winter | stone | limed ash and smoked oak | slate in black marble | a Nordic band in smoked oak |
  | Spring | carved | birch | ivory and jade, veined | the elven stone |
  | Summer | wood | the sunset wood | amber granite | amber signs in granite |

  `--autumn N`, `--winter N`, `--spring N`, `--summer N`, `--wood N`, and `--marble N`
  pick a look or model over the material, for tuning.
- **Wood and stone are baked** once into 2048² maps with mips (`shaders::BAKE_FRAG`) when
  getting ready and on a theme change, never per frame; on a phone's screen (`gui::phone`,
  a window as narrow too) into 1024² maps, each texel the average of the 2 × 2 the full
  bake has there, the same look at a quarter of the memory (`draw3d::screen_bake`): growth rings round a wandering
  pith with pores and fibre relief, colored by Beer's law, under a finish per look
  (`looks::Finish`); marble as contours of a warped ramp. The bake takes 37 ms on an M1
  Pro and about 0.3 s on the Galaxy Tab A11+.

## Fonts

**Libertinus Sans** (SIL OFL 1.1), a humanist sans with õ ä ö ü š ž
([why](../decisions/rendering.md#fonts)), regular weight, in `assets/fonts/`. The atlas
bakes Latin-1, Latin Extended-A, and general punctuation.

`src/app/text.goose` bakes it with `ui`'s atlas once per size the UI uses at the screen's
pixel size, so a glyph is a texel a pixel: 64 dp for the wordmark, 30 for labels, 17 for
notes, and so on. The atlas sizes a font by ascent less descent (1.14 em), so each is
baked at 1.14 times its size to match the prototypes' CSS. Glyph boxes go into `gui`'s
fixed tables, which lay text out headless; the coverage goes to the renderer
(`render::upload_text`); the atlas is then destroyed. Baked again only when the scale
changes.

- **The title and figures hold only their characters** (`shell::face_chars`): the 64 dp
  face the app's name in every language, the 36 dp figures the clock's digits and colon,
  and `?`. `test/shell/faces` fails if a string uses a character outside its face's set.
- **One byte a texel, only the rows used**: `ui` bakes RGBA at a power-of-two height
  ([findings](../goose-findings.md)); the app uploads the alpha alone, down to the lowest
  glyph, as R8. The texture is 0.25 to 1.45 MiB from a low-density phone to a 2880 × 1920
  screen, under 2 MiB, so it lives in SDL's shared blocks ([GPU memory](#gpu-memory)).

## GPU memory

On Android all GPU memory comes from SDL_GPU's Vulkan allocator, as patched by
`patches/SDL/0003-large-allocations-at-their-size.patch` ([findings](../goose-findings.md)).
The Mac's Metal leaves allocation to the driver.

- **Up to 2 MiB** (by the driver's requirements): shared 16 MiB blocks, as upstream. The
  storage buffers, text atlas, ASTC photograph, blurred copies, thumbnails, and uniform
  buffers live there, one block on the tablet. An emptied block goes back.
- **Over 2 MiB**: a `VkDeviceMemory` of the resource's exact size, given back soon after
  the resource is released ([why](../decisions/rendering.md#gpu-memory)).
- **Transfer buffers** are their own allocations; each drawn frame makes and frees three
  small ones (gfx's `update_buffer`).
- Large allocations happen at launch, on a resize or rotation, and (with a decoded JPEG)
  on a season change; never in a frame that only draws.
- A released texture is freed only after its submit completes, so the app calls
  `gfx::flush()` between short-lived resources made in a row.

At home on the Galaxy Tab A11+ (1920 × 1200): GL mtrack about 36 MB (the screen 9.6 MiB,
one shared block, about 10 MB of the driver's own), EGL mtrack 55 to 60 MB, native heap
about 27 MB. The swapchain is the driver's minimum: SDL asks for 2 images, but the Mali's
`minImageCount` is 6, so it is most of what is left at every size.

On the CPU, Android's Scudo keeps freed pages resident, so the app calls
`mallopt(M_PURGE_ALL, 0)` once in the first idle frame after launch (`src/app/memory.c`,
about 16 MB, 2 ms). The computer's worker's tables (about 5 MB, [ai](ai.md)) take memory
only once it first plays.

Adding large resources:

- Make and release them at load, a season change, or a resize, never per frame; each over
  2 MiB is one `vkAllocateMemory`.
- A large target SDL cycles (cleared or written with `cycle` while the GPU still reads it)
  keeps extra copies for good; clear without cycling where the GPU can wait. A target
  cleared by its first pass right after it is made is cycled too.
- A pipeline is compiled once per set of target formats (about 0.4 s for the 3D bake's
  on the Pixel 7a), so keep formats shared.
- Reuse one transfer buffer for large per-frame uploads.
- A 4× MSAA target costs four times the screen's bytes: SDL doesn't use Mali's lazily
  allocated memory. The fork's `msaa-resolve-without-store` saves the bandwidth of storing
  samples, not the memory ([findings](../goose-findings.md)).

## The 3D board on devices

Measured with `--bench 300` ([development](../development.md#time-the-3d-board)), idle with
`scripts/idle_cpu.sh`, memory with `dumpsys meminfo` at rest, Android with
`scripts/device_perf.sh` on a release build, the iPhone with `scripts/ios_perf.py`
(`--rest`). How the numbers came to be:
[decisions](../decisions/rendering.md#the-3d-board-on-devices).

| Device | Board | Idle program thread | GL mtrack | EGL mtrack | Total PSS |
| --- | --- | --- | --- | --- | --- |
| Galaxy Tab A11+, 1920 × 1200 | 2D | 0.04 to 0.08% | 37 MB | 55 to 60 MB | 133 to 141 MB |
| Galaxy Tab A11+ | 3D | 0.28 to 0.32% | 210 MB | 32 MB | 295 MB |
| Pixel 7a, 2400 × 1080 | 2D | 0.08% | 45 MB | 73 MB | 159 MB |
| Pixel 7a | 3D | 0.04% | 215 MB | 73 MB | 324 MB |
| Galaxy A33 5G, 2400 × 1080 | 2D | 0.04% | 35 MB | 43 MB | 116 MB |
| Galaxy A33 5G | 3D | 0.04% | 197 MB | 29 MB | 275 MB |
| iPhone 13 mini, 2340 × 1080 | 2D | 0.08% | | | 59 MB footprint |
| iPhone 13 mini | 3D | 0.08% | | | 204 MB footprint |

- **Galaxy Tab A11+** (90 Hz): waited P50 9.22 / P99 12.13 ms, 90 fps with none dropped.
  MSAA 4× adds about 3.2 ms, the shadow map about 2 ms on the frames that draw it.
- **Pixel 7a** (60 Hz): waited P50 13.5 / P99 16.0 ms; the theme ready at launch in
  0.76 s. The moving 3D frame is fragment-bound at 4.70M GPU cycles; the lit fragment
  shader holds 64 registers.
- **Galaxy A33** (90 Hz): the 3D frame waited P50 23.2 ms at 4×; it draws 2×. Its
  Mali-G68 loses the device on a mip level 0 pixels high, so the bake's mips stop at the
  shorter side's 1 pixel (`render3d::baked`; [findings](../goose-findings.md)).
- **A slow 3D board** on Android: once 60 frames average over 1.25 refreshes
  (`src/app/display.c`), the pass draws 2× MSAA (`render3d::FEW_SAMPLES`); if still slow
  on a display faster than 60 Hz, the app asks for 60 Hz while the 3D board draws
  (`ANativeWindow_setFrameRate`). The log says `3D board: too slow for the display, 2x
  MSAA`.
- **At rest** the tablet's 3D board spends about 2.7 ms CPU a wakeup against the flat
  board's 0.3.

### The release's frames

The release in a game (Russian, wood, the start), idle 25 s at rest and drawing every
frame (`--bench 1000`); frames as the display showed them (Android's compositor,
Instruments on the iPhone, PresentMon on Windows, the app's bench on Linux), against
11.1 ms at 90 Hz or 16.7 ms at 60 Hz ([development](../development.md#time-the-3d-board)).

| Device | Board | Idle CPU (one core) | Memory | FPS (avg / 1% low) | Frame time (P50 / P99) |
| --- | --- | --- | --- | --- | --- |
| Galaxy Tab A11+, 1920 × 1200, 90 Hz | 2D | 0.08% | 137 MB | 90 / 90 | 11.1 / 11.1 ms |
| Galaxy Tab A11+ | 3D | 0.32% | 295 MB | 90 / 90 | 11.1 / 11.1 ms |
| Pixel 7a, 2400 × 1080, 60 Hz | 2D | 0.08% | 159 MB | 60 / 60 | 16.7 / 16.7 ms |
| Pixel 7a | 3D | 0.04% | 324 MB | 60 / 60 | 16.7 / 16.7 ms |
| Galaxy A33 5G, 2400 × 1080, 90 Hz | 2D | 0.04% | 116 MB | 90 / 90 | 11.1 / 11.1 ms |
| Galaxy A33 5G | 3D | 0.04% | 275 MB | 75 / 45 | 11.1 / 22.2 ms |
| iPhone 13 mini, 2340 × 1080, 60 Hz | 2D | 0.08% | 59 MB | 60 / 60 | 16.7 / 16.7 ms |
| iPhone 13 mini | 3D | 0.08% | 204 MB | 60 / 60 | 16.7 / 16.7 ms |
| Windows PC, 2560 × 1440, 165 Hz | 2D | 0.00% | 258 MB | 165 / 165 | 6.1 / 6.1 ms |
| Windows PC | 3D | 0.12% | 477 MB | 165 / 165 | 6.1 / 6.1 ms |
| Linux PC, 1920 × 1080, 60 Hz, Wayland | 2D | 0.01% | 84 MB | 60 / 58 | – |
| Linux PC, Wayland | 3D | 0.02% | 89 MB | 60 / 58 | – |

Memory is PSS on Android and Linux (Linux's leaves out the GPU's own), the footprint on
the iPhone, and private bytes on Windows. The 3D board's extra memory is GPU memory: 180
to 230 MB against about 36 MB in 2D. The Galaxy A33's 3D frame (15 to 16 ms of GPU work
at 4×) shows 19% of its frames for two refreshes.

### When a frame reaches the screen

goose_gfx records a frame and its blit into the window's image in one command buffer,
committed once SDL has that image (`SDL_WaitAndAcquireGPUSwapchainTexture`, 2 frames in
flight). On Metal the command buffer then waits until the image's surface is free, so a
frame's GPU work must end about 7.5 ms after a refresh at 120 Hz, not 8.3. On an M1 Pro at
2560 × 1600 the moving 3D frame takes 6.2 ms and about 1 frame in 200 is late
([why](../decisions/rendering.md#when-a-frame-reaches-the-screen)).

## Frames and battery

The app draws only when something changed: input, a running animation, the computer's
reply, or a new size, safe area, or scale. Otherwise goose_gfx's `frame()` neither
presents nor spins; it waits for the next event, up to a second. An idle board costs about
one wakeup a second and no GPU work.

```goose
while gfx::frame() {
    // read input, advance animations; set dirty if anything changed
    if dirty || animating { draw(); dirty = false; }
}
```

This is the fork's `draw-on-demand` ([findings](../goose-findings.md)), in every build
(`scripts/android.py`, `ios.py`, `mac.py`, `windows.py`, `linux.py` build goose_gfx from the
fork). The release's own gfx presents every frame. The patched `frame()`:

- presents only if something used the GPU, or the window needs the screen again
  (exposed, restored, resized, back in the foreground);
- after a frame with nothing drawn, waits in `SDL_WaitEventTimeout` up to 1 s;
- retries up to 8 frames when the window has no image yet (after Android recreates the
  surface);
- leaves the wait out of `delta_time()`;
- on Android turns off SDL's poll sentinel, without which the wait spins;
- on iOS waits in the main run loop (`CFRunLoopRunInMode`), woken by a run loop source of
  gfx's own (`ios-run-loop-wait`).

On Android `DraughtsActivity` keeps SDL's Java from listening to the accelerometer, which
would wake the app 52 times a second ([findings](../goose-findings.md)).

SDL keeps the screen on while the window is open. After 15 minutes with no touch, key,
or computer move, `host::keep_screen` hands the screen back to the system's own timeout,
which dims and locks it. The next touch keeps it on again. The idle loop's wake-up once
a second is all the check needs.

At rest over 25 s (`--rest 25`):

| Where | Process CPU | `frame()` returns, draws |
| --- | --- | --- |
| Android, Galaxy Tab A11+ | 0.04 to 0.3% of a core | about 1 a second, none |
| iPhone 13 mini, a game, flat or 3D | 0.08% | 26, none |
| iPhone 13 mini, a clock running | 0.52% | 51, 26 |
| Mac, home | 0.03% (8.2% with the release's gfx) | 27, none |
| Mac, a clock running | 0.17% | 51, 26 |
| Windows, home | 0.06% | 27, none |
| Windows, full screen, a game, flat or 3D | 0.06 to 0.18% | 27, none |
| Linux, Wayland, home | 0.01% (0.65% with the release's gfx) | 26, none |
| Linux, full screen, a game, flat or 3D | 0.01 to 0.02% | 26, none |
| Linux, a clock running | 0.05% | 53, 27 |

Rules that keep it so:

- **Animations that move the 3D camera** run the 3D pass on each frame of the ease (about
  36 for 0.6 s at 60 Hz) and none once settled (`test/game/camera`). A pulse, a flash, or
  a hint's ring only adds marks over the kept image (`view3d::changes`' MARKS,
  `test/board/scene3d`).
- **The frame after an animation** is drawn too (`board::update` reports it), or the board
  would keep the move's last in-between frame without its marks.
- **A look a frame behind the board**: a screen declares its tiles before the board takes
  the pointer, so when the board's input changes a tile's look the next frame is drawn too
  (`gui::Gui.acted`).
- **A running clock** sets an SDL timer for when its shown time changes
  (`src/app/wake.c`), pushing an event that ends the wait, so the second is drawn within
  5 ms. `--frames` runs end every wait at once (`draughts_wake_now`).
- **Work on another thread**: while the computer thinks its piece pulses, keeping frames
  coming; a longer think against the clock sets the timer for its move (`game::due`). A
  hint or the lookout polls its worker every 20 ms (`HINT_POLL`) drawing nothing
  (`think::frame`).
- **In the background**: Android's SDL blocks the loop while paused; on iOS the loop
  draws nothing while the app hasn't focus, since iOS ends an app that submits GPU work in
  the background.
- **Long work stays off moving frames**: settings' thumbnails load in the first idle frame
  after launch (about 125 ms on the tablet where JPEGs are decoded), which also purges
  malloc's cache; a setting changed by a tap that starts a transition is written once the
  transition ends (13 to 17 ms on the tablet).
