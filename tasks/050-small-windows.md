# 050: Small windows

Status: in-progress

On iPad, iPadOS 26 lets every app's window be resized (task 046 drops
`UIRequiresFullScreen`), down to about 374 × 484 pt on an iPad Pro 11-inch. Every size
must work, not look perfect: extra width or height only leaves room, and the extremes
need no polish. Tried 2026-11-09 on an iPad Pro 11-inch (M5) simulator, iOS 26.4, in
Windowed Apps; the shots are in `~/Downloads/draughts-ipad-windows/` (outside git).

| Window (iPad Pro 11-inch, screen 834 × 1210 pt) | Size, pt |
| --- | --- |
| Smallest | about 374 × 484 (measured) |
| Tallest | about 380 × 1190 (from the shot's proportions) |
| Widest, landscape | about 1210 × 480 (likewise) |

A 13" iPad's full screen is 1032 × 1376 pt.

## What a small window does now

- **Game** (`06-game-smallest`, `09-game-smallest`): works but wastes room. Back,
  Settings, and Start over are full tiles with labels, the turn and Undo stack in a tall
  card, and the board is about a third of the window's width. The tallest and widest
  windows are fine.
- **Home** (`02-home-smallest-window`): the board is gone; the panel (title, Continue, A
  friend, The computer, Puzzles) fills the window under a strip of the photograph.
- **Settings** (`05-settings-look-small-window`): Look's Board row is cut off at the
  panel's foot; the theme's choices wrap untidily (two pushed right of "Theme", the four
  seasons in a row, "By date" alone under them).
- **Puzzles** (`10-puzzles-small-window`): the library is cut off; King shots shows
  half, Safe move can't be reached.
- **Every screen:** iPadOS draws its window control (three dots) over the top-left
  corner, on the player chip, Back, or the game's tiles.

## Plan

A compact layout for very small windows on three screens, chosen by the window's size,
and scrolling where a list doesn't fit. Nothing else changes.

- **Game:** Back, Settings, and Start over smaller and icon-only; the turn and Undo side
  by side in one row; the board takes the room freed.
- **Home:** the panel tighter (rows, title) so a board stays.
- **Settings:** the Board row reachable; the theme's choices wrapped tidily.
- **Scrolling:** the puzzle library, a theme's puzzles, and settings' panel scroll when
  they don't fit. Nothing in `src/` scrolls yet; goose_gfx's UI keeps a window's scroll
  offset (`ui::window_get_scroll`, `ui::window_set_scroll`), and the app turns a finger's
  drag into scrolling while telling a drag from a tap. One shared vertical scroll for all
  three; it helps Android's split screen too.
- **The window control:** a top-left margin clear of it on every screen, in a window
  only.

Check the sizes by resizing the window on the Mac; the iPad simulator only for the window
control at the end (`docs/development.md`, "Run on iOS").

## Decisions (the user, 2026-11-09)

From a proposal with headless before and after shots of a prototype:

- Compact tap sizes accepted in compact only: the game's 72 × 64 dp icon tiles and home's
  72 dp rows, under the 88 dp floor (48 and 54 pt on the iPad).
- Settings, as a window widens from portrait to landscape: both groups side by side under
  the board until the landscape layout fits, with no board near square; tabs only on a
  phone and in a small window.
- Scrolling: a plain drag and the wheel, no fling.
- A single puzzle in the smallest window: later. It keeps its layout (`small: false` from
  `shell::puzzle_layout`).
- The window control in a full-screen app: to check in the simulator.

After trying it in the iPad simulator (the user, 2026-11-09): "very strong result", with
these changes.

- **The window control may sit over a control's corner.** The margin that moved back,
  the chip, and the game's tiles clear of iPadOS's three dots is taken out, with
  `gui::Gui`'s corner, `--corner`, and `ios/corner.m`: a control that moves away only in a
  window bothered the user more than the dots over its corner, and back is large and
  still easy to tap where it was. Settings' title shows again in the small window.
- **Settings' theme tiles slim in a small window:** in the Look tab the theme's tiles
  were tall and Board fell below the fold. In compact only they are 48 dp tall, a smaller
  thumbnail with its word beside it, and the switch as low; Board's foot now ends 87 dp
  above the glass's, where it was 33 under it, and Kings shows its top 49 dp
  (`test/shell/sizes`' new last line). Phones and larger windows are unchanged
  (`sizes.out`'s other lines).

## What was built

How it works is in `docs/architecture/rendering.md`, "Small windows" and "Settings".
Numbers, headless at the iPad's 2 px a point with its density floor (1.5 px a dp):

| Window | Layout, dp | What changed |
| --- | --- | --- |
| Smallest, 374 × 484 pt | 499 × 645, compact | Game: the 3D board about 350 dp wide, from about 200; home: a board about 160 dp wide above the menu, from none; settings: one tab, its rows scrolling, Board and Kings reachable; the library and a theme's levels scroll |
| Tallest, 380 × 1190 pt | 507 × 1587 | As before |
| Widest, 1210 × 480 pt | 1613 × 640 | As before |

Settings at the Mac sizes the user widened through (800 dp across the shorter side):
800 × 1457, 1033, and 925 dp keep the groups side by side under the board, the board
shrinking; about 800 × 826, near square, keeps them with no board; 914 × 800 is landscape
with a small board, 1354 × 800 as before. The hand-over to landscape is at about
870 × 800 dp. Blessed with it: `test/expected/sizes.out` and `screens3d.out` (the
foldable's and 4:3's portrait settings now show both groups with a 206 and 269 dp board,
where the tabs gave 401 and 464; the tablet's portrait with its navigation bar 425 dp,
from 333, the groups sharing the width in proportion), and `transition.out` (one quad
fewer in settings' portrait, the privacy note wrapping at the new width).

The final headless shots, not kept in the repo:
`/private/tmp/claude-501/-Users-kaitkasak-projects-personal-draughts/b7477f16-67e8-47ad-8c8d-5690c6660fd1/scratchpad/050-build/`.

## Left

- A single puzzle's compact layout (later, above).

## Acceptance criteria

- [x] The game, home, and settings fit the smallest window, the board showing on game
      and home, checked on the Mac at about 374 × 484 pt (headless, 748 × 968 px)
- [x] The puzzle library, a theme's puzzles, and settings scroll by drag where they
      don't fit, a tap still a tap (`test/gui/scroll`)
- [x] The iPad's window control may sit over a control's corner (the user's decision,
      2026-11-09: back is large and easy to tap beside the dots, and a control that moves
      only in a window is worse), checked in the iPad simulator
- [x] The tallest and widest windows still work
