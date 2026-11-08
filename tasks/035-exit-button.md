# 035: A way to close the app from home

Status: done (the tablet and the Pixel 7a checked)

Home's menu has no way to close the app (found 2026-11-08); on the tablet it takes the
system's gestures, and on the Mac the window's close button or Escape. Add one control on
home, the only screen with it, that closes the app at once.

It asks nothing. Exiting loses nothing: the settings (the setup's choices, the language,
the stars won in each puzzle) are written to `settings.txt` on every change, and the game
as it stands (`shell::Saved`: the position, the undo history, the clocks, the computer's
side and level) to `game.bin` when the app is paused and when its loop ends
(`app/draughts.goose`, after the `while gfx::frame()` loop). A tap by mistake costs a
restart that opens where it left off.

## Takes (2026-11-08)

`prototypes/exit.html`, home as `shell/home.goose` lays it out (the sharp photograph,
the board as the game stands in 2D, the glass column or sheet), `&lang=et` for Estonian.

- **a, a quiet last row**: Exit under the menu, 14 dp further down than the rows' gap,
  its door icon and word at the dim text color on no fill. Fits the landscape column
  (640 of the 704 dp it has). In portrait it is a fifth row in the sheet, and the board
  shrinks from 640 to 588 dp.
  file:///Users/kaitkasak/projects/personal/draughts/prototypes/exit.html?take=a
- **b, an X in the corner**: a round glass button, 88 dp, in the screen's top right, 24
  dp from both edges, its X 32 dp; the menu is unchanged. In landscape it sits above the
  photograph, clear of the board (28 dp right of its edge, 8 dp above its top). In portrait the board
  moves down to 16 dp under it and shrinks from 640 to 620 dp to keep 24 dp above the
  sheet.
  file:///Users/kaitkasak/projects/personal/draughts/prototypes/exit.html?take=b
- **c, a door in the corner**: as b, with a door and an arrow leaving it instead of the X;
  `&glyph=power` shows a power sign.
  file:///Users/kaitkasak/projects/personal/draughts/prototypes/exit.html?take=c

Screenshots, local and out of git, in
`/private/tmp/claude-501/-Users-kaitkasak-projects-personal-draughts/d9f11ac9-ef2c-4a62-bf58-8c3587116c29/scratchpad/exit/`:
`{a,b,c}-{land,port}-{en,et}.png` (1280 × 800 and 800 × 1280), `c-power-*.png`, and the
app's home now in `app/`.

## Recommendation: b

The X in the top right, in both orientations:

- One place in both orientations, and the tablet turns. Settings is split (a row in
  landscape, a button in portrait) only because the sheet has no room for a row; exit
  needn't copy that.
- It costs the menu nothing. On phones (task 030) the portrait sheet already runs off the
  bottom, while the stage above it has height to spare, so the corner is free there; on
  the tablet it costs the board 20 dp, a lot less than a's 52.
- It is far from where children tap: the menu at the left or the bottom, the board in the
  middle. Hands holding a tablet usually rest at its sides and lower corners.
  The top edge has no gesture that takes a tap: the app is fullscreen, and pulling the
  status bar down is a swipe. The side edges' back gesture is a swipe too, and the button
  starts 24 dp in.
- An X is what closes things in the apps and games children know. The door (c) is more
  literal but reads less surely at 32 dp; a power sign suggests turning the tablet off.
- a reads well in landscape and labels itself in words for a parent, but in portrait it
  takes the board's room and adds to the sheet that phones can't fit.

The X takes no string. Take a would add `home.exit = Exit`, and in Estonian
`home.exit = Välju` (the usual word for leaving a program), a draft for task 024's
review.

Seen in the screenshots: home's portrait settings button is 48 dp, under the 88 dp floor
for small hands, beside an 88 dp X; task 030 can bring it up to size.

## What exit does

- **Both**: home returns a new `home::EXIT`; the shell asks the app to stop, the loop
  ends as Escape ends it now, and `game.bin` is written after the loop as it already is.
