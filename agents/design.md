# Design work: references, images, and the look

What a session needs to work on the app's look without the conversations that settled it.
The values themselves are in `docs/architecture/rendering.md` ("Look"); this file says
where they came from, how to check against them, and what has been tried.

## Reference images

All of them are local, in `~/Downloads` on the user's Mac, made with ChatGPT image
generation, and are not to be checked in. On another machine or account they may be
missing: ask the user for them rather than guessing from memory.

| File | What it shows | Use it for |
| --- | --- | --- |
| `Autumn Checkers Board with Crowned King-1.png` | A close-up of the autumn board, 1254 px | The preferred board and pieces: the thin raised lip with a light outer line, one wide rim around a flat face, warm wood with calm grain |
| `Winter Stone Checkers Board-2.png` | The same close-up for winter | The same, in stone: a steel-blue lip, felt-like squares |
| `ChatGPT Image Nov 7, 2026, 08_19_31 PM.png` | The autumn board in 3D, a low angle | The pieces' true shape: flat-topped matte discs with a fine step, rounded only at the outer edge; read the top-down look from it |
| `kabe_theme_design_boards/kabe_autumn_wood.png` | The autumn design board: home, game in both orientations, puzzles, palette | Layout, panel, buttons, states (glow ring, dots, red ring) |
| `kabe_theme_design_boards/kabe_winter_stone.png` | The winter design board | As above |
| `kabe_theme_design_boards/kabe_spring_birch_four_seasons.png` | The four seasons side by side, and the spring screens | Each season's palette and scene |
| `kabe_theme_design_boards/kabe_winter_sea_comparison.png` | Winter and summer (sea) screens | The sea theme |
| `Kabe Winter Stone UI Board.png` | A winter UI board, 1536 px | Glass panels and buttons |
| `draughts-store/icon/master-winter-jump-1254.png` | The chosen app icon (2026-11-08), the winter jump: a 3×3 stone board at three-quarters, a dark slate piece in the centre, the ivory stacked king jumping it along a pale blue arc, on navy (#06172b corners, #0d2139 top) | The icon's master: copy it to `design/icon/master-winter.png` and run `scripts/icon.py` (`design/icon/README.md`); the monochrome layer is drawn from its geometry |
| `draughts-store/icon/master-autumn-jump-1254.png` | The autumn jump (2026-11-08): the same scene in wood, a dark brown piece, the cream king, a golden arc, on dark brown (#140c09 corners); the shipped icon since 2026-11-09 | The autumn master: `design/icon/master-autumn.png`, built with `scripts/icon.py autumn --res DIR`; its geometry matches winter's within 0.25 dp |
| `draughts-store/tablet-home-with-icons.png` | The icon candidates mocked up on the tablet's real home screen, 82 px | How an icon reads at the launcher's size |

Where the close-ups and the design boards differ, the close-ups win for the board and
pieces (chosen 2026-11-07); the design boards still set the layout, glass, and controls.

## How the user makes images

- Design boards and backgrounds come from ChatGPT; the user asks for the prompts
  (`prototypes/design-boards-prompt.md`, `design/backgrounds/README.md`) and saves the
  results to `~/Downloads`.
- Final backgrounds get an AI upscale on the user's Windows desktop (RTX 4090, ComfyUI)
  with Snowtime's pipeline (task 014). Originals and masters stay local and out of git,
  with a README saying how to make them again.

## Checking a look against the references

- Look at the reference up close before writing a shader: crop and enlarge with
  `magick ref.png -crop WxH+X+Y +repage -resize 300% crop.png`, and read the crop.
- Put the app's screenshot beside the reference at the same scale
  (`magick ours.png ref.png +append cmp.png`): `--size 960x600` on a 2× Mac saves
  1920 × 1200.
- Measure colors instead of judging them: `magick ref.png -crop 100x100+X+Y +repage
  -scale 1x1! -format '%[pixel:p{0,0}]' info:` gives a patch's mean.
- Text bare on the photograph that a bright patch (birch bark, snow) washes out:
  `gui::shadowed` draws it over a dark halo with no shader change (the text shader takes
  a dark color from `gui::write` with `own` true). The library's title uses it; the
  player's chip took a glass pill instead (2026-11-09). Spring's birch is the brightest
  patch behind the left edge at the tablet's landscape, autumn's lichen next.
- To show that a change touched only one thing, take the same headless shot before and
  after and box the differing pixels: `magick a.png b.png -compose difference -composite
  -threshold 0 -format '%@' info:` prints the box (WxH+X+Y).
- Preview SVG (an icon's vector layer, say) in a browser page shot with `agent-browser`:
  ImageMagick's built-in SVG renderer drops stroked paths, and the Mac has no `rsvg`.
  For an icon, show the central 72 of its 108 dp in circle and squircle masks at 48 and
  82 px (the tablet's launcher size).

## What has been tried and set aside (2026-11-07)

- Generated tabletop pictures and a plain painted tabletop behind the 2D board (task 016):
  they looked like flat stock textures next to the design boards. Don't propose more
  generated-image rounds for 2D surfaces.
- A strong light pool, a frame, and a crafted board with grain and seams on the 2D board.
  The 2D board stays simple; rich materials and lighting belong to the 3D board (task 015).
- Visible wood grain, and any regular stripe in it (sines), which bands when the board
  is seen from afar: the close-up's grain is smooth, irregular, and barely there.
- On the 3D board, grain as noise drawn out along it read as soft streaks beside the 3D
  reference; growth rings from a pith axis per piece, with pores, read as wood and don't
  band from afar (task 039, 2026-11-09). Crop the frame's front and a square of each at
  300% beside the reference and measure the patches, as that task did.
- Two rings on the pieces (an inner ring at half the radius as well as the rim), then a
  wide rounded rim like a tyre, and gloss: the pieces are flat, matte turned discs. The
  close-ups' rims are wider and rounder than ours; ours follow the 3D reference, with a
  groove and a narrow shoulder. A face too matte lost the dark pieces' edge highlight.
- The design boards' icons are a little heavier, and their bulb is filled; the
  prototypes' 2.4-unit stroke and outlined bulb look right on the tablet and stay
  (2026-11-07).
- Left different from the design boards on purpose: their wood grain is finer and
  straighter; their lifted piece shows a tall side, ours lifts 0.8% of the board with a
  growing shadow; they set board and panel in one glass card, which task 008 decides.

When an idea drifts from the references, prototype it cheaply and put it next to the
matching reference before investing in it.
