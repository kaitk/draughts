# 03: Wood, stone, or auto for the 3D board

Status: in-progress

A choice for the raised board: Wood, Stone, or Auto, the season's own (the user,
2026-11-13). It replaces task 045, which listed every alternative look; this offers two
per season. The flat board doesn't change.

| Season | Auto | Wood | Stone |
| --- | --- | --- | --- |
| Autumn | wood | maple and walnut in cherry (`looks::autumn`) | **new** |
| Winter | stone | **new** | slate in marble (`looks::winter`) |
| Spring | stone | Baltic carved oak (`SPRING_BALTIC`) | elven carved stone (`SPRING_ELVEN`) |
| Summer | wood | `looks::summer` | amber-carved granite (`SUMMER_AMBER`), to finish |

Spring's wood could be the birch (`looks::spring`) instead of the Baltic oak; the user
to choose.

To decide: one choice for every season (Wood shows each season's wood), or one per
season (settings shows the theme season's two boards, each season remembers its own).
One choice is simpler to show and to say; per season matters only if a child likes
autumn's stone but spring's wood.

Steps:

1. Autumn's stone and winter's wood in `poc/3d`, as looks beside the others, made with the
   bake's existing machinery (stone mottling and veins, the woods' models, the carving),
   shots beside each season's other board for the user. A new concept is welcome.
2. Summer's amber stone finished: the open points in task 041 (the amber reads as an
   inlay, the motifs small against the squares).
3. The choice in the player's file, the renderer picking the look from season and
   material; the flags (`--spring`, `--summer`, `--marble`) kept for tuning.
4. The bake's cost of each new look on the Pixel 7a and the A33, and the memory the same.

## Acceptance criteria

- [ ] Autumn's stone and winter's wood made; shots of all eight boards; the user's pick
- [ ] Summer's stone finished
- [ ] The choice in settings (per 02's take) and the player's file; Auto as today's looks
- [ ] Bake time of the new looks on the A33
