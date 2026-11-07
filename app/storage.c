// The app's own storage folder, through SDL's SDL_GetPrefPath: on Android the app's
// internal files folder, on the Mac ~/Library/Application Support/kaitk/draughts/. The
// settings and the saved game are kept there. As in locale.c, on the Mac SDL is in the
// goose binary and is looked up when called; on Android the program links libSDL3.so.

#include <stdint.h>
#include <string.h>

#if defined(__ANDROID__)
extern char *SDL_GetPrefPath(const char *org, const char *app);
extern void SDL_free(void *mem);
#else
#include <dlfcn.h>
#endif

typedef struct { uint8_t *data; int64_t len; } draughts_path;

// Writes the folder's path, ending in a separator, into out and returns how many bytes;
// 0 when SDL can't make one.
int64_t draughts_storage(draughts_path out) {
#if defined(__ANDROID__)
    char *(*pref_path)(const char *, const char *) = SDL_GetPrefPath;
    void (*sdl_free)(void *) = SDL_free;
#else
    char *(*pref_path)(const char *, const char *) =
        (char *(*)(const char *, const char *))dlsym(RTLD_DEFAULT, "SDL_GetPrefPath");
    void (*sdl_free)(void *) = (void (*)(void *))dlsym(RTLD_DEFAULT, "SDL_free");
    if (!pref_path || !sdl_free) return 0;
#endif
    char *path = pref_path("kaitk", "draughts");
    if (!path) return 0;
    int64_t n = (int64_t)strlen(path);
    if (n > out.len) n = 0;
    memcpy(out.data, path, (size_t)n);
    sdl_free(path);
    return n;
}
