#include <stdint.h>

typedef struct { const uint8_t *data; int64_t len; } CapturePath;

uint8_t tuner_capture_start(CapturePath path) {
    (void)path;
    return 0;
}

void tuner_capture_stop(void) {}
