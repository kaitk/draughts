// Wakes the frame loop at a given time, for a running clock to show its next second on
// time (docs/architecture/rendering.md, "Frames and battery"). goose_gfx's patched
// frame() (patches/goose_gfx/0002) waits up to a second for an event after a frame that
// drew nothing, so a clock drawn once a second slipped by a frame each second and
// skipped a second about every two and a half minutes. An SDL timer pushes an event of
// the program's own type when the time shown changes, which ends the wait; goose_gfx
// ignores the event. Every build takes the patched gfx (scripts/android.py, ios.py,
// mac.py, windows.py); with the release's own (a plain `goose build`) frame() doesn't
// wait, and the event changes nothing. On the Mac SDL's functions are looked up with
// dlsym (platform.h).

#include "platform.h"
#include <stdbool.h>
#include <stdint.h>

typedef struct { uint32_t type; uint8_t rest[124]; } SDL_Event;    // SDL3's 128-byte union
typedef uint32_t (*SDL_TimerCallback)(void *userdata, uint32_t timer, uint32_t interval);

#if DRAUGHTS_SDL_LINKED
extern uint32_t SDL_AddTimer(uint32_t interval, SDL_TimerCallback callback, void *userdata);
extern uint32_t SDL_RegisterEvents(int numevents);
extern bool SDL_PushEvent(SDL_Event *event);
#define sdl_add_timer SDL_AddTimer
#define sdl_register_events SDL_RegisterEvents
#define sdl_push_event SDL_PushEvent
static bool sdl_found(void) { return true; }
#else
#include <dlfcn.h>
static uint32_t (*sdl_add_timer)(uint32_t, SDL_TimerCallback, void *);
static uint32_t (*sdl_register_events)(int);
static bool (*sdl_push_event)(SDL_Event *);
static bool sdl_found(void) {
    if (!sdl_push_event) {
        sdl_add_timer = (uint32_t (*)(uint32_t, SDL_TimerCallback, void *))dlsym(RTLD_DEFAULT, "SDL_AddTimer");
        sdl_register_events = (uint32_t (*)(int))dlsym(RTLD_DEFAULT, "SDL_RegisterEvents");
        sdl_push_event = (bool (*)(SDL_Event *))dlsym(RTLD_DEFAULT, "SDL_PushEvent");
    }
    return sdl_add_timer && sdl_register_events && sdl_push_event;
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
