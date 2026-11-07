# 008-05: Resume after the app is killed

Status: todo

Android kills a paused app when it needs memory; opening it again must show the game as
it was.

## Work

- Save the game (position, history for undo, the screen) when the app is paused, as a
  flat value written to the app's storage, and read it at start.
- Check by killing the paused app (`adb shell am kill`) and starting it again.

## Acceptance criteria

- [ ] The game, its undo history, and the screen come back after a kill
- [ ] Nothing written while idle; one small write per pause
