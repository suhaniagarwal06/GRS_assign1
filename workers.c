#include "workers.h"
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>

/**
 * CPU-intensive worker:
 * Uses arithmetic operations that keep CPU busy (stable CPU load).
 */
void cpu_worker(int id) {
    (void)id;

    volatile double x = 1.000001;
    volatile double y = 1.0000001;

    for (int i = 0; i < LOOP_COUNT * 5000; i++) {
        x = x * 1.0000001 + y;
        y = y * 0.9999999 + x;

        if (x > 1e6) x = 1.000001;
        if (y > 1e6) y = 1.0000001;
    }
}

/**
 * Memory-intensive worker:
 * Allocates large memory ONCE and repeatedly touches it (bandwidth bound).
 */
void mem_worker(int id) {
    (void)id;

    size_t bytes = 128UL * 1024 * 1024; // 128MB
    char *buf = (char *)malloc(bytes);

    if (!buf) {
        perror("malloc failed in mem_worker");
        return;
    }

    memset(buf, 1, bytes);

    for (int i = 0; i < LOOP_COUNT * 50; i++) {
        for (size_t j = 0; j < bytes; j += 64) { // cache-line stride
            buf[j] = (char)(buf[j] + 1);
        }
    }

    free(buf);
}

/**
 * I/O-intensive worker:
 * Writes + fsync + reads large blocks to force real disk activity.
 */
void io_worker(int id) {
    char filename[256];
    snprintf(filename, sizeof(filename), "io_worker_%d.tmp", id);

    const size_t block_size = 4 * 1024 * 1024; // 4MB
    char *buf = (char *)malloc(block_size);

    if (!buf) {
        perror("malloc failed in io_worker");
        return;
    }

    memset(buf, 'A' + (id % 26), block_size);

    int fd = open(filename, O_CREAT | O_TRUNC | O_RDWR, 0644);
    if (fd < 0) {
        perror("open failed in io_worker");
        free(buf);
        return;
    }

    for (int i = 0; i < LOOP_COUNT; i++) {
        ssize_t w = write(fd, buf, block_size);
        if (w < 0) {
            perror("write failed");
            break;
        }

        fsync(fd);
        lseek(fd, 0, SEEK_SET);

        ssize_t r = read(fd, buf, block_size);
        if (r < 0) {
            perror("read failed");
            break;
        }

        lseek(fd, 0, SEEK_SET);
    }

    close(fd);
    remove(filename);
    free(buf);
}
