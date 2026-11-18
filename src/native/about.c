// What settings' About shows of the build and the system (shell's settings::About,
// filled by app.goose): the version and commit the build scripts write into
// build/draughts_version.c (scripts/native.py), the system's name and version and the
// CPU's, and the GPU's name.
//
// The GPU's name comes from Metal on Apple's systems and from Vulkan elsewhere, asked
// once, the first time About opens: Vulkan's needs an instance of its own (gfx's SDL
// device keeps its name to itself), a few milliseconds. The first GPU listed, a discrete
// one before any other, as SDL picks.
#include "platform.h"
#include <stdint.h>
#include <stdio.h>
#include <string.h>

extern const char draughts_version_name[], draughts_commit[], draughts_commit_date[];

typedef struct { uint8_t *data; int64_t len; } draughts_bytes;

static int64_t put(draughts_bytes out, const char *text) {
    int64_t n = (int64_t)strlen(text);
    if (n > out.len) n = out.len;
    memcpy(out.data, text, (size_t)n);
    return n;
}

// "version|commit|date".
int64_t draughts_about_build(draughts_bytes out) {
    char text[128];
    snprintf(text, sizeof text, "%s|%s|%s", draughts_version_name, draughts_commit,
             draughts_commit_date);
    return put(out, text);
}

#if defined(__aarch64__) || defined(_M_ARM64)
#define CPU "arm64"
#elif defined(__x86_64__) || defined(_M_X64)
#define CPU "x64"
#else
#define CPU "?"
#endif

#if defined(__APPLE__)
#include <objc/message.h>
#include <objc/runtime.h>
#include <sys/sysctl.h>
#elif defined(__ANDROID__)
#include <sys/system_properties.h>
#elif defined(_WIN32)
#include <windows.h>
#else
#include <sys/utsname.h>
#endif

// The system's name and version and the CPU's: "macOS 26.1 · arm64".
int64_t draughts_about_system(draughts_bytes out) {
    char text[160] = "";
#if defined(__APPLE__)
    char version[32] = "?";
    size_t size = sizeof version;
    sysctlbyname("kern.osproductversion", version, &size, 0, 0);
    snprintf(text, sizeof text, "%s %s \xC2\xB7 " CPU, DRAUGHTS_IOS ? "iOS" : "macOS", version);
#elif defined(__ANDROID__)
    char release[PROP_VALUE_MAX] = "?";
    __system_property_get("ro.build.version.release", release);
    snprintf(text, sizeof text, "Android %s \xC2\xB7 " CPU, release);
#elif defined(_WIN32)
    // RtlGetVersion, as GetVersionEx says 8 to a program without a manifest saying more.
    typedef struct {
        ULONG size, major, minor, build, platform;
        WCHAR service_pack[128];
    } Version;
    Version v = {.size = sizeof v};
    HMODULE ntdll = GetModuleHandleA("ntdll.dll");
    LONG (WINAPI *get)(Version *) = ntdll ? (LONG (WINAPI *)(Version *))GetProcAddress(ntdll, "RtlGetVersion") : 0;
    if (get) get(&v);
    // Windows 11 still says 10.0, told by its build from 22000.
    snprintf(text, sizeof text, "Windows %s (%lu) \xC2\xB7 " CPU, v.major == 10 && v.build >= 22000 ? "11" : v.major == 10 ? "10" : "?",
             (unsigned long)v.build);
#else
    // The distribution's name and version, else the kernel's.
    char name[96] = "";
    FILE *f = fopen("/etc/os-release", "r");
    if (f) {
        char line[256];
        while (fgets(line, sizeof line, f)) {
            if (strncmp(line, "PRETTY_NAME=", 12) != 0) continue;
            char *s = line + 12, *e = s + strcspn(s, "\n");
            if (*s == '"') ++s;
            if (e > s && e[-1] == '"') --e;
            snprintf(name, sizeof name, "%.*s", (int)(e - s), s);
        }
        fclose(f);
    }
    struct utsname u;
    if (!name[0] && uname(&u) == 0) snprintf(name, sizeof name, "Linux %s", u.release);
    snprintf(text, sizeof text, "%s \xC2\xB7 " CPU, name[0] ? name : "Linux");
#endif
    return put(out, text);
}

#if defined(__APPLE__)
#include <dlfcn.h>

