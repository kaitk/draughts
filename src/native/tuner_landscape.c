// The light tuner held in landscape on Android, as its benches' views are framed (task 115);
// the app itself turns with the device. Before gfx opens the window, which reads the hint.
// Nothing elsewhere.
#include <stdbool.h>

#if defined(__ANDROID__)
extern bool SDL_SetHint(const char *name, const char *value);
#endif

void tuner_landscape(void) {
#if defined(__ANDROID__)
    SDL_SetHint("SDL_ORIENTATIONS", "LandscapeLeft LandscapeRight");
#endif
}
