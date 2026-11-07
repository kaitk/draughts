// The season's photograph: the JPEGs built into the program, and stb_image to decode
// one (docs/architecture/rendering.md, "Scene and glass"). goose_gfx reads only PNG and
// BMP, from a file (docs/goose-findings.md).
//
// The images are not in git yet, so each is embedded only if its file is there: a fresh
// checkout builds, with no photograph, and the app shows the page color. Until they are
// checked in, the build takes the local masters (design/backgrounds/README.md).

#define STB_IMAGE_IMPLEMENTATION
#define STBI_ONLY_JPEG
#define STBI_NO_STDIO
#define STBI_NO_LINEAR
#define STBI_NO_HDR
#define STBI_FAILURE_USERMSG
#include "stb_image.h"

#include <stdint.h>
#include <string.h>

// A Goose slice of bytes, as an extern fn passes it.
typedef struct { uint8_t *data; int64_t len; } kabe_bytes;

// Each image's bytes and then one 0, so the array is never empty. #embed is C23, which
// clang takes in C11 too.
#pragma clang diagnostic ignored "-Wc23-extensions"
#if __has_embed("../design/backgrounds/masters/autumn-01-2048.jpg")
static const unsigned char autumn[] = {
#embed "../design/backgrounds/masters/autumn-01-2048.jpg"
    , 0 };
#else
static const unsigned char autumn[] = { 0 };
#endif
#if __has_embed("../design/backgrounds/masters/winter-01-2048.jpg")
static const unsigned char winter[] = {
#embed "../design/backgrounds/masters/winter-01-2048.jpg"
    , 0 };
#else
static const unsigned char winter[] = { 0 };
#endif
#if __has_embed("../design/backgrounds/masters/spring-01-2048.jpg")
static const unsigned char spring[] = {
#embed "../design/backgrounds/masters/spring-01-2048.jpg"
    , 0 };
#else
static const unsigned char spring[] = { 0 };
#endif
#if __has_embed("../design/backgrounds/masters/summer-01-2048.jpg")
static const unsigned char summer[] = {
#embed "../design/backgrounds/masters/summer-01-2048.jpg"
    , 0 };
#else
static const unsigned char summer[] = { 0 };
#endif

// By theme: wood (autumn), stone (winter), birch (spring), sea (summer).
static const unsigned char *const images[4] = { autumn, winter, spring, summer };
static const int64_t lengths[4] = { sizeof autumn - 1, sizeof winter - 1, sizeof spring - 1,
                                    sizeof summer - 1 };

// Decodes theme `kind`'s photograph, crops the middle square, and scales it down to
// `size` × `size` RGBA by averaging, into `out` (size * size * 4 bytes). False when the
// image isn't built in or doesn't decode.
_Bool kabe_background(int64_t kind, int64_t size, kabe_bytes out) {
    if (kind < 0 || kind > 3 || lengths[kind] == 0 || size <= 0 || out.len < size * size * 4) {
        return 0;
    }
    int w = 0, h = 0, n = 0;
    unsigned char *px = stbi_load_from_memory(images[kind], (int)lengths[kind], &w, &h, &n, 3);
    if (!px) return 0;
    int side = w < h ? w : h;
    int x0 = (w - side) / 2, y0 = (h - side) / 2;
    for (int64_t y = 0; y < size; y++) {
        int ya = y0 + (int)(y * side / size), yb = y0 + (int)((y + 1) * side / size);
        for (int64_t x = 0; x < size; x++) {
            int xa = x0 + (int)(x * side / size), xb = x0 + (int)((x + 1) * side / size);
            uint32_t r = 0, g = 0, b = 0, count = 0;
            for (int sy = ya; sy < yb; sy++) {
                const unsigned char *p = px + ((size_t)sy * w + xa) * 3;
                for (int sx = xa; sx < xb; sx++, p += 3) {
                    r += p[0]; g += p[1]; b += p[2]; count++;
                }
            }
            uint8_t *o = out.data + (y * size + x) * 4;
            o[0] = (uint8_t)((r + count / 2) / count);
            o[1] = (uint8_t)((g + count / 2) / count);
            o[2] = (uint8_t)((b + count / 2) / count);
            o[3] = 255;
        }
    }
    stbi_image_free(px);
    return 1;
}
