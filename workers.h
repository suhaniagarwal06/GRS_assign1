#ifndef WORKERS_H
#define WORKERS_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define LOOP_COUNT 6000   // roll last digit 6 => 6 * 10^3

void cpu_worker(int id);
void mem_worker(int id);
void io_worker(int id);

#endif