- **The Mac**: the program returns and the window closes.
- **Android**: just before the program returns, it calls `finishAndRemoveTask()` on the
  activity, through a small method in `DraughtsActivity` called over JNI as
  `firstFrame()` is (`app/launch.c`). That ends the activity and takes its card out of
  recents, as a parent closing an app by swiping it away expects. Plain `finish()`, what
  SDL does when the program returns, would leave a card with a picture of home, as if
  the app still ran, and opening that card starts it afresh anyway. SDL then sees the
  activity already finishing and leaves it. On the next start in the same process,
  `SDLActivity.onCreate` finds its main finished and calls `System.exit(0)`, so the app
  starts in a fresh process and restores `game.bin`; check that this start works from the
  launcher and from recents. Android's own back gesture is unchanged: SDL passes it to
  the system, which puts the app in the background. (Since 2026-11-08 back goes back a
  screen, and only on home's menu to the system: below.)

## Built (2026-11-08): b

The user picked b. `shell/home.goose` declares the X last on home, on the menu and in a
setup, so the tiles before it keep their order: `gui::round_button`, a glass panel under
a quiet tile, both going down 4% while pressed as tiles do, with the new line icon
`gui::CLOSE` (two strokes, 6 to 18 on the 24-unit grid) at 32 dp and 90%. A tap returns
`home::EXIT`; the shell sets `Shell.quit`, the app's loop breaks as on Escape, writes
`game.bin` after the loop as before, and then calls `draughts_close()` (`app/launch.c`),
which on Android calls `DraughtsActivity.closeApp()`, `finishAndRemoveTask()`, from the
program's thread, as SDL calls `finish()` from there too, so the activity is finishing
when SDL looks. On the Mac it does nothing and the window closes as `main` returns. The
X needs no string.

In portrait the board moves to 16 dp under the X and shrinks to keep 24 dp above the
sheet: 640 to 620 dp on the tablet's proportions, as the prototype. In a setup the
sheet is taller and the board, 472 dp, already clears it beside (52 dp). In landscape
the board's top is at least 120 dp down (its size is at most 70% of the 800 dp short
side), so the X (to 112 dp) always clears it. Settings' transition eases from home's
new portrait place (128 dp down rather than 66), so the board moves down less.

Re-blessed: `shell.out` (the setups count one more tile; the portrait board at 90, 128,
620) and `transition.out` (home's three more quads; the portrait transition from the
new place). `test/shell/exit.goose` is new.

Checked on the Mac: screenshots of home at 1280 × 800, 960 × 600, and 600 × 960, and
800 × 1280, which the Mac's screen cuts to 800 × 1098, in English and Estonian, and the
computer's setup in Estonian at 960 × 600 and 600 × 960: the X clear of the board, the
column, the sheet, and the words in each, in
`/private/tmp/claude-501/-Users-kaitkasak-projects-personal-draughts/d9f11ac9-ef2c-4a62-bf58-8c3587116c29/scratchpad/exit-built/`
(`home-<size>-<lang>.png`, `computer-<size>-et.png`, `mac-exit-run1.png`). The X
closing the window and the game coming back were run through a local copy of the app
that taps the X on frame 30 (scripted clicks can't reach the window,
`agents/testing.md`): started from a `game.bin` with a distinctive position, it showed
that position on home, the window closed with exit code 0, and `game.bin` was written
again (byte for byte the same, as nothing changed). The write after the loop is the one
Escape already used; `test/shell/exit.goose` checks that the X sets `Shell.quit` and
that the image saved then restores the game. The APK
builds with the JNI call and `closeApp` in it.

## On the tablet (2026-11-08)

This used the APK built from `6b20e66`, run without flags, so `game.bin` was read and
written. The app's data was saved first through a debuggable copy and `run-as`. It held
only `settings.txt`, which came through byte for byte the same, and the `game.bin` the
check made was then removed.

- **Where the X sits.** On home, in both orientations, and in both setups, the X is clear
  of everything (`exit-*.png`):
  - Landscape (1920 × 1200): the X is a 132 px (88 dp) circle centred near (1818, 101).
    Its left edge is about 44 px (29 dp) right of the board's right edge, and its bottom
    about 15 px above the board's top.
  - Portrait (1200 × 1920): the board starts about 26 px (17 dp) under the X and is
    930 px (620 dp) wide.
  - The computer's setup in portrait: the X sits beside the board, about 51 dp right of
    it.
- **A tap closes the app.** Its card leaves recents: before the tap, `dumpsys activity
  recents` listed Draughts as Recent #0, and two seconds after it the launcher. The
  screen goes to the launcher. The process stays alive (the same pid 2 s later).
- **The next start.** Started again, `SDLActivity.onCreate` in that process calls
  `System.exit(0)`, and ActivityManager logs the process as died and starts a fresh one.
  The fresh process opened home with the game where it was (a friend game two plies in),
  and logcat had no FATAL. This was done three times:
  - home's X in landscape, then
    `adb shell monkey -p com.kaitk.draughts -c android.intent.category.LAUNCHER 1`;
  - home's X in portrait, then a tap on the icon in the app drawer;
  - the computer setup's X in landscape, then `monkey` again.
  The two recorded launches showed only the icon's brown before the first frame (task
  033).

