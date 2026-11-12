# 072: Keyboard and controller focus

Status: in-progress (steps 1 to 6 built 2026-11-11, the board's look agreed 2026-11-12; a real gamepad to try)

Every screen played with the keyboard alone, and later a gamepad, as a desktop game is
expected to be: arrow keys move a visible focus between the controls, Enter presses the
focused one, Escape goes back as it does now (`host::back`). The gamepad of task 064's
"Controllers" criterion feeds the same moves through SDL's gamepad API, so the screens
don't change for it. Home's menu comes first, with a Quit row on a desktop.

Built once in `gui`, not per screen: the UI is immediate mode, each control declared each
frame with its id, so focus is an id in `gui::Gui` as `active` and `under` are.

## Plan

1. Focus in `gui`: `Gui.focus`, an id or 0. Each control that takes focus (`row`,
   `button`, `icon_button`, `bare_x`, the choice tiles) records its id and rect in a
   fixed array reset each frame, in declaration order. Nothing allocates.
2. Moves: up and down step through that order; left and right, and up and down on a
   grid (the setups' tiles, settings' groups), go to the nearest control that way by
   rect. Enter clicks the focused control as a release over it does. The moves come in
   as `gui::Input` fields from `host::input`, so tests can drive them.
3. Look: the focused control drawn lit as `hover` lights the one under the mouse (task
   066), perhaps with a ring if hover's light reads too faintly as focus; to agree with
   the user. The first arrow press focuses the screen's primary control (Continue on
   home); moving the mouse or a tap clears focus, as games do. A screen change focuses
   the new screen's primary control while keys are in use.
4. Home's menu with a Quit row: on a desktop only (`host::DESKTOP`), the last row after
   settings in the landscape column, `gui::CLOSE` and a new `HOME_QUIT` string in every
   `strings/` file, picking `home::EXIT`. Not in the portrait sheet, where the
   2026-11-08 decision rejected a last row for taking the board's room (agreed
   2026-11-11). The corner X and the Quit row are one way out shown two ways, as settings
   is the gear or a row: the X shows only where the row doesn't (the portrait sheet, a
   column too short for it, Android), so no screen has both (agreed 2026-11-11).
   `menu_height` counts the row, so `gear_beside` still folds settings into the gear
   where the column doesn't fit, and the row goes back to the X with it.
5. The other screens: settings, the setups, puzzles' picker, who's playing, the game's
   panels. The board itself (a cursor on the squares, choose a piece and its target) is
   a further step, with task 067's lit square as its likely look.
6. Gamepad, with task 064: D-pad and left stick move, A presses, B goes back, with
   gamepad glyphs where a key's name would show.

## Progress (2026-11-11)

Steps 1 to 4 built: `gui::focus_keys` and `gui::Spot` (every `gui::hold` offers its
control, 128 at most a frame), the arrows, Enter, and Space from `host::input` (not while
a name is typed), the focus lit as the hover, home's Quit row and the X shown one or the
other, and `--keys` for shots. Shot at 1280 × 800 on the Mac: the Quit row fits under
settings, and the X is gone. The hover's light is too faint for a focus: Quit focused
shows only a faint outline, and Continue, primary and so lit already, shows no change at
all. So the focus is ringed: 2 dp of glow 3 dp outside the control's shape, agreed with
the user, who also tried the keys on the other screens and found them working (but the
board).

## Steps of 2026-11-11 (agreed)

The rest of step 5, in this order:

1. Done (2026-11-11): a focused control in a scrolled list scrolled into view.
   `gui::Spot.list` records the list a control was offered in, `gui::Gui.focused` keeps
   the focused spot as the last frame laid it out, and `scroll_begin` moves the offset so
   it lies `PAD` dp inside the view (`test/gui/scroll`). Not seen in the app: on the Mac
   the UI scales with the window, so no list scrolled at any size tried (settings at
   900 × 380 and 360 × 640 at 540 dp, a puzzle page at 200 × 250), and the
   focus's faint light didn't show in the shots. A phone-sized run once in a while never
   reached its `--frames` shot, with or without this change (5 of 5 runs of each build
   finished when retried).
2. Done (2026-11-11): hold tiles (who's playing's start again and remove,
   `gui::hold_tile`) filled by Enter held while focused. `gui::Input.held` is Enter or
   Space down (`gfx::key_down` in `host::input`); `gui::hold`'s `keyhold` takes Enter on a
   hold tile as a press, not a click, and `gui::key_held` keeps it down, a ring that
   fired staying empty until Enter is pressed again (`test/gui/focus`). Checked headless
   only: `--keys` presses Enter but can't hold it.
