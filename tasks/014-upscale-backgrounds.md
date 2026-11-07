# 014: Upscale the backgrounds with real detail

Status: todo

The seasonal backgrounds are 1254 px originals enlarged to 2048 px with Lanczos
(`design/backgrounds/README.md`): sharp enough behind the board, soft up close. Upscale
them properly on the user's desktop (RTX 4090, ComfyUI), with the pipeline Snowtime used
for its backgrounds, recorded in
`~/projects/snowtime/snowtime/design/backgrounds/README.md` (task 051 there). Its
ComfyUI setup was cleared to save space, so it needs setting up again first.

The pipeline, from that README:

1. Resize the original with Lanczos to the largest size Qwen-Image 2.1 edits whole
   (about 2048² pixels; for a square, 2048 × 2048).
2. Enhance: Qwen-Image 2.1 in edit mode, the original as its only reference, 40 steps,
   CFG 1, euler, simple. The prompt keeps everything ("Keep <image1> exactly: the same
   place, camera, composition, ... add, remove or move nothing. Render it as a sharp,
   detailed photograph with crisp textures ..."). Winter needs its own prompt that keeps
   every bit of snow.
3. Detail: the same model img2img at denoise 0.25, 25 steps.
4. Upscale: SeedVR2 7B through `SeedVR2TilingUpscaler`, `linear` blending (not
   `multiband`, which leaves seams), the model cached on the GPU, `lab` color correction.
5. Encode for the app: JPEG quality 85, 2048 × 2048, as `assets/backgrounds/<season>.jpg`
   ([rendering](../docs/architecture/rendering.md#scene-and-glass)).

For kabe the target is smaller than Snowtime's 3840 px: the tablet is 1920 × 1200, and a
square image covering it in both orientations needs 1920 px. Steps 2 and 3 at 2048 px
may be enough, without step 4; try that first.

## Acceptance criteria

- [ ] ComfyUI set up again on the desktop with the models above, versions recorded
- [ ] Four masters at 2048 px or more that keep each original's content, light, and
      colors, with real texture in bark, moss, snow, leaves, and rock
- [ ] Checked at 1:1 for seams, redrawn shapes, and color shifts against the original
- [ ] `design/backgrounds/README.md` updated with the steps and settings that ran
- [ ] The four JPEGs in `assets/backgrounds/`, added to git only once the user agrees
