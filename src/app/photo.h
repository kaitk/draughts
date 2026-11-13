// The season's photograph as pixels, between its decoder (background.c), which knows no
// graphics API, and the renderer's upload (photo.c).
#ifndef DRAUGHTS_PHOTO_H
#define DRAUGHTS_PHOTO_H

#include <stdbool.h>
#include <stdint.h>

enum { DRAUGHTS_RGBA8 = 0, DRAUGHTS_ASTC_6x6 = 1 };

// `len` bytes at `data`, `width` × `height` texels of `format`: ASTC's blocks pointing into
// the embedded image (`embedded`, whose pages are given back once it is uploaded), or the
// decoded JPEG's RGBA8 in a buffer of its own (`owned`).
typedef struct {
    const unsigned char *data;
    int64_t len;
    int width, height, format;
    const unsigned char *embedded;
    int64_t embedded_len;
    unsigned char *owned;
} draughts_pixels;

// Theme `kind`'s photograph into `out`, or false when it isn't built in: the ASTC image as
// stored where the GPU samples ASTC (`astc_sampled`), else the JPEG's middle square
// decoded and scaled to `decoded` × `decoded` (at most 4096). Kind 4 is settings' board
// pictures' atlas, decoded whole.
bool draughts_photo_pixels(int64_t kind, int64_t decoded, bool astc_sampled, draughts_pixels *out);

// Gives back what the pixels hold, once they are uploaded.
void draughts_photo_done(draughts_pixels *p);

#endif
