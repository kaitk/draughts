// The renderer's upload of the season's photograph (docs/architecture/rendering.md,
// "Scene and glass"): the pixels background.c hands over, made into a texture through the
// renderer's C API, gfx's here (render3d::photo), goose-ngfx's in src/ngfx/photo_ngfx.c,
// so the embedded ASTC blocks reach the GPU with no copy on the program's data stack.
// goose_gfx has no compressed formats of its own and reads only PNG and BMP, from a file
// (docs/goose-findings.md).

#include <stdint.h>
#include "photo.h"
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

// Theme `kind`'s photograph as a texture, its handle's id, or 0 when it isn't built in:
// the ASTC image as stored where the GPU samples ASTC (`astc`), else (or if that upload
// fails) the JPEG decoded and scaled to `decoded` square; `upload` the renderer's.
uint32_t draughts_photo_with(int64_t kind, int64_t decoded, bool astc, uint32_t (*upload)(const draughts_pixels *)) {
    draughts_pixels p;
    if (!draughts_photo_pixels(kind, decoded, astc, &p)) return 0;
    uint32_t t = upload(&p);
    bool was_astc = p.format == DRAUGHTS_ASTC_6x6;
    draughts_photo_done(&p);
    if (t || !was_astc) return t;
    if (!draughts_photo_pixels(kind, decoded, false, &p)) return 0;
    t = upload(&p);
    draughts_photo_done(&p);
    return t;
}

// gfx's.
uint32_t draughts_photo_id(int64_t kind, int64_t decoded) {
    return draughts_photo_with(kind, decoded, photo_astc_sampled(), photo_upload);
}
