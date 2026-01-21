CC=gcc
CFLAGS=-Wall -Wextra -O2
LDFLAGS=-pthread

# BINARIES (The output executable names don't need to change)
all: program_a program_b

# Update: 'program_a.c' -> 'MT25046_Part_A_Program_A.c'
# Update: 'workers.c'   -> 'MT25046_Part_B_Workers.c'
# Update: 'workers.h'   -> 'MT25046_Part_B_Workers.h'

program_a: MT25046_Part_A_Program_A.c MT25046_Part_B_Workers.c MT25046_Part_B_Workers.h
	$(CC) $(CFLAGS) -o program_a MT25046_Part_A_Program_A.c MT25046_Part_B_Workers.c

program_b: MT25046_Part_A_Program_B.c MT25046_Part_B_Workers.c MT25046_Part_B_Workers.h
	$(CC) $(CFLAGS) $(LDFLAGS) -o program_b MT25046_Part_A_Program_B.c MT25046_Part_B_Workers.c

clean:
	rm -f program_a program_b *.o *.tmp
	rm -rf measurements
