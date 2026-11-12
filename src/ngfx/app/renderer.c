// What the build holding both renderers asks before it opens a window (task 073): whether
// this system can run NoGraphicsAPI at all, from what can be asked without a window or a
// device, and which GPU and driver it would run on, for the crash marker's key; and the
// window shown once ngfx has opened it hidden. scripts/ngfx.py adds this file to the
// sidecar's c_sources, with the app's version written in for @VERSION@.
#include "platform.h"
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef struct { uint8_t *data; int64_t len; } draughts_bytes;

// The app's version and the commit it was built from (scripts/ngfx.py).
static const char version[] = "@VERSION@";

// Which system this is: 0 macOS, 1 Windows, 2 Linux, 3 iOS.
int64_t draughts_os(void) {
#if defined(_WIN32)
    return 1;
#elif DRAUGHTS_IOS
    return 3;
#elif defined(__APPLE__)
    return 0;
#else
    return 2;
#endif
}

static int64_t put(draughts_bytes out, const char *text) {
    int64_t n = (int64_t)strlen(text);
    if (n > out.len) n = out.len;
    memcpy(out.data, text, (size_t)n);
    return n;
}

#if defined(__APPLE__)
#include <objc/message.h>
#include <objc/runtime.h>
#include <sys/sysctl.h>

extern void *MTLCreateSystemDefaultDevice(void);
enum { FAMILY_APPLE7 = 1007, FAMILY_METAL4 = 5002 };

// NoGraphicsAPI's Metal backend needs Metal 4 (macOS and iOS 26) and an Apple7 GPU (A14,
// M1). Writes "GPU|OS version|app" or why not into out; returns its length, negative
// when ngfx can't run here.
int64_t draughts_ngfx_check(draughts_bytes out) {
    if (!__builtin_available(macOS 26.0, iOS 26.0, *)) return -put(out, "Metal 4 needs macOS or iOS 26");
    void *device = MTLCreateSystemDefaultDevice();
    if (!device) return -put(out, "no Metal device");
    SEL supports = sel_registerName("supportsFamily:");
    bool (*family)(void *, SEL, long) = (bool (*)(void *, SEL, long))objc_msgSend;
    void *name = ((void *(*)(void *, SEL))objc_msgSend)(device, sel_registerName("name"));
    const char *gpu = name ? ((const char *(*)(void *, SEL))objc_msgSend)(name, sel_registerName("UTF8String")) : "?";
    char os[32] = "?";
    size_t size = sizeof os;
    sysctlbyname("kern.osproductversion", os, &size, 0, 0);
    char text[512];
    bool ok = family(device, supports, FAMILY_APPLE7) && family(device, supports, FAMILY_METAL4);
    if (ok) snprintf(text, sizeof text, "%s|%s|%s", gpu, os, version);
    else snprintf(text, sizeof text, "%s is not an Apple7 GPU with Metal 4", gpu);
    ((void (*)(void *, SEL))objc_msgSend)(device, sel_registerName("release"));
    return ok ? put(out, text) : -put(out, text);
}
#else
#define VK_NO_PROTOTYPES
#include "vulkan/vulkan_core.h"
#if defined(_WIN32)
#include <windows.h>
#define LOAD_VULKAN() ((void *)LoadLibraryA("vulkan-1.dll"))
#define VULKAN_PROC(lib, name) ((void *)GetProcAddress((HMODULE)(lib), name))
#define FREE_VULKAN(lib) FreeLibrary((HMODULE)(lib))
#else
#include <dlfcn.h>
#define LOAD_VULKAN() dlopen("libvulkan.so.1", RTLD_NOW | RTLD_LOCAL)
#define VULKAN_PROC(lib, name) dlsym(lib, name)
#define FREE_VULKAN(lib) dlclose(lib)
#endif

// The device extensions NoGraphicsAPI requires (its docs/vulkan-support.md).
static const char *const needed[] = {"VK_EXT_descriptor_heap", "VK_KHR_device_address_commands",
                                     "VK_KHR_shader_untyped_pointers", "VK_EXT_mesh_shader"};

static bool has_all(VkPhysicalDevice device, PFN_vkEnumerateDeviceExtensionProperties extensions) {
    VkExtensionProperties list[512];
    uint32_t count = 512;
    if (extensions(device, 0, &count, list) < 0) return false;
    for (size_t i = 0; i < sizeof needed / sizeof needed[0]; ++i) {
        bool found = false;
        for (uint32_t j = 0; j < count && !found; ++j) found = strcmp(list[j].extensionName, needed[i]) == 0;
        if (!found) return false;
    }
    return true;
}

