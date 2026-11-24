// The light tuner's Metal capture where tuner_capture.m isn't built: off. Empty on the Mac,
// where tuner_capture.m has them; iOS builds c_sources alone (scripts/ios.py), so it's here.
#include "platform.h"
#if !defined(__APPLE__) || DRAUGHTS_IOS
#include <stdint.h>

typedef struct { const uint8_t *data; int64_t len; } CapturePath;

uint8_t tuner_capture_start(CapturePath path) {
    (void)path;
    return 0;
}

void tuner_capture_stop(void) {}
#endif
