# 012: Seasonal themes in the prototypes

Status: todo

The user's design boards, kept out of git in `~/Downloads/`: `kabe_theme_design_boards/`
(autumn wood, winter stone, spring birch with all four seasons, winter and sea side by
side, with hex palettes), `Kabe 3D prototüüp sügiseses metsas.png` (the 3D board, a
stacked king with a crown), and three earlier concept boards (`Kabe app design concept
board.png`, `Kabe App UI_ Winter and Sea Themes-2.png`, `Kabe Winter Stone UI
Board-1.png`). They pair each season with a board: autumn wood, winter stone, spring birch,
summer sea. Each has its own palette, glow, and glass tint, over a photographic
background. Bring the prototypes in line, then record the values in
`docs/architecture/rendering.md`.

## Acceptance criteria

- [ ] The season picks the board theme (overridable): wood, stone, birch, sea, with each
      board's squares, pieces, glow, and glass tint (autumn's warm glass is 66%, the
      others about 40%)
- [ ] Backgrounds from `design/backgrounds/masters/` (local; how to make them is in
      its README); the page shows them as they are, and glass samples a blurred copy
- [ ] Landscape controls as a 2×2 grid under the turn piece; puzzle picker as three theme
      rows with 0 to 3 stars; a red ring for the piece that must capture
- [ ] King: crown in 2D by default, stack with a crown on top in 3D, set by a setting
      (crown, stack, auto)
- [ ] Storage as planned in rendering.md (JPEG, stb_image, glass copy on the GPU)
      confirmed: goose_gfx's image loading checked, and where the final JPEGs live in
      the repo and the APK decided
- [ ] Each page checked with agent-browser at 1280×800 and 800×1280
