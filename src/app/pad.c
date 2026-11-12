// A gamepad, through SDL's gamepad API, for the keys' focus (task 072; host's keys.goose,
// docs/architecture/rendering.md, "Keys"). goose_gfx has no gamepad (docs/goose-findings.md).
// On Android and iOS the program links SDL and calls it directly (platform.h); on the Mac
// SDL is in the goose binary, so its functions are looked up once.
//
// The first gamepad connected is opened when SDL says one is there (SDL_HasGamepad, which
// allocates nothing; the list of them is asked for only then), and closed when it goes.
// SDL doesn't read the gamepads by itself (SDL_HINT_AUTO_UPDATE_JOYSTICKS off): left on,
// its event wait wakes every millisecond while one is open, to read it, which kept the
// idle app at about 5% of a core on the Mac with a PS5 pad. Instead each call here reads
// them (SDL_UpdateGamepads), when the loop runs. On the Mac and iOS the system's
// GameController framework reads the gamepads (SDL's HIDAPI off: its own reading thread
// took a PS5 pad's reports hundreds of times a second), and its change handler wakes the
// loop when a button changes or a stick or the D-pad leaves the middle (draughts_wake_now),
// so the idle loop sleeps until the gamepad is used. Elsewhere the loop wakes about 30
// times a second while one is connected, to read it (draughts_pad_wakes; host's keys.goose,
// PAD_POLL). A button pressed and let go between two reads isn't lost: an event watch keeps
// the presses SDL's reading sends (pressed), and they count as down for one call. The
// left stick past
// half way counts as the D-pad toward its larger axis, let go under a third (a little
// hysteresis, so a stick resting near the threshold doesn't flicker).
//
// Android: the gamepads start no sensor. SDL 3 has no accelerometer joystick; the phone's
// accelerometer is SDL's sensor subsystem, which is never started (DraughtsActivity's
// note), and a gamepad's own sensors stay off until asked for.

#include "platform.h"
#include <stdbool.h>
#include <stdint.h>

typedef struct SDL_Gamepad SDL_Gamepad;
typedef uint32_t SDL_JoystickID;
typedef struct { uint32_t type; uint8_t rest[124]; } SDL_Event;    // SDL3's 128-byte union
typedef bool (*SDL_EventFilter)(void *userdata, SDL_Event *event);
#define SDL_INIT_GAMEPAD 0x00002000u
#define SDL_EVENT_GAMEPAD_BUTTON_DOWN 0x651u

#if DRAUGHTS_SDL_LINKED
extern bool SDL_InitSubSystem(uint32_t flags);
extern bool SDL_HasGamepad(void);
extern SDL_JoystickID *SDL_GetGamepads(int *count);
extern SDL_Gamepad *SDL_OpenGamepad(SDL_JoystickID id);
extern bool SDL_GamepadConnected(SDL_Gamepad *gamepad);
extern void SDL_CloseGamepad(SDL_Gamepad *gamepad);
extern bool SDL_GetGamepadButton(SDL_Gamepad *gamepad, int button);
extern int16_t SDL_GetGamepadAxis(SDL_Gamepad *gamepad, int axis);
extern void SDL_free(void *mem);
extern bool SDL_SetHint(const char *name, const char *value);
extern void SDL_UpdateGamepads(void);
extern bool SDL_AddEventWatch(SDL_EventFilter filter, void *userdata);
#endif
#if !DRAUGHTS_SDL_LINKED || defined(__APPLE__)
#include <dlfcn.h>
#endif

static bool (*init_sub)(uint32_t);
static bool (*has_gamepad)(void);
static SDL_JoystickID *(*get_gamepads)(int *);
static SDL_Gamepad *(*open_gamepad)(SDL_JoystickID);
static bool (*connected)(SDL_Gamepad *);
static void (*close_gamepad)(SDL_Gamepad *);
static bool (*button)(SDL_Gamepad *, int);
static int16_t (*axis)(SDL_Gamepad *, int);
static void (*sdl_free)(void *);
static bool (*set_hint)(const char *, const char *);
static void (*update)(void);
static bool (*add_watch)(SDL_EventFilter, void *);

static int state;                // 0 not started, 1 started, -1 unavailable
static SDL_Gamepad *pad;
static uint32_t stick;           // the stick's direction bits last frame, for the hysteresis
static uint32_t pressed;         // SDL's buttons pressed since the last call (watch)

