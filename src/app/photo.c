// The renderer's upload of the season's photograph (docs/architecture/rendering.md,
// "Scene and glass"): the pixels background.c hands over, made into a texture through
// goose_gfx's C API, so the embedded ASTC blocks reach the GPU with no copy on the
// program's data stack. goose_gfx has no compressed formats of its own and reads only PNG
// and BMP, from a file (docs/goose-findings.md). Another renderer replaces this file.

#include <stdint.h>
#include "gfx_api.h"
#include "photo.h"

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

// A texture holding the pixels, or 0.
static gs_gfx_texture upload(const draughts_pixels *p) {
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
    return t;
}

// Theme `kind`'s photograph as a texture, or 0 when it isn't built in: the ASTC image as
// stored where the GPU samples ASTC, else (or if that upload fails) the JPEG decoded and
// scaled to `decoded` square.
gs_gfx_texture draughts_photo(int64_t kind, int64_t decoded) {
    bool astc = gs_gfx_format_supported(ASTC_6x6, GS_GFX_SAMPLED);
    draughts_pixels p;
    if (!draughts_photo_pixels(kind, decoded, astc, &p)) return (gs_gfx_texture){ 0 };
    gs_gfx_texture t = upload(&p);
    bool was_astc = p.format == DRAUGHTS_ASTC_6x6;
    draughts_photo_done(&p);
    if (t.id || !was_astc) return t;
    if (!draughts_photo_pixels(kind, decoded, false, &p)) return t;
    t = upload(&p);
    draughts_photo_done(&p);
    return t;
}
