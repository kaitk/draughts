# 011: Stop SDL's accelerometer listener

Status: todo

SDL's Java side registers the accelerometer at `SENSOR_DELAY_GAME` (50 Hz) whenever the
app is resumed (`SDLSurface.handleResume`, and at start in `SDLActivity`), whether or not
the program reads sensors. It uses it for two things: an accelerometer joystick, which
kabe doesn't open, and noticing display rotation (`onNativeRotationChanged`). On the
idle board this is all the CPU left after task 005: 1.9% of a core on the Java main
thread, 50 wakeups a second, plus the sensor's own power.

The fix is a patch in `patches/SDL/` to SDL's Java (`scripts/android.py` compiles it
from the patched copy): register the accelerometer only when native code asks for
sensor input, and learn rotation from a `DisplayManager.DisplayListener` instead. SDL
takes no AI-written code or reports, so this stays a local patch and a finding for the
user ([findings](../docs/goose-findings.md)).

## Acceptance criteria

- [ ] Idle on the board with the screen on: the whole process under 0.2% of a core
      (`scripts/idle_cpu.sh 300`)
- [ ] Rotation still resizes the board both ways, and `scripts/lifecycle_memory.sh 20`
      stays flat
- [ ] The finding says what changed in SDL's Java and why
