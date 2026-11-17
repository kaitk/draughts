# Seasonal backgrounds

One photograph-like background per season, behind the board. The board theme follows
the season: autumn wood, winter stone, spring birch, summer sunset
([rendering](../../docs/architecture/rendering.md)).

| Files | What they are |
| --- | --- |
| `<season>-01.png` | The originals from ChatGPT, 1254 × 1254 px. Kept as they are. Local. |
| `masters/<season>-01-3840.png` | The masters, 3840 × 3840, upscaled with real detail (below). Local. |
| `masters/<season>-01-2048.png` | The master shrunk to 2048 × 2048, for the ASTC file. Local. |
| `masters/<season>-01-3840.jpg` | The master at JPEG quality 85, 1.39 to 1.92 MB: what desktops decode, at the display's size. In git. |
| `masters/<season>-01-512.jpg` | The master at 512 px, quality 90, 60 to 78 KB: desktops' small uses (the 3D board's blurred copy, settings' thumbnails). In git. |
| `masters/<season>-01-2048-6x6.astc` | The 2048 PNG as ASTC in 6 × 6 blocks, 1.87 MB: what phones' and tablets' GPUs sample. In git. |

The JPEG and ASTC files, which the app embeds, are in git, so a fresh checkout shows the
photographs; replacing them adds their size to git's history. The originals and the PNG
masters stay local (`.gitignore`), and this README says how to make them again. The app
builds them into the program from `masters/` (`src/app/background.c`,
[rendering](../../docs/architecture/rendering.md#scene-and-glass)): phones and tablets
embed only the ASTC files, desktops only the JPEGs. Each is made from the lossless PNG
master, never one from another. After replacing a file, touch `src/app/background.c`:
the build doesn't see a changed `#embed` file and keeps the old object.

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

## The masters (2026-11-17)

The originals carry a fine mesh, plain on rock, moss, snow, and bark: a 2 px checker and
a 4 px diagonal diamond (sharp peaks in their spectrum). The masters lose it and add real
texture while keeping each original's content, light, and colors. They were made in
ComfyUI on Windows with an RTX 4090 (24 GB):

1. **Enlarge** the original to 2048 × 2048 with Lanczos in linear light.
2. **Redraw** it with Qwen-Image 2.1 img2img at denoise 0.3: 25 steps, CFG 1, euler,
   simple scheduler, a short prompt naming what the season shows and asking to keep it
   exactly as a sharp, detailed photograph (winter: every bit of snow stays). Seeds:
   autumn, spring, and summer 301, winter 302. This is what removes the mesh.
3. **Upscale** to 3840 with `SeedVR2TilingUpscaler` and SeedVR2 7B
   (`seedvr2_ema_7b_fp16`, VAE `ema_vae_fp16`): 1024 px tiles, 128 px padding,
   `tile_upscale_resolution` 1536 (SeedVR2 itself does about 1.2×, Lanczos the rest),
   `linear` blending with `mask_blur` 16, `Chess` order, anti-aliasing 0.1, `lab` color
   correction, the DiT cached on `cuda:0`. Flatten to RGB (ComfyUI saves RGBA).
4. **Encode**:

```sh
magick masters/<season>-01-3840.png -quality 85 -sampling-factor 4:2:0 -strip   masters/<season>-01-3840.jpg
magick masters/<season>-01-3840.png -colorspace RGB -filter Lanczos -resize 512x512   -colorspace sRGB -quality 90 -sampling-factor 4:2:0 -strip masters/<season>-01-512.jpg
magick masters/<season>-01-3840.png -colorspace RGB -filter Lanczos -resize 2048x2048   -colorspace sRGB masters/<season>-01-2048.png
../../build/astcenc-5.7.0/bin/astcenc -cl masters/<season>-01-2048.png   masters/<season>-01-2048-6x6.astc 6x6 -thorough -esw rgb1
```

On Windows astcenc's binary is `bin/astcenc-avx2.exe`. The ASTC file is LDR and linear
(`-cl`), since the app samples the JPEG's bytes as they are too; `-esw rgb1` spends no
bits on the opaque alpha.

Against their masters the 3840 JPEGs are 38.9 to 41.7 dB. Lossy WebP at the same PSNR
would be about 40% smaller (about 4 MB for the four instead of 6.6), which doesn't pay
for a second decoder; jpegli, which writes JPEGs the app already decodes, would save
part of that with no code (2026-11-17).

The masters are about 1 L unit (of 100) darker than the originals, with no hue shift.
At the finest scale the redraw changes single leaves, lichen, and spruce sprigs, not
their arrangement or tone.

What didn't work (2026-11-17):

- **SeedVR2 alone** turns the mesh into a regular crackle of scale-like cells.
- **Snowtime's pipeline** (a Qwen-Image edit with the original as reference, a detail
  pass, then SeedVR2): the edit copies the mesh, one seed sharpening it into a plain grid,
  and the result is colder, greyer, and wet-looking, with moss and lichen redrawn.
- **SeedVR2 at the full 1.875× per tile** (768 px tiles, 2048 cap) turns leftover fine
  texture into a leather-like crackle on snow and a cell net on rock.
- **Denoise 0.4** drifts from the original; a softened base (Lanczos to 1000 px first)
  makes paving-like cells; a notch filter on the mesh's frequencies alone leaves the woven
  look, since it isn't strictly periodic.
- **Real-ESRGAN-type upscalers** on the Mac (2026-11-16) sharpen the mesh into a net.
