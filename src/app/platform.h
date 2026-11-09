// Which platform the program's C is built for. On Android and iOS SDL is linked into the
// program (scripts/android.py, scripts/ios.py), which calls it directly; on the Mac the
// program's C is linked on its own and SDL is in the goose binary, so its functions are
// looked up with dlsym (docs: agents/goose.md).
#ifndef DRAUGHTS_PLATFORM_H
#define DRAUGHTS_PLATFORM_H

#if defined(__APPLE__)
#include <TargetConditionals.h>
#endif

#if defined(__APPLE__) && TARGET_OS_IPHONE
#define DRAUGHTS_IOS 1
#else
#define DRAUGHTS_IOS 0
#endif

#if defined(__ANDROID__) || DRAUGHTS_IOS
#define DRAUGHTS_SDL_LINKED 1
#else
#define DRAUGHTS_SDL_LINKED 0
#endif

#endif
