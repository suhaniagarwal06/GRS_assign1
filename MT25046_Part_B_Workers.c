#include "MT25046_Part_B_Workers.h"
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
/**
 * Performs heavy floating-point calculations to stress the CPU.
 * This worker is designed to consume significant CPU cycles without
 * waiting on I/O or memory operations.
 * 
 * Characteristics:
 * - High CPU usage (~100% per process/thread)
 * - Low memory usage
 * - No I/O operations
 * 
 */
void cpu_worker(int id) {
    (void)id; // unused

    long total = LOOPS * 20000; // scale so CPU usage is visible
    // Total iterations: 6000 × 20000 = 120,000,000

    // Use volatile to prevent compiler optimization
    volatile double x = 0.0;
    // Perform intensive floating-point arithmetic
    for (long i = 0; i < total; i++) {
        x += (i % 97) * 0.000001;
        x *= 1.0000001;
        
        // Reset to prevent overflow
        if (x > 1e9) x = 0.0;
    }
}

// ---------------- MEM WORKER ----------------
/**
 * Allocates a large memory buffer and performs random memory accesses.
 * This worker stresses the memory subsystem by forcing cache misses
 * and working with a large resident set size (RSS).
 * 
 * Characteristics:
 * - Moderate CPU usage
 * - High memory usage (~150 MB per worker)
 * - No I/O operations
 * - Random access pattern to stress memory bandwidth
 * 
 */
void mem_worker(int id) {
    (void)id;
    
    // Allocate 150 MB buffer (safe for most VMs)
    size_t size_mb = 150; // safe for VM
    size_t size = size_mb * 1024 * 1024;
    
   // Allocate memory
    char *buf = (char *)malloc(size);
    if (!buf) {
        perror("malloc failed");
        return;
    }

    // Touch pages to force RSS allocation
    for (size_t i = 0; i < size; i += 4096) {
        buf[i] = (char)(i % 256);
    }
    
    // Perform memory-intensive operations
    // Total iterations: 6000 × 5000 = 30,000,000
    volatile uint64_t sum = 0;
    long total = LOOPS * 5000;

    for (long i = 0; i < total; i++) {
    // Access memory at 4KB intervals to cause cache misses
        size_t idx = (size_t)(i * 4096) % size;
        sum += (unsigned char)buf[idx];
        buf[idx] = (char)(sum % 256);
    }

    // Prevent compiler optimization (unlikely condition)
    if (sum == 123456789) {
        printf("sum=%llu\n", (unsigned long long)sum);
    }

    // Free allocated memory
    free(buf);
}

// ---------------- IO WORKER ----------------
/**
 * Performs heavy disk I/O operations by writing large amounts of data
 * and forcing synchronization with fsync(). This worker is designed to
 * stress the disk I/O subsystem.
 * 
 * Characteristics:
 * - Low CPU usage (most time waiting for I/O)
 * - Low memory usage
 * - High I/O throughput (writes 400 MB total per worker)
 * - Uses fsync() to force actual disk writes (critical for measurement!)
 * 
 */
void io_worker(int id) {
    // Create unique filename using process ID and worker ID
    // This prevents conflicts when multiple workers run concurrently
    pid_t pid = getpid();

    char filename[128];
    snprintf(filename, sizeof(filename), "iofile_%d_%d.bin", pid, id);

    // Open file for writing
    int fd = open(filename, O_CREAT | O_WRONLY | O_TRUNC, 0644);
    if (fd < 0) {
        perror("open failed");
        return;
    }

    // Allocate 4 MB write buffer
    size_t chunk = 4 * 1024 * 1024; // 4MB
    char *buffer = (char *)malloc(chunk);
    if (!buffer) {
        perror("malloc buffer failed");
        close(fd);
        return;
    }
    
    // Fill buffer with data
    memset(buffer, 'A', chunk);

    // Write 100 MB per repeat cycle
    size_t total_write = 100 * 1024 * 1024; // 100MB
    int repeats = 4; // make IO visible

    // Perform multiple write cycles to make I/O activity visible in monitoring
    for (int r = 0; r < repeats; r++) {
        size_t written = 0;
        // Write 100 MB in 4 MB chunks
        while (written < total_write) {
            ssize_t w = write(fd, buffer, chunk);
            if (w < 0) {
                perror("write failed");
                break;
            }
            written += (size_t)w;
        }

        // CRITICAL: Force data to be written to disk
        // Without fsync(), data might stay in OS buffer cache and not hit the     disk
        // This ensures we measure actual I/O performance, not cache performance
        fsync(fd);
        
        // Seek back to beginning for next write cycle (overwrites previous data)
        lseek(fd, 0, SEEK_SET);
    }

    // Cleanup
    free(buffer);
    close(fd);

    // Delete the temporary file
    unlink(filename);
}

