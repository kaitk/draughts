# 035: A way to close the app from home

Status: todo

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

## Acceptance criteria

- [x] Takes prototyped (a, b, c above), checked in both orientations and in Estonian
- [ ] One picked by the user
- [ ] Built in `shell/home.goose` with a new icon in `gui/` (an X, or the pick's glyph),
      88 dp, clear of the board and the menu in both orientations; any text in
      `strings/en.txt` and `strings/et.txt`
- [ ] Mac: exit closes the window; the next start opens the game where it was
- [ ] Android: exit closes the app and removes it from recents; starting it again from
      the launcher opens the game where it was, without an error or a blank start
- [ ] Clear of the gesture areas and of the board at the phone sizes in task 030
- [ ] Headless test: tapping exit on home returns `home::EXIT`, in both orientations
- [ ] Checked on the Mac and on the tablet, in both orientations
