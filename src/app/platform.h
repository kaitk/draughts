// Which platform the program's C is built for. On Android and iOS SDL is linked into the
// program (scripts/android.py, scripts/ios.py), which calls it directly; on Windows
// `goose build` links the gfx package's static SDL into the program, so it is called
// directly there too; on the Mac the program's C is linked on its own and SDL is in the
// goose binary, so its functions are looked up with dlsym (docs: agents/goose.md).
//
// DRAUGHTS_PATCHED_GFX: the program is linked with goose_gfx built from
// patches/goose_gfx (Android, iOS), whose frame() waits for events (wake.c); the
// desktops link the release's own gfx.
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
#define DRAUGHTS_PATCHED_GFX 1
#else
#define DRAUGHTS_PATCHED_GFX 0
#endif

#if DRAUGHTS_PATCHED_GFX || defined(_WIN32)
#define DRAUGHTS_SDL_LINKED 1
#else
#define DRAUGHTS_SDL_LINKED 0
#endif

#endif
