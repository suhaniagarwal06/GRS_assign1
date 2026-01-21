#include "workers.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>

#define LOOPS 6000   // roll no 25046 => 6 * 10^3

// ---------------- CPU WORKER ----------------
void cpu_worker(int id) {
    (void)id; // unused

    long total = LOOPS * 20000; // scale so CPU usage is visible

    volatile double x = 0.0;
    for (long i = 0; i < total; i++) {
        x += (i % 97) * 0.000001;
        x *= 1.0000001;
        if (x > 1e9) x = 0.0;
    }
}

// ---------------- MEM WORKER ----------------
void mem_worker(int id) {
    (void)id;

    size_t size_mb = 150; // safe for VM
    size_t size = size_mb * 1024 * 1024;

    char *buf = (char *)malloc(size);
    if (!buf) {
        perror("malloc failed");
        return;
    }

    // Touch pages to force RSS allocation
    for (size_t i = 0; i < size; i += 4096) {
        buf[i] = (char)(i % 256);
    }

    volatile uint64_t sum = 0;
    long total = LOOPS * 5000;

    for (long i = 0; i < total; i++) {
        size_t idx = (size_t)(i * 4096) % size;
        sum += (unsigned char)buf[idx];
        buf[idx] = (char)(sum % 256);
    }

    if (sum == 123456789) {
        printf("sum=%llu\n", (unsigned long long)sum);
    }

    free(buf);
}

// ---------------- IO WORKER ----------------
void io_worker(int id) {
    // Unique filename per worker
    pid_t pid = getpid();

    char filename[128];
    snprintf(filename, sizeof(filename), "iofile_%d_%d.bin", pid, id);

    int fd = open(filename, O_CREAT | O_WRONLY | O_TRUNC, 0644);
    if (fd < 0) {
        perror("open failed");
        return;
    }

    size_t chunk = 4 * 1024 * 1024; // 4MB
    char *buffer = (char *)malloc(chunk);
    if (!buffer) {
        perror("malloc buffer failed");
        close(fd);
        return;
    }
    memset(buffer, 'A', chunk);

    size_t total_write = 100 * 1024 * 1024; // 100MB
    int repeats = 4; // make IO visible

    for (int r = 0; r < repeats; r++) {
        size_t written = 0;
        while (written < total_write) {
            ssize_t w = write(fd, buffer, chunk);
            if (w < 0) {
                perror("write failed");
                break;
            }
            written += (size_t)w;
        }

        // Force disk IO (important!)
        fsync(fd);
        lseek(fd, 0, SEEK_SET);
    }

    free(buffer);
    close(fd);

    unlink(filename);
}

