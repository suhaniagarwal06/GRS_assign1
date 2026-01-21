CC=gcc
CFLAGS=-Wall -Wextra -O2
LDFLAGS=-pthread

all: program_a program_b

program_a: program_a.c workers.c workers.h
	$(CC) $(CFLAGS) -o program_a program_a.c workers.c

program_b: program_b.c workers.c workers.h
	$(CC) $(CFLAGS) $(LDFLAGS) -o program_b program_b.c workers.c

clean:
	rm -f program_a program_b *.o *.tmp
	rm -rf measurements
