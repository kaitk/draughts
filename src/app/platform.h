// Which platform the program's C is built for. On Android, iOS, Windows, and Linux SDL is
// linked into the program (scripts/android.py, ios.py, windows.py, linux.py, and a plain
// `goose build` on Windows or Linux), which calls it directly: a Linux executable exports
// none of SDL's functions for dlsym to find (2026-11-12). On the Mac the program's C is
// linked on its own and SDL is in the goose binary, so its functions are looked up with
// dlsym (docs: agents/goose.md).
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

#if defined(__ANDROID__) || DRAUGHTS_IOS || defined(_WIN32) || defined(__linux__)
#define DRAUGHTS_SDL_LINKED 1
#else
#define DRAUGHTS_SDL_LINKED 0
#endif

#endif
