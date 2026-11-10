# 058: A window being resized shows a stretched picture

Status: in-progress

On the Mac, dragging a window's edge stretched the last frame until the mouse came up,
then the layout caught up (seen by the user, 2026-11-10, on both the release's gfx and
the patched one). During the drag Cocoa keeps the main thread in its own tracking loop,
so the app's loop doesn't run; SDL only sends `SDL_EVENT_WINDOW_EXPOSED` with `data1` 1
to event watches at 60 Hz (`windowWillStartLiveResize`, `SDL_OnWindowLiveResizeUpdate`),
or runs the main callbacks, which goose_gfx doesn't use. goose_gfx has no event watch,
so neither its release nor the patched one redraws during the drag.

## What was found (2026-11-10)

- **No build ever redrew live.** `c8e0afe` (the 3D board behind `--3d`, 2026-11-09),
  built with a plain `goose build` in a worktree, stretches the same with the 3D board on
  and off, so there was nothing to bisect. A live redraw remembered from then was likely
  something else (perhaps `poc/3d`'s own loop; not checked).
- **A live redraw was set aside**: the loop's body would have to run from an event watch
  inside gfx's `frame()` (an `export fn` called back into while Goose is in a C call,
  which the docs don't say is allowed), plus a gfx patch to present from there; and
  Metal's frame lags the window's size by one, so the edges wobble.
- **First try, a cover**: a layer of the blurred photograph over the Metal view from the
  drag's first resize, off after the next frame. It worked, but flickered on mouse-up
  and switched suddenly (the user).
- **Kept**: the Metal layer keeps its last frame's shape, scaled to fit
  (`kCAGravityResizeAspect`, not opaque), and the content view's layer under it shows
  the backdrop, aspect-filled: the flat game's blurred photograph or the page color, or
  the 3D board's graded backdrop drawn once at 512 px (`draw3d::cover`; the flat one
  read darker beside it). `src/app/resize.c`, set once; nothing changes at rest. With
  the patched gfx (`scripts/mac.py`) and a plain `goose build` alike
  ([rendering](../docs/architecture/rendering.md#window-resizing)).

At rest over 25 s at home (`--rest 25`, the patched gfx): 0.08% of a core, 27 returns of
`frame()`, none drawn (0.03% in task 057).

## Windows and the iPad

Windows' modal size loop is the Mac's (`WM_ENTERSIZEMOVE`; SDL's same 60 Hz expose).
What it shows during a drag, the old frame unscaled or stretched, is for the user to
check on the PC; anything needed there is a child window or the class brush painted with
the backdrop, not this file's Core Animation. An iPad's window resizes without holding
the loop, so it should lay out live: checked in the iPad Pro 11" (M4) simulator, iOS
26.4.

## Acceptance criteria

- [x] The commit that lost the live redraw, and what it changed: none lost it; no build
  redrew live
- [x] On the Mac a resize drag shows no stretched picture
- [ ] On Windows a resize drag shows no stretched picture
- [ ] The iPad simulator's window checked while it resizes
