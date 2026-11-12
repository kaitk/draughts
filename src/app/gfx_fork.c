// Stand-ins for the gamepad and fullscreen functions of the fork's goose_gfx
// (kaitk/goose_gfx, which every build script links), which host declares itself
// (keys.goose, host.goose): the release's gfx (a plain `goose build`) and goose-ngfx have
// none, and with these it still links, a gamepad never connected and the window never
// fullscreen. The fork's own definitions take their place. Without gfx_api.h, which the
// goose-ngfx build's c_include doesn't reach (scripts/ngfx.py).

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
