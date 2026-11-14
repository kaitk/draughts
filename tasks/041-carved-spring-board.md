# 041: A carved spring board

Status: in-progress

Carved looks for the 3D board in our own motifs (2026-11-09): elven leaf and vine work in
pale stone with moss, with a temple take (lotus and leaf scrolls) as the alternative.
Built in `src/model3d/looks` and judged beside the user's reference images
(`agents/design.md`); the full build notes, colours, and shots are in git at 314c3b5.

Built 2026-11-09:

- Spring 1, elven (`looks::elven`, spring's default): ivory stone frame with low-relief
  vines and sage leaves, moss in the outline and along the edges, olive jade dark squares.
- Spring 2, Baltic folk (`looks::baltic`): dark oiled oak with a grooved band of diamonds,
  zigzags, and meanders, a sun wheel on each corner, a tree of life mid-side.
- Summer 4 and 5, amber stone (`summer_amber`, `summer_serpentine`): granite with sun signs
  and runes filled with amber, 5 in limestone and serpentine as in the image.
- `--spring N` and `--summer N` pick them in the app and `poc/3d` (G); P opens the tuning
  panel, V prints a `looks::Carving`.

How it is made: one carving, its motif a parameter (`BAKE_FRAG`'s `carving`: `vines`,
`folk`, `signs`), a height field in the frame map's bake in world units. The frame is
mitred, each side its own band of the map, across laid along the profile; along is laid
out by |along| so a symmetric knot or medallion sits on each corner's diagonal over the
mirror's seam. The height goes into the normal by finite difference and the cut into the
cavity; every edge stays a texel soft so the mips and the Toksvig term keep it from
shimmering. Motifs are sized for a phone's 40 to 80 px frame (vines about 4 px).

Bake on the M1 Pro (plan and frame map with mips): birch 24 ms, elven 53, Baltic 35,
amber 54; a frame costs the same as the birch.

## What is left

- The bakes on the Pixel 7a (never connected while measuring).
- The user's pick of the looks, seen on the tablet beside the reference images.
- Seen against the images: the amber reads as an inlay more than a deep cut; the images'
  frames are wider, so their motifs are larger; the folk meander is a plain step line.
- The temple take, if the elven one doesn't settle it.

## Acceptance criteria

- [x] The carved looks selectable beside the birch in the prototype and the game
- [x] Spring 1 toned to the mossy image; spring 2 Baltic oak; summer 4 and 5 amber stone,
      one carving with the motif a parameter, in the panel
- [ ] The bakes' cost on the Pixel 7a
- [ ] The user's pick
- [ ] The temple take, if needed
