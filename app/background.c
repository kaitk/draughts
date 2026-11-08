// The season's photograph: the images built into the program, made into a texture
// (docs/architecture/rendering.md, "Scene and glass"). Where gfx and the GPU take ASTC,
// the compressed image is uploaded as it is stored, with nothing decoded; elsewhere the
// JPEG is decoded with stb_image and scaled down. goose_gfx has no compressed formats
// and reads only PNG and BMP, from a file (docs/goose-findings.md); its C API is called
// from here so the embedded bytes upload with no copy on the program's data stack.
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
// stb_image turns on its NEON loops (the IDCT, and the color conversion when decoding
// to four channels) only when asked; on x86 it finds SSE2 itself.
#if defined(__aarch64__) || defined(__ARM_NEON)
#define STBI_NEON
#endif
#include "stb_image.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#include "gfx_api.h"

// What patches/goose_gfx/0004-compressed-textures.patch adds to gfx: its number for
// ASTC in 6 × 6 blocks, and whether the GPU samples a format. A gfx without the patch
// (the Mac's, built into Goose) has neither, and this weak stand-in says no, so the
// JPEG is decoded there; the patched gfx's own definition takes its place.
enum { ASTC_6x6 = 26, BLOCK = 6 };
__attribute__((weak)) uint8_t gs_gfx_format_supported(int32_t format, int32_t usage) {
    (void)format;
    (void)usage;
    return 0;
}

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
#if __has_embed("../design/backgrounds/masters/autumn-01-2048-6x6.astc")
static const unsigned char autumn_astc[] = {
#embed "../design/backgrounds/masters/autumn-01-2048-6x6.astc"
    , 0 };
#else
static const unsigned char autumn_astc[] = { 0 };
#endif
#if __has_embed("../design/backgrounds/masters/winter-01-2048-6x6.astc")
static const unsigned char winter_astc[] = {
#embed "../design/backgrounds/masters/winter-01-2048-6x6.astc"
    , 0 };
#else
static const unsigned char winter_astc[] = { 0 };
#endif
#if __has_embed("../design/backgrounds/masters/spring-01-2048-6x6.astc")
static const unsigned char spring_astc[] = {
#embed "../design/backgrounds/masters/spring-01-2048-6x6.astc"
    , 0 };
#else
static const unsigned char spring_astc[] = { 0 };
#endif
#if __has_embed("../design/backgrounds/masters/summer-01-2048-6x6.astc")
static const unsigned char summer_astc[] = {
#embed "../design/backgrounds/masters/summer-01-2048-6x6.astc"
    , 0 };
#else
static const unsigned char summer_astc[] = { 0 };
#endif

// By theme: wood (autumn), stone (winter), birch (spring), sunset (summer).
static const unsigned char *const jpegs[4] = { autumn, winter, spring, summer };
static const int64_t jpeg_lengths[4] = { sizeof autumn - 1, sizeof winter - 1,
                                         sizeof spring - 1, sizeof summer - 1 };
static const unsigned char *const astcs[4] = { autumn_astc, winter_astc, spring_astc,
                                               summer_astc };
static const int64_t astc_lengths[4] = { sizeof autumn_astc - 1, sizeof winter_astc - 1,
                                         sizeof spring_astc - 1, sizeof summer_astc - 1 };

// Gives back the pages of an embedded image once it is uploaded or decoded. They are clean
// pages of the program's file (on Android mapped from the APK), read again if needed, but
// count in the process's memory while resident: 5 MB once the thumbnails read all four.
static void forget(const unsigned char *data, int64_t len) {
    uintptr_t page = (uintptr_t)sysconf(_SC_PAGESIZE);
    uintptr_t a = ((uintptr_t)data + page - 1) & ~(page - 1);
    uintptr_t b = ((uintptr_t)data + (uintptr_t)len) & ~(page - 1);
    if (b > a) madvise((void *)a, b - a, MADV_DONTNEED);
}

// A texture of `format` holding `data`, or 0.
static gs_gfx_texture upload(int32_t format, int width, int height, const unsigned char *data,
                             int64_t len) {
    gs_gfx_texture_desc d = { .kind = GS_GFX_TEXTURE_2D, .format = format,
                              .usage = GS_GFX_SAMPLED, .width = width, .height = height,
                              .depth = 1, .mips = 1, .samples = 1 };
    gs_gfx_texture t = gs_gfx_create_texture(&d);
    gs_gfx_region whole = { 0 };
    if (t.id && !gs_gfx_update_texture(t, &whole, (gs_gfx_bytes){ (uint8_t *)data, len })) {
        gs_gfx_release_texture(t);
        t.id = 0;
    }
    return t;
}

// The ASTC image's texture, or 0 if it isn't built in or the GPU doesn't take it. The
// file is astcenc's: a 16-byte header (magic, block size, then each side in 3 bytes)
// and the blocks.
static gs_gfx_texture astc(int64_t kind) {
    const unsigned char *a = astcs[kind];
    int64_t len = astc_lengths[kind];
    if (len < 16 || a[0] != 0x13 || a[1] != 0xAB || a[2] != 0xA1 || a[3] != 0x5C ||
        a[4] != BLOCK || a[5] != BLOCK || a[6] != 1 ||
        !gs_gfx_format_supported(ASTC_6x6, GS_GFX_SAMPLED)) {
        return (gs_gfx_texture){ 0 };
    }
    int w = a[7] | a[8] << 8 | a[9] << 16, h = a[10] | a[11] << 8 | a[12] << 16;
    int64_t blocks = (int64_t)((w + BLOCK - 1) / BLOCK) * ((h + BLOCK - 1) / BLOCK);
    if (w < 1 || h < 1 || len != 16 + blocks * 16) return (gs_gfx_texture){ 0 };
    gs_gfx_texture t = upload(ASTC_6x6, w, h, a + 16, len - 16);
    forget(a, len);
    return t;
}

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
// when that is its side), or 0. It decodes to RGBA, which stb converts with NEON.
static gs_gfx_texture jpeg(int64_t kind, int size) {
    if (jpeg_lengths[kind] == 0) return (gs_gfx_texture){ 0 };
    int w = 0, h = 0, n = 0;
    unsigned char *px = stbi_load_from_memory(jpegs[kind], (int)jpeg_lengths[kind], &w, &h, &n, 4);
    forget(jpegs[kind], jpeg_lengths[kind]);
    if (!px) return (gs_gfx_texture){ 0 };
    int side = w < h ? w : h;
    gs_gfx_texture t = { 0 };
    if (side == size && w == h) {
        t = upload(GS_GFX_RGBA8, size, size, px, (int64_t)size * size * 4);
    } else if (side > size) {           // it only scales down
        unsigned char *out = malloc((size_t)size * size * 4);
        if (out) {
            shrink(px, w, (w - side) / 2, (h - side) / 2, side, size, out);
            t = upload(GS_GFX_RGBA8, size, size, out, (int64_t)size * size * 4);
            free(out);
        }
    }
    stbi_image_free(px);
    return t;
}

// Theme `kind`'s photograph as a texture, or 0 when it isn't built in: the ASTC image as
// stored where the GPU samples ASTC, else the JPEG's middle square decoded and scaled
// to `decoded` × `decoded` (at most 4096).
gs_gfx_texture draughts_photo(int64_t kind, int64_t decoded) {
    if (kind < 0 || kind > 3 || decoded < 1 || decoded > 4096) return (gs_gfx_texture){ 0 };
    gs_gfx_texture t = astc(kind);
    return t.id ? t : jpeg(kind, (int)decoded);
}
