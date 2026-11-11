// The goose-ngfx build's upload of the season's photograph (task 065; src/app/photo.c is
// gfx's): the pixels background.c hands over, made into a texture through ngfx's C API,
// the embedded ASTC 6 × 6 blocks where the GPU samples them, else the JPEG decoded.

#include <stdint.h>
#include "ngfx_api.h"
#include "photo.h"

// A texture holding the pixels, or 0.
static ngfx_texture upload(const draughts_pixels *p) {
    int32_t format = p->format == DRAUGHTS_ASTC_6x6 ? NGFX_ASTC_6x6 : NGFX_RGBA8;
    ngfx_texture_desc d = { .kind = NGFX_TEXTURE_2D, .format = format, .usage = NGFX_SAMPLED,
                            .width = p->width, .height = p->height, .depth = 1, .mips = 1 };
    ngfx_texture t = ngfx_create_texture(&d);
    ngfx_region whole = { 0 };
    if (t.id && !ngfx_update_texture(t, &whole, (ngfx_bytes){ (uint8_t *)p->data, p->len })) {
        ngfx_release_texture(t);
        t.id = 0;
    }
    return t;
}

// Theme `kind`'s photograph as a texture, its handle's id, or 0 when it isn't built in:
// the ASTC image as stored where the GPU samples ASTC, else (or if that upload fails) the
// JPEG decoded and scaled to `decoded` square.
uint32_t draughts_photo_ngfx(int64_t kind, int64_t decoded) {
    bool astc = ngfx_format_supported(NGFX_ASTC_6x6, NGFX_SAMPLED);
    draughts_pixels p;
    if (!draughts_photo_pixels(kind, decoded, astc, &p)) return 0;
    ngfx_texture t = upload(&p);
    bool was_astc = p.format == DRAUGHTS_ASTC_6x6;
    draughts_photo_done(&p);
    if (t.id || !was_astc) return t.id;
    if (!draughts_photo_pixels(kind, decoded, false, &p)) return 0;
    t = upload(&p);
    draughts_photo_done(&p);
    return t.id;
}
