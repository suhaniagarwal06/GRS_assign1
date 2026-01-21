#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#include "MT25046_Part_B_Workers.h"

static void run_worker(const char *worker, int id) {
    if (strcmp(worker, "cpu") == 0) cpu_worker(id);
    else if (strcmp(worker, "mem") == 0) mem_worker(id);
    else if (strcmp(worker, "io") == 0) io_worker(id);
    else {
        fprintf(stderr, "Invalid worker type: %s\n", worker);
        exit(1);
    }
}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "Usage: %s <num_processes> <cpu|mem|io>\n", argv[0]);
        return 1;
    }

    int n = atoi(argv[1]);
    const char *worker = argv[2];

    if (n <= 0) {
        fprintf(stderr, "num_processes must be > 0\n");
        return 1;
    }

    // Parent does not count. We create n CHILD processes.
    for (int i = 0; i < n; i++) {
        pid_t pid = fork();

        if (pid < 0) {
            perror("fork failed");
            exit(1);
        }

        if (pid == 0) {
            run_worker(worker, i);
            exit(0);
        }
    }

    // Parent waits
    for (int i = 0; i < n; i++) {
        wait(NULL);
    }

    return 0;
}
