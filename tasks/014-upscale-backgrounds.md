# 014: Upscale the backgrounds with real detail

Status: in-progress

The seasonal backgrounds were 1254 px originals enlarged to 2048 px with Lanczos: sharp
enough behind the board, soft up close, with the originals' fine mesh (a 2 px checker and
a 4 px diamond) plain on rock, moss, snow, and bark. Make masters up to 3840 px that keep
each original's look, lose the mesh, and have real texture; phones get 2048 px ASTC as
before, desktops a 4K JPEG.

## Done (2026-11-17, branch `bg-4k`)

- 3840 × 3840 masters by Lanczos to 2048, Qwen-Image 2.1 img2img at denoise 0.3, and
  SeedVR2 7B tiled to 3840; the steps, settings, seeds, and what didn't work are in
  `design/backgrounds/README.md`. Versions: ComfyUI `79be670e` (0.37.0),
  ComfyUI-SeedVR2_VideoUpscaler `4490bd1` (v2.5.24), comfyui-seedvr2-tilingupscaler
  `a117bf1`; the five models' SHA-256s match Hugging Face's.
- Timings on an RTX 4090: img2img 66 s a season, SeedVR2 30 s, a ComfyUI restart between
  them (Qwen-Image and SeedVR2 don't fit in 32 GB of RAM together); the four seasons
  with two seeds each in about 20 minutes.
- Checks: the masters are about 1 L unit darker than the originals with no hue shift
  (ΔE at 314 px: autumn 5.2, winter 3.2, spring 4.6, summer 4.3); no line at the tile
  edge (x = 1920); autumn has a 2.7-level tone step across it from Qwen's redraw of the
  top branches, not a seam. Left in all four: a faint diagonal peak at 0.267 cycles/px
  (Qwen's VAE, a 2.65 px period), a slight grain on the dark autumn boulder, and soft
  streaks in winter's snow, both far milder than the alternatives'.
- The app: phones keep 2048 ASTC (new files, same size); desktops embed only JPEGs, 3840
  for the sharp photograph decoded at the display's size and 512 for small uses, and no
  ASTC (`docs/decisions/rendering.md`, "Scene and glass"). The Windows program went from
  17.3 to 14.4 MB; the photograph's load from 21 to about 84 ms at 2560 px. Tests pass;
  the Android build compiles.
- Formats at matched PSNR (about 40 dB) for the four 3840 images: JPEG q85 6.6 MB, lossy
  WebP about 4 MB. JPEG stays (no second decoder).

## Left

- The user's look: per season, the comparison page of the original, the pick, the other
  seed, and crops at 1:1 (kept locally with the run's scripts and every render).
- jpegli for the 3840 JPEGs: the same decoder, likely 25 to 35% smaller. Its prebuilt
  Windows tool wasn't fetched in the unattended run (the download wasn't permitted).
- The branch on the Mac (Retina: about 3000 px decoded) and on the tablet (the new ASTC
  files), with the numbers here, then merge.

## Acceptance criteria

- [x] ComfyUI set up again on the desktop with the models above, versions recorded
- [x] Four masters at 2048 px or more that keep each original's content, light, and
      colors, with real texture in bark, moss, snow, leaves, and rock
- [x] Checked at 1:1 for seams, redrawn shapes, and color shifts against the original
- [x] `design/backgrounds/README.md` updated with the steps and settings that ran
- [x] The tracked masters in `design/backgrounds/masters/` replaced, made from the new
      PNG masters
- [ ] The user has looked at them and agrees
- [ ] Checked on the Mac and the tablet
