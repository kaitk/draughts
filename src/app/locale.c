// The system's preferred locales, through SDL, for the string table to pick a language
// from (strings/strings.goose). SDL reads them from macOS's settings and, on Android,
// from the Java side, and on iOS from NSLocale. On Android and iOS the program links SDL
// and calls it directly (platform.h);
// on the Mac the program's C is linked on its own and SDL is in the goose binary, so a
// direct call wouldn't link, and SDL's two functions are looked up when called. And the
// local date, for the daily puzzles (draughts_local_day, at the end).

#include "platform.h"
#include <stdint.h>

typedef struct { const char *language; const char *country; } SDL_Locale;

#if DRAUGHTS_SDL_LINKED
extern SDL_Locale **SDL_GetPreferredLocales(int *count);
extern void SDL_free(void *mem);
#else
#include <dlfcn.h>
#endif

typedef struct { uint8_t *data; int64_t len; } draughts_text;

// Writes the locales into out in order of preference, as "et-EE,en-US", and returns how
// many bytes; 0 when SDL knows none.
int64_t draughts_locales(draughts_text out) {
#if DRAUGHTS_SDL_LINKED
    SDL_Locale **(*preferred)(int *) = SDL_GetPreferredLocales;
    void (*sdl_free)(void *) = SDL_free;
#else
    SDL_Locale **(*preferred)(int *) = (SDL_Locale **(*)(int *))dlsym(RTLD_DEFAULT, "SDL_GetPreferredLocales");
    void (*sdl_free)(void *) = (void (*)(void *))dlsym(RTLD_DEFAULT, "SDL_free");
    if (!preferred || !sdl_free) return 0;
#endif
    int count = 0;
    SDL_Locale **locales = preferred(&count);
    if (!locales) return 0;
    int64_t n = 0;
    for (int i = 0; i < count && locales[i]; i++) {
        const char *parts[2] = { locales[i]->language, locales[i]->country };
        if (n > 0 && n < out.len) out.data[n++] = ',';
        for (int p = 0; p < 2; p++) {
            const char *s = parts[p];
            if (!s) continue;
            if (p == 1 && n < out.len) out.data[n++] = '-';
            while (*s && n < out.len) out.data[n++] = (uint8_t)*s++;
        }
    }
    sdl_free(locales);
    return n;
}

// The local date as days since the epoch (1970-01-01 is 0), for the daily puzzles
// (task 088): the time now moved by the zone's offset, daylight saving's too, over a
// day's seconds. Windows' struct tm has no tm_gmtoff: there the offset is the local
// time's fields read back as UTC, less now.
#include <time.h>

int64_t draughts_local_day(void) {
    time_t now = time(NULL);
    struct tm local;
#if defined(_WIN32)
    localtime_s(&local, &now);
    long long offset = (long long)_mkgmtime(&local) - (long long)now;
#else
    localtime_r(&now, &local);
    long long offset = (long long)local.tm_gmtoff;
#endif
    long long s = (long long)now + offset;
    return (int64_t)((s >= 0 ? s : s - 86399) / 86400);
}
