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
// On the Mac there is nothing to tell: the window closes as the program returns.

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
#else
void draughts_first_frame(void) {}
void draughts_close(void) {}
#endif
