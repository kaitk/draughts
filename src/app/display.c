// The window's safe area and its display's scale, through SDL, for the layout
// (gui::insets, gui::scale_of; docs/architecture/rendering.md, "Screen sizes"). goose_gfx
// has neither (docs/goose-findings.md). On Android and iOS the program links SDL and calls
// it directly (platform.h); on the Mac SDL is in the goose binary, so its functions are
// looked up once.
//
// The safe area: on Android SDL fills it from the window's insets, the display cutout,
// the system bars while shown, and the bottom gesture bar (patches/SDL/0002: the back
// gesture's side strips and the top swipe-down strip left out), in the window's pixels;
// on iOS from the view's safeAreaInsets (the notch and the home indicator), in points;
// on the Mac a window's safe area is all of it. The display scale: on Android
// densityDpi / 160 (2.625 on the Pixel 7a, 1.5 on the Tab A11+), on iOS the screen's
// pixels a point, on a Mac's Retina screen 2.
//
// The GPU driver: Vulkan on Windows, as on Android, which SDL would otherwise pass over
// for Direct3D 12 (docs/architecture/README.md).

#include "platform.h"
#include <stdbool.h>
#include <stdint.h>

typedef struct SDL_Window SDL_Window;
typedef struct { int x, y, w, h; } SDL_Rect;

#if defined(_WIN32)
extern bool SDL_SetHint(const char *name, const char *value);
#endif

// Asks SDL for the GPU driver the app draws with, before gfx opens the window: Vulkan on
// Windows; elsewhere the platform's only one (Metal on Apple's, Vulkan on Android).
void draughts_choose_gpu(void) {
#if defined(_WIN32)
    SDL_SetHint("SDL_GPU_DRIVER", "vulkan");
#endif
}

#if DRAUGHTS_SDL_LINKED
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
#if DRAUGHTS_SDL_LINKED
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
    // The safe area is in the window's coordinates, points on the Mac and iOS: in pixels.
    float sx = (float)pw / w, sy = (float)ph / h;
    out.data[0] = r.x * sx;
    out.data[1] = r.y * sy;
    out.data[2] = (w - r.x - r.w) * sx;
    out.data[3] = (h - r.y - r.h) * sy;
    out.data[4] = display_scale(window);
    return 1;
}

// The display at 60 Hz while the 3D board draws, on a device whose 3D board can't keep up
// with a faster display (task 056). On a 90 Hz display, such as the Galaxy A33's, a 3D
// board that draws 60 frames a second shows them two refreshes and one in turn; at 60 Hz
// each shows for one. A device that holds its display's rate keeps it.
//
// draughts_pace_3d(drawing, now) is called each pass of the loop, drawing 1 when the pass
// drew the 3D board, ready and shown (its preparing steps are long by design), and not
// in --bench's waited phases. The gaps between passes that drew it one after the other are timed
// at the display's own rate: after SLOW_AFTER of them, if they average over a quarter
// more than a refresh and the display is faster than 60, the app asks for 60 whenever the
// 3D board draws, from then on, and for the display's own rate (0) otherwise. Android
// only (ANativeWindow_setFrameRate, API 30, looked up as the app runs from 29), and only
// when the rate or the surface changed: a new surface, after the app was in the
// background, starts with no rate of its own. Some displays ignore it: the Galaxy A33's
// "High" motion smoothness holds 90 Hz whatever an app asks.
#if defined(__ANDROID__)
#include <dlfcn.h>
typedef struct ANativeWindow ANativeWindow;
typedef uint32_t SDL_PropertiesID;
typedef uint32_t SDL_DisplayID;
typedef struct {
    SDL_DisplayID displayID;
    uint32_t format;
    int w, h;
    float pixel_density, refresh_rate;
    int refresh_rate_numerator, refresh_rate_denominator;
    void *internal;
} SDL_DisplayMode;
extern SDL_PropertiesID SDL_GetWindowProperties(SDL_Window *window);
extern void *SDL_GetPointerProperty(SDL_PropertiesID props, const char *name, void *default_value);
extern SDL_DisplayID SDL_GetDisplayForWindow(SDL_Window *window);
extern const SDL_DisplayMode *SDL_GetCurrentDisplayMode(SDL_DisplayID display);

enum { SLOW_AFTER = 60 };

static void ask_rate(float hz) {
    static int32_t (*set_rate)(ANativeWindow *, float, int8_t);
    static int looked;
    static ANativeWindow *was;
    static float was_hz;
    if (!looked) {
        looked = 1;
        // Not found through RTLD_DEFAULT: the app's libraries are in their own namespace.
        void *lib = dlopen("libandroid.so", RTLD_NOW);
        if (lib) set_rate = (int32_t (*)(ANativeWindow *, float, int8_t))dlsym(lib, "ANativeWindow_setFrameRate");
    }
    if (!set_rate) return;
    ANativeWindow *surface = (ANativeWindow *)SDL_GetPointerProperty(
        SDL_GetWindowProperties(window), "SDL.window.android.window", 0);
    if (!surface || (surface == was && hz == was_hz)) return;
    // ANATIVEWINDOW_FRAME_RATE_COMPATIBILITY_DEFAULT: a game's frames, not a video's.
    if (set_rate(surface, hz, 0) == 0) {
        was = surface;
        was_hz = hz;
    }
}

void draughts_pace_3d(int64_t drawing, double now) {
    static int slow, timed;
    static double last = -1.0, sum;
    if (!the_window()) return;
    // A gap over 0.1 s is a hitch (a season's photograph loading), not the board's pace.
    if (!slow && drawing && last >= 0.0 && now - last < 0.1) {
        sum += now - last;
        if (++timed == SLOW_AFTER) {
            const SDL_DisplayMode *mode = SDL_GetCurrentDisplayMode(SDL_GetDisplayForWindow(window));
            float hz = mode ? mode->refresh_rate : 0.0f;
            slow = hz > 61.0f && sum / SLOW_AFTER > 1.25 / hz;
            timed = 0;
            sum = 0.0;
        }
    }
    last = drawing ? now : -1.0;
    ask_rate(slow && drawing ? 60.0f : 0.0f);
}
#else
void draughts_pace_3d(int64_t drawing, double now) { (void)drawing; (void)now; }
#endif
