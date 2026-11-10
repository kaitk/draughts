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
// (flags.goose), which measures the app at rest where Instruments can't.
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
#else
double draughts_footprint_mb(void) { return -1.0; }
#endif
