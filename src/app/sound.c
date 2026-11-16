// The audio session iOS gives the app's sounds (docs/architecture/sound.md): "ambient",
// set before goose_gfx's audio opens SDL's audio, so the silent switch mutes them and the
// player's own music keeps playing under them. Elsewhere it does nothing: Android plays
// them on the media stream, which its volume keys govern, and a desktop has no session.

#include "platform.h"
#include <stdbool.h>

#if DRAUGHTS_IOS
extern bool SDL_SetHint(const char *name, const char *value);
#endif

void draughts_sound_session(void) {
#if DRAUGHTS_IOS
    SDL_SetHint("SDL_AUDIO_CATEGORY", "ambient");
#endif
}
