# SMAA

Enhanced Subpixel Morphological Antialiasing, by Jorge Jimenez, Jose I. Echevarria, Belen
Masia, Fernando Navarro, and Diego Gutierrez, MIT licensed (`LICENSE.txt`). From
github.com/iryoku/smaa at `71c806a` (2026-11-11):

- `SMAA.hlsl`: the shader as published, unchanged. The ngfx build's
  `src/ngfx/shaders/smaa.slang` includes it with its porting macros (`SMAA_CUSTOM_SL`).
- `area.bin`: `Textures/AreaTex.h`'s bytes, 160 × 560 RG8, rows top first.
- `search.bin`: `Textures/SearchTex.h`'s bytes, 64 × 16 R8, rows top first.