3. Done (2026-11-11): arrow keys repeat while held, 0.4 s after the press and then
   every 0.08 s, in `src/app/keys.goose` (part of `host`, in its namespace, where a
   gamepad's moves will come in too); `host::repeat_in` joins the loop's wake timer so a
   held arrow repeats in an idle loop. Built, not yet tried by hand: `--keys` can't hold a
   key.
4. Built (2026-11-11, branch `keys-board`): the board with the keys, flat and 3D. The
   board is one control to the focus, a grid (`gui::grid`, `board::keys`), and the
   game's and a puzzle's first choice: the first arrow puts the cursor on the side to
   move's movable piece nearest the bottom middle; the arrows move it a square at a
   time, light squares too; Enter on a dark square is a tap there (`board::press`), so
   a piece, its target, a capture's stops, and a mistake are what they are for a finger;
   past the edge an arrow leaves for the nearest control, and one back comes in on the
   near edge in line. With a piece chosen the lookout reads the cursor's square as it
   reads the mouse's. Escape with a piece chosen puts it down (`shell::put_down`). Tab
   and Shift and Tab step between groups (`gui::group`: the way out, the board, the play
   panel), each coming back to where it was. On the 3D board's hot-seat turn the arrows
   turn with it, past a quarter turn, and the cursor keeps its square (2026-11-12, the
   user's find). `test/game/board_keys`; `--keys` takes
   `tab` and `backtab`.
   The look, agreed with the user 2026-11-12: a glow line just inside the square, its
   corners rounded, over a faint dark seam (it vanished on a light square without it),
   in the flat board's pass and, on the 3D board, with the marks over the kept image, so
   a move of the cursor draws only those. Rejected: task 067's lit square, which the
   last move's tint already is. Shots at 1280 × 800, `--touch off`: a piece chosen and
   the cursor on its target, flat and 3D; the cursor on a light square; off the board
   onto back; Tab to undo move.

Step 6, the gamepad, built the same night (`src/app/pad.c`, `host::keys`): the D-pad or
the left stick (past half way, let go under a third) moves and repeats as the arrows do,
A presses as Enter and holds a hold tile, B goes back as Escape, LB and RB step between
the groups as Shift and Tab and Tab. SDL's gamepad API from the program's C, as on every
platform (Android's and iOS's SDL already carry it; iOS without HIDAPI, so no Bluetooth
ask). Checked against SDL's virtual gamepad on the Mac. No gamepad glyphs: the app shows
no key's name anywhere to replace.

At rest, 2026-11-12, on the Mac with a PS5 pad connected (CPU over 20 s idle, from
`ps`): SDL reading it itself, every 1 ms, 1.0 s (none without the pad); SDL's reading
off and the loop waking 30 times a second to read it, 0.37 s, of which SDL's HIDAPI
thread taking the pad's streamed reports was most; HIDAPI off on Apple's systems (the
GameController framework reads the pad), 0.30 s; its change handler waking the loop
and no timed wakes, 0.01 s. Elsewhere (Android, Windows) the 30 wakes a second remain
while a gamepad is connected, unmeasured (docs/goose-findings.md, "no gamepad").

The ngfx build (scripts/ngfx.py, `NGFX` and `NGFX_SLANGC` set) built 2026-11-12 with the
cursor: headless shots at 1280 × 800 match gfx's flat, and the 3D cursor draws.

## Next session

1. Try by hand on the Mac: the held-key repeat, Enter holding a hold tile, the board with
   the keys flat and 3D, Tab; and the PS5 pad (A, B, the D-pad, the stick, the
   shoulders), its first press after a long rest waking the app at once.
2. A gamepad on Android, Windows, and the other platforms mustn't wake the loop at rest
   either, as on the Mac and iOS (the user, 2026-11-12): replace the 30 wakes a second
   with a wake when the gamepad is used. Android's SDL gets its buttons from Java
   callbacks, which push events and may already wake the wait without HIDAPI; Windows
   (XInput, RawInput, Windows.Gaming.Input) to find out. A patch in `patches/SDL` is
   fine where it is the easier way (the user, 2026-11-12): Android, iOS, and Windows build
   SDL from source with those patches applied (scripts/native.py); the Mac's SDL is the
   Goose binary's and can't be patched, but needs none. For example SDL's joystick
   reading could push a wake event only when a button or an axis past a dead zone
   changes, rather than the program polling. Then a gamepad on a phone or
   the tablet, and its idle cost there, at the task's end with the other device numbers.
3. Merge `keys-board` into main.

## Acceptance criteria

- [x] Home's menu worked with the arrow keys and Enter on the Mac, the focus visible and
      its look agreed with the user.
- [x] The Quit row on a desktop's landscape column only; never on Android, iOS, or with
      `--touch on`; the corner X shown only where the row isn't; a touch screen's layout
      unchanged.
- [ ] Every screen but the board worked with the keyboard alone.
- [ ] A focus that rests draws nothing; a key press draws one frame
      (`docs/architecture/rendering.md`), and the frame loop allocates nothing.
- [x] A test drives the keys through home and a setup and checks the focus and the pick
      (`test/gui/focus`, `test/shell/home_keys`).
- [x] The board played with the keyboard (step 5), agreed with the user: built, tested
      headless, the look agreed 2026-11-12.
- [ ] A gamepad does all of it (with task 064): built, checked against SDL's virtual
      gamepad, idle with a PS5 pad on the Mac at no cost; a real one's buttons to try.
- [x] `docs/architecture/rendering.md` and `docs/decisions/rendering.md` updated, the
      Quit row recorded as narrowing the 2026-11-08 decision against a last row (and the
      board's keys, the groups, and the gamepad).
