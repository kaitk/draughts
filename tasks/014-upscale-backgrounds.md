# 014: Upscale the backgrounds with real detail

Status: todo

The seasonal backgrounds are 1254 px originals enlarged to 2048 px with Lanczos
(`design/backgrounds/README.md`): sharp enough behind the board, soft up close. Upscale
them properly on the user's desktop (RTX 4090, ComfyUI), with the pipeline Snowtime used
for its backgrounds, recorded in Snowtime's
[`design/backgrounds/README.md`](https://github.com/Snowhound/snowtime/blob/main/design/backgrounds/README.md)
(task 051 there). Its ComfyUI setup was cleared to save space, so it needs setting up again first.

## What the desktop has and needs (checked 2026-11-16)

In place, at the versions Snowtime recorded:

- ComfyUI at commit `79be670e`, its venv working (PyTorch 2.13.0 with CUDA 13.0, the GPU
  seen).
- The nodes ComfyUI-SeedVR2_VideoUpscaler `4490bd1` and comfyui-seedvr2-tilingupscaler
  `a117bf1`.
- Snowtime's ComfyUI API scripts (`qwen_edit.py` for the enhance step, `detail.py`,
  `upscale.py`, `download-models.sh`, `overnight.sh`), and ImageMagick 7.1.2-31 and
  cwebp 1.6.0, kept beside the ComfyUI checkout.

To download, 41.2 GB in all:

| File | Size | From |
| --- | --- | --- |
| `diffusion_models/qwen_image_2.1_bf16.safetensors` | 14.2 GB | [Comfy-Org/Qwen-Image-2.1](https://huggingface.co/Comfy-Org/Qwen-Image-2.1) |
| `text_encoders/qwen3vl_8b_int8_convrot.safetensors` | 9.4 GB | the same |
| `vae/qwen_image_2.1_vae_bf16.safetensors` | 0.7 GB | the same |
| `SEEDVR2/seedvr2_ema_7b_fp16.safetensors` | 16.5 GB | [numz/SeedVR2_comfyUI](https://huggingface.co/numz/SeedVR2_comfyUI) |
| `SEEDVR2/ema_vae_fp16.safetensors` | 0.5 GB | the same |

`download-models.sh` fetches all five into ComfyUI's `models/`, resuming a broken
download. Check the drive first: ComfyUI's drive needs room for the 41 GB and the outputs,
or the models go on another drive through `extra_model_paths.yaml` (check that the SeedVR2
node reads its folder from there before relying on it).

Also needed:

- **The four originals**, `design/backgrounds/<season>-01.png` (1254 px). They are kept
  locally, not in git, and only the Mac has them now: copy them over first. The JPEG masters
  in git are Lanczos-enlarged and sharpened, so they are no starting point.
- **astcenc 5.7.0** for the ASTC masters: the Windows x64 zip from the same release as
  the Mac's (`docs/development.md`), into `build/astcenc-5.7.0/`. A few MB. Or encode the
  ASTC files on the Mac from the new PNG masters.

What Snowtime's run learned on a 24 GB GPU with 32 GB of RAM: Qwen-Image and SeedVR2 don't
fit in memory together, so restart ComfyUI between the Qwen steps and the upscale. Keep
SeedVR2's DiT cached on the GPU (`cache_model` on, `offload_device` `cuda:0`), and keep
`QwenImage21Cache` off. Use linear tile blending (multiband leaves seams). ComfyUI saves
RGBA, so flatten the result to RGB before encoding.

## Plan for these square images

The originals are 1254 × 1254. Qwen-Image 2.1 edits within about 2048² pixels, so resize
to 2048 × 2048 with Lanczos for the enhance and detail steps (Snowtime's 2720 × 1536 is
its 16:9 equivalent). Then:

1. Enhance (40 steps, CFG 1, euler, simple, the original as `<image1>`, `resolution` 0)
   with Snowtime's prompt, worded for this forest scene: bark, moss, leaves, rock, snow.
   Winter gets the snow-keeping prompt. Try two or three seeds each.
2. Detail: img2img at denoise 0.25, 25 steps.
3. Upscale to 3840 × 3840 with SeedVR2 (`upscale.py` with `new_resolution` 3840), and
   Lanczos down to 2048 for the mobile masters.
4. Compare at 1:1 with the original and the current master on one page, per season, and
   pick.

The pipeline in short: Lanczos to about 2048², Qwen-Image 2.1 edit to enhance (winter
with its own prompt that keeps every bit of snow), img2img at denoise 0.25 for detail,
SeedVR2 to upscale, then JPEG 85 and ASTC 6 × 6 at 2048² as the tracked masters
(`design/backgrounds/README.md`).

For this app the target is smaller than Snowtime's 3840 px: the tablet is 1920 × 1200, and a
square image covering it in both orientations needs 1920 px. Steps 2 and 3 at 2048 px
may be enough, without step 4; try that first.

Desktops want more: a square image covering a 3840 × 2160 screen needs 3840 px. Make the
3840 px master in the same run and scale it down to 2048 px for the mobile masters, so both
come from one upscale.

## Tried and set aside (2026-11-16)

Real-ESRGAN-type upscalers on the Mac (upscayl-bin 20251207, Metal; UltraSharp, Remacri,
Upscayl standard, high-fidelity, Nomos8kSC; about 40 s an image on an M1 Pro): they add
no detail. The ChatGPT originals carry a fine mesh pattern, plain on rock, moss, and the
birch's dark marks, and these models sharpen it into a visible net. Remacri and
high-fidelity are the mildest; shrinking to 1000 px first removes the mesh but paints the
rock in oil-paint strokes. So the enhance step (Qwen-Image edit, img2img) must be what
removes the mesh and adds detail; a sharpening upscale alone won't do.

## Acceptance criteria

- [ ] ComfyUI set up again on the desktop with the models above, versions recorded
- [ ] Four masters at 2048 px or more that keep each original's content, light, and
      colors, with real texture in bark, moss, snow, leaves, and rock
- [ ] Checked at 1:1 for seams, redrawn shapes, and color shifts against the original
- [ ] `design/backgrounds/README.md` updated with the steps and settings that ran
- [ ] The eight tracked JPEG and ASTC masters in `design/backgrounds/masters/` replaced
      (in git since 2026-11-10), made from the new PNG masters
