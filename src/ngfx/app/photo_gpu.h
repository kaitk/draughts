// photo.c's upload in the build that holds both renderers (scripts/ngfx.py lays this over
// src/app/photo_gpu.h): gfx's (photo_gfx.h, src/app/photo_gpu.h copied) or goose-ngfx's
// (photo_ngfx.h), each under its own names, as draughts_photo_ngfx says, set once at
// start by host_gpu::open.
#define photo_astc_sampled photo_gfx_astc_sampled
#define photo_upload photo_gfx_upload
#include "photo_gfx.h"
#undef photo_astc_sampled
#undef photo_upload
#define photo_astc_sampled photo_ngfx_astc_sampled
#define photo_upload photo_ngfx_upload
#include "photo_ngfx.h"
#undef photo_astc_sampled
#undef photo_upload

static uint8_t photo_ngfx_on;
void draughts_photo_ngfx(uint8_t on) { photo_ngfx_on = on; }

// Whether the GPU samples ASTC in 6 × 6 blocks.
static bool photo_astc_sampled(void) { return photo_ngfx_on ? photo_ngfx_astc_sampled() : photo_gfx_astc_sampled(); }

// A texture holding the pixels, its handle's id, or 0.
static uint32_t photo_upload(const draughts_pixels *p) { return photo_ngfx_on ? photo_ngfx_upload(p) : photo_gfx_upload(p); }