// NoGraphicsAPI's Vulkan backend needs a 1.4 loader and a 1.4 device with its four
// extensions; the rest (swapchain maintenance with a surface, the core features) it checks
// as it makes its device. Writes "GPU|driver|app" of the first device that passes, or why
// none does, into out; returns its length, negative when ngfx can't run here.
int64_t draughts_ngfx_check(draughts_bytes out) {
    void *lib = LOAD_VULKAN();
    if (!lib) return -put(out, "no Vulkan loader");
    PFN_vkGetInstanceProcAddr proc = (PFN_vkGetInstanceProcAddr)VULKAN_PROC(lib, "vkGetInstanceProcAddr");
    PFN_vkEnumerateInstanceVersion instance_version =
        proc ? (PFN_vkEnumerateInstanceVersion)proc(0, "vkEnumerateInstanceVersion") : 0;
    uint32_t api = 0;
    const uint32_t v14 = VK_MAKE_API_VERSION(0, 1, 4, 0);
    char text[512];
    int64_t result;
    if (!instance_version || instance_version(&api) != VK_SUCCESS || api < v14) {
        result = -put(out, "Vulkan's loader is older than 1.4");
        FREE_VULKAN(lib);
        return result;
    }
    PFN_vkCreateInstance create = (PFN_vkCreateInstance)proc(0, "vkCreateInstance");
    VkApplicationInfo app = {.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO, .apiVersion = v14};
    VkInstanceCreateInfo info = {.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO, .pApplicationInfo = &app};
    VkInstance instance = 0;
    if (!create || create(&info, 0, &instance) != VK_SUCCESS) {
        result = -put(out, "no Vulkan 1.4 instance");
        FREE_VULKAN(lib);
        return result;
    }
    PFN_vkDestroyInstance destroy = (PFN_vkDestroyInstance)proc(instance, "vkDestroyInstance");
    PFN_vkEnumeratePhysicalDevices devices = (PFN_vkEnumeratePhysicalDevices)proc(instance, "vkEnumeratePhysicalDevices");
    PFN_vkGetPhysicalDeviceProperties properties = (PFN_vkGetPhysicalDeviceProperties)proc(instance, "vkGetPhysicalDeviceProperties");
    PFN_vkEnumerateDeviceExtensionProperties extensions =
        (PFN_vkEnumerateDeviceExtensionProperties)proc(instance, "vkEnumerateDeviceExtensionProperties");
    VkPhysicalDevice list[16];
    uint32_t count = 16;
    if (!devices || devices(instance, &count, list) < 0) count = 0;
    snprintf(text, sizeof text, "no Vulkan 1.4 GPU with VK_EXT_descriptor_heap and NoGraphicsAPI's other extensions");
    bool ok = false;
    for (uint32_t i = 0; i < count && !ok; ++i) {
        VkPhysicalDeviceProperties p;
        properties(list[i], &p);
        if (p.apiVersion < v14 || !has_all(list[i], extensions)) continue;
        snprintf(text, sizeof text, "%s|%08x|%s", p.deviceName, p.driverVersion, version);
        ok = true;
    }
    destroy(instance, 0);
    FREE_VULKAN(lib);
    return ok ? put(out, text) : -put(out, text);
}
#endif

// The program's one window shown: ngfx's start opens it hidden (gfx's WINDOW_HIDDEN), and
// shows it once ngfx draws into it. SDL is found as display.c finds it (platform.h).
#if DRAUGHTS_SDL_LINKED
typedef struct SDL_Window SDL_Window;
extern SDL_Window **SDL_GetWindows(int *count);
extern bool SDL_ShowWindow(SDL_Window *window);
extern void SDL_free(void *memory);
#define SDL_FN(type, name) ((type)name)
#else
#include <dlfcn.h>
#define SDL_FN(type, name) ((type)dlsym(RTLD_DEFAULT, #name))
#endif

void draughts_show_window(void) {
    void **(*get_windows)(int *) = SDL_FN(void **(*)(int *), SDL_GetWindows);
    bool (*show)(void *) = SDL_FN(bool (*)(void *), SDL_ShowWindow);
    void (*sdl_free)(void *) = SDL_FN(void (*)(void *), SDL_free);
    if (!get_windows || !show || !sdl_free) return;
    int count = 0;
    void **all = get_windows(&count);
    if (!all) return;
    if (count > 0) show(all[0]);
    sdl_free(all);
}
