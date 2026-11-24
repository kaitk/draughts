// The light tuner held in landscape on Android and iOS, as its benches' views are framed
// (task 115); the app itself turns with the device. Before gfx opens the window, which
// reads the hint. On iOS the tuner's Info.plist allows landscape alone too
// (scripts/ios.py, LANDSCAPE), so it starts that way. Nothing elsewhere.
#include "platform.h"
#include <stdbool.h>

#if defined(__ANDROID__) || DRAUGHTS_IOS
extern bool SDL_SetHint(const char *name, const char *value);
#endif

void tuner_landscape(void) {
#if defined(__ANDROID__) || DRAUGHTS_IOS
    SDL_SetHint("SDL_ORIENTATIONS", "LandscapeLeft LandscapeRight");
#endif
}
