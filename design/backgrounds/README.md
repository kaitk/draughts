# Seasonal backgrounds

One photograph-like background per season, behind the board. The board theme follows
the season: autumn wood, winter stone, spring birch, summer sunset
([rendering](../../docs/architecture/rendering.md)).

| Files | What they are |
| --- | --- |
| `<season>-01.png` | The originals from ChatGPT, 1254 × 1254 px. Kept as they are. |
| `masters/<season>-01-2048.png` | Placeholder masters, 2048 × 2048, Lanczos and a light sharpen. |
| `masters/<season>-01-2048.jpg` | The same at JPEG quality 85, 0.46 to 0.70 MB: the fallback where the GPU lacks ASTC. |
| `masters/<season>-01-2048-6x6.astc` | The PNG master as ASTC in 6 × 6 blocks, 1.87 MB: what Android's GPU samples. |

Originals and masters stay local and out of git (`.gitignore`): they're temporary, and
this README says how to make them again. The app builds each season's JPEG and ASTC
file into the program from `masters/` (`app/background.c`,
[rendering](../../docs/architecture/rendering.md#scene-and-glass)). Both are made from the
lossless PNG master, never one from the other; the final images (task 014) take the
same steps.

## The originals (2026-11-07)

Generated in one ChatGPT chat, square, with a calm soft-focus middle for the board and
sharp framing at the edges. The prompts asked for the view from inside each place, with
no lake or horizon across the middle. Summer is from an earlier run in the same chat:
its frame (a pine and a birch at the edges, a forested point, boulders) shows more
beside the board than the later, open-sea version.

Shared part of each prompt:

> A photograph-like background for a calm board game app. Square, 2048 × 2048; it will
> be cropped to both 16:10 landscape and 10:16 portrait, and a game board will cover the
> middle. Eye-level view from inside the landscape, not a vista: near trees or rocks frame
> the edges and corners in sharp focus, and the middle is the depth of the place, softly
> out of focus through natural shallow depth of field (like a 50 mm lens at f/2), calm
> and even in tone. No lake, river, or pond unless the season below asks for water, and
> no single horizon line across the middle. Soft natural light, slightly muted, a little
> darker than a normal photo so light text and glass panels read well over it. No people,
> animals, buildings, paths leading into the centre, text, board, pieces, or UI. Nothing
> falling through the air (no snowflakes, leaves, or rain; the app adds those).

Per season:

- Autumn: "Inside a mixed Estonian forest in early October: maple and birch branches
  with orange, amber and red leaves close at the top corners, a mossy boulder and fallen
  leaves on the ground at the bottom, warm low sunlight glowing between the trunks in the
  soft-focus depth. Warm browns and ambers."
- Winter: "Inside a snowy spruce forest at blue hour: snow-laden spruce boughs close at
  the sides and top, deep untouched snow with soft drifts at the bottom, tall spruces
  fading into blue haze in the middle, a faint pink and violet glow of sky through the
  gaps. Cool blue-grey, quiet and clean."
- Spring: "Inside a light birch grove in late May: white birch trunks with black marks
  close at the left and right edges, fresh bright-green leaves at the top, white wood
  anemones and new grass at the bottom, morning light filtering through the leaves into
  a soft green depth. Fresh greens and creamy whites."
- Summer (earlier run): "The rocky North Estonian coast on a calm summer evening: large
  rounded granite boulders, a pine at a top corner, a forested point beyond, a peach and
  blue sky. Sea greens, sage, and warm stone."

## The placeholder masters

```sh
magick <season>-01.png -alpha off -colorspace RGB -filter Lanczos -resize 2048x2048 \
  -colorspace sRGB -unsharp 0x1+0.4+0.02 masters/<season>-01-2048.png
magick masters/<season>-01-2048.png -quality 85 -sampling-factor 4:2:0 -strip \
  masters/<season>-01-2048.jpg
```

```sh
../../build/astcenc-5.7.0/bin/astcenc -cl masters/<season>-01-2048.png \
  masters/<season>-01-2048-6x6.astc 6x6 -thorough -esw rgb1
```

The ASTC file (astcenc, `docs/development.md`) is LDR and linear (`-cl`), since the app
samples the JPEG's bytes as they are too; `-esw rgb1` spends no bits on the opaque
alpha. About a second a season. Against the PNG master, the JPEG is 37.5 to 41.5 dB,
the ASTC 40 to 45 (4 × 4: 45.6 to 50, at 4 MB; task 032, cut 5).

Resizing in linear light avoids dark fringes; the sharpen is light enough to leave no
halos at 1:1. They add no detail: fine behind the board and glass, soft up close. Task
014 replaces them with a real upscale.
