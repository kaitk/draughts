// photo.c's upload through goose_gfx's C API; the goose-ngfx build's
// src/ngfx/app/photo_gpu.h takes this file's place.
#include "gfx_api.h"

// What patches/goose_gfx/0004-compressed-textures.patch adds to gfx: its number for
// ASTC in 6 × 6 blocks, and whether the GPU samples a format. A gfx without the patch
// (the Mac's, built into Goose) has neither, and this weak stand-in says no, so the
// JPEG is decoded there; the patched gfx's own definition takes its place.
enum { ASTC_6x6 = 26 };
__attribute__((weak)) uint8_t gs_gfx_format_supported(int32_t format, int32_t usage) {
    (void)format;
    (void)usage;
    return 0;
}

// Whether the GPU samples ASTC in 6 × 6 blocks.
static bool photo_astc_sampled(void) { return gs_gfx_format_supported(ASTC_6x6, GS_GFX_SAMPLED); }

// A texture holding the pixels, its handle's id, or 0.
static uint32_t photo_upload(const draughts_pixels *p) {
    int32_t format = p->format == DRAUGHTS_ASTC_6x6 ? ASTC_6x6 : GS_GFX_RGBA8;
    gs_gfx_texture_desc d = { .kind = GS_GFX_TEXTURE_2D, .format = format,
                              .usage = GS_GFX_SAMPLED, .width = p->width, .height = p->height,
                              .depth = 1, .mips = 1, .samples = 1 };
    gs_gfx_texture t = gs_gfx_create_texture(&d);
    gs_gfx_region whole = { 0 };
    if (t.id && !gs_gfx_update_texture(t, &whole, (gs_gfx_bytes){ (uint8_t *)p->data, p->len })) {
        gs_gfx_release_texture(t);
        t.id = 0;
    }
    return t.id;
}
