// The season's photograph: the images built into the program, as pixels for the renderer
// (docs/architecture/rendering.md, "Scene and glass"), which photo.c uploads. Where the
// renderer takes ASTC, the compressed image is handed over as it is stored, with nothing
// decoded or copied; elsewhere the JPEG is decoded with stb_image and scaled down. No
// graphics API here: a renderer brings its own upload (photo.h).
//
// Android embeds only the ASTC files and has no JPEG decoder: every Vulkan GPU the app
// targets samples ASTC LDR, and the JPEGs would add 2.2 MB to the APK. A GPU without it
// gets no photograph, the page color, as a checkout without the images does. An iPhone
// or iPad embeds only the ASTC files for the same reasons (every Apple GPU since the A8
// samples ASTC); the iOS simulator keeps the JPEGs, as its GPU may not.
//
// The JPEG and ASTC masters are in git (design/backgrounds/README.md). Each is still
// embedded only if its file is there, so a checkout without them builds, with no
// photograph, and the app shows the page color.

#include "platform.h"
#if defined(__ANDROID__) || (DRAUGHTS_IOS && !TARGET_OS_SIMULATOR)
#define ASTC_ONLY 1
#else
#define ASTC_ONLY 0
#endif

#if !ASTC_ONLY
#define STB_IMAGE_IMPLEMENTATION
#define STBI_ONLY_JPEG
#define STBI_NO_STDIO
#define STBI_NO_LINEAR
#define STBI_NO_HDR
#define STBI_FAILURE_USERMSG
// stb_image turns on its NEON loops (the IDCT, and the color conversion when decoding
// to four channels) only when asked; on x86 it finds SSE2 itself.
#if defined(__aarch64__) || defined(__ARM_NEON)
#define STBI_NEON
#endif
#include "stb_image.h"
#endif

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#if !defined(_WIN32)
#include <sys/mman.h>
#include <unistd.h>
#endif

#include "photo.h"

enum { BLOCK = 6 };     // the ASTC blocks' side

// Each image's bytes and then one 0, so the array is never empty. #embed is C23, which
// clang takes in C11 too.
#pragma clang diagnostic ignored "-Wc23-extensions"
#if !ASTC_ONLY
#if __has_embed("../../design/backgrounds/masters/autumn-01-2048.jpg")
static const unsigned char autumn[] = {
#embed "../../design/backgrounds/masters/autumn-01-2048.jpg"
    , 0 };
#else
static const unsigned char autumn[] = { 0 };
#endif
#if __has_embed("../../design/backgrounds/masters/winter-01-2048.jpg")
static const unsigned char winter[] = {
#embed "../../design/backgrounds/masters/winter-01-2048.jpg"
    , 0 };
#else
static const unsigned char winter[] = { 0 };
#endif
#if __has_embed("../../design/backgrounds/masters/spring-01-2048.jpg")
static const unsigned char spring[] = {
#embed "../../design/backgrounds/masters/spring-01-2048.jpg"
    , 0 };
#else
static const unsigned char spring[] = { 0 };
#endif
#if __has_embed("../../design/backgrounds/masters/summer-01-2048.jpg")
static const unsigned char summer[] = {
#embed "../../design/backgrounds/masters/summer-01-2048.jpg"
    , 0 };
#else
static const unsigned char summer[] = { 0 };
#endif
#endif
#if __has_embed("../../design/backgrounds/masters/autumn-01-2048-6x6.astc")
static const unsigned char autumn_astc[] = {
#embed "../../design/backgrounds/masters/autumn-01-2048-6x6.astc"
    , 0 };
#else
static const unsigned char autumn_astc[] = { 0 };
#endif
#if __has_embed("../../design/backgrounds/masters/winter-01-2048-6x6.astc")
static const unsigned char winter_astc[] = {
#embed "../../design/backgrounds/masters/winter-01-2048-6x6.astc"
    , 0 };
#else
static const unsigned char winter_astc[] = { 0 };
#endif
#if __has_embed("../../design/backgrounds/masters/spring-01-2048-6x6.astc")
static const unsigned char spring_astc[] = {
#embed "../../design/backgrounds/masters/spring-01-2048-6x6.astc"
    , 0 };
#else
static const unsigned char spring_astc[] = { 0 };
#endif
#if __has_embed("../../design/backgrounds/masters/summer-01-2048-6x6.astc")
static const unsigned char summer_astc[] = {
#embed "../../design/backgrounds/masters/summer-01-2048-6x6.astc"
    , 0 };
#else
static const unsigned char summer_astc[] = { 0 };
#endif

// By theme: wood (autumn), stone (winter), birch (spring), sunset (summer).
#if !ASTC_ONLY
static const unsigned char *const jpegs[4] = { autumn, winter, spring, summer };
static const int64_t jpeg_lengths[4] = { sizeof autumn - 1, sizeof winter - 1,
                                         sizeof spring - 1, sizeof summer - 1 };
#endif
static const unsigned char *const astcs[4] = { autumn_astc, winter_astc, spring_astc,
                                               summer_astc };
static const int64_t astc_lengths[4] = { sizeof autumn_astc - 1, sizeof winter_astc - 1,
                                         sizeof spring_astc - 1, sizeof summer_astc - 1 };

