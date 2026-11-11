// The renderer's upload of the season's photograph (docs/architecture/rendering.md,
// "Scene and glass"): the pixels background.c hands over, made into a texture through the
// renderer's C API (photo_gpu.h: gfx's here, goose-ngfx's in the build scripts/ngfx.py
// makes), so the embedded ASTC blocks reach the GPU with no copy on the program's data
// stack. goose_gfx has no compressed formats of its own and reads only PNG and BMP, from
// a file (docs/goose-findings.md).

#include <stdint.h>
#include "photo.h"
#include "photo_gpu.h"

// Theme `kind`'s photograph as a texture, its handle's id, or 0 when it isn't built in:
// the ASTC image as stored where the GPU samples ASTC, else (or if that upload fails) the
// JPEG decoded and scaled to `decoded` square.
uint32_t draughts_photo_id(int64_t kind, int64_t decoded) {
    draughts_pixels p;
    if (!draughts_photo_pixels(kind, decoded, photo_astc_sampled(), &p)) return 0;
    uint32_t t = photo_upload(&p);
    bool was_astc = p.format == DRAUGHTS_ASTC_6x6;
    draughts_photo_done(&p);
    if (t || !was_astc) return t;
    if (!draughts_photo_pixels(kind, decoded, false, &p)) return 0;
    t = photo_upload(&p);
    draughts_photo_done(&p);
    return t;
}
