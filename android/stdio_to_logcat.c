/* Android discards a process's stdout and stderr, where Goose's print, abort, and runtime
   errors go. This forwards both to logcat under the tag "goose", line by line, from a
   thread started before SDL_main runs. */
#include <android/log.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static int pipe_fds[2];

static void *forward(void *unused) {
    (void)unused;
    char buf[1024];
    size_t len = 0;
    for (;;) {
        ssize_t n = read(pipe_fds[0], buf + len, sizeof buf - 1 - len);
        if (n <= 0) break;
        len += (size_t)n;
        char *start = buf, *nl;
        while ((nl = memchr(start, '\n', len - (size_t)(start - buf)))) {
            *nl = 0;
            __android_log_write(ANDROID_LOG_INFO, "goose", start);
            start = nl + 1;
        }
        len -= (size_t)(start - buf);
        memmove(buf, start, len);
        if (len == sizeof buf - 1) {  /* a line longer than the buffer: flush it as is */
            buf[len] = 0;
            __android_log_write(ANDROID_LOG_INFO, "goose", buf);
            len = 0;
        }
    }
    return NULL;
}

__attribute__((constructor)) static void stdio_to_logcat(void) {
    setvbuf(stdout, NULL, _IOLBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);
    if (pipe(pipe_fds) != 0) return;
    dup2(pipe_fds[1], STDOUT_FILENO);
    dup2(pipe_fds[1], STDERR_FILENO);
    pthread_t t;
    if (pthread_create(&t, NULL, forward, NULL) == 0) pthread_detach(t);
}