// Gives back the pages of an embedded image once it is uploaded or decoded. They are clean
// pages of the program's file (on Android mapped from the APK), read again if needed, but
// count in the process's memory while resident: 5 MB once the thumbnails read all four.
// Windows has no madvise for an image's pages, and keeps them.
static void forget(const unsigned char *data, int64_t len) {
#if defined(_WIN32)
    (void)data;
    (void)len;
#else
    uintptr_t page = (uintptr_t)sysconf(_SC_PAGESIZE);
    uintptr_t a = ((uintptr_t)data + page - 1) & ~(page - 1);
    uintptr_t b = ((uintptr_t)data + (uintptr_t)len) & ~(page - 1);
    if (b > a) madvise((void *)a, b - a, MADV_DONTNEED);
#endif
}

// The ASTC image's blocks, as they are embedded, or false if it isn't built in. The file
// is astcenc's: a 16-byte header (magic, block size, then each side in 3 bytes) and the
// blocks.
static bool astc(int64_t kind, draughts_pixels *out) {
    const unsigned char *a = astcs[kind];
    int64_t len = astc_lengths[kind];
    if (len < 16 || a[0] != 0x13 || a[1] != 0xAB || a[2] != 0xA1 || a[3] != 0x5C ||
        a[4] != BLOCK || a[5] != BLOCK || a[6] != 1) {
        return false;
    }
    int w = a[7] | a[8] << 8 | a[9] << 16, h = a[10] | a[11] << 8 | a[12] << 16;
    int64_t blocks = (int64_t)((w + BLOCK - 1) / BLOCK) * ((h + BLOCK - 1) / BLOCK);
    if (w < 1 || h < 1 || len != 16 + blocks * 16) return false;
    *out = (draughts_pixels){ .data = a + 16, .len = len - 16, .width = w, .height = h,
                              .format = DRAUGHTS_ASTC_6x6, .embedded = a, .embedded_len = len };
    return true;
}

#if !ASTC_ONLY
// The middle square of an RGBA image, `side` × `side` from (x0, y0), scaled down to
// size × size by averaging into `out`. A box's sum is divided by one reciprocal multiply.
static void shrink(const unsigned char *px, int w, int x0, int y0, int side, int size,
                   unsigned char *out) {
    static int xs[4097];        // each column's first source column, and the end
    for (int x = 0; x <= size; x++) xs[x] = x0 + (int)((int64_t)x * side / size);
    for (int y = 0; y < size; y++) {
        int ya = y0 + (int)((int64_t)y * side / size);
        int yb = y0 + (int)((int64_t)(y + 1) * side / size);
        for (int x = 0; x < size; x++) {
            int xa = xs[x], xb = xs[x + 1];
            uint32_t r = 0, g = 0, b = 0;
            for (int sy = ya; sy < yb; sy++) {
                const unsigned char *p = px + ((size_t)sy * w + xa) * 4;
                for (int sx = xa; sx < xb; sx++, p += 4) {
                    r += p[0]; g += p[1]; b += p[2];
                }
            }
            uint32_t count = (uint32_t)((yb - ya) * (xb - xa));
            uint32_t inv = (65536 + count / 2) / count;
            unsigned char *o = out + ((size_t)y * size + x) * 4;
            o[0] = (unsigned char)((r * inv + 32768) >> 16);
            o[1] = (unsigned char)((g * inv + 32768) >> 16);
            o[2] = (unsigned char)((b * inv + 32768) >> 16);
            o[3] = 255;
        }
    }
}

// The JPEG's middle square, decoded and scaled down to `size` × `size` RGBA8 (as it is
// when that is its side), or false. It decodes to RGBA, which stb converts with NEON. The
// pixels are stb's own, or the scaled copy's, given back by draughts_photo_done.
static bool jpeg(int64_t kind, int size, draughts_pixels *out) {
    if (jpeg_lengths[kind] == 0) return false;
    int w = 0, h = 0, n = 0;
    unsigned char *px = stbi_load_from_memory(jpegs[kind], (int)jpeg_lengths[kind], &w, &h, &n, 4);
    forget(jpegs[kind], jpeg_lengths[kind]);
    if (!px) return false;
    int side = w < h ? w : h;
    unsigned char *owned = 0;
    if (side == size && w == h) {
        owned = px;
    } else if (side > size) {           // it only scales down
        owned = malloc((size_t)size * size * 4);
        if (owned) shrink(px, w, (w - side) / 2, (h - side) / 2, side, size, owned);
        stbi_image_free(px);
    } else {
        stbi_image_free(px);
    }
    if (!owned) return false;
    *out = (draughts_pixels){ .data = owned, .len = (int64_t)size * size * 4, .width = size,
                              .height = size, .format = DRAUGHTS_RGBA8, .owned = owned };
    return true;
}
#else
static bool jpeg(int64_t kind, int size, draughts_pixels *out) {
    (void)kind;
    (void)size;
    (void)out;
    return false;
}
#endif

bool draughts_photo_pixels(int64_t kind, int64_t decoded, bool astc_sampled, draughts_pixels *out) {
    *out = (draughts_pixels){ 0 };
    if (kind < 0 || kind > 3 || decoded < 1 || decoded > 4096) return false;
    if (astc_sampled && astc(kind, out)) return true;
    return jpeg(kind, (int)decoded, out);
}

void draughts_photo_done(draughts_pixels *p) {
    if (p->embedded) forget(p->embedded, p->embedded_len);
    free(p->owned);     // stb's buffer is malloc's too (STBI_FREE)
    *p = (draughts_pixels){ 0 };
}
