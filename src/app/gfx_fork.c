// Stand-ins for the gamepad functions of the fork's goose_gfx (kaitk/goose_gfx, which
// every build script links), which host's keys.goose declares itself: the release's gfx
// (a plain `goose build`) has none, and with these it still links, a gamepad never
// connected. The fork's own definitions take their place. Without gfx_api.h, which the
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
