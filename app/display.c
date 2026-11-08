// The window's safe area and its display's scale, through SDL, for the layout
// (gui::insets, gui::scale_of; docs/architecture/rendering.md, "Screen sizes"). goose_gfx
// has neither (docs/goose-findings.md). On Android the program links libSDL3.so and calls
// it directly; on the Mac SDL is in the goose binary, so its functions are looked up once.
//
// The safe area: on Android SDL fills it from the window's insets, the display cutout
// and the system bars and gestures (patches/SDL/0002: the back gesture's side strips
// left out), in the window's pixels; on the Mac a window's safe area is all of it. The
// display scale: on Android densityDpi / 160 (2.625 on the Pixel 7a, 1.5 on the Tab
// A11+), on a Mac's Retina screen 2.

#include <stdbool.h>
#include <stdint.h>

typedef struct SDL_Window SDL_Window;
typedef struct { int x, y, w, h; } SDL_Rect;

#if defined(__ANDROID__)
extern SDL_Window **SDL_GetWindows(int *count);
extern void SDL_free(void *mem);
extern bool SDL_GetWindowSafeArea(SDL_Window *window, SDL_Rect *rect);
extern bool SDL_GetWindowSize(SDL_Window *window, int *w, int *h);
extern bool SDL_GetWindowSizeInPixels(SDL_Window *window, int *w, int *h);
extern float SDL_GetWindowDisplayScale(SDL_Window *window);
#else
#include <dlfcn.h>
#endif

static SDL_Window **(*get_windows)(int *);
static void (*sdl_free)(void *);
static bool (*safe_area)(SDL_Window *, SDL_Rect *);
static bool (*window_size)(SDL_Window *, int *, int *);
static bool (*pixel_size)(SDL_Window *, int *, int *);
static float (*display_scale)(SDL_Window *);
static SDL_Window *window;

// The program's one window, found once.
static SDL_Window *the_window(void) {
    if (window) return window;
#if defined(__ANDROID__)
    get_windows = SDL_GetWindows;
    sdl_free = SDL_free;
    safe_area = SDL_GetWindowSafeArea;
    window_size = SDL_GetWindowSize;
    pixel_size = SDL_GetWindowSizeInPixels;
    display_scale = SDL_GetWindowDisplayScale;
#else
    get_windows = (SDL_Window **(*)(int *))dlsym(RTLD_DEFAULT, "SDL_GetWindows");
    sdl_free = (void (*)(void *))dlsym(RTLD_DEFAULT, "SDL_free");
    safe_area = (bool (*)(SDL_Window *, SDL_Rect *))dlsym(RTLD_DEFAULT, "SDL_GetWindowSafeArea");
    window_size = (bool (*)(SDL_Window *, int *, int *))dlsym(RTLD_DEFAULT, "SDL_GetWindowSize");
    pixel_size = (bool (*)(SDL_Window *, int *, int *))dlsym(RTLD_DEFAULT, "SDL_GetWindowSizeInPixels");
    display_scale = (float (*)(SDL_Window *))dlsym(RTLD_DEFAULT, "SDL_GetWindowDisplayScale");
    if (!get_windows || !sdl_free || !safe_area || !window_size || !pixel_size || !display_scale) return 0;
#endif
    int count = 0;
    SDL_Window **all = get_windows(&count);
    if (!all) return 0;
    if (count > 0) window = all[0];
    sdl_free(all);
    return window;
}

typedef struct { float *data; int64_t len; } draughts_floats;

// Writes the insets around the safe area, in pixels (left, top, right, bottom), and the
// display scale into out[0..5]; returns 0, leaving out as it is, without a window.
int64_t draughts_display(draughts_floats out) {
    if (out.len < 5 || !the_window()) return 0;
    SDL_Rect r;
    int w = 0, h = 0, pw = 0, ph = 0;
    if (!safe_area(window, &r) || !window_size(window, &w, &h) || !pixel_size(window, &pw, &ph) || w <= 0 || h <= 0)
        return 0;
    // The safe area is in the window's coordinates, points on the Mac: in pixels.
    float sx = (float)pw / w, sy = (float)ph / h;
    out.data[0] = r.x * sx;
    out.data[1] = r.y * sy;
    out.data[2] = (w - r.x - r.w) * sx;
    out.data[3] = (h - r.y - r.h) * sy;
    out.data[4] = display_scale(window);
    return 1;
}
