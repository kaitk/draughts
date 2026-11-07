# 012: Seasonal themes in the prototypes

Status: todo

The user's design boards (`~/Downloads/kabe_theme_design_boards/` and the 3D board,
kept out of git) pair each season with a board: autumn wood, winter stone, spring birch,
summer sea. Each has its own palette, glow, and glass tint, over a photographic
background. Bring the prototypes in line, then record the values in
`docs/architecture/rendering.md`.

## Acceptance criteria

- [ ] The season picks the board theme (overridable): wood, stone, birch, sea, with each
      board's squares, pieces, glow, and glass tint (autumn's warm glass is 66%, the
      others about 40%)
- [ ] Backgrounds from the user's new sharp photos (not checked in until the storage
      decision); the page shows them as they are, and glass samples a blurred copy
- [ ] Landscape controls as a 2×2 grid under the turn piece; puzzle picker as three theme
      rows with 0 to 3 stars; a red ring for the piece that must capture
- [ ] King: crown in 2D by default, stack with a crown on top in 3D, set by a setting
      (crown, stack, auto)
- [ ] How the app stores and loads backgrounds decided and recorded
- [ ] Each page checked with agent-browser at 1280×800 and 800×1280
