// The system's preferred locales, through SDL, for the string table to pick a language
// from (strings/strings.goose). SDL reads them from macOS's settings and, on Android,
// from the Java side. SDL's two functions are looked up when called: on the Mac the
// program's C is linked on its own and SDL is in the goose binary, so a direct call
// wouldn't link; on Android they are in libSDL3.so.

#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdint.h>

typedef struct { const char *language; const char *country; } SDL_Locale;

typedef struct { uint8_t *data; int64_t len; } draughts_text;

// Writes the locales into out in order of preference, as "et-EE,en-US", and returns how
// many bytes; 0 when SDL knows none.
int64_t draughts_locales(draughts_text out) {
    SDL_Locale **(*preferred)(int *) = (SDL_Locale **(*)(int *))dlsym(RTLD_DEFAULT, "SDL_GetPreferredLocales");
    void (*sdl_free)(void *) = (void (*)(void *))dlsym(RTLD_DEFAULT, "SDL_free");
    if (!preferred || !sdl_free) return 0;
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