// The bits draughts_pad returns, as host's keys.goose reads them.
enum {
    PAD_A = 1u << 0, PAD_B = 1u << 1, PAD_X = 1u << 2, PAD_Y = 1u << 3,
    PAD_LB = 1u << 4, PAD_RB = 1u << 5, PAD_START = 1u << 6, PAD_BACK = 1u << 7,
    PAD_UP = 1u << 8, PAD_DOWN = 1u << 9, PAD_LEFT = 1u << 10, PAD_RIGHT = 1u << 11,
    PAD_THERE = 1u << 31,
};

// SDL's buttons: south 0, east 1, west 2, north 3, back 4, start 6, the shoulders 9 and
// 10, the D-pad 11 to 14; as the bits above, in their order.
static const int BUTTONS[12] = {0, 1, 2, 3, 9, 10, 6, 4, 11, 12, 13, 14};

// Keeps a button's press, from whichever thread SDL sends it on.
static bool watch(void *userdata, SDL_Event *event) {
    (void)userdata;
    if (event->type == SDL_EVENT_GAMEPAD_BUTTON_DOWN) {
        uint8_t b = event->rest[16];    // SDL_GamepadButtonEvent's button, 20 bytes in
        for (int i = 0; i < 12; i++) {
            if (BUTTONS[i] == b) __atomic_fetch_or(&pressed, 1u << i, __ATOMIC_RELAXED);
        }
    }
    return true;
}

#if defined(__APPLE__)
// The GameController framework through the Objective-C runtime, looked up as resize.c's.
typedef void *id;
typedef void *SEL;
static id (*get_class)(const char *);
static SEL (*sel)(const char *);
static void *msg;       // objc_msgSend, cast at each call to the method's type
#define SEND(type, ...) ((type)msg)(__VA_ARGS__)

extern void draughts_wake_now(void);

// A gamepad's element changed: a button, or a stick or the D-pad off the middle (a stick
// resting near it may stir; going back is seen by the held arrow's repeat, which reads it).
static void changed(id element) {
    if (SEND(bool (*)(id, SEL, id), element, sel("isKindOfClass:"), get_class("GCControllerDirectionPad"))) {
        float x = SEND(float (*)(id, SEL), SEND(id (*)(id, SEL), element, sel("xAxis")), sel("value"));
        float y = SEND(float (*)(id, SEL), SEND(id (*)(id, SEL), element, sel("yAxis")), sel("value"));
        if (x < 0.3f && x > -0.3f && y < 0.3f && y > -0.3f) return;
    }
    draughts_wake_now();
}

// Each controller's change handler set, once it is opened; whether they could be.
static bool watch_controllers(void) {
    if (!get_class) {
        get_class = (id (*)(const char *))dlsym(RTLD_DEFAULT, "objc_getClass");
        sel = (SEL (*)(const char *))dlsym(RTLD_DEFAULT, "sel_registerName");
        msg = dlsym(RTLD_DEFAULT, "objc_msgSend");
    }
    id gc = get_class ? get_class("GCController") : 0;
    if (!sel || !msg || !gc) return false;
    void (^handler)(id, id) = ^(id gamepad, id element) {
        (void)gamepad;
        changed(element);
    };
    id all = SEND(id (*)(id, SEL), gc, sel("controllers"));
    unsigned long n = all ? SEND(unsigned long (*)(id, SEL), all, sel("count")) : 0;
    for (unsigned long i = 0; i < n; i++) {
        id c = SEND(id (*)(id, SEL, unsigned long), all, sel("objectAtIndex:"), i);
        id gamepad = SEND(id (*)(id, SEL), c, sel("extendedGamepad"));
        if (gamepad) SEND(void (*)(id, SEL, void *), gamepad, sel("setValueChangedHandler:"), (void *)handler);
    }
    return n > 0;
}
#endif

static bool wakes;      // the open gamepad wakes the loop itself (watch_controllers)

