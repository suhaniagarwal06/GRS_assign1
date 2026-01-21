#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "MT25046_Part_B_Workers.h"

typedef struct {
    int id;
    char worker[8];
} thread_arg_t;

static void *thread_func(void *arg) {
    thread_arg_t *t = (thread_arg_t *)arg;

    if (strcmp(t->worker, "cpu") == 0) cpu_worker(t->id);
    else if (strcmp(t->worker, "mem") == 0) mem_worker(t->id);
    else if (strcmp(t->worker, "io") == 0) io_worker(t->id);

    return NULL;
}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "Usage: %s <num_threads> <cpu|mem|io>\n", argv[0]);
        return 1;
    }

    int n = atoi(argv[1]);
    const char *worker = argv[2];

    if (n <= 0) {
        fprintf(stderr, "num_threads must be > 0\n");
        return 1;
    }

    pthread_t *threads = malloc(sizeof(pthread_t) * n);
    thread_arg_t *args = malloc(sizeof(thread_arg_t) * n);

    if (!threads || !args) {
        perror("malloc failed");
        return 1;
    }

    for (int i = 0; i < n; i++) {
        args[i].id = i;
        strncpy(args[i].worker, worker, sizeof(args[i].worker) - 1);
        args[i].worker[sizeof(args[i].worker) - 1] = '\0';

        if (pthread_create(&threads[i], NULL, thread_func, &args[i]) != 0) {
            perror("pthread_create failed");
            return 1;
        }
    }

    for (int i = 0; i < n; i++) {
        pthread_join(threads[i], NULL);
    }

    free(threads);
    free(args);
    return 0;
}
