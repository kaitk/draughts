// draughts_release_memory: gives back to the system the pages malloc keeps for blocks
// that were freed. Android's allocator (Scudo) keeps freed memory resident: small blocks'
// pages in its primary regions until Android purges them as the app goes to the
// background, and freed large blocks (up to 2 MB each) in its secondary cache, which
// that purge leaves. The launch frees about 16 MB of the two, so the program calls this
// once the launch's loads are done (task 032, leftovers): native heap at home 42.6 →
// 26.7 MB, about 2 ms on the tablet. Elsewhere it does nothing.

#if defined(__ANDROID__)
#include <malloc.h>

void draughts_release_memory(void) { mallopt(M_PURGE_ALL, 0); }
#else
void draughts_release_memory(void) {}
#endif