static bool start(void) {
#if DRAUGHTS_SDL_LINKED
    init_sub = SDL_InitSubSystem;
    has_gamepad = SDL_HasGamepad;
    get_gamepads = SDL_GetGamepads;
    open_gamepad = SDL_OpenGamepad;
    connected = SDL_GamepadConnected;
    close_gamepad = SDL_CloseGamepad;
    button = SDL_GetGamepadButton;
    axis = SDL_GetGamepadAxis;
    sdl_free = SDL_free;
    set_hint = SDL_SetHint;
    update = SDL_UpdateGamepads;
    add_watch = SDL_AddEventWatch;
#else
    init_sub = (bool (*)(uint32_t))dlsym(RTLD_DEFAULT, "SDL_InitSubSystem");
    has_gamepad = (bool (*)(void))dlsym(RTLD_DEFAULT, "SDL_HasGamepad");
    get_gamepads = (SDL_JoystickID * (*)(int *)) dlsym(RTLD_DEFAULT, "SDL_GetGamepads");
    open_gamepad = (SDL_Gamepad * (*)(SDL_JoystickID)) dlsym(RTLD_DEFAULT, "SDL_OpenGamepad");
    connected = (bool (*)(SDL_Gamepad *))dlsym(RTLD_DEFAULT, "SDL_GamepadConnected");
    close_gamepad = (void (*)(SDL_Gamepad *))dlsym(RTLD_DEFAULT, "SDL_CloseGamepad");
    button = (bool (*)(SDL_Gamepad *, int))dlsym(RTLD_DEFAULT, "SDL_GetGamepadButton");
    axis = (int16_t(*)(SDL_Gamepad *, int))dlsym(RTLD_DEFAULT, "SDL_GetGamepadAxis");
    sdl_free = (void (*)(void *))dlsym(RTLD_DEFAULT, "SDL_free");
    set_hint = (bool (*)(const char *, const char *))dlsym(RTLD_DEFAULT, "SDL_SetHint");
    update = (void (*)(void))dlsym(RTLD_DEFAULT, "SDL_UpdateGamepads");
    add_watch = (bool (*)(SDL_EventFilter, void *))dlsym(RTLD_DEFAULT, "SDL_AddEventWatch");
    if (!init_sub || !has_gamepad || !get_gamepads || !open_gamepad || !connected || !close_gamepad ||
        !button || !axis || !sdl_free || !set_hint || !update || !add_watch)
        return false;
#endif
    set_hint("SDL_AUTO_UPDATE_JOYSTICKS", "0");
#if defined(__APPLE__)
    set_hint("SDL_JOYSTICK_HIDAPI", "0");
#endif
    if (!init_sub(SDL_INIT_GAMEPAD)) return false;
    add_watch(watch, 0);
    return true;
}

// The first gamepad's buttons down this frame, as the bits above, PAD_THERE while one is
// connected; 0 with none, or where SDL has no gamepads.
int64_t draughts_pad(void) {
    if (state == 0) state = start() ? 1 : -1;
    if (state < 0) return 0;
    update();
    uint32_t taps = __atomic_exchange_n(&pressed, 0, __ATOMIC_RELAXED);
    if (pad && !connected(pad)) {
        close_gamepad(pad);
        pad = 0;
        stick = 0;
        wakes = false;
    }
    if (!pad) {
        if (!has_gamepad()) return 0;
        int count = 0;
        SDL_JoystickID *ids = get_gamepads(&count);
        if (ids && count > 0) pad = open_gamepad(ids[0]);
        if (ids) sdl_free(ids);
        if (!pad) return 0;
#if defined(__APPLE__)
        wakes = watch_controllers();
#endif
    }
    // The buttons down now, and those pressed since the last call though let go again.
    // Axes: the left stick 0 (x) and 1 (y, down positive).
    uint32_t bits = PAD_THERE | taps;
    for (int i = 0; i < 12; i++) {
        if (button(pad, BUTTONS[i])) bits |= 1u << i;
    }
    float x = axis(pad, 0) / 32767.0f;
    float y = axis(pad, 1) / 32767.0f;
    float ax = x < 0 ? -x : x;
    float ay = y < 0 ? -y : y;
    uint32_t dir = 0;
    float far = ax > ay ? ax : ay;
    uint32_t want = ax > ay ? (x < 0 ? PAD_LEFT : PAD_RIGHT) : (y < 0 ? PAD_UP : PAD_DOWN);
    if (far > 0.5f) dir = want;
    else if (stick != 0 && far > 0.33f) dir = stick;   // held past a third: as it was
    stick = dir;
    return bits | dir;
}

// Whether the gamepad open wakes the loop when used, so the idle loop needn't read it.
uint8_t draughts_pad_wakes(void) { return wakes; }
