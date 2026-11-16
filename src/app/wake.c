// Wakes the frame loop at a given time, for a running clock to show its next second on
// time (docs/architecture/rendering.md, "Frames and battery"), and lets the screen sleep
// once nobody has played for a while (host::keep_screen). The goose_gfx fork's
// frame() waits up to a second for an event after a frame that drew nothing; an SDL timer
// pushes an event of the program's own type, which ends the wait and gfx ignores. With
// the release's gfx frame() doesn't wait, and the event changes nothing. SDL is looked up
// where it isn't linked in (platform.h).

#include "platform.h"
#include <stdbool.h>
#include <stdint.h>

typedef struct { uint32_t type; uint8_t rest[124]; } SDL_Event;    // SDL3's 128-byte union
typedef uint32_t (*SDL_TimerCallback)(void *userdata, uint32_t timer, uint32_t interval);

#if DRAUGHTS_SDL_LINKED
extern uint32_t SDL_AddTimer(uint32_t interval, SDL_TimerCallback callback, void *userdata);
extern uint32_t SDL_RegisterEvents(int numevents);
extern bool SDL_PushEvent(SDL_Event *event);
extern bool SDL_EnableScreenSaver(void);
extern bool SDL_DisableScreenSaver(void);
#define sdl_add_timer SDL_AddTimer
#define sdl_register_events SDL_RegisterEvents
#define sdl_push_event SDL_PushEvent
#define sdl_enable_screen_saver SDL_EnableScreenSaver
#define sdl_disable_screen_saver SDL_DisableScreenSaver
static bool sdl_found(void) { return true; }
#else
#include <dlfcn.h>
static uint32_t (*sdl_add_timer)(uint32_t, SDL_TimerCallback, void *);
static uint32_t (*sdl_register_events)(int);
static bool (*sdl_push_event)(SDL_Event *);
static bool (*sdl_enable_screen_saver)(void);
static bool (*sdl_disable_screen_saver)(void);
static bool sdl_found(void) {
    if (!sdl_push_event) {
        sdl_add_timer = (uint32_t (*)(uint32_t, SDL_TimerCallback, void *))dlsym(RTLD_DEFAULT, "SDL_AddTimer");
        sdl_register_events = (uint32_t (*)(int))dlsym(RTLD_DEFAULT, "SDL_RegisterEvents");
        sdl_push_event = (bool (*)(SDL_Event *))dlsym(RTLD_DEFAULT, "SDL_PushEvent");
        sdl_enable_screen_saver = (bool (*)(void))dlsym(RTLD_DEFAULT, "SDL_EnableScreenSaver");
        sdl_disable_screen_saver = (bool (*)(void))dlsym(RTLD_DEFAULT, "SDL_DisableScreenSaver");
    }
    return sdl_add_timer && sdl_register_events && sdl_push_event && sdl_enable_screen_saver && sdl_disable_screen_saver;
}
#endif

static uint32_t wake_type;

static uint32_t wake(void *userdata, uint32_t timer, uint32_t interval) {
    (void)userdata;
    (void)timer;
    (void)interval;
    SDL_Event e = { wake_type, { 0 } };
    sdl_push_event(&e);
    return 0;       // once
}

// Ends the next frame()'s wait at once, with the event pushed now.
void draughts_wake_now(void) {
    if (!sdl_found()) return;
    if (wake_type == 0) wake_type = sdl_register_events(1);
    if (wake_type == 0) return;
    SDL_Event e = { wake_type, { 0 } };
    sdl_push_event(&e);
}

// Wakes the loop in `ms` milliseconds.
void draughts_wake_in(int64_t ms) {
    if (!sdl_found()) return;
    if (wake_type == 0) wake_type = sdl_register_events(1);
    if (wake_type == 0 || ms < 0) return;
    sdl_add_timer((uint32_t)ms, wake, 0);
}

// Lets the system dim and lock the screen after its own timeout (1), or keeps it on (0).
// SDL keeps it on from the window's opening: FLAG_KEEP_SCREEN_ON on Android, the idle
// timer off on iOS, a held power assertion on a desktop.
void draughts_screen_sleeps(int64_t allow) {
    if (!sdl_found()) return;
    if (allow) sdl_enable_screen_saver(); else sdl_disable_screen_saver();
}
