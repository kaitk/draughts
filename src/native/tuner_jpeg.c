// The light tuner's JPEG reader, for the downloaded woods it compares with ours (task 122,
// tools/wood_pictures.goose): stb_image's own copy, JPEG alone and static, so it builds
// where background.c's isn't compiled in (the ASTC-only builds).

#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_STATIC
#define STBI_ONLY_JPEG
#define STBI_NO_STDIO
#define STBI_NO_LINEAR
#define STBI_NO_HDR
#define STBI_FAILURE_USERMSG
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-function"
#include "stb_image.h"
#pragma clang diagnostic pop

typedef struct { uint8_t *data; int64_t len; } bytes;

// The JPEG in `file` into `out`, w × h RGBA8, or false when it doesn't decode or isn't that
// size.
bool tuner_jpeg(bytes file, bytes out, int64_t w, int64_t h) {
    if (file.len <= 0 || file.len > INT32_MAX || out.len < 4 * w * h) return false;
    int iw = 0, ih = 0, n = 0;
    unsigned char *px = stbi_load_from_memory(file.data, (int)file.len, &iw, &ih, &n, 4);
    if (!px) return false;
    bool ok = iw == w && ih == h;
    if (ok) memcpy(out.data, px, (size_t)(4 * w * h));
    stbi_image_free(px);
    return ok;
}
