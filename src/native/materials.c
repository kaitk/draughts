// The room's material masks, built into the program and decoded for the renderer's upload
// (render3d::room_surfaces), one channel (design/materials/): the library's wallpaper and
// the plaster's tone, 1024² each, the curtains' lace. And RGBA: the view out of its
// windows, the far band of trees and the oak (render3d::put_outside); the books' atlas
// (render3d::put_books).
// stb_image here decodes PNG alone and is static, apart from background.c's JPEG one.

#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_STATIC
#define STBI_ONLY_PNG
#define STBI_NO_STDIO
#define STBI_NO_LINEAR
#define STBI_NO_HDR
#define STBI_FAILURE_USERMSG
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-function"
#include "stb_image.h"
#pragma clang diagnostic pop

#pragma clang diagnostic ignored "-Wc23-extensions"
#if __has_embed("../../design/materials/wallpaper_mask.png")
static const unsigned char wallpaper[] = {
#embed "../../design/materials/wallpaper_mask.png"
    , 0 };
#else
static const unsigned char wallpaper[] = { 0 };
#endif
#if __has_embed("../../design/materials/plaster_tone.png")
static const unsigned char plaster[] = {
#embed "../../design/materials/plaster_tone.png"
    , 0 };
#else
static const unsigned char plaster[] = { 0 };
#endif
// The curtains' lace (tools/materials/lace_panel.py): way f2, and ways f and d while the
// choice is open, the field's tile over the hem's strip, 1024 x 1408 each.
#if __has_embed("../../design/materials/lace_f2.png")
static const unsigned char lace_f2[] = {
#embed "../../design/materials/lace_f2.png"
    , 0 };
#else
static const unsigned char lace_f2[] = { 0 };
#endif
#if __has_embed("../../design/materials/lace_f.png")
static const unsigned char lace_f[] = {
#embed "../../design/materials/lace_f.png"
    , 0 };
#else
static const unsigned char lace_f[] = { 0 };
#endif
#if __has_embed("../../design/materials/lace_d.png")
static const unsigned char lace_d[] = {
#embed "../../design/materials/lace_d.png"
    , 0 };
#else
static const unsigned char lace_d[] = { 0 };
#endif

#if __has_embed("../../design/materials/outside_band.png")
static const unsigned char band[] = {
#embed "../../design/materials/outside_band.png"
    , 0 };
#else
static const unsigned char band[] = { 0 };
#endif
#if __has_embed("../../design/materials/outside_oak.png")
static const unsigned char oak[] = {
#embed "../../design/materials/outside_oak.png"
    , 0 };
#else
static const unsigned char oak[] = { 0 };
#endif

#if __has_embed("../../design/materials/books_atlas.png")
static const unsigned char book_atlas[] = {
#embed "../../design/materials/books_atlas.png"
    , 0 };
#else
static const unsigned char book_atlas[] = { 0 };
#endif

typedef struct { uint8_t *data; int64_t len; } bytes;

static bool decode_gray(const unsigned char *png, size_t len, bytes out, int64_t w, int64_t h) {
    if (len < 2 || out.len != w * h) return false;
    int pw = 0, ph = 0, n = 0;
    unsigned char *px = stbi_load_from_memory(png, (int)(len - 1), &pw, &ph, &n, 1);
    if (!px) return false;
    bool ok = pw == w && ph == h;
    if (ok) memcpy(out.data, px, (size_t)out.len);
    stbi_image_free(px);
    return ok;
}

// Mask `which` (0 the wallpaper, 1 the plaster's tone) into `out`, side × side bytes, or
// false when it isn't built in or isn't that size.
bool draughts_material_mask(int64_t which, bytes out, int64_t side) {
    if (which == 1) return decode_gray(plaster, sizeof plaster, out, side, side);
    return decode_gray(wallpaper, sizeof wallpaper, out, side, side);
}

// The curtains' lace of way `way` (0 f2, 1 f, 2 d) into `out`, w × h bytes, or false when
// it isn't built in or isn't that size.
bool draughts_lace_mask(int64_t way, bytes out, int64_t w, int64_t h) {
    if (way == 1) return decode_gray(lace_f, sizeof lace_f, out, w, h);
    if (way == 2) return decode_gray(lace_d, sizeof lace_d, out, w, h);
    return decode_gray(lace_f2, sizeof lace_f2, out, w, h);
}

static bool decode_rgba(const unsigned char *png, size_t len, bytes out, int64_t w, int64_t h) {
    if (len < 2 || out.len != w * h * 4) return false;
    int pw = 0, ph = 0, n = 0;
    unsigned char *px = stbi_load_from_memory(png, (int)(len - 1), &pw, &ph, &n, 4);
    if (!px) return false;
    bool ok = pw == w && ph == h;
    if (ok) memcpy(out.data, px, (size_t)out.len);
    stbi_image_free(px);
    return ok;
}

// The books' atlas into `out`, w × h RGBA8 as stored (a mask: tone, gilt, label, wear), or
// false when it isn't built in or isn't that size.
bool draughts_book_atlas(bytes out, int64_t w, int64_t h) {
    return decode_rgba(book_atlas, sizeof book_atlas, out, w, h);
}

// Picture `which` of the view out (0 the far band, 1 the oak) into `out`, w × h RGBA8 as
// stored (sRGB, premultiplied in linear light), or false when it isn't built in or isn't
// that size.
bool draughts_outside_picture(int64_t which, bytes out, int64_t w, int64_t h) {
    if (which == 1) return decode_rgba(oak, sizeof oak, out, w, h);
    return decode_rgba(band, sizeof band, out, w, h);
}
