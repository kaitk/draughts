// draughts_release_memory: gives back to the system the pages malloc keeps for blocks
// that were freed. Android's allocator (Scudo) keeps freed memory resident: small blocks'
// pages in its primary regions until Android purges them as the app goes to the
// background, and freed large blocks (up to 2 MB each) in its secondary cache, which
// that purge leaves. The launch frees about 16 MB of the two, so the program calls this
// once the launch's loads are done: native heap at home 42.6 → 26.7 MB, about 2 ms on
// the tablet (docs/architecture/rendering.md, GPU memory). Elsewhere it does nothing.

#if defined(__ANDROID__)
#include <malloc.h>

void draughts_release_memory(void) { mallopt(M_PURGE_ALL, 0); }
#else
void draughts_release_memory(void) {}
#endif

// draughts_cpu_seconds: the process's CPU time so far, user and system, in seconds; and
// draughts_footprint_mb: its memory as the system counts it against the app (Apple's
// phys_footprint, what Xcode's gauge shows), in MB, -1 where not had. For --rest
// (flags.goose), which measures the app at rest where Instruments can't. On Windows the
// footprint is the private bytes, what Task Manager's Memory column shows.
#if defined(_WIN32)
#define PSAPI_VERSION 2         // GetProcessMemoryInfo from kernel32, no psapi.lib
#include <windows.h>
#include <psapi.h>
#include <stdint.h>

double draughts_cpu_seconds(void) {
    FILETIME created, ended, kernel, user;
    if (!GetProcessTimes(GetCurrentProcess(), &created, &ended, &kernel, &user)) return -1.0;
    uint64_t k = ((uint64_t)kernel.dwHighDateTime << 32) | kernel.dwLowDateTime;
    uint64_t u = ((uint64_t)user.dwHighDateTime << 32) | user.dwLowDateTime;
    return (double)(k + u) / 1e7;      // 100 ns units
}

double draughts_footprint_mb(void) {
    PROCESS_MEMORY_COUNTERS_EX m;
    if (!GetProcessMemoryInfo(GetCurrentProcess(), (PROCESS_MEMORY_COUNTERS *)&m, sizeof m)) return -1.0;
    return (double)m.PrivateUsage / (1024.0 * 1024.0);
}

typedef struct { uint8_t *data; int64_t len; } draughts_text;
int64_t draughts_threads(draughts_text text) { (void)text; return 0; }
#else
#include <sys/resource.h>

double draughts_cpu_seconds(void) {
    struct rusage r;
    if (getrusage(RUSAGE_SELF, &r) != 0) return -1.0;
    return (double)(r.ru_utime.tv_sec + r.ru_stime.tv_sec) +
           (double)(r.ru_utime.tv_usec + r.ru_stime.tv_usec) / 1e6;
}

#if defined(__APPLE__)
#include <mach/mach.h>

double draughts_footprint_mb(void) {
    task_vm_info_data_t info;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    if (task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count) != KERN_SUCCESS)
        return -1.0;
    return (double)info.phys_footprint / (1024.0 * 1024.0);
}

// draughts_threads: each thread's name and CPU time so far, "name 1.23 s; ...", into the
// text (cut at its size); returns the length. For --rest, to find what is busy at rest.
#include <stdint.h>
#include <stdio.h>

typedef struct { uint8_t *data; int64_t len; } draughts_text;   // a Goose u8[:]

int64_t draughts_threads(draughts_text text) {
    char *out = (char *)text.data;
    long size = (long)text.len;
    thread_act_array_t threads;
    mach_msg_type_number_t n = 0;
    long len = 0;
    if (size <= 0 || task_threads(mach_task_self(), &threads, &n) != KERN_SUCCESS) return 0;
    for (mach_msg_type_number_t i = 0; i < n; i++) {
        thread_extended_info_data_t info;
        mach_msg_type_number_t count = THREAD_EXTENDED_INFO_COUNT;
        if (thread_info(threads[i], THREAD_EXTENDED_INFO, (thread_info_t)&info, &count) == KERN_SUCCESS) {
            double s = (double)(info.pth_user_time + info.pth_system_time) / 1e9;
            int w = snprintf(out + len, (size_t)(size - len), "%s%s %.2f s", len ? "; " : "",
                             info.pth_name[0] ? info.pth_name : "?", s);
            if (w > 0) len += w < size - len ? w : size - len - 1;
        }
        mach_port_deallocate(mach_task_self(), threads[i]);
    }
    vm_deallocate(mach_task_self(), (vm_address_t)threads, n * sizeof(thread_act_t));
    return len;
}
#else
double draughts_footprint_mb(void) { return -1.0; }
#include <stdint.h>
typedef struct { uint8_t *data; int64_t len; } draughts_text;
int64_t draughts_threads(draughts_text text) { (void)text; return 0; }
#endif
#endif
