# 013: Season effects

Status: todo

Small Snowtime-style effects over the background: snow falling in winter, a few leaves
in autumn, light on the water in summer, perhaps pollen or light through birches in
spring. Cheap to draw, and they stop when the board is idle (or after a short while),
so idle CPU stays where task 005 left it.

## Acceptance criteria

- [ ] One effect per season, tried in the prototypes first
- [ ] A setting turns effects off
- [ ] Idle with effects settled: `scripts/idle_cpu.sh` as before (task 005's numbers)
