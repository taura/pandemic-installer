all: sonic

CFLAGS = -Wall -O3 -g -static
LDFLAGS = -lpthread

sonic: sonic.c
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

