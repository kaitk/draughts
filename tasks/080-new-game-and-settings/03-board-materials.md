# 03: Wood, stone, or carved for the 3D board

Status: in-progress

A choice for the raised board: Wood, Stone, Carved, or Auto, the season's own (the user,
2026-11-13), one choice for every season. Carved is the season's best carved board,
whether wood or stone. It replaces task 045. The flat board doesn't change.

| Season | Auto | Wood | Stone | Carved |
| --- | --- | --- | --- | --- |
| Autumn | wood | maple and walnut in cherry (`--autumn 0`) | sandstone and porphyry, a solid speckled frame (`--autumn 3`) | rust vines in weathered stone (`--autumn 2`) |
| Winter | stone | limed ash and smoked oak (`--winter 1`) | slate in marble (`--winter 0`) | the same wood, a Nordic band in smoked oak (`--winter 2`) |
| Spring | carved | the birch (`--spring 0`) | ivory and jade, uncarved, veined and cracked (`--spring 3`) | the elven stone (`--spring 1`) |
| Summer | wood | `--summer 0` | the amber granite, uncarved (`--summer 6`) | the Baltic oak tuned for summer, amber signs in red oiled oak (`--summer 7`) |

The Baltic oak (`--spring 2`) is liked but has no place yet. Autumn 1 (travertine and red
jasper) and winter 3 (stained birch) were takes the user didn't pick.

## Built (2026-11-13)

- The looks in `looks::AUTUMNS` and `WINTERS` beside the others, made with the bake's
  existing machinery; a look may have its own frame marble (`looks::marble_for`). The
  plain stones are the carved looks through `looks::plain`, weathered by `BAKE_FRAG`'s
  `cracks` with moss settled in them (`looks::MOSSY`, `WEATHERED`).
- Settings' Board row: Flat, Raised (Auto), Wood, Stone, Carved; the player's `material =
  auto|wood|stone|carved`. `looks::of(season, material)` gives the look
  (`test/model3d/material`); the board is prepared again on a change. The season flags
  pick their season's look over it; `--material` sets it for a run.

The bake on the A33 (portrait, warm second runs): a wood prepares in about 2.3 s, the
stones 2.7 to 2.8 s, the carved looks between; 1.1 s of it is the bake pipeline's compile
whatever the look. No look is more than about 0.6 s slower than today's defaults. Memory
is the same for every look: they bake into the same targets.

## Left

- Summer's stone finished: task 041's open points (the amber reads as an inlay, the
  motifs small against the squares).
- The chosen takes' tuning in the panel (P), if the user wants it.

## Acceptance criteria

- [ ] Autumn's stone and winter's wood made; shots of all eight boards; the user's pick
- [ ] Summer's stone finished
- [x] The choice in settings (per 02's take) and the player's file; Auto as today's looks
- [x] Bake time of the new looks on the A33
