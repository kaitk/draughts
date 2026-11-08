# 011: Stop SDL's accelerometer listener

Status: done (2026-11-08, as task 032's cut 4)

SDL's Java side registers the accelerometer at `SENSOR_DELAY_GAME` (50 Hz) whenever the
app is resumed (`SDLSurface.handleResume`, and at start in `SDLActivity`), whether or not
the program reads sensors. It uses it for two things: an accelerometer joystick, which
the app doesn't open, and noticing display rotation (`onNativeRotationChanged`). On the
idle board this is all the CPU left after task 005: 1.9% of a core on the Java main
thread, 50 wakeups a second, plus the sensor's own power.

The plan was a patch in `patches/SDL/` to SDL's Java: register the accelerometer only
when native code asks for sensor input, and learn rotation from a
`DisplayManager.DisplayListener` instead. SDL's Java turned out to have a hook, so no
patch: `DraughtsActivity` overrides `createSDLSurface` with a subclass of `SDLSurface`
whose `enableSensor` ignores `TYPE_ACCELEROMETER`. SDL takes no AI-written code or
reports, so the upstream fix stays a finding for the user
([findings](../docs/goose-findings.md)).

## Acceptance criteria

- [x] Idle on the board with the screen on: the whole process under 0.2% of a core
      (`scripts/idle_cpu.sh 300`): 0.14 s in 300 s, 0.05%
- [x] Rotation still resizes the board both ways, and `scripts/lifecycle_memory.sh 20`
      stays flat
- [x] The finding says what changed in SDL's Java and why

## Measured (2026-11-08)

Galaxy tablet, landscape, rotation locked, `pm clear` before each build's launch; before
is `9530afe`'s APK, after the same with the change. Each figure is 60 s untouched, 10 s
after launch, at home and in a game (`--screen game`).

| CPU in 60 s (voluntary switches) | Home before | Home after | Game before | Game after |
| --- | --- | --- | --- | --- |
| `SDLActivity` (the Java main thread) | 1.14 s (3123) | 0.00 s (0) | 1.25 s (3132) | 0.00 s (0) |
| `SDLThread` (the program) | 0.03 s (62) | 0.03 s (63) | 0.03 s (62) | 0.02 s (63) |
| Process | 1.19 s | 0.05 s | 1.29 s | 0.06 s |

`scripts/idle_cpu.sh 300` at home after: the program's thread 0.14 s, the process 0.14
s, 299 voluntary switches. `dumpsys sensorservice` before: our process's one connection,
the accelerometer at 20 ms (`org.libsdl.app.SDLSurface`), and with rotation locked the
accelerometer's only one; after: no connection from our process, the accelerometer not
active at all, and still none after 20 lifecycle cycles (20 resumes).

Rotation: with auto-rotate on the tablet lay landscape and the app with it (it can't be
turned from the Mac; Samsung's own rotation listens to its "Device Orientation" sensor,
not to ours). Turned through `user_rotation`, which drives the same activity rotation:
portrait (1200 × 1920), landscape, and the flipped landscape each laid the game out right
at once. `scripts/lifecycle_memory.sh 20`: the same process throughout, no errors, PSS
162 to 166 MB, graphics 106 to 110 MB (task 032's file).
