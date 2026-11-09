# 050: Small windows

Status: todo

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

## Acceptance criteria

- [ ] The game, home, and settings fit the smallest window, the board showing on game
      and home, checked on the Mac at about 374 × 484 pt
- [ ] The puzzle library, a theme's puzzles, and settings scroll by drag where they
      don't fit, a tap still a tap
- [ ] No screen's control under the iPad's window control, checked in the iPad simulator
- [ ] The tallest and widest windows still work
