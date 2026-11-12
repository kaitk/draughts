// photo.c's upload through goose-ngfx's C API, beside gfx's src/app/photo_gpu.h in the
// build that holds both (scripts/ngfx.py; photo_gpu.h there picks one).
#include "ngfx_api.h"

// Whether the GPU samples ASTC in 6 × 6 blocks.
static bool photo_astc_sampled(void) { return ngfx_format_supported(NGFX_ASTC_6x6, NGFX_SAMPLED); }

// A texture holding the pixels, its handle's id, or 0.
static uint32_t photo_upload(const draughts_pixels *p) {
    int32_t format = p->format == DRAUGHTS_ASTC_6x6 ? NGFX_ASTC_6x6 : NGFX_RGBA8;
    ngfx_texture_desc d = { .kind = NGFX_TEXTURE_2D, .format = format, .usage = NGFX_SAMPLED,
                            .width = p->width, .height = p->height, .depth = 1, .mips = 1 };
    ngfx_texture t = ngfx_create_texture(&d);
    ngfx_region whole = { 0 };
    if (t.id && !ngfx_update_texture(t, &whole, (ngfx_bytes){ (uint8_t *)p->data, p->len })) {
        ngfx_release_texture(t);
        t.id = 0;
    }
    return t.id;
}
