# 016: Tabletop pictures for the 2D game

Status: todo

The 2D game sits on a flat tabletop, for now a gradient with noise in the theme's table
color ([rendering](../docs/architecture/rendering.md#scene-and-glass)). Try generated
tabletops in ChatGPT, one per season, with a few objects at the edges that belong with
the board. Images stay local until the user agrees to add them to git.

Every prompt keeps to these: straight top-down with flat, even light (a tilt or a shadow
direction fights the flat board); square, at least 2048 px, so one picture crops to
1920 × 1200 either way; objects only in the outer 12% of each side, so the middle under
the board and panel is calm; low contrast and a little dark; no board, pieces, or text.

## Prompts

Ready to paste, all twelve in order: `design/tabletops/prompts.txt`. The
templates:

Realistic:

> Top-down orthographic photo of a [TABLE] tabletop, perfectly flat overhead view, soft
> even diffuse light, no strong shadows, no perspective. The centre 75% of the image is
> plain, calm, slightly darker table surface with subtle texture and no objects. Only
> along the outer edges and corners, partly cut off by the frame: [OBJECTS]. Muted,
> low-contrast colors, gentle vignette. No game board, no pieces, no text. Square,
> 2048×2048.

1990s Amiga style, at modern resolution (generate at the final size, or ask for chunky
3×3 pixels, since pixel art doesn't upscale cleanly):

> Top-down view of a [TABLE] tabletop in the style of a high-resolution 1990s Amiga game
> screen: hand-painted pixel art with crisp clean pixels, ordered-dither gradients, a
> limited rich palette of about 32 colors per material, the polished look of a Deluxe
> Paint title screen, but at modern high resolution. Flat overhead view, even light.
> The centre 75% is plain table surface with gentle dithered shading and no objects.
> Only along the edges and corners: [OBJECTS], drawn in the same pixel style. No game
> board, no pieces, no text. Square.

A game mat instead of a table:

> Top-down flat photo of a [color] wool felt game mat with a fine woven texture and a
> stitched border just inside the edges, on a [TABLE]. Even soft light, plain centre, no
> objects in the middle. No game board, no pieces, no text. Square.

| Season | TABLE | OBJECTS |
| --- | --- | --- |
| Autumn (wood) | dark oiled oak with fine straight grain | a few fallen maple leaves, a mug of tea, an acorn or two |
| Winter (stone) | grey-blue slate or painted wood | knitted mittens, a pine sprig, a candle stub, a few snow crystals |
| Spring (birch) | pale birch plywood, light green-grey stain | birch twigs with small new leaves, a few wildflowers, a pencil |
| Summer (sea) | sun-bleached teal-painted boards | a few seashells, smooth pebbles, a piece of driftwood, sand at one corner |

## Acceptance criteria

- [ ] A few tabletops per season tried behind `prototypes/game.html` at both sizes
- [ ] The user picks a style, or keeps the plain table
- [ ] If pictures win: stored as the scenes are, added to git only once the user agrees
