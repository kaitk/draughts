// The goose-ngfx build's upload of the season's photograph (task 065; src/app/photo.c is
// gfx's): the pixels background.c hands over, made into a texture through ngfx's C API.
// ngfx has no compressed formats yet, so the JPEG is decoded everywhere; ASTC on Apple
// silicon is the task's later step.

#include <stdint.h>
#include "ngfx_api.h"
#include "photo.h"

// Theme `kind`'s photograph as a texture, its handle's id, or 0 when it isn't built in:
// the JPEG decoded and scaled to `decoded` square.
uint32_t draughts_photo_ngfx(int64_t kind, int64_t decoded) {
    draughts_pixels p;
    if (!draughts_photo_pixels(kind, decoded, false, &p)) return 0;
    ngfx_texture_desc d = { .kind = NGFX_TEXTURE_2D, .format = NGFX_RGBA8, .usage = NGFX_SAMPLED,
                            .width = p.width, .height = p.height, .depth = 1, .mips = 1 };
    ngfx_texture t = ngfx_create_texture(&d);
    ngfx_region whole = { 0 };
    if (t.id && !ngfx_update_texture(t, &whole, (ngfx_bytes){ (uint8_t *)p.data, p.len })) {
        ngfx_release_texture(t);
        t.id = 0;
    }
    draughts_photo_done(&p);
    return t.id;
}
