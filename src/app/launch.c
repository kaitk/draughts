// What the program tells DraughtsActivity (android/java/), from the program's thread.
//
// draughts_first_frame: the first frame is on screen, so it lifts the splash and the
// cover in the icon's background colour it keeps over SDL's surface until then: without
// them the surface shows black between Android's splash and the first frame (task 028).
// Called once.
//
// draughts_close: home's way out was tapped and the game is written, so the activity
// finishes and takes its card out of recents (finishAndRemoveTask), just before the
// program returns. SDL then finds the activity finishing and leaves it; the next start
// is a fresh process that restores the game.
//
// draughts_leave: Android's back on home's menu, which has no way back: the activity
// moves its task to the background (leaveApp), as the system's back does for an app's
// first screen, the process and the activity kept. Handing the back on to the activity's
// onBackPressed (SDL_SendAndroidBackButton) finished it on Android 17 instead, taking
// the card out of recents (the Pixel 7a, 2026-11-08).
//
// On the Mac there is nothing to tell: the window closes as the program returns. On iOS
// neither: an app never closes itself there (home hides its way out), and the system
// takes the launch screen down at the first frame by itself.
//
// draughts_platform: which platform the program runs on, which Goose can't ask
// (docs/goose-findings.md): 0 a desktop, 1 Android, 2 iOS.

#include "platform.h"
#include <stdint.h>

int64_t draughts_platform(void) {
#if defined(__ANDROID__)
    return 1;
#elif DRAUGHTS_IOS
    return 2;
#else
    return 0;
#endif
}

#if defined(__ANDROID__)
#include <jni.h>

extern void *SDL_GetAndroidJNIEnv(void);
extern void *SDL_GetAndroidActivity(void);

// Calls the activity's method `name`, taking and returning nothing.
static void call_activity(const char *name) {
    JNIEnv *env = (JNIEnv *)SDL_GetAndroidJNIEnv();
    jobject activity = (jobject)SDL_GetAndroidActivity();
    if (!env || !activity) return;
    // The activity's own class: FindClass from this thread would search the system's
    // class loader, which doesn't know the app's classes.
    jclass cls = (*env)->GetObjectClass(env, activity);
    jmethodID method = (*env)->GetMethodID(env, cls, name, "()V");
    if (method) (*env)->CallVoidMethod(env, activity, method);
    if ((*env)->ExceptionCheck(env)) (*env)->ExceptionClear(env);
    (*env)->DeleteLocalRef(env, cls);
    (*env)->DeleteLocalRef(env, activity);
}

void draughts_first_frame(void) { call_activity("firstFrame"); }
void draughts_close(void) { call_activity("closeApp"); }
void draughts_leave(void) { call_activity("leaveApp"); }
#else
void draughts_first_frame(void) {}
void draughts_close(void) {}
void draughts_leave(void) {}
#endif
