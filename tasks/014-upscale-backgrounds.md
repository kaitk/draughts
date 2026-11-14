# 014: Upscale the backgrounds with real detail

Status: todo

The seasonal backgrounds are 1254 px originals enlarged to 2048 px with Lanczos
(`design/backgrounds/README.md`): sharp enough behind the board, soft up close. Upscale
them properly on the user's desktop (RTX 4090, ComfyUI), with the pipeline Snowtime used
for its backgrounds, recorded in Snowtime's
[`design/backgrounds/README.md`](https://github.com/Snowhound/snowtime/blob/main/design/backgrounds/README.md)
(task 051 there). Its ComfyUI setup was cleared to save space, so it needs setting up again first.

The pipeline in short: Lanczos to about 2048², Qwen-Image 2.1 edit to enhance (winter
with its own prompt that keeps every bit of snow), img2img at denoise 0.25 for detail,
SeedVR2 to upscale, then JPEG 85 and ASTC 6 × 6 at 2048² as the tracked masters
(`design/backgrounds/README.md`).

For this app the target is smaller than Snowtime's 3840 px: the tablet is 1920 × 1200, and a
square image covering it in both orientations needs 1920 px. Steps 2 and 3 at 2048 px
may be enough, without step 4; try that first.

## Acceptance criteria

- [ ] ComfyUI set up again on the desktop with the models above, versions recorded
- [ ] Four masters at 2048 px or more that keep each original's content, light, and
      colors, with real texture in bark, moss, snow, leaves, and rock
- [ ] Checked at 1:1 for seams, redrawn shapes, and color shifts against the original
- [ ] `design/backgrounds/README.md` updated with the steps and settings that ran
- [ ] The eight tracked JPEG and ASTC masters in `design/backgrounds/masters/` replaced
      (in git since 2026-11-10), made from the new PNG masters
