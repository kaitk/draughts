// The room's material masks, built into the program and decoded for the renderer's upload
// (render3d::room_surfaces), one channel, 1024² each (design/materials/): the library's
// wallpaper, the plaster's tone, the lace's coverage.
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
#if __has_embed("../../design/materials/lace_mask.png")
static const unsigned char lace[] = {
#embed "../../design/materials/lace_mask.png"
    , 0 };
#else
static const unsigned char lace[] = { 0 };
#endif

typedef struct { uint8_t *data; int64_t len; } bytes;

// Mask `which` (0 the wallpaper, 1 the plaster's tone, 2 the lace) into `out`, side × side
// bytes, or false when it isn't built in or isn't that size.
bool draughts_material_mask(int64_t which, bytes out, int64_t side) {
    const unsigned char *png = which == 1 ? plaster : which == 2 ? lace : wallpaper;
    size_t len = which == 1 ? sizeof plaster : which == 2 ? sizeof lace : sizeof wallpaper;
    if (len < 2 || out.len != side * side) return false;
    int w = 0, h = 0, n = 0;
    unsigned char *px = stbi_load_from_memory(png, (int)(len - 1), &w, &h, &n, 1);
    if (!px) return false;
    bool ok = w == side && h == side;
    if (ok) memcpy(out.data, px, (size_t)out.len);
    stbi_image_free(px);
    return ok;
}
