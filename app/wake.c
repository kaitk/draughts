// Wakes the frame loop at a given time, for a running clock to show its next second on
// time (docs/architecture/rendering.md, "Frames and battery"). On Android goose_gfx's
// patched frame() waits up to a second for an event after a frame that drew nothing, so
// a clock drawn once a second slipped by a frame each second and skipped a second about
// every two and a half minutes. An SDL timer pushes an event of the program's own type
// when the time shown changes, which ends the wait; goose_gfx ignores the event. On the
// Mac the built-in frame() doesn't wait, so this does nothing there.

#include <stdbool.h>
#include <stdint.h>

#if defined(__ANDROID__)
typedef struct { uint32_t type; uint8_t rest[124]; } SDL_Event;    // SDL3's 128-byte union
typedef uint32_t (*SDL_TimerCallback)(void *userdata, uint32_t timer, uint32_t interval);
extern uint32_t SDL_AddTimer(uint32_t interval, SDL_TimerCallback callback, void *userdata);
extern uint32_t SDL_RegisterEvents(int numevents);
extern bool SDL_PushEvent(SDL_Event *event);

static uint32_t wake_type;

static uint32_t wake(void *userdata, uint32_t timer, uint32_t interval) {
    (void)userdata;
    (void)timer;
    (void)interval;
    SDL_Event e = { wake_type, { 0 } };
    SDL_PushEvent(&e);
    return 0;       // once
}

// Wakes the loop in `ms` milliseconds.
void draughts_wake_in(int64_t ms) {
    if (wake_type == 0) wake_type = SDL_RegisterEvents(1);
    if (wake_type == 0 || ms < 0) return;
    SDL_AddTimer((uint32_t)ms, wake, 0);
}
#else
void draughts_wake_in(int64_t ms) { (void)ms; }
#endif
