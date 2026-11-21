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

The build holding goose-ngfx too (`src/main/draughts_ngfx.goose`) ships on macOS, iOS, and
Windows, gfx alone on Android and Linux; it draws the same frames through either, chosen at start (`--renderer auto|gfx|ngfx`). The drawers (`draw`,
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
`backend::with() { be => ... }`. The gfx build's `src/gfx/backend.goose` hands gfx's
backend; `src/ngfx/backend.goose`, in the second root `src/main/draughts_ngfx.goose`,
makes the choice ([architecture](README.md#code-layout)) and holds both. Both roots run
`src/app/app.goose`'s program.

goose-ngfx's shaders are gfx's GLSL, written as Slang at each build into
`build/ngfx/shaders/` (`scripts/ngfx_2d_shaders.py`, `ngfx_3d_shaders.py`) and compiled
ahead into `build/ngfx/blobs/`, which `src/ngfx/` embeds. `scripts/ngfx.py` also links the
goose-ngfx checkout at `build/ngfx/goose-ngfx`. Every build script writes the app's
version and commit into `build/draughts_version.c` (`scripts/native.py`), which settings'
About shows and the crash marker is keyed by.

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
- Calls append quads (`panel`, `button`, `icon`, `rounded_rect`, `text`) to one fixed array, reset
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
  a window whose width limits the board. The 3D board's frame has half its top margin moved
  to the bottom (`panel::FRAME_UP_3D`).
- Home's column stands 40 dp from the top, at least 440 dp wide (`home::DESKTOP_TOP`,
  `DESKTOP_COLUMN_W`).
- No window lays out wider than 1.9 times its height (`gui::WIDEST`): `gui::safe` keeps
  the middle of an ultrawide; the photograph and edge glass (`gui::extend_to_screen_edge`) still fill it.
- Taps are thinner: every tap-sized length is `gui::tap_size()` (88 dp touch, 64 desktop), a
  worded tile's side room `gui::word_padding()` (16 and 12), a tile with its icon over its word
  `gui::stacked_tile_height()` (at least 72 dp). The panels' heights are sums of their rows
  (`panel::corner_h`, `left_h`, `bar_h`, `play_h`), so they follow.

The **safe area** is the window less its insets (camera cutout, gesture bar). SDL reports
them (`SDL_GetWindowSafeArea`, read each frame with the display scale by
`src/native/display.c`). The app draws behind the cutout, so the photograph and glass that
runs off an edge reach the screen's edges; everything else is placed in the safe rect as
in a whole window of that size (`gui::safe`, `shell::frame`). The scale stays the whole
short side's, the same in both orientations. Layouts hold down to a safe area of 443 ×
801 dp. `DraughtsActivity`'s surface keeps the back gesture's side strips and the top swipe
strip inside the safe area, since taps there still reach the window. A change of insets or scale
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
- **A tap while a move shows** (`board::touch`): a press while the last move slides or
  its taken pieces fade is kept and pressed once it has ended, with its release if the
  pointer went up meanwhile. On a desktop the click that brings the window to the front
  counts too (`SDL_MOUSE_FOCUS_CLICKTHROUGH`, `src/native/display.c`).
- **The window control** (iPadOS's three dots at the top left) may sit over back or the
  player's chip; no screen moves for it ([why](../decisions/rendering.md#small-windows)).
  UIKit's corner-adapted safe area reports its reach, should a screen need it.

### Window resizing

While a Mac window's edge is dragged, Cocoa holds the main thread and the frame loop
doesn't run. `src/native/resize.c` keeps the Metal layer's last frame its shape, scaled to
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
- **Stored** per season at 2048 × 2048, embedded in the program with C23 `#embed`, as
  ASTC 6 × 6 (1.87 MB each, from the masters with `astcenc`,
  `design/backgrounds/README.md`), sampled as stored, and as JPEG at quality 85, decoded
  ([why 6 × 6](../decisions/rendering.md#scene-and-glass)). Android and iOS embed only the
  ASTC (7.5 MB of `libmain.so`) and no stb_image; Windows and Linux only the JPEG, which
  their GPUs need. The Mac app (the ngfx root, `DRAUGHTS_ASTC_ONLY`) embeds only the
  ASTC; the gfx root embeds both on the Mac, the JPEG for a plain `goose build` with the
  Goose release's own gfx, which lacks compressed formats. A
  checkout without the images still builds and shows the page color (`__has_embed`).
- **Loading**: `src/native/background.c` decodes (no graphics API) and `src/native/photo.c`
  uploads through gfx's C API, with no copy on the data stack. Compressed formats come
  from the fork's `compressed-textures` ([findings](../goose-findings.md)). Where ASTC
  isn't taken, the JPEG is decoded with stb_image into a 16 MB texture. A season loads in
  the frame after its lit tile shows, after a `gfx::flush()`; only the current season is
  resident, and the embedded pages are given back once read (`madvise`).
- **Settings' thumbnails** (`scene::thumbs`): each photograph shrunk on the GPU in turn,
  waiting after each, into one 1280 × 945 texture (4.8 MB) of 160 × 105 px slots, 8
  across: four photographs, four plain fades, and sixteen pictures a season from the
  atlas `design/boards/boards.jpg` / `boards-6x6.astc` (2560 × 420), made by
  `tools/assets/board_thumbs.py` from `tools/board_shot.goose`'s shots of each look: its
  four boards, then on each a light and a dark piece Matching and Classic, and the board on
  its table.
- **The table** (settings' Background row's third tile on the 3D board; the player's
  `table = on`): the 3D board on a round table, the take `tables::for_look`
  gives each look. It stands on a turned pedestal: a ringed column and an urn over a
  drum, and four cabriole legs ending in scroll toes on the floor (`mesh::table_base`),
  made with the top as one mesh and drawn with it, its wood the top's map with the grain
  along the column and the legs. A leg is a bar, a rounded section swept along a curve
  (`mesh::bar`), which other furniture's legs and rails can share. Putting it on or off
  bakes only the table's steps and the photograph's again (`draw3d::table_steps`). Behind it is always the plain fade, never
  the photograph (`settings::photo_shown`).
- **What each side has taken** lies on the table beside the board (`taken3d`): white's
  catch at the board's right as white sees it, black's at its left, both on the near half
  where the landscape panels leave the table in view, the kings apart from the men and
  nearer: the first two side by side, the next three in a line along the outer one, then
  stacked on those. The pieces are the board's (their material, instances in the same
  pass), but out of the shadow map, which covers only the board and shades the table
  too (`TABLE_FRAG`, with the board's outline past it): each is a disc in
  `Frame.discs` (up to 48), and the shaders work out their shadows from them. The table's
  takes each disc swept along the light, a capsule, and darkens the table round its foot
  (`TABLE_FRAG`'s `discs_shadow`); the lit shader, outside the field, traces the light's
  ray against each upright disc, which gives a piece its own shadow and its neighbours',
  and darkens where two meet (`LIT_FRAG`'s `discs_shadow`, `discs_occlusion`). A piece on
  the table takes its contact shading from its own foot. The layout is towers of five in
  a line (`taken3d::TOWERS`); `--taken stacks|row|heap` shows the others, and
  `tools/taken_tune.goose` tunes each. A place
  depends only on the piece's number, so a capture adds one and moves none. A capture's
  pieces stay on the board, see-through, till the last hop, then are carried to their
  places in 0.5 s (`board::CARRY`, in place of the 0.18 s fade), rising 1.2 units and
  growing opaque on the way; an undo carries them back. The flat panels' counts stay.
- **The pieces' finish** (settings' Pieces row on the 3D board; `pieces = matching|classic`):
  Matching is the look's own material; Classic plain pieces of one
  color with a faint mottling (`looks::classic`), which takes only the theme's last step.
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
  (8% and a 1 dp border at 40%), fading over `gui::PRESS`. `gui::press_widget` notes the topmost
  tile each frame and the next frame's `gui::begin` makes it the hovered one. A frame is
  drawn only while the hover changes or fades (`gui::animating`). `--mouse X,Y` holds the
  pointer for a shot.
- **The keys' focus** (`gui::focus_keys`): arrows move a focus among the controls each
  `gui::press_widget` offers (`gui::Spot`), Enter or Space presses it. The focused control is lit
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
  settings.txt keeps it (`window = full`) and the next start opens so, as does
  `--size full`. The window's state at closing is kept too, so leaving by macOS's green
  button sticks.
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
How to play for a player still learning (under Continue or Replay, else first and lit;
gone once a tutorial is played to its end, a game against the computer won, or the other
puzzle themes opened, `shell::past_basics`), New game with the setup's opponent at its
end, Replay in Continue's place once the last game has ended
(its note how it ended and against whom, on time where a clock ran out, outlined over New game, which is lit; it opens
that game's [replay](#a-games-replay), whose back goes home), Puzzles (solved count, or today's dots once
[daily puzzles](puzzles.md#daily-puzzles) open, smaller where they would come within
16 dp of the label), the games played with the rating
([results](#the-results-screen)), and Settings. A row's note keeps 12 dp from its label,
shrinking to fit down to 80% and left out below that (a long translation in landscape's
360 dp column). Where the rows don't fit they scroll under
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
(Theme; Board: Flat, Raised, Wood, Stone, Carved; then under a heading naming the board
the rows it uses: the 3D board's Pieces, Matching or Classic, and Background, Photo, Plain
or Table; the flat board's Background, Photo or Plain; Kings), **Sound** (Volume:
a speaker and a slider, [sound](sound.md#the-setting)), **Game** (Move hints, Move list),
and the privacy note with a small About row beside it. A new player starts on Raised on
a desktop and on Flat on a phone or a tablet. Pictured rows show a 76 × 50 dp picture
over the word (`gui::choice`). In landscape the list is a 480 dp column at the left and the preview the
rest; in portrait the preview is a band on top. The preview is home's board moved there
(see [Transitions](#transitions)), set to one fixed capture position that shows what the
move hints do; the 3D preview turns under a drag as home's board does (see [Board and
pieces](#board-and-pieces)). The language button opens a small list of the languages in
themselves.
`test/shell/settings_sizes` checks the sizes.

**About** (`prototypes/settings.html?about=tablet`, `src/shell/about.goose`) is a glass card over
the dimmed settings, for a bug report: the version, commit and its date, and the system;
the renderer (gfx or ngfx), its driver, the GPU's name, the display's refresh rate, and
the system's battery saver; and what the 3D board uses now: its antialiasing (with a note
when a slow device lowered it to 2×), its shadow's taps, and its surfaces' side, dim with
a note while the board is flat. Copy puts it all on the clipboard. Two columns where one
doesn't fit (a phone in landscape). The row, Copy, and close are 40 dp tiles, each taking
a tap round it. The app fills the card (`app.goose`'s `fill_about`, `about.c`): the build
at start, the system and the GPU's name (from Metal, or a Vulkan instance of its own) the
first time it opens, the rest each frame it shows.

**The puzzles** (`prototypes/puzzles.html`): a library of themes and a theme's page. The
library has back, the title, the draughts switch (the setup's choice, one setting), and a
glass row per theme with its mark, stars, and a bar; locked themes show what unlocks them.
How to play's row, and Today's row once open, head the list
([daily puzzles](puzzles.md#daily-puzzles)). Today's row holds a tile per puzzle, and the
row itself is a tile round them that opens the first unsolved, or the first once all are
(`picker::today_row`). Rows are one column in portrait and two in
landscape where they fit, scrolling where they don't. A theme's page lists its levels as
rows of tiles with 0 to 3 stars, scrolling under its head where they run past the foot
(International's three levels of Shots on a small phone in landscape).

**A puzzle** (`prototypes/puzzle.html`): the game's layout; on the right whose puzzle it
is, the goal's icon and words, the three stars at stake, and next (dim until solved). A
wrong move plays, then slides back with a red flash, "try again" shows for 2 s, and a star
goes out; where the other side would answer it, that answer plays first
([puzzles](puzzles.md#the-screen)). After two misses the piece to move glows. Solved, the
stars pop in and next lights.

**How to play** (`src/shell/tutorial.goose`, `prototypes/tutorial.html`): the rules one
step at a time, each played on the board in a puzzle's layout with the moves shown: ten
steps for International and Brazilian, eleven for Russian. Back a step (an arrow over a word, as next, dim on
the first step) plays the step before again: beside next in landscape, under start over
where the panel is narrower than two taps (a phone), and over next in portrait, whose play
panel grows to hold both. The last opens a card offering
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
- **The marks** on the board (`board::build_frame_pieces`): a piece in danger is drained (greyed, darker,
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
landscape, above the board between the corner panels in 3D landscape where it clears
(on a desktop the zoom keeps the whole board under it), under the bar in portrait, each
side's on a card of its own once it has taken something, its ends round.
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
scrolling list of the games, newest first: the result, the opponent and date (the day it
ended in the local zone, `history::zone`), the rating's change, and the blunders as `?? n`.
A row opens the game's replay. On a desktop's large window (`gui::large`) it is at most
1640 dp wide and drawn larger.

#### A game's replay

`src/shell/replay.goose` shows a finished game at any move. A game against the computer
opens at the player's first blunder (else first mistake), compared with the best move
there; a friend's game, or one with neither, at its end. The moves' columns put the
player's side first where the board is turned for them. It has four step
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
with no pointer (`gui::set_input_enabled`, `game::still`), then the screen come to, fades each's
quads (`gui::fade`, a quad's `extra.w`), and cuts the board's rect out of them
(`shell.hole`) but for what lies on the board (`gui::on_board`). The board pass mixes
the sharp and blurred photograph by one uniform. While a transition runs
`shell::animating` is true; the frame after it ends is drawn at rest.

With the 3D board the board is drawn once into its kept image through the larger end's
view, and each frame lays that image moved and scaled between the two ends' bounds
(`shell.place`); both ends share the camera, so the image only scales and shifts.

### The library's light

The library's shell (the light tuner's room) is lit as a room of its own, apart from the
board's light:

- **The sun** through its three windows, its penumbra about the sun's disc and its light on
  the room's surfaces 4.4 times the board's (`rooms::Room.shell_sun`), at 0.6 of the key's
  saturation; the panelling oak takes half of it at the key's saturation
  (`render3d::room_sun`), so the paper and the doors take the stronger sun and the
  wainscot keeps its look. A second, broad lobe of its highlight (roughness 0.8) lies on
  the painted wood and the paper (`render3d::sheen_look`). Its highlight takes
  only what comes through a window (`window_open`); the diffuse also keeps the shade's
  floor (`rooms::Room.pattern`'s x leaves 10% of the key in autumn, of which the room keeps
  a fifth beside its baked light, `render3d::shade_fill`), which stands for light thrown
  back and takes the occlusion. Any shadow inside a sun patch (the bars', the
  table's, the bookcases') removes only the sun: the shade's floor stays under each.
- **The games table's own shadow** (`render3d::table_map`): its top and base drawn into a
  1024 × 512 depth map projected along the key onto the floor round the table, drawn again
  only when the key or the table changes. The floor, the walls and the base itself take
  it; the floor under the base is darker by the drum's and legs' own occlusion, tightest
  round the scroll toes (`base_hides`), and no broader: the top's shade on the floor is
  the probes' and the screen's occlusion's.
- **Baked light** (`model3d::room_light`): a grid of 10,140 probes 0.3 m apart, half a step
  in from every wall, the floor and the ceiling, made on the CPU in about 88 ms when the
  room turns on and again when the sun, the room's light, the tree or the table changes,
  never per frame and held while a slider drags. Each probe holds the sky seen through the
  niches, the sun's patches thrown back, and the light the room throws on after that, as
  a constant and a direction per colour. A probe within 0.35 m of a wall, the floor or the
  ceiling also sums that plane's exact light (the clamped cosine) and turns its direction
  so the plane reads exactly that (`room_light::settle`); two bands alone would give a
  plane a quarter of each light along or behind it. A probe in a niche sees only its own
  window; one inside a wall, past the glass or behind the hall wall takes the light of
  the nearest probe toward the room (`fill_walled`). The light thrown on is bounced once
  more between 1,209 cells over
  the room's surfaces (half a metre on the floor, ceiling and walls, 0.2 m in the niches,
  the table's top) from every source: the sun's rays where they land, the sky through the
  niches on the floor, sills and reveals, the backlit lace; the probes gather it at half
  their density, with the stove end's own row. No surface throws back more than 0.85 of
  the light it gets (`thrown_albedo`), and a sill's or reveal's light leaves its niche
  only through the niche's outline. The lace lets about three quarters through where it
  hangs flat and less where it is gathered toward its tie, and throws on 0.4 of what it
  stops (`LACE_SCATTER`); its sun
  shadow stops about 28% of the sun where it hangs flat (its net a fifth, its motifs
  what the thread keeps), darker where gathered, soft, blurred well past the bars'. They fill a 390 × 78 RGBA16F atlas
  (0.24 MB) that `ROOM_FRAG` reads with six taps. Beside it the
  room keeps a part of the harmonics and of the flat bounce (`rooms::Room.baked`).
- **The games table in the room** takes the baked light too: the probes sampled at four
  heights on its axis after each bake, in its block (`render3d::probes_on_table`), its base
  at the room's exposure, its top at the board's, through the board's tonemap toe (off the
  least channel), as in the game. In the game it keeps the look's harmonics.
- **Contact shadows** (`ROOM_FRAG`'s `contact_lit`, `render3d::contact_look`), in the
  standard and high tiers where the SSAO's map is drawn: a 12-step ray 10 cm toward the
  sun over that map of positions stops 0.8 of the sun behind what stands nearer, so the
  architraves, the caps and the mouldings cast their thin shadows.
- **The panels** (`surfaces::panel_ring`): their rings shade as their profiles are, smooth
  where they turn by less than 32°, a step under 5 mm wide shaded from the facet before it
  to the one after, the groove's occlusion a thin dip in its first 4 mm.
- **The toes**: each tonemap keeps its own (the room's and the view out's on the
  luminance, the board's and the table's off the least channel); the light tuner can switch
  them in shaders of its own (`shaders::TOE_FN`, `--toe`, `--table-toe`, `--board-toe`).
- **Corners and edges** (`model3d::corner_map`, `rooms::Room.corners`): the
  indirect light darkened by the distance to each of the shell's planes standing square to
  a surface, a plane hiding a half of the light at the line and nothing beyond the reach
  (0.4 m): the floor along the walls, the inside corners, the walls along the floor and
  under the cornice, the ceiling past it, over and under the wainscot's cap, under the
  sills, the windows' niches, the doors' jambs and architraves, round the bookcases. What
  stands out of a wall and ends (the bookcases, the architraves and plinth blocks, the
  sills' noses, the piers beside a niche) is a box whose faces' shade falls off past their
  edges, and the doors' and windows' openings are holes in their walls, so no shade runs on
  past an outside corner. Every tier; the sun is never darkened by it. Baked on the CPU
  into an R8 atlas (4096 × 1013, 4.1 MB, about 300 ms on an M1 Pro) when the shell's mesh
  is made or the corners change: the mesh cut into planar charts, each laid flat at 2.5 mm
  to 2 cm a texel; `ROOM_FRAG` reads it with one tap held inside the vertex's chart.
- **Ambient occlusion from the screen** (`render3d::ssao_pass`, `rooms::Room.ssao`), in
  the standard and high tiers, not on a phone (`render3d::ssao_allowed`): before the
  board's pass the room, the table, the board and the pieces are drawn at half size into
  where each pixel is and which way it faces (`PRE_FRAG`; the lace hides less, the glass
  nothing); each pixel's share of the sky hidden within 0.35 m, eight taps on a spiral
  turned across a 4 × 4 block (`SSAO_FRAG`), blurred over that block by distance
  (`SSAO_BLUR_FRAG`), so a still frame shows no noise. `ROOM_FRAG` and the table's room
  shader read it back by the distance from the eye (`SSAO_FN`) and darken their indirect
  light by the lesser of it and what the mesh and the corners already know, so no plane
  is darkened twice: the books between them and under the shelves, the table's base and
  the floor round it, the curtains' folds, the shutters, the window's frames. Five
  half-size targets, 22 bytes a pixel (8.8 MB at 1600 × 1000). The light tuner's Light
  section sets its strength, reach, bias and gain, and shows it alone (`--ssao-view
  alone`) or with all the indirect light keeps (`kept`).
- **The floor's mirror** (`render3d::planar_pass`, `rooms::Room.planar`), in the standard
  and high tiers, not on a phone (`render3d::planar_allowed`): before the board's pass, the
  view out, the table and the room are drawn mirrored across the floor at half size, the
  clip's depth made the height over the floor so nothing under it is drawn, the room with
  `ROOM_FRAG` less its sharp reflections and screen occlusion (`MIRROR_PASS`). Each
  shader there writes its exposed light before the tonemap (`mirror_light`, held to 16),
  the view out at `planar.w` (6) times its look, as a clear sky is far brighter than the
  tonemap shows. The board and its pieces are left out: from under the floor the table's
  top hides them. A resolve (`PLANAR_RESOLVE_FRAG`) takes a 3 × 3 tent over that picture
  back by the room's exposure, each texel made safe first (NaN, infinity and negatives
  black, the luminance held to 16), with each texel's distance from the floor along the
  reflection from the depth, into an RGBA16F map with six mips, each a tent over the
  level above (`PLANAR_MIP_FRAG`, a pass a level), so a window's bar reads the same
  wherever it falls on their texels; above the floor's far
  edge it repeats the nearest drawn texel below, so no blur takes in black. The floor
  (`PLANAR_FLOOR`'s `planar_seen`) finds the point its flat reflection shows along the wax
  film's normal (its board's tilt and cup, a quarter of the grain), at the distance the
  map's second mip gives, blurred by the film (half the oak's roughness) as wide as its
  lobe is at that distance and at least three texels across and six down, so the contact
  is sharp but steady as the eye moves and a door's head smeared, drawn out down the
  screen by 1 / n·v in five taps of one mip chosen from those widths, as a grazing look
  stretches it into streaks; each board's wax a little stronger or weaker and its film smoother or
  rougher; where the wax is worn (the paths, scratches, slow patches, the grain's pores)
  the film's mirror turns toward the oak's rough sheen; Fresnel by the view's angle
  through the film; at 0.85 of it. Past the screen's edge it fades to the
  room's light that way. Three targets at half the screen's height and at least 1600
  texels across (at most its width, `render3d::planar_least_wide`), 16.5 MB at
  1600 × 1000. The light
  tuner's Light section sets its strength, the film and the boards' wax (`--planar`), and
  shows the floor's reflection alone, the map or its distances (`--planar-view
  floor|map|distance`); its walk records a strafe, a turn or a walk forward frame by frame
  (`--walk-frames`).
- **Reflections**: the brass, and on a phone the waxed floor too, see the shell's box (its
  walls, doors, ceiling and floor lit by the probes and the sun) and its windows, worked
  out per pixel. Brass inside a window's niche (the shutters' hinges) sees the window's
  light (`lace_light`) instead as it turns to face out of the room. Brass takes neither the
  corners' shade nor the screen's occlusion, only its mesh's own.
- **The window's glow**: a quarter-size bloom of what is near white, added in linear light
  (`render3d::bloom_pass`, `rooms::Room.bloom`).
- **The oak outside** is blurred once when uploaded (`render3d::soften`), and the tree
  that shades the windows draws its limbs finer and softer than the game's
  (`rooms::SHELL_LIMBS`).

### The library's bookcases and books

Two open oak bookcases stand built into the hall wall either side of the door
(`room_shell::bookcase_at`, `bookcases.goose`): a folio base 0.45 m deep with its ledge on
the wainscot's line at 1.20 m, an upper case 0.30 m deep to the architrave's head at
2.84 m. They are part of the shell's mesh, made once when the room turns on. Their books
(`model3d::books`) are boxes with rounded spines, about 390 of them at 10 triangles each,
filled onto the shelves by size, sets together in runs of a few volumes, mostly in old
calf and half calf browns. Each spine samples a cell of a mask atlas
(`design/materials/books_atlas.png`, 1024 × 928 RGBA8 with four mips, 5 MB on the GPU;
its cells in `book_cells.goose`, both made by `tools/materials/books.py`), and `ROOM_FRAG`
colours it from a table of covers and labels in the room's block, picked by the code in
the vertex's material, with gilt, wear and the sun's fade. Inside a case the books and
the oak are darker under each shelf and toward the back, and `case_shade` keeps the sun
off what the case's ends, upright, shelves and books hide. The titles are baked into the
atlas; the fonts that set them stay with the baker.

### The library's shutters and doors

Each window's reveals hold a pair of working shutters folded flat
(`shell_mesh::shutters`, `room_shell::SHUTTER_*`): a panelled front leaf 0.325 m wide on
three brass knuckles at the lining, a plain back leaf behind it on two more, the 58 mm
stack outside the daylight, the middle window's right pair standing 14° ajar. Each door's
two leaves hang 1.5 cm behind the wall's face in a rebate, 4 cm thick with 3 mm joints,
the right leaf with a meeting bead and a lever on a long escutcheon, three knuckles a
leaf on the outer jambs (`shell_mesh::door`). They are part of the shell's one mesh, in
its paint and the curtains' brass; the hinges are lathed (`shell_mesh::lathe`), the bead
swept upright, their normals smoothed as the mouldings' are. The baked light sees the
stack's face in front of the lining and the niche's opening narrowed to the stacks'
front edges (`room_light::open_half`). The wainscot's cap returns 1.5 cm into each reveal, its
end square 5 mm before the stack's front edge (`shell_mesh::cap_return`). The light
tuner's `--shutters off` (H) leaves the shutters out and the cap's return 6.5 cm, making
the mesh and the bake again ([why](../decisions/rendering.md)).

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
the flat board's draw lists (`board::build_frame_pieces`), so both views follow one state.

- **The screen round it** (`panel::corners_in`): the corner panels as above, the board as
  large as clears them.
- **The camera buttons** (`gui::floating`): View cycles the rest angle and the top view
  (74°), Zoom frames the playing field (landscape only), Showcase lets a drag turn the
  board ±35° and tip it 35° to 80° (a drag past a limit turns back only from where it
  reached it); each eases over 0.6 s. The camera is plain data in
  `board/rig.goose`; `panel::apply_camera` fits it each frame. The zoom stands at the
  room's bottom at the rest angle and in its middle in the top view; on a desktop the top
  view's room reaches to a gap above the window's foot, and the board sits lower where
  what each side has taken holds it down. The game's view and
  zoom are kept in the player's file and come back at launch (`rig::choose`).
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
  filtered more taps on desktop and iOS than on Android; on a desktop the spring stone
  board also lets the key light scatter through its stone) draws into a kept image, only when
  the 3D scene changed (`view3d::changes`); each drawn frame lays it over the backdrop,
  itself kept (`render3d::keep_backdrop`), under the UI.
- **Off the screen** the pass's MSAA targets, the kept backdrop, and the kept depth go
  back: they stay while the board shows, so a move after a pause draws at once, and go at
  the frame's end once a screen without the board shows or the app on a phone or tablet
  goes to the background (`draw3d::release_targets_unless_shown`, `render3d::release_targets`); the next draw makes them
  again (about 4 ms more on an M1 Pro, 13 ms on an iPhone 13 mini).
- **Ambient light** is nine spherical harmonics from the blurred photograph, or from the
  plain fade scaled to a dim ambient (`model3d::no_photo_ambient`).
- **Getting ready** (`draw3d::prepare`) takes a step a frame: the setup, the theme's 44
  steps (the table's 16 skipped without one), the pass's 12 pipelines. Meanwhile the
  board's place shows "Setting up the board…" under a thin white bar with rounded ends
  over a faint track as long as all of it (`gui::loading_bar`), filled by the steps' weight: each step's time
  on a Pixel 7a (`draw3d::theme_ms`, `warm_ms`), as the bake's and the lit pipelines'
  compiles take most of it. The board fades in over 0.3 s. A new season, size, or material keeps the old image, eased toward grey, until the
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
  | Winter | stone | limed ash and smoked oak | Cloud breccia with ivory and black marble pieces | a Nordic band in smoked oak |
  | Spring | carved | birch | ivory and jade, veined | the elven stone |
  | Summer | wood | the sunset wood | amber granite, veined and cracked | amber signs in granite |

  `--autumn N`, `--winter N`, `--spring N`, `--summer N`, `--wood N`, and `--marble N`
  pick a look or model over the material, for tuning. A plain stone's hairline cracks and
  veins are laid out by its own seed (`looks::Carving.scale`), so no two share them.
- **Wood and stone are baked** once into 2048² maps with mips (`shaders::BAKE_FRAG`) when
  getting ready and on a theme change, never per frame; on a phone's screen (`gui::phone`,
  a window as narrow too) into 1024² maps, each texel the average of the 2 × 2 the full
  bake has there, the same look at a quarter of the memory (`draw3d::screen_bake`): growth rings round a wandering
  pith with pores and fibre relief, colored by Beer's law, under a finish per look
  (`looks::Finish`); flowing marble as contours of a warped ramp. Winter’s black marble has forked
  seams with clouded mineral pockets. Its frame takes one continuous cut and each dark
  square takes its own. The bake takes 37 ms on an M1
  Pro and about 0.3 s on the Galaxy Tab A11+. On the A33 a wood prepares in about 2.3 s
  and the stones in 2.7 to 2.8, 1.1 s of it the bake pipeline's compile whatever the look
  (2026-11-13); every look bakes into the same targets, so memory is the same. The
  table's two maps add about 45 MB at the full side (2048 square, with mips) and 11 MB on a
  phone, only with the table.
- **Shader variants:** a Mali compiles every branch of a shader, so the bake and the lit
  shader are built in variants and a look compiles only its own. The bake comes in three:
  the board's, the board's with winter's black marble slab, and the table's alone
  (`render3d::bake_kind`). The table's and the slab's pipelines are made the first time
  a look wants them. The lit shader comes in one per pieces' material (classic, turned
  wood, winter's stones, a mineral: `render3d::PIECES_..`) for each shadow filter, and
  the board's scattering only in the desktop's (`SHADOW_16`). A theme whose pieces take
  another material makes the lit pipelines again and warms them (`set_pieces`). On the
  Pixel 7a the board gets ready in about 1.9 s, and with the table in about 2.8 s.

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
`mallopt(M_PURGE_ALL, 0)` once in the first idle frame after launch (`src/native/memory.c`,
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
`tools/perf/idle_cpu.sh`, memory with `dumpsys meminfo` at rest, Android with
`tools/perf/device_perf.sh` on a release build, the iPhone with `tools/perf/ios_perf.py`
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
  (`src/native/display.c`), the pass draws 2× MSAA (`render3d::FEW_SAMPLES`); if still slow
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
reply, or a new size, safe area, or scale. (A high mode drawing every frame, on desktops
and on mains power, is planned: [decisions](../decisions/rendering.md#frames-and-battery).) Otherwise goose_gfx's `frame()` neither
presents nor spins; it waits for the next event, up to a second. An idle board costs about
one wakeup a second and no GPU work.

```goose
while gfx::frame() {
    // read input, advance animations; set dirty if anything changed
    if dirty || animating { draw(); dirty = false; }
}
```

This is goose_gfx's `WAIT_WHEN_IDLE` open flag, which `host::open` passes with
`SYSTEM_GAMEPADS`: the fork's `draw-on-demand`, proposed upstream as an opt-in flag
([findings](../goose-findings.md)), in every build (`scripts/android.py`, `ios.py`,
`mac.py`, `windows.py`, `linux.py` build goose_gfx from the fork). Without the flag, and
with the release's own gfx, `frame()` presents every frame. With it, `frame()`:

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

The system's battery saver (Android's power save mode, Apple's Low Power Mode, Windows'
battery saver; `draughts_battery_saver`) is read at start and whenever the app gets the
focus back. While it is on, Android's display is asked for 60 Hz (`draughts_cap_60`, the
same request as a slow 3D board's). iOS needs nothing: the app runs at 60 Hz there, and
iOS caps a ProMotion iPad itself in Low Power Mode. A desktop isn't capped.

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
| Mac, a game, flat, gfx or ngfx | 0.02 or 0.04% | 26, none |
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
  (`src/native/wake.c`), pushing an event that ends the wait, so the second is drawn within
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
