// Tells DraughtsActivity (android/java/) that the program's first frame is on screen, so
// it lifts the splash and the navy cover it keeps over SDL's surface until then: without
// them the surface shows black between Android's splash and the first frame (task 028).
// Called once, from the program's thread. On the Mac there is nothing to tell.

#if defined(__ANDROID__)
#include <jni.h>

extern void *SDL_GetAndroidJNIEnv(void);
extern void *SDL_GetAndroidActivity(void);

void draughts_first_frame(void) {
    JNIEnv *env = (JNIEnv *)SDL_GetAndroidJNIEnv();
    jobject activity = (jobject)SDL_GetAndroidActivity();
    if (!env || !activity) return;
    // The activity's own class: FindClass from this thread would search the system's
    // class loader, which doesn't know the app's classes.
    jclass cls = (*env)->GetObjectClass(env, activity);
    jmethodID shown = (*env)->GetMethodID(env, cls, "firstFrame", "()V");
    if (shown) (*env)->CallVoidMethod(env, activity, shown);
    if ((*env)->ExceptionCheck(env)) (*env)->ExceptionClear(env);
    (*env)->DeleteLocalRef(env, cls);
    (*env)->DeleteLocalRef(env, activity);
}
#else
void draughts_first_frame(void) {}
#endif
