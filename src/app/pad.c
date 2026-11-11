// A gamepad, through SDL's gamepad API, for the keys' focus (task 072; host's keys.goose,
// docs/architecture/rendering.md, "Keys"). goose_gfx has no gamepad (docs/goose-findings.md).
// On Android and iOS the program links SDL and calls it directly (platform.h); on the Mac
// SDL is in the goose binary, so its functions are looked up once.
//
// The first gamepad connected is opened when SDL says one is there (SDL_HasGamepad, which
// allocates nothing; the list of them is asked for only then), and closed when it goes.
// gfx's event loop pumps SDL's events, which keeps the gamepad's state current, and a
// button or the stick moving wakes the idle loop as any event does. The left stick past
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
#define SDL_INIT_GAMEPAD 0x00002000u

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
#else
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

static int state;                // 0 not started, 1 started, -1 unavailable
static SDL_Gamepad *pad;
static uint32_t stick;           // the stick's direction bits last frame, for the hysteresis

// The bits draughts_pad returns, as host's keys.goose reads them.
enum {
    PAD_A = 1u << 0, PAD_B = 1u << 1, PAD_X = 1u << 2, PAD_Y = 1u << 3,
    PAD_LB = 1u << 4, PAD_RB = 1u << 5, PAD_START = 1u << 6, PAD_BACK = 1u << 7,
    PAD_UP = 1u << 8, PAD_DOWN = 1u << 9, PAD_LEFT = 1u << 10, PAD_RIGHT = 1u << 11,
    PAD_THERE = 1u << 31,
};

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
    if (!init_sub || !has_gamepad || !get_gamepads || !open_gamepad || !connected || !close_gamepad ||
        !button || !axis || !sdl_free)
        return false;
#endif
    return init_sub(SDL_INIT_GAMEPAD);
}

// The first gamepad's buttons down this frame, as the bits above, PAD_THERE while one is
// connected; 0 with none, or where SDL has no gamepads.
int64_t draughts_pad(void) {
    if (state == 0) state = start() ? 1 : -1;
    if (state < 0) return 0;
    if (pad && !connected(pad)) {
        close_gamepad(pad);
        pad = 0;
        stick = 0;
    }
    if (!pad) {
        if (!has_gamepad()) return 0;
        int count = 0;
        SDL_JoystickID *ids = get_gamepads(&count);
        if (ids && count > 0) pad = open_gamepad(ids[0]);
        if (ids) sdl_free(ids);
        if (!pad) return 0;
    }
    // SDL's buttons: south 0, east 1, west 2, north 3, back 4, start 6, the shoulders 9
    // and 10, the D-pad 11 to 14. Axes: the left stick 0 (x) and 1 (y, down positive).
    static const int BUTTONS[12] = {0, 1, 2, 3, 9, 10, 6, 4, 11, 12, 13, 14};
    uint32_t bits = PAD_THERE;
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
