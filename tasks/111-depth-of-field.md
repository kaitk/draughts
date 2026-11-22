# 111: Depth of field for the scenic views

Status: in-progress (2026-11-22; B0 to B2 built, on the branch `room-light`, under the epic 107)

A camera's focus for the artistic scenes only (the main menu's and a few more, never the
game): the board sharp with the window, the maple and the sun in soft round discs behind
it, or the tree sharp and the table blurred before it, the focus pulled between them in
about 2.2 s. The plan, its methods and its reference: `build/notes/bokeh/` (steps B0 to B8).
The user's choices (2026-11-22): on higher-end GPUs, the high tier; tablets the cheap
fallback later, phones none; the concept's disc the default lens, other lens presets later;
a fixed aperture per scene, the focus pulled in dioptres; the HDR target 4x MSAA in
RG11B10F with a dither at the tonemap, RGBA16F MSAA the fallback.

## Acceptance criteria

- [x] B0: the lens (focus, aperture, near and far caps; `render3d::Lens`) and the light
      tuner's Lens section and flags (`--dof`, `--focus`, `--aperture`, `--dof-caps`); the
      motes take their discs from it when it is on
- [x] B1: the scenic views drawn into the HDR target, tonemapped after; the old 8-bit path
      one switch away (`--hdr off`, X); the game and the standard and phone tiers unchanged
- [x] B2: a 1x sampled depth of the scene (DEPTH32F), the lace by its coverage, and the
      tuner's views of it and of the lens's disc (`--lens-view depth|coc`, Q)
- [ ] The HDR look retuned where it differs from the 8-bit one (below), the user choosing
- [ ] B3: the view out's discs (the outside into a half-size HDR target with the tree's
      layer depth, a dense fixed gather)
- [ ] B4: the room's near and far fields (half size, tile max, gathers, composite with the
      tonemap)
- [ ] B5: bright highlights as soft-knee sprites
- [ ] B6: the motes after the composite, in the shared lens
- [ ] B7: the focus pull (two focus states per scene, the dioptre ease, `--pull-time`)
- [ ] B8 if wanted: cat's-eye discs toward the corners, a faint fringe
- [ ] The tablets' fallback (the view out's discs and a mip blend for the room)
- [ ] Costs measured at each step on a quiet Mac (below), then on the devices that get it

The view out's baked blur (the oak's upload blur, the pictures' `OAK_BLUR` and
`BAND_BLUR`) goes when the park's impostor trees come, leaving this lens the only blur of
distant objects: task 109, Outside, the user's verdicts of 2026-11-22.

## B0 to B2 (builder 28, 2026-11-22, `build/notes/builder-28/`)

Headless 3024 × 1890 on the M1 Pro, Metal System Trace, GPU ms, two rounds alike
(`build/b28/round{1,2}-b{1,2}.txt`); "native" is `--scene-scale 1`, "budget" the 4.1 MP
default; the table-window view with its dust.

| | room, native | table-window, native | room, budget | table-window, budget |
|---|---|---|---|---|
| main pass, before (0bf607d7) | 11.95-11.96 | 5.04 | 9.04-9.05 | 3.94 |
| main pass, 8 bits (`--hdr off`) | 11.93-11.94 | 5.02-5.04 | 9.02-9.03 | 3.93 |
| main pass, HDR RG11B10F | 11.63-11.64 | 4.65-4.66 | 8.81-8.82 | 3.66-3.67 |
| the tonemap's pass | 0.45-0.46 | 0.43-0.44 | 0.35 | 0.35-0.36 |
| main pass, HDR RGBA16F | 11.73-11.74 | 4.63 | | |
| the depth pass (`--dof on`) | 0.19 | 0.19 | 0.16 | 0.16 |
| its view (`--lens-view depth`) | 0.13 | 0.13 | | |
| the frame's GPU parts: 8 bits / HDR / HDR and depth | 14.90-14.93 / 14.82-14.84 / 15.04-15.05 | 7.46-7.58 / 7.39-7.48 / 7.58 | 11.87 / 11.85-11.86 / 12.06-12.07 | 6.40 / 6.32-6.33 / 6.47-6.48 |

Memory at native (budget): the HDR resolve 22.9 MB (16.4), RG11B10F; its 4× target takes the
8-bit one's place (91 MB, 66; transient in ngfx); the depth 22.9 MB (16.4); RGBA16F would
add 114 MB at native.

The look, 8 bits against HDR (`build/notes/builder-28/`): the surfaces within 2-3 levels;
the lace lighter and more opaque (linear blending), the glass's film and scratches about
three times as strong over the tree (+6.9 levels there, +1.4 with them off), the glass's
reflection over the sky +4.5 with the film off, thin bars against the sky a little
thinner. Nothing retuned yet. The game's shot unchanged in both renderers at each step;
`--hdr off` matches 0bf607d7 but for 34 pixels of the glass's scratches, which a NaN had
blanked (fixed).

Open: retuning the lace and the film in HDR; the glow from the HDR light after the blur
(B4); a sample-count query in the fork for the RGBA16F fallback; click to focus.
