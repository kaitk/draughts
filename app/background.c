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
typedef struct { uint8_t *data; int64_t len; } draughts_bytes;

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

// The last image decoded, kept for the next size until draughts_background_done.
static unsigned char *decoded;
static int decoded_w, decoded_h;
static int64_t decoded_kind = -1;

// Frees the decoded image.
void draughts_background_done(void) {
    stbi_image_free(decoded);
    decoded = 0;
    decoded_kind = -1;
}

// Decodes theme `kind`'s photograph (once for any number of sizes), crops the middle
// of its middle square to the shape of `width` × `height`, and scales that down to
// width × height RGBA by averaging, into `out` (width * height * 4 bytes). False when
// the image isn't built in or doesn't decode.
_Bool draughts_background_crop(int64_t kind, int64_t width, int64_t height, draughts_bytes out) {
    if (kind < 0 || kind > 3 || lengths[kind] == 0 || width <= 0 || height <= 0 || height > width ||
        out.len < width * height * 4) {
        return 0;
    }
    if (decoded_kind != kind) {
        draughts_background_done();
        int n = 0;
        decoded = stbi_load_from_memory(images[kind], (int)lengths[kind], &decoded_w, &decoded_h, &n, 3);
        if (!decoded) return 0;
        decoded_kind = kind;
    }
    int w = decoded_w, h = decoded_h;
    const unsigned char *px = decoded;
    int side = w < h ? w : h;
    int crop = (int)(side * height / width);
    int x0 = (w - side) / 2, y0 = (h - crop) / 2;
    for (int64_t y = 0; y < height; y++) {
        int ya = y0 + (int)(y * crop / height), yb = y0 + (int)((y + 1) * crop / height);
        for (int64_t x = 0; x < width; x++) {
            int xa = x0 + (int)(x * side / width), xb = x0 + (int)((x + 1) * side / width);
            uint32_t r = 0, g = 0, b = 0, count = 0;
            for (int sy = ya; sy < yb; sy++) {
                const unsigned char *p = px + ((size_t)sy * w + xa) * 3;
                for (int sx = xa; sx < xb; sx++, p += 3) {
                    r += p[0]; g += p[1]; b += p[2]; count++;
                }
            }
            uint8_t *o = out.data + (y * width + x) * 4;
            o[0] = (uint8_t)((r + count / 2) / count);
            o[1] = (uint8_t)((g + count / 2) / count);
            o[2] = (uint8_t)((b + count / 2) / count);
            o[3] = 255;
        }
    }
    return 1;
}

// The middle square of theme `kind`'s photograph, `size` × `size`; as above.
_Bool draughts_background(int64_t kind, int64_t size, draughts_bytes out) {
    return draughts_background_crop(kind, size, size, out);
}
