// What the program tells DraughtsActivity (android/java/), from the program's thread.
//
// draughts_first_frame: the first frame is on screen, so the activity lifts the splash
// and the cover it keeps over SDL's surface, which shows black until then. Called once.
//
// draughts_close: home's way out, the game written: the activity finishes and leaves
// recents (finishAndRemoveTask) just before the program returns.
//
// draughts_leave: Android's back on home's menu: the activity moves its task to the
// background (leaveApp), as the system's back does for an app's first screen. Passing the
// back on (SDL_SendAndroidBackButton) would finish the activity instead.
//
// Nothing to tell on the Mac or iOS.
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
