// Weak stand-ins for the goose_gfx fork's gamepad and fullscreen functions, so a plain
// `goose build` against the release's gfx still links; the fork's definitions win in
// every build script's link. No gfx_api.h: the goose-ngfx build's c_include lacks it.

#include <stdint.h>

__attribute__((weak)) uint8_t gs_gfx_gamepad_connected(int64_t slot) {
    (void)slot;
    return 0;
}

__attribute__((weak)) uint8_t gs_gfx_gamepad_down(int64_t slot, int64_t button) {
    (void)slot;
    (void)button;
    return 0;
}

__attribute__((weak)) uint8_t gs_gfx_gamepad_pressed(int64_t slot, int64_t button) {
    (void)slot;
    (void)button;
    return 0;
}

__attribute__((weak)) float gs_gfx_gamepad_axis(int64_t slot, int64_t axis) {
    (void)slot;
    (void)axis;
    return 0;
}

__attribute__((weak)) uint8_t gs_gfx_set_fullscreen(uint8_t on) {
    (void)on;
    return 0;
}

__attribute__((weak)) uint8_t gs_gfx_fullscreen(void) {
    return 0;
}