Screenshots and recordings, out of git:
`/private/tmp/claude-501/-Users-kaitkasak-projects-personal-draughts/d9f11ac9-ef2c-4a62-bf58-8c3587116c29/scratchpad/tabletround/`.

## Back goes back (2026-11-08)

The user found on the Pixel 7a that the back gesture left the app from every screen.
Now Android's back, the gesture or the button, does what the screen's own back or home
control does (`shell::back`): a setup goes to home's menu, the game, settings opened from
home, and the puzzles to pick from go home, settings opened from the game or a puzzle go
back to it, and a puzzle to the puzzles; in a transition it turns round, as a tap would.
On home's menu back leaves the app as before, the system putting it in the background
(the activity is kept, unlike home's X): the program hands it back through
`draughts_leave()` (`app/launch.c`), which has the activity move its task to the back
(`DraughtsActivity.leaveApp`). It first went through SDL's `SDL_SendAndroidBackButton` and
the activity's `onBackPressed`, which on the Pixel 7a (Android 17) finished the activity
and took its card out of recents, as home's X does (below). Escape on the Mac does the same, and closes the window only
from home's menu; nothing scripted used Escape. `test/shell/back.goose` checks each
screen against its tile.

How back reaches the program: SDL turns Android's `KEYCODE_BACK` into its "AC Back" key
(`gfx::key_pressed("AC Back")`) whatever `SDL_HINT_ANDROID_TRAP_BACK_BUTTON` says (the
hint only stops `onBackPressed` passing it on). But an app targeting Android 16 (API 36)
gets predictive back on Android 16 and later: the key is no longer dispatched and
`onBackPressed` not called, and the system's default moved the app to the background.
SDL's own sample manifest opts out (`enableOnBackInvokedCallback="false"`), which Android
calls temporary; instead the manifest opts in from Android 13 and `DraughtsActivity`
registers an `OnBackInvokedCallback` that hands the back to SDL as the key down and up
(`SDLActivity.onNativeKeyDown`). Up to Android 12 the key comes through SDL's surface as
before. No SDL patch is needed.

## Back on the Pixel 7a (2026-11-08)

Android 17, gesture navigation, at the density floor (549 dp across). `adb shell input
keyevent KEYCODE_BACK` and an edge swipe (`input swipe 5 1200 500 1200 150` in portrait,
`5 540 600 540 150` in landscape), in portrait and landscape, from each screen: the
friend's and the computer's setup, the game, settings from home, and the puzzles go to
home's menu; settings opened from the game (by its tile) goes back to the game; puzzle 21
goes to the puzzles, on its shield tier. Settings opened with `--screen game --go
settings` goes home, not to the game: the flag opens it as from home, which a tap never
does. The app hides the system bars, so the first edge swipe only shows them and the
second goes back (Android's immersive mode); the key goes back at once.

On home's menu back finished the activity (`wm_finish_activity ... app-request`,
`onDestroy`, the task removed from recents), so the next start was a fresh process at
home rather than a return. SDL's `SDL_SendAndroidBackButton` runs `onBackPressed`, which
on Android 17, with back callbacks opted into, didn't move the root task to the back as
older Android did. Now `draughts_leave` calls `DraughtsActivity.leaveApp`
(`moveTaskToBack(true)` on the UI thread): the launcher shows, the card stays in recents,
the process (same pid) and activity are kept, and starting the app again from the
launcher opens home's menu as it was, drawn at once. Home's X still finishes it and
removes the card. No FATAL or app errors in logcat.

Home's X and every back control sit clear of the gesture areas in both orientations
(task 030, "On the Pixel 7a (2026-11-08)").

## Acceptance criteria

- [x] Takes prototyped (a, b, c above), checked in both orientations and in Estonian
- [x] One picked by the user: b
- [x] Built in `shell/home.goose` with a new icon in `gui/` (an X, or the pick's glyph),
      88 dp, clear of the board and the menu in both orientations; any text in
      `strings/en.txt` and `strings/et.txt` (none needed)
- [x] Mac: exit closes the window; the next start opens the game where it was
- [x] Android: exit closes the app and removes it from recents; starting it again from
      the launcher opens the game where it was, without an error or a blank start
- [x] Clear of the gesture areas and of the board at the phone sizes in task 030
- [x] Headless test: tapping exit on home returns `home::EXIT`, in both orientations
- [x] Checked on the Mac and on the tablet, in both orientations
