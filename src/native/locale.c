// The system's preferred locales through SDL, for the string table to pick a language
// from (strings/strings.goose), and the local date for the daily puzzles. Where SDL isn't
// linked into the program its functions are looked up (platform.h).

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

// The local zone's offset from UTC now in seconds, daylight saving's too. Windows'
// struct tm has no tm_gmtoff: there the offset is the local time's fields read back as
// UTC, less now.
#include <time.h>

int64_t draughts_utc_offset(void) {
    time_t now = time(NULL);
    struct tm local;
#if defined(_WIN32)
    localtime_s(&local, &now);
    return (int64_t)((long long)_mkgmtime(&local) - (long long)now);
#else
    localtime_r(&now, &local);
    return (int64_t)local.tm_gmtoff;
#endif
}

// The local date as days since the epoch (1970-01-01 is 0): the time now moved by the
// zone's offset, over a day's seconds.
int64_t draughts_local_day(void) {
    long long s = (long long)time(NULL) + (long long)draughts_utc_offset();
    return (int64_t)((s >= 0 ? s : s - 86399) / 86400);
}