// Metal is looked up: on the Mac the program's C links on its own, without the framework.
static void gpu_name(char *text, size_t size) {
    void *(*default_device)(void) = (void *(*)(void))dlsym(RTLD_DEFAULT, "MTLCreateSystemDefaultDevice");
    void *device = default_device ? default_device() : 0;
    if (!device) return;
    void *name = ((void *(*)(void *, SEL))objc_msgSend)(device, sel_registerName("name"));
    const char *s = name ? ((const char *(*)(void *, SEL))objc_msgSend)(name, sel_registerName("UTF8String")) : 0;
    if (s) snprintf(text, size, "%s", s);
    ((void (*)(void *, SEL))objc_msgSend)(device, sel_registerName("release"));
}
#else
#define VK_NO_PROTOTYPES
#include "vulkan/vulkan_core.h"
#if defined(_WIN32)
#define LOAD_VULKAN() ((void *)LoadLibraryA("vulkan-1.dll"))
#define VULKAN_PROC(lib, name) ((void *)GetProcAddress((HMODULE)(lib), name))
#define FREE_VULKAN(lib) FreeLibrary((HMODULE)(lib))
#else
#include <dlfcn.h>
#if defined(__ANDROID__)
#define LOAD_VULKAN() dlopen("libvulkan.so", RTLD_NOW | RTLD_LOCAL)
#else
#define LOAD_VULKAN() dlopen("libvulkan.so.1", RTLD_NOW | RTLD_LOCAL)
#endif
#define VULKAN_PROC(lib, name) dlsym(lib, name)
#define FREE_VULKAN(lib) dlclose(lib)
#endif

static void gpu_name(char *text, size_t size) {
    void *lib = LOAD_VULKAN();
    if (!lib) return;
    PFN_vkGetInstanceProcAddr proc = (PFN_vkGetInstanceProcAddr)VULKAN_PROC(lib, "vkGetInstanceProcAddr");
    PFN_vkCreateInstance create = proc ? (PFN_vkCreateInstance)proc(0, "vkCreateInstance") : 0;
    VkApplicationInfo app = {.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO, .apiVersion = VK_API_VERSION_1_0};
    VkInstanceCreateInfo info = {.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO, .pApplicationInfo = &app};
    VkInstance instance = 0;
    if (create && create(&info, 0, &instance) == VK_SUCCESS) {
        PFN_vkDestroyInstance destroy = (PFN_vkDestroyInstance)proc(instance, "vkDestroyInstance");
        PFN_vkEnumeratePhysicalDevices devices = (PFN_vkEnumeratePhysicalDevices)proc(instance, "vkEnumeratePhysicalDevices");
        PFN_vkGetPhysicalDeviceProperties properties =
            (PFN_vkGetPhysicalDeviceProperties)proc(instance, "vkGetPhysicalDeviceProperties");
        VkPhysicalDevice list[16];
        uint32_t count = 16;
        if (!devices || !properties || devices(instance, &count, list) < 0) count = 0;
        for (uint32_t i = 0; i < count; ++i) {
            VkPhysicalDeviceProperties p;
            properties(list[i], &p);
            if (i == 0 || p.deviceType == VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) snprintf(text, size, "%s", p.deviceName);
            if (p.deviceType == VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) break;
        }
        if (destroy) destroy(instance, 0);
    }
    FREE_VULKAN(lib);
}
#endif

// The GPU's name, "" where none is found; asked once.
int64_t draughts_about_gpu(draughts_bytes out) {
    static char text[256];
    static int asked;
    if (!asked) {
        asked = 1;
        gpu_name(text, sizeof text);
    }
    return put(out, text);
}

// Whether the system's battery saver is on: 1 on, 0 off, -1 where it can't be asked
// (Linux, an older macOS). Android's power save mode (PowerManager.isPowerSaveMode),
// Apple's Low Power Mode (NSProcessInfo, macOS 12 and iOS), Windows' battery saver
// (GetSystemPowerStatus). Cheap: asked at start and whenever the app gets the focus back.
#if defined(__ANDROID__)
#include <jni.h>
extern void *SDL_GetAndroidJNIEnv(void);
extern void *SDL_GetAndroidActivity(void);

