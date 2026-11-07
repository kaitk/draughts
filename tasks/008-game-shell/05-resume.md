# 008-05: Resume after the app is killed

Status: done (awaiting review)

Android kills a paused app when it needs memory; opening it again must show the game as
it was.

## Work

- Save the game (position, history for undo, the screen) when the app is paused, as a
  flat value written to the app's storage, and read it at start.
- Check by killing the paused app (`adb shell am kill`) and starting it again.

## Acceptance criteria

- [x] The game, its undo history, and the screen come back after a kill
- [x] Nothing written while idle; one small write per pause

## Outcome (2026-11-07)

- `shell::Saved`: the screen, the variant, where the game began, the position, the last
  move, and the undo history (`board::Step[..512]`), one flat value. `shell::save`
  writes it with `to_bytes` and appends an FNV-1a checksum, 14 932 bytes;
  `shell::restore` takes it back only if `from_bytes` verifies it, the checksum
  matches, and `VERSION` and the variant agree, with no move or selection under way.
- The app writes `game.bin` (`write_file_atomic`, beside `settings.txt`) in the frame
  where the window loses focus, which on Android comes as the app is paused: SDL runs
  the loop once more before blocking (`Android_PumpEvents`). It writes on quitting too,
  and reads it at start. Runs with `--fen`, `--tap`, `--screen`, or `--frames` neither
  read nor write it.
- `test/shell/resume.goose`: a game of two moves from a FEN start saved and restored,
  then undone twice back to the start; a flipped byte, a cut file, a settings file, and
  an empty one are refused and change nothing. Without the checksum the flipped byte
  loaded: `from_bytes` checks shape, not data.

### On the tablet

A friend, c3-d4, f6-e5; home; `adb shell am kill com.kaitk.draughts` (the pid gone);
started again (a new pid): the game screen with both moves and the last move's marks,
and undo took back f6-e5, then c3-d4. Over 20 cycles of home, resume, and rotation (a
write at each pause): one process, no errors, PSS 262 to 264 MB, native heap 27 MB,
graphics 211 to 215 MB, as after 04. An idle run after this read 0.05 s of program CPU
with 79 wakeups in 60 s, but the tablet was rotated by hand during it, so it isn't an
idle figure; idle at home measured clean in 04 (0.03 s, 60 wakeups), and 05 adds work
only at a pause.
