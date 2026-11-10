// What a Mac window shows while its edge is dragged (docs/architecture/rendering.md,
// "Window resizing"). Cocoa keeps the main thread in its own loop until the mouse comes
// up, so the app draws nothing new, and the Metal layer would stretch its last frame to
// the window. Instead the layer keeps that frame's shape, scaled to fit, and the window's
// content view, under it, shows the season's blurred photograph (or the page color),
// cover-cropped as the board pass crops it. Core Animation does both on its own while
// the loop is held; once the app draws the new size, its frame fills the window again.
// Nothing changes at rest: the layers are set once, and again on a season change.
//
// Elsewhere it does nothing: Android and iOS don't block the loop while a window
// resizes, and Windows' modal size loop shows the last frame unscaled, not stretched. SDL,
// Objective-C, and Core Graphics are looked up with dlsym, as the program's C is linked
// on the Mac with no undefined symbols (platform.h).

#include "platform.h"
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "gfx_api.h"

#if defined(__APPLE__) && !DRAUGHTS_IOS

#include <dlfcn.h>

typedef double CGFloat;
typedef void *id;
typedef void *SEL;

enum { SIDE = 512 };    // scene.goose's SIZE: the blurred copy's side

static id (*get_class)(const char *);
static SEL (*sel)(const char *);
static void *msg;       // objc_msgSend, cast at each call to the method's type
static id under;        // the content view's layer, under the Metal view
static uint8_t pixels[SIDE * SIDE * 4];

#define SEND(type, ...) ((type)msg)(__VA_ARGS__)

// The window's content view, which holds SDL's Metal view.
static id content_view(void) {
    void **(*get_windows)(int *) = (void **(*)(int *))dlsym(RTLD_DEFAULT, "SDL_GetWindows");
    void (*sdl_free)(void *) = (void (*)(void *))dlsym(RTLD_DEFAULT, "SDL_free");
    uint32_t (*props)(void *) = (uint32_t (*)(void *))dlsym(RTLD_DEFAULT, "SDL_GetWindowProperties");
    void *(*pointer)(uint32_t, const char *, void *) =
        (void *(*)(uint32_t, const char *, void *))dlsym(RTLD_DEFAULT, "SDL_GetPointerProperty");
    if (!get_windows || !sdl_free || !props || !pointer) return 0;
    int count = 0;
    void **all = get_windows(&count);
    id w = all && count > 0 ? pointer(props(all[0]), "SDL.window.cocoa.window", 0) : 0;
    if (all) sdl_free(all);
    return w ? SEND(id (*)(id, SEL), w, sel("contentView")) : 0;
}

// Sets the layers up once: the content view's own layer under the Metal view's, and the
// Metal layer keeping its frame's shape.
static bool setup(void) {
    if (under) return true;
    get_class = (id (*)(const char *))dlsym(RTLD_DEFAULT, "objc_getClass");
    sel = (SEL (*)(const char *))dlsym(RTLD_DEFAULT, "sel_registerName");
    msg = dlsym(RTLD_DEFAULT, "objc_msgSend");
    id *fill = (id *)dlsym(RTLD_DEFAULT, "kCAGravityResizeAspectFill");
    id *fit = (id *)dlsym(RTLD_DEFAULT, "kCAGravityResizeAspect");
    if (!get_class || !sel || !msg || !fill || !fit) return false;
    id view = content_view();
    if (!view) return false;
    id metal = SEND(id (*)(id, SEL), SEND(id (*)(id, SEL), view, sel("subviews")), sel("lastObject"));
    id metal_layer = metal ? SEND(id (*)(id, SEL), metal, sel("layer")) : 0;
    if (!metal_layer) return false;
    SEND(void (*)(id, SEL, bool), view, sel("setWantsLayer:"), true);
    under = SEND(id (*)(id, SEL), view, sel("layer"));
    if (!under) return false;
    SEND(void (*)(id, SEL, id), under, sel("setContentsGravity:"), *fill);
    SEND(void (*)(id, SEL, id), metal_layer, sel("setContentsGravity:"), *fit);
    SEND(void (*)(id, SEL, bool), metal_layer, sel("setOpaque:"), false);
    return true;
}

// Puts the scene under the Metal view: `photo`, the blurred copy (SIDE square, RGBA8),
// when `has`, else the page color (r, g, b).
void draughts_resize_cover(gs_gfx_texture photo, uint8_t has, float r, float g, float b) {
    void *(*space_named)(void *) = (void *(*)(void *))dlsym(RTLD_DEFAULT, "CGColorSpaceCreateWithName");
    void **srgb = (void **)dlsym(RTLD_DEFAULT, "kCGColorSpaceSRGB");
    void *(*color)(CGFloat, CGFloat, CGFloat, CGFloat) =
        (void *(*)(CGFloat, CGFloat, CGFloat, CGFloat))dlsym(RTLD_DEFAULT, "CGColorCreateSRGB");
    void *(*provider)(void *, const void *, size_t, void *) =
        (void *(*)(void *, const void *, size_t, void *))dlsym(RTLD_DEFAULT, "CGDataProviderCreateWithData");
    void *(*image)(size_t, size_t, size_t, size_t, size_t, void *, uint32_t, void *, void *, bool, int) =
        (void *(*)(size_t, size_t, size_t, size_t, size_t, void *, uint32_t, void *, void *, bool, int))
            dlsym(RTLD_DEFAULT, "CGImageCreate");
    void (*release)(const void *) = (void (*)(const void *))dlsym(RTLD_DEFAULT, "CFRelease");
    if (!space_named || !srgb || !color || !provider || !image || !release || !setup()) return;
    void *contents = 0;
    gs_gfx_region whole = { 0 };
    if (has && gs_gfx_read_texture(photo, &whole, (gs_gfx_bytes){ pixels, sizeof pixels })) {
        void *space = space_named(*srgb);
        void *data = provider(0, pixels, sizeof pixels, 0);
        contents = image(SIDE, SIDE, 8, 32, SIDE * 4, space, 5 /* RGBX: no alpha, skip last */,
                         data, 0, true, 0);
        release(data);
        release(space);
    }
    void *page = color(r, g, b, 1.0);
    id ca = get_class("CATransaction");
    SEND(void (*)(id, SEL), ca, sel("begin"));
    SEND(void (*)(id, SEL, bool), ca, sel("setDisableActions:"), true);
    SEND(void (*)(id, SEL, void *), under, sel("setContents:"), contents);
    SEND(void (*)(id, SEL, void *), under, sel("setBackgroundColor:"), page);
    SEND(void (*)(id, SEL), ca, sel("commit"));
    release(page);
    if (contents) release(contents);
}

#else

void draughts_resize_cover(gs_gfx_texture photo, uint8_t has, float r, float g, float b) {
    (void)photo;
    (void)has;
    (void)r;
    (void)g;
    (void)b;
}

#endif