int64_t draughts_battery_saver(void) {
    JNIEnv *env = (JNIEnv *)SDL_GetAndroidJNIEnv();
    jobject activity = (jobject)SDL_GetAndroidActivity();
    if (!env || !activity) return -1;
    int64_t on = -1;
    jclass cls = (*env)->GetObjectClass(env, activity);
    jmethodID service = (*env)->GetMethodID(env, cls, "getSystemService", "(Ljava/lang/String;)Ljava/lang/Object;");
    jstring name = (*env)->NewStringUTF(env, "power");
    jobject power = service && name ? (*env)->CallObjectMethod(env, activity, service, name) : 0;
    if ((*env)->ExceptionCheck(env)) (*env)->ExceptionClear(env);
    if (power) {
        jclass pm = (*env)->GetObjectClass(env, power);
        jmethodID saving = (*env)->GetMethodID(env, pm, "isPowerSaveMode", "()Z");
        if (saving) on = (*env)->CallBooleanMethod(env, power, saving) ? 1 : 0;
        if ((*env)->ExceptionCheck(env)) {
            (*env)->ExceptionClear(env);
            on = -1;
        }
        (*env)->DeleteLocalRef(env, pm);
        (*env)->DeleteLocalRef(env, power);
    }
    if (name) (*env)->DeleteLocalRef(env, name);
    (*env)->DeleteLocalRef(env, cls);
    (*env)->DeleteLocalRef(env, activity);
    return on;
}
#elif defined(__APPLE__)
int64_t draughts_battery_saver(void) {
    id (*send)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
    id info = send((id)objc_getClass("NSProcessInfo"), sel_registerName("processInfo"));
    SEL low = sel_registerName("isLowPowerModeEnabled");
    if (!info || !((bool (*)(id, SEL, SEL))objc_msgSend)(info, sel_registerName("respondsToSelector:"), low)) return -1;
    return ((bool (*)(id, SEL))objc_msgSend)(info, low) ? 1 : 0;
}
#elif defined(_WIN32)
int64_t draughts_battery_saver(void) {
    SYSTEM_POWER_STATUS status;
    if (!GetSystemPowerStatus(&status)) return -1;
    return status.SystemStatusFlag == 1 ? 1 : 0;
}
#else
int64_t draughts_battery_saver(void) { return -1; }
#endif

// The display's refresh rate in Hz, 0 where SDL doesn't know: as display.c finds SDL.
#if DRAUGHTS_SDL_LINKED
typedef struct SDL_Window SDL_Window;
typedef uint32_t SDL_DisplayID;
typedef struct {
    SDL_DisplayID displayID;
    uint32_t format;
    int w, h;
    float pixel_density, refresh_rate;
    int refresh_rate_numerator, refresh_rate_denominator;
    void *internal;
} SDL_DisplayMode;
extern SDL_Window **SDL_GetWindows(int *count);
extern void SDL_free(void *mem);
extern SDL_DisplayID SDL_GetDisplayForWindow(SDL_Window *window);
extern const SDL_DisplayMode *SDL_GetCurrentDisplayMode(SDL_DisplayID display);
#define LOOK(name) name
#else
#include <dlfcn.h>
typedef struct SDL_Window SDL_Window;
typedef uint32_t SDL_DisplayID;
typedef struct {
    SDL_DisplayID displayID;
    uint32_t format;
    int w, h;
    float pixel_density, refresh_rate;
    int refresh_rate_numerator, refresh_rate_denominator;
    void *internal;
} SDL_DisplayMode;
#define LOOK(name) ((name##_t *)dlsym(RTLD_DEFAULT, #name))
typedef SDL_Window **SDL_GetWindows_t(int *count);
typedef void SDL_free_t(void *mem);
typedef SDL_DisplayID SDL_GetDisplayForWindow_t(SDL_Window *window);
typedef const SDL_DisplayMode *SDL_GetCurrentDisplayMode_t(SDL_DisplayID display);
#endif

float draughts_about_refresh(void) {
    SDL_Window **(*get_windows)(int *) = LOOK(SDL_GetWindows);
    void (*sdl_free)(void *) = LOOK(SDL_free);
    SDL_DisplayID (*display_for)(SDL_Window *) = LOOK(SDL_GetDisplayForWindow);
    const SDL_DisplayMode *(*mode_of)(SDL_DisplayID) = LOOK(SDL_GetCurrentDisplayMode);
    if (!get_windows || !sdl_free || !display_for || !mode_of) return 0.0f;
    int n = 0;
    SDL_Window **windows = get_windows(&n);
    SDL_Window *window = windows && n > 0 ? windows[0] : 0;
    if (windows) sdl_free(windows);
    const SDL_DisplayMode *mode = window ? mode_of(display_for(window)) : 0;
    return mode ? mode->refresh_rate : 0.0f;
}
