# 035: A way to close the app from home

Status: in-progress

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
  the system, which puts the app in the background.

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

Left: the tablet check, in both orientations: exit closes the app with no card left in
recents; starting it again from the launcher (and, if a card remains, from recents)
opens the game where it was, in a fresh process, without an error or a blank start.

## Acceptance criteria

- [x] Takes prototyped (a, b, c above), checked in both orientations and in Estonian
- [x] One picked by the user: b
- [x] Built in `shell/home.goose` with a new icon in `gui/` (an X, or the pick's glyph),
      88 dp, clear of the board and the menu in both orientations; any text in
      `strings/en.txt` and `strings/et.txt` (none needed)
- [x] Mac: exit closes the window; the next start opens the game where it was
- [ ] Android: exit closes the app and removes it from recents; starting it again from
      the launcher opens the game where it was, without an error or a blank start
- [ ] Clear of the gesture areas and of the board at the phone sizes in task 030
- [x] Headless test: tapping exit on home returns `home::EXIT`, in both orientations
- [ ] Checked on the Mac and on the tablet, in both orientations (the Mac done)
