# 058: A window being resized shows a stretched picture

Status: todo

On the Mac, dragging a window's edge stretches the last frame until the mouse comes up,
then the layout catches up (seen by the user, 2026-11-10, on both the release's gfx and
the patched one). During the drag Cocoa keeps the main thread in its own tracking loop,
so the app's loop doesn't run; SDL only sends `SDL_EVENT_WINDOW_EXPOSED` with `data1` 1
to event watches at 60 Hz (`windowWillStartLiveResize`, `SDL_OnWindowLiveResizeUpdate`),
or runs the main callbacks, which goose_gfx doesn't use. Windows' modal size loop is the
same. An iPad's window resizes without blocking the loop, so it should re-lay out live
already: to check in the simulator.

Early 3D builds on main redrew live on the Mac, likely by accident (the user, 2026-11-10):
find what they did differently before building anything. Start around the 3D renderer's
arrival on main (`c8e0afe`, the game's 3D board behind `--3d`, and the commits after it
on 2026-11-09): build one with a plain `goose build` in a worktree, drag the window's
corner by hand, then bisect to the commit that lost it.

## Direction

Only if cheap. A live redraw needs the app's loop body callable from a C event watch
(`export fn`, Goose reference §24) and gfx presenting from inside its own event pump.
Otherwise a quick fix: don't stretch the old frame, show only the background, or
nothing, until the size settles.

## Acceptance criteria

- [ ] The commit that lost the live redraw, and what it changed
- [ ] On the Mac (and Windows) a resize drag shows no stretched picture
- [ ] The iPad simulator's window checked while it resizes
